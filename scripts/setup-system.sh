#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GIT_NAME:-}" || -z "${GIT_EMAIL:-}" ]]; then
  echo "Set GIT_NAME and GIT_EMAIL before running." >&2
  echo "Example: MACHINE=macbook GIT_NAME=\"your-name\" GIT_EMAIL=\"your-noreply@users.noreply.github.com\" ./scripts/setup-system.sh" >&2
  exit 1
fi

# Home Manager and its activation script invoke Nix themselves. CLI flags only
# affect the outer process; export the features so child processes inherit them.
export NIX_CONFIG="${NIX_CONFIG:-}"$'\nextra-experimental-features = nix-command flakes'

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/azzz9/dotfiles.git}"
DEFAULT_DOTFILES_DIR="${HOME}/src/github.com/azzz9/dotfiles"
MACHINE="${MACHINE:-}"

os_name="$(uname -s)"
arch="$(uname -m)"
should_reboot=0
linux_distribution=""

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [[ "$EUID" == 0 ]]; then
    "$@"
  elif command_exists sudo; then
    sudo "$@"
  else
    echo "System package setup needs administrator access. Run with sudo or from a root shell." >&2
    exit 1
  fi
}

dotfiles_dir() {
  printf '%s\n' "${DOTFILES_DIR:-$DEFAULT_DOTFILES_DIR}"
}

# Only x86_64 Linux and Apple Silicon macOS have machine rows, so reject any
# other OS/arch pair before touching the system.
check_supported_platform() {
  case "${os_name}:${arch}" in
    Linux:x86_64 | Darwin:arm64)
      ;;
    Darwin:x86_64)
      echo "Intel Mac (x86_64-darwin) is not supported. This flake only provides" >&2
      echo "an aarch64-darwin configuration." >&2
      exit 1
      ;;
    *)
      echo "Unsupported platform: ${os_name}:${arch}." >&2
      exit 1
      ;;
  esac
}

# The hostname, minus the .local suffix macOS reports its mDNS name with. The
# readiness check reads this, not the value the operator passed, so it reports
# the name the installed `dotfiles` will resolve.
hostname_name() {
  local name
  name="$(hostname)"
  printf '%s\n' "${name%.local}"
}

# The operator names the machine once, here. The hostname follows from it
# (sync_hostname below), so the `dotfiles` CLI resolves the same name with
# nothing passed in.
machine_name() {
  if [[ -z "$MACHINE" ]]; then
    echo "Set MACHINE to this machine's name, one of the machines rows in flake.nix." >&2
    echo "Example: MACHINE=macbook ./scripts/setup-system.sh" >&2
    exit 1
  fi

  printf '%s\n' "$MACHINE"
}

load_nix_profile() {
  local profiles=(
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    "${HOME}/.nix-profile/etc/profile.d/nix.sh"
  )
  local profile

  for profile in "${profiles[@]}"; do
    if [[ -r "$profile" ]]; then
      # shellcheck source=/dev/null
      . "$profile"
      return
    fi
  done
}

nix_cmd() {
  nix --extra-experimental-features "nix-command flakes" "$@"
}

ensure_bootstrap_tools() {
  local tool paths path
  local missing=()

  for tool in git curl; do
    if ! command_exists "$tool"; then
      missing+=("nixpkgs#$tool")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "Preparing missing bootstrap tools: ${missing[*]}"
    # Nix can fetch binary packages without Git or the curl executable. Add
    # their binaries for this run, without installing a separate user profile.
    paths="$(nix_cmd build --no-link --print-out-paths "${missing[@]}")"
    while IFS= read -r path; do
      if [[ -n "$path" ]]; then
        export PATH="$path/bin:$PATH"
      fi
    done <<< "$paths"
  fi

  for tool in git curl; do
    if ! command_exists "$tool"; then
      echo "Bootstrap tool is still unavailable after setup: $tool" >&2
      exit 1
    fi
  done
}

install_nix() {
  load_nix_profile

  if command_exists nix; then
    return
  fi

  if ! command_exists curl; then
    echo "curl is required to download Nix, but system package setup did not provide it." >&2
    exit 1
  fi

  echo "Installing Nix..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm

  load_nix_profile

  if ! command_exists nix; then
    echo "Nix was installed, but nix is still not available in PATH." >&2
    echo "Open a new shell and re-run this script." >&2
    exit 1
  fi
}

install_macos_packages() {
  if ! command_exists brew; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  brew update
  brew list zsh >/dev/null 2>&1 || brew install zsh
  brew list --cask font-udev-gothic-nf >/dev/null 2>&1 || brew install --cask font-udev-gothic-nf

  if ! brew list --cask docker >/dev/null 2>&1 && [[ ! -d /Applications/Docker.app ]]; then
    brew install --cask docker
  fi
}

install_linux_packages() {
  if [[ ! -r /etc/os-release ]]; then
    echo "/etc/os-release not found. Cannot detect Linux distribution." >&2
    exit 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  linux_distribution="${ID:-}"

  case "$linux_distribution" in
    nixos)
      load_nix_profile
      if ! command_exists nix; then
        echo "NixOS's system Nix is not available in PATH." >&2
        exit 1
      fi
      ;;
    ubuntu)
      run_as_root apt-get update
      run_as_root apt-get install -y ca-certificates curl gnupg lsb-release
      run_as_root install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | run_as_root gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
      run_as_root chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
        | run_as_root tee /etc/apt/sources.list.d/docker.list >/dev/null
      run_as_root apt-get update
      run_as_root apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      run_as_root systemctl enable --now docker
      run_as_root usermod -aG docker "$USER"
      run_as_root apt-get install -y zsh
      should_reboot=1
      ;;
    arch)
      run_as_root pacman -Syu --noconfirm
      run_as_root pacman -S --needed --noconfirm curl docker docker-compose-plugin zsh
      run_as_root systemctl enable --now docker
      run_as_root usermod -aG docker "$USER"
      should_reboot=1
      ;;
    *)
      echo "Unsupported Linux distribution: ${ID:-unknown}" >&2
      exit 1
      ;;
  esac
}

configure_zsh() {
  local zsh_path

  # NixOS manages login shells declaratively through users.users.<name>.shell.
  if [[ "$linux_distribution" == "nixos" ]]; then
    return
  fi

  if ! zsh_path="$(command -v zsh)"; then
    return
  fi

  if [[ "$os_name" == "Darwin" ]]; then
    if ! grep -qxF "$zsh_path" /etc/shells; then
      echo "$zsh_path" | run_as_root tee -a /etc/shells >/dev/null
    fi

    if [[ "$(basename "${SHELL:-}")" != "zsh" ]]; then
      chsh -s "$zsh_path" "$USER"
    fi
  else
    run_as_root chsh -s "$zsh_path" "$USER"
  fi
}

configure_git() {
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
}

ensure_dotfiles_repo() {
  local repo_dir="$1"

  if [[ -d "$repo_dir/.git" ]]; then
    return
  fi

  if [[ -e "$repo_dir" ]]; then
    echo "$repo_dir exists but is not a git repository." >&2
    exit 1
  fi

  mkdir -p "$(dirname "$repo_dir")"
  git clone "$DOTFILES_REPO_URL" "$repo_dir"
}

# The machines the repository carries, from the flake's own attr names. The
# machines row key is a homeConfigurations attribute, so this is the list the
# `dotfiles` CLI and its completion resolve a name against.
flake_machines() {
  local repo_dir="$1"

  nix_cmd eval --impure --raw \
    --apply 'names: builtins.concatStringsSep " " (builtins.attrNames names)' \
    "$repo_dir#homeConfigurations"
}

# MACHINE has to name a machine this repository can apply. NixOS adopts a name
# the repository does not carry yet, because the adoption writes the row. The
# other platforms have nothing that writes one, so a missing name stops the run
# before anything is installed or applied.
require_known_machine() {
  local repo_dir="$1"
  local machine="$2"
  local known=""
  local system="${arch}-linux"

  if ! known="$(flake_machines "$repo_dir")"; then
    echo "Could not read the machine list from the flake. Home Manager reports an unknown machine itself." >&2
    return 0
  fi

  if [[ " $known " == *" $machine "* ]]; then
    return 0
  fi

  if [[ "$linux_distribution" == "nixos" ]]; then
    echo "The repository does not carry '$machine' yet. The adoption below writes its row."
    return 0
  fi

  if [[ "$os_name" == "Darwin" ]]; then
    system="aarch64-darwin"
  fi

  echo "MACHINE names '$machine', which the repository does not carry." >&2
  echo "Machines in flake.nix: $known" >&2
  echo "Add this row to its machines block, then run the bootstrap again:" >&2
  echo "" >&2
  echo "        $machine = { system = \"$system\"; };" >&2
  exit 1
}

# nixos-generate-config writes three header comment lines, and its lambda
# pattern can name an argument the body never uses. deadnix fails on an unused
# named argument, so drop both. `...` stays, so the module keeps accepting
# whatever else the module system passes.
prune_generated_hardware_config() {
  local line header="" body="" arg names="" pattern=""
  local -a params=()
  local in_header=1 skip_comments=1

  while IFS= read -r line; do
    if [[ "$in_header" == 0 ]]; then
      body+="$line"$'\n'
      continue
    fi
    if [[ "$skip_comments" == 1 && "$line" == "#"* ]]; then
      continue
    fi
    skip_comments=0
    if [[ "$line" == *"}:"* ]]; then
      header="$line"
      in_header=0
    fi
  done

  header="${header#*\{}"
  header="${header%%\}*}"
  IFS=',' read -r -a params <<< "$header"
  for arg in "${params[@]}"; do
    arg="${arg//[[:space:]]/}"
    if [[ -z "$arg" || "$arg" == "..." ]]; then
      continue
    fi
    if grep -qw -- "$arg" <<< "$body"; then
      names+="${names:+, }$arg"
    fi
  done

  if [[ -n "$names" ]]; then
    pattern="{ $names, ... }"
  else
    pattern="{ ... }"
  fi

  printf '%s:\n%s' "$pattern" "$body"
}

# A NixOS machine whose system configuration is the repository's needs no
# /etc/nixos wiring, because nixosConfigurations.<machine> is the flake output.
# Adoption writes that machine into the repository from the installer's own
# configuration, so nothing has to be prepared by hand.
adopt_nixos_machine() {
  local repo_dir="$1"
  local machine="$2"
  local relative_dir="hosts/platform/nixos/machines/$machine"
  local machine_dir="$repo_dir/$relative_dir"
  local capability="" capability_reason="" marker="" generated="" line="" row=""
  local in_machines=0 inserted=0
  local in_users=0

  if [[ "$linux_distribution" != "nixos" ]]; then
    return 0
  fi

  if [[ -n "${MACHINE_CAPABILITY:-}" ]]; then
    case "$MACHINE_CAPABILITY" in
      desktop | headless)
        capability="$MACHINE_CAPABILITY"
        capability_reason="MACHINE_CAPABILITY=$MACHINE_CAPABILITY set it"
        ;;
      *)
        echo "MACHINE_CAPABILITY must be desktop or headless, not '$MACHINE_CAPABILITY'." >&2
        exit 1
        ;;
    esac
  fi

  if [[ -f "$machine_dir/default.nix" && -f "$machine_dir/hardware-configuration.nix" ]]; then
    echo "Machine '$machine' already has a system configuration. Left $relative_dir alone."
    return 0
  fi

  if [[ ! -f /etc/nixos/configuration.nix ]]; then
    echo "Cannot adopt this machine: /etc/nixos/configuration.nix is missing." >&2
    exit 1
  fi

  generated="$(run_as_root nixos-generate-config --show-hardware-config)"
  if [[ -z "$generated" ]]; then
    echo "nixos-generate-config returned no hardware configuration." >&2
    exit 1
  fi

  mkdir -p "$machine_dir"
  prune_generated_hardware_config <<< "$generated" > "$machine_dir/hardware-configuration.nix"

  # The generated default.nix owns the name. The user's shell leaves the copy as
  # well: NixOS gives that option the uniq type, so two definitions of it are an
  # error even when the values agree, and common.nix already defines it.
  while IFS= read -r line; do
    if [[ "$line" == "  users.users."* ]]; then
      in_users=1
    elif [[ "$in_users" == 1 && "$line" == "  };" ]]; then
      in_users=0
    fi
    if [[ "$line" =~ ^[[:space:]]*networking\.hostName[[:space:]]*= ]]; then
      continue
    fi
    if [[ "$in_users" == 1 && "$line" =~ ^[[:space:]]*shell[[:space:]]*= ]]; then
      continue
    fi
    printf '%s\n' "$line"
  done < /etc/nixos/configuration.nix > "$machine_dir/configuration.nix"

  if [[ -z "$capability" ]]; then
    capability="headless"
    capability_reason="the copied configuration drives no GUI"
    for marker in services.xserver services.displayManager services.desktopManager programs.hyprland programs.plasma; do
      if grep -qF -- "$marker" "$machine_dir/configuration.nix"; then
        capability="desktop"
        capability_reason="the copied configuration mentions $marker"
        break
      fi
    done
  fi

  cat > "$machine_dir/default.nix" <<EOF
{ ... }:

{
  imports = [
    ../../modules/common.nix
    ../../modules/$capability.nix
    ./configuration.nix
  ];

  networking.hostName = "$machine";
}
EOF

  # The row exposes nixosConfigurations.<machine>, which the switch below
  # evaluates. Anchor on the machines block, so the insert lands inside it.
  row="        $machine = { system = \"$arch-linux\"; nixos = ./$relative_dir; };"
  if grep -qE "^[[:space:]]*$machine = \\{" "$repo_dir/flake.nix"; then
    echo "flake.nix already carries the machines.$machine row. Left it alone."
  else
    while IFS= read -r line; do
      if [[ "$in_machines" == 1 && "$line" == "      };"* ]]; then
        printf '%s\n' "$row"
        in_machines=0
        inserted=1
      fi
      printf '%s\n' "$line"
      if [[ "$line" == "      machines = {"* ]]; then
        in_machines=1
      fi
    done < "$repo_dir/flake.nix" > "$repo_dir/flake.nix.new"

    if [[ "$inserted" == 0 ]]; then
      rm -f "$repo_dir/flake.nix.new"
      echo "Cannot find the machines block in flake.nix. Add this row to it:" >&2
      printf '%s\n' "$row" >&2
      exit 1
    fi
    mv "$repo_dir/flake.nix.new" "$repo_dir/flake.nix"
  fi

  # Nix sees tracked files only, and the system switch below evaluates the flake.
  git -C "$repo_dir" add -- "$relative_dir" flake.nix

  echo "Adopted machine '$machine'. Wrote:"
  echo "  $relative_dir/hardware-configuration.nix"
  echo "  $relative_dir/configuration.nix"
  echo "  $relative_dir/default.nix, importing $capability.nix because $capability_reason"
  echo "  flake.nix, with the machines.$machine row, then staged all four with git add"
}

apply_home_manager() {
  local repo_dir="$1"
  local machine="$2"

  DOTFILES_DIR="$repo_dir" nix_cmd run nixpkgs#home-manager -- switch --flake "$repo_dir#$machine" --impure -b backup
}

# Debian's installer points the 127.0.1.1 line at the name the machine had when
# it was installed, and tools that resolve through /etc/hosts, `hostname -f`
# included, still answer with that name. Read the file whole first, because tee
# truncates it while this runs.
rewrite_hosts_hostname() {
  local machine="$1"
  local line rest name
  local changed=0
  local -a lines=() rewritten=()

  [[ -r /etc/hosts ]] || return 0
  mapfile -t lines < /etc/hosts

  for line in "${lines[@]}"; do
    if [[ "$line" == "127.0.1.1" || "$line" == 127.0.1.1[[:space:]]* ]]; then
      rest="${line#127.0.1.1}"
      rest="${rest#"${rest%%[![:space:]]*}"}"
      name="${rest%%[[:space:]]*}"
      if [[ "$name" != "$machine" ]]; then
        line="127.0.1.1"$'\t'"$machine"
        changed=1
      fi
    fi
    rewritten+=("$line")
  done

  [[ "$changed" == 1 ]] || return 0
  printf '%s\n' "${rewritten[@]}" | run_as_root tee /etc/hosts >/dev/null
  echo "Pointed the 127.0.1.1 line of /etc/hosts at '$machine'."
}

# The installed `dotfiles` CLI reads the hostname, and the machines row key is
# the machine name, so the hostname has to be that name. NixOS is exempt: its
# machine configuration carries networking.hostName and the system switch
# applies it.
sync_hostname() {
  local machine="$1"
  local current
  local failed=0

  if [[ "$linux_distribution" == "nixos" ]]; then
    return 0
  fi

  current="$(hostname_name)"
  if [[ "$current" == "$machine" ]]; then
    return 0
  fi

  # A failure here leaves the rest of the setup done, so warn rather than abort
  # and let report_ready_name say what the CLI will resolve.
  if [[ "$os_name" == "Darwin" ]]; then
    run_as_root scutil --set HostName "$machine" || failed=1
    run_as_root scutil --set LocalHostName "$machine" || failed=1
  else
    run_as_root hostnamectl set-hostname "$machine" || failed=1
    rewrite_hosts_hostname "$machine" || failed=1
  fi

  if [[ "$failed" == 1 ]]; then
    echo "Could not set the hostname to '$machine'. Set it by hand before relying on the bare 'dotfiles'." >&2
    return 0
  fi

  echo "Set the hostname to '$machine' (was '$current')."
}

# The last word on the one name, read from the machine so it says what the next
# `dotfiles` run will resolve.
report_ready_name() {
  local machine="$1"
  local current
  current="$(hostname_name)"

  if [[ "$current" == "$machine" ]]; then
    echo "This machine's hostname is '$machine', so 'dotfiles' needs no argument."
    return 0
  fi

  echo "This machine's hostname is '$current', not '$machine', so 'dotfiles' still needs one." >&2
  if [[ "$linux_distribution" == "nixos" ]]; then
    echo "hosts/platform/nixos/machines/$machine/default.nix sets networking.hostName, and the switch above applies it." >&2
  fi
}

main() {
  local repo_dir
  local machine

  check_supported_platform
  machine="$(machine_name)"

  case "$os_name" in
    Darwin)
      install_macos_packages
      ;;
    Linux)
      install_linux_packages
      ;;
    *)
      echo "Unsupported OS: $os_name" >&2
      exit 1
      ;;
  esac

  install_nix
  ensure_bootstrap_tools
  repo_dir="$(dotfiles_dir)"
  configure_zsh
  configure_git
  ensure_dotfiles_repo "$repo_dir"
  require_known_machine "$repo_dir" "$machine"
  adopt_nixos_machine "$repo_dir" "$machine"
  apply_home_manager "$repo_dir" "$machine"
  sync_hostname "$machine"

  if [[ "$linux_distribution" == "nixos" && -d "$repo_dir/hosts/platform/nixos/machines/$machine" ]]; then
    # A copied machine configuration can collide with the repo's modules. Fail
    # here, naming the file to edit, rather than inside nixos-rebuild.
    if ! nix_cmd eval --impure --raw \
      "$repo_dir#nixosConfigurations.$machine.config.system.build.toplevel.drvPath" >/dev/null; then
      echo "The system configuration for '$machine' does not evaluate." >&2
      echo "Resolve the conflict nix reported above in hosts/platform/nixos/machines/$machine/configuration.nix." >&2
      exit 1
    fi
    # sudo resets the environment, so pass the features this script exported to
    # nixos-rebuild explicitly; a fresh NixOS has flakes off.
    echo "Applying the NixOS system configuration for '$machine'..."
    run_as_root env NIX_CONFIG="extra-experimental-features = nix-command flakes" \
      nixos-rebuild switch --flake "$repo_dir#$machine" --impure
  fi

  if [[ "$should_reboot" == 1 && "${REBOOT:-0}" == 1 ]]; then
    echo "Setup complete. Rebooting now..."
    run_as_root reboot
    return 0
  fi

  echo "Setup complete."
  if [[ "$os_name" == "Darwin" ]]; then
    echo "Open Docker.app once to finish Docker Desktop setup."
  elif [[ "$should_reboot" == 1 ]]; then
    echo "Reboot before using Docker without sudo."
  fi
  report_ready_name "$machine"
}

main "$@"
