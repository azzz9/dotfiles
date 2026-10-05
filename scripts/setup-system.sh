#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GIT_NAME:-}" || -z "${GIT_EMAIL:-}" ]]; then
  echo "Set GIT_NAME and GIT_EMAIL before running." >&2
  echo "Example: GIT_NAME=\"your-name\" GIT_EMAIL=\"your-noreply@users.noreply.github.com\" ./scripts/setup-system.sh" >&2
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

# The one name both layers use. MACHINE names it explicitly; otherwise the
# hostname does, minus the .local suffix macOS reports its mDNS name with.
machine_name() {
  if [[ -n "$MACHINE" ]]; then
    printf '%s\n' "$MACHINE"
    return
  fi

  local name
  name="$(hostname)"
  printf '%s\n' "${name%.local}"
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

list_nixos_machines() {
  local repo_dir="$1"
  local machine
  local names=""

  for entry in "$repo_dir"/hosts/platform/nixos/machines/*/default.nix; do
    [[ -f "$entry" ]] || continue
    names+="${names:+ }$(basename "$(dirname "$entry")")"
  done

  printf '%s' "$names"
}

# On NixOS the system configuration is a flake output, so the bootstrap only
# checks that the machine is complete and prints the command that applies it.
check_nixos_machine() {
  local repo_dir="$1"
  local machine="$2"
  local entry hardware

  if [[ "$linux_distribution" != "nixos" ]]; then
    return 0
  fi

  entry="$repo_dir/hosts/platform/nixos/machines/$machine/default.nix"
  hardware="$repo_dir/hosts/platform/nixos/machines/$machine/hardware-configuration.nix"

  if [[ ! -f "$entry" ]]; then
    echo "No NixOS configuration for machine '$machine'. Available machines: $(list_nixos_machines "$repo_dir")" >&2
    echo "Set MACHINE=<name> to check a different machine." >&2
    exit 1
  fi

  if [[ ! -f "$hardware" ]]; then
    echo "Missing hardware configuration for machine '$machine'." >&2
    echo "Generate it on this machine and copy it into the repository:" >&2
    echo "  sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix" >&2
    echo "  cp /tmp/hardware-configuration.nix $hardware" >&2
    exit 1
  fi

  echo "System configuration for '$machine' is a flake output. Apply it with:"
  echo "  sudo nixos-rebuild switch --flake $repo_dir#$machine --impure"
}

apply_home_manager() {
  local repo_dir="$1"
  local machine="$2"

  DOTFILES_DIR="$repo_dir" nix_cmd run nixpkgs#home-manager -- switch --flake "$repo_dir#$machine" --impure -b backup
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
  check_nixos_machine "$repo_dir" "$machine"
  apply_home_manager "$repo_dir" "$machine"

  if [[ "$should_reboot" == 1 && "${REBOOT:-0}" == 1 ]]; then
    echo "Setup complete. Rebooting now..."
    run_as_root reboot
  elif [[ "$os_name" == "Darwin" ]]; then
    echo "Setup complete. Open Docker.app once to finish Docker Desktop setup."
  elif [[ "$linux_distribution" == "nixos" ]]; then
    echo "Setup complete. Git and Zsh are installed through Home Manager."
    echo "Configure the login shell and Docker in your NixOS configuration (see README.md)."
  else
    echo "Setup complete. Reboot before using Docker without sudo."
  fi
}

main "$@"
