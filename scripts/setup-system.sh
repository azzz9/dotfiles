#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GIT_NAME:-}" || -z "${GIT_EMAIL:-}" ]]; then
  echo "Set GIT_NAME and GIT_EMAIL before running." >&2
  echo "Example: GIT_NAME=\"your-name\" GIT_EMAIL=\"your-noreply@users.noreply.github.com\" ./scripts/setup-system.sh" >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "/etc/os-release not found. Cannot detect OS." >&2
  exit 1
fi

case "${ID:-}" in
  ubuntu)
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    sudo apt-get install -y git tmux zsh
    ;;
  arch)
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm docker docker-compose-plugin git tmux zsh
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    ;;
  *)
    echo "Unsupported OS: ${ID:-unknown}" >&2
    exit 1
    ;;
esac

if command -v zsh >/dev/null 2>&1; then
  sudo chsh -s "$(command -v zsh)" "$USER"
fi

sudo git config --global user.name "${GIT_NAME}"
sudo git config --global user.email "${GIT_EMAIL}"

tmux_conf="${HOME}/.config/tmux/tmux.conf"
tpm_dir="${HOME}/.tmux/plugins/tpm"

if [[ -f "${tmux_conf}" ]]; then
  if [[ ! -d "${tpm_dir}" ]]; then
    git clone https://github.com/tmux-plugins/tpm "${tpm_dir}"
  fi

  if command -v tmux >/dev/null 2>&1; then
    if tmux has-session >/dev/null 2>&1; then
      tmux source-file "${tmux_conf}"
    else
      tmux new-session -d -s dotfiles >/dev/null 2>&1 || true
      tmux source-file "${tmux_conf}"
    fi
  fi
else
  echo "tmux config not found: ${tmux_conf}"
fi

echo "Setup complete. Rebooting now..."
sudo reboot
