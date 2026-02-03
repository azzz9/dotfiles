# dotfiles

Home Manager + Nix flake setup.(I'm not a NixOS user.)

## Install (new machine)

1. Install Nix (recommended installer):

```
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
```

2. Clone this repo:

```
git clone https://github.com/azzz9/dotfiles.git ~/dotfiles
```

3. Apply the Home Manager config (no prior install needed):

```
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#arch-linux --impure
```

Use `#ubuntu` on the server:

```
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#ubuntu --impure
```

## System bootstrap (Docker + Zsh + Git)

This script installs Docker CE, sets Zsh as the login shell, and configures
global Git user info. It reboots at the end.

```
GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" ./scripts/setup-system.sh
```

## Update (Nix packages)

1. Update flake inputs:

```
cd ~/dotfiles
nix flake update
```

Update a specific input (example):

```
cd ~/dotfiles
nix flake lock --update-input nixpkgs
```

2. Rebuild Home Manager:

```
nix run nixpkgs#home-manager -- switch --flake .#arch-linux --impure
```

Use `.#ubuntu` on the server.

## Notes

- If you add new files to the flake, they must be `git add`'d before running
  `home-manager switch`, otherwise Nix will not see them.
- tmux plugins are managed by TPM. After tmux starts, press `prefix + I` to
  install plugins.
- WSL only: this config uses `im-select.exe` to switch IME back to English on
  InsertLeave. Place it at `/mnt/c/im-select.exe` or update the path in
  `modules/nvim.nix`.
