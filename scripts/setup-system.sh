#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GIT_NAME:-}" || -z "${GIT_EMAIL:-}" ]]; then
  echo "Set GIT_NAME and GIT_EMAIL before running." >&2
  echo "Example: GIT_NAME=\"your-name\" GIT_EMAIL=\"your-noreply@users.noreply.github.com\" ./scripts/setup-system.sh" >&2
  exit 1
fi

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/azzz9/dotfiles.git}"
DEFAULT_DOTFILES_DIR="${HOME}/dotfiles"
HM_HOST="${HM_HOST:-}"

os_name="$(uname -s)"
machine="$(uname -m)"
should_reboot=0

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

current_repo_dir() {
  local dir
  dir="$(script_dir)"

  if command_exists git && git -C "$dir/.." rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$dir/.." rev-parse --show-toplevel
  fi
}

dotfiles_dir() {
  local repo

  if [[ -n "${DOTFILES_DIR:-}" ]]; then
    printf '%s\n' "$DOTFILES_DIR"
    return
  fi

  if repo="$(current_repo_dir)" && [[ -n "${repo:-}" ]]; then
    printf '%s\n' "$repo"
    return
  fi

  printf '%s\n' "$DEFAULT_DOTFILES_DIR"
}

detect_home_configuration() {
  if [[ -n "$HM_HOST" ]]; then
    printf '%s\n' "$HM_HOST"
    return
  fi

  case "${os_name}:${machine}" in
    Linux:x86_64)
      printf '%s\n' "x86_64-linux"
      ;;
    Darwin:arm64)
      printf '%s\n' "aarch64-darwin"
      ;;
    *)
      echo "Unsupported Home Manager target: ${os_name}:${machine}. Set HM_HOST to override." >&2
      exit 1
      ;;
  esac
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

install_nix() {
  load_nix_profile

  if command_exists nix; then
    return
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
  brew list git >/dev/null 2>&1 || brew install git
  brew list tmux >/dev/null 2>&1 || brew install tmux
  brew list zsh >/dev/null 2>&1 || brew install zsh

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

  case "${ID:-}" in
    ubuntu)
      sudo apt-get update
      sudo apt-get install -y ca-certificates curl gnupg lsb-release
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo systemctl enable --now docker
      sudo usermod -aG docker "$USER"
      sudo apt-get install -y git tmux zsh
      should_reboot=1
      ;;
    arch)
      sudo pacman -Syu --noconfirm
      sudo pacman -S --noconfirm curl docker docker-compose-plugin git tmux zsh
      sudo systemctl enable --now docker
      sudo usermod -aG docker "$USER"
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

  if ! zsh_path="$(command -v zsh)"; then
    return
  fi

  if [[ "$os_name" == "Darwin" ]]; then
    if ! grep -qxF "$zsh_path" /etc/shells; then
      echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    if [[ "$(basename "${SHELL:-}")" != "zsh" ]]; then
      chsh -s "$zsh_path" "$USER"
    fi
  else
    sudo chsh -s "$zsh_path" "$USER"
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

  git clone "$DOTFILES_REPO_URL" "$repo_dir"
}

apply_home_manager() {
  local repo_dir="$1"
  local host="$2"

  nix_cmd run nixpkgs#home-manager -- switch --flake "$repo_dir#$host" --impure -b backup
}

main() {
  local repo_dir
  local host

  repo_dir="$(dotfiles_dir)"
  host="$(detect_home_configuration)"

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

  configure_zsh
  configure_git
  ensure_dotfiles_repo "$repo_dir"
  install_nix
  apply_home_manager "$repo_dir" "$host"

  if [[ "$should_reboot" == 1 && "${REBOOT:-0}" == 1 ]]; then
    echo "Setup complete. Rebooting now..."
    sudo reboot
  elif [[ "$os_name" == "Darwin" ]]; then
    echo "Setup complete. Open Docker.app once to finish Docker Desktop setup."
  else
    echo "Setup complete. Reboot before using Docker without sudo."
  fi
}

main "$@"
