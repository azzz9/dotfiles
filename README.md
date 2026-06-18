# dotfiles

Home Manager + Nix flake setup.(I'm not a NixOS user.)

## Install (new machine)

Prerequisites: `curl` and `git`

1. Clone this repo:

```
git clone https://github.com/azzz9/dotfiles.git ~/dotfiles
```

2. Run the bootstrap script:

```
GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" ~/dotfiles/scripts/setup-system.sh
```

The script installs system dependencies, installs Nix if needed, configures
Git/Zsh/Docker, and applies the Home Manager flake for the current platform and
current user.

Optional overrides:

```
DOTFILES_DIR=~/dotfiles
DOTFILES_REPO_URL=https://github.com/azzz9/dotfiles.git
HM_HOST=x86_64-linux
REBOOT=1
```

Manual Home Manager apply:

```
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#default --impure -b backup

# Apple Silicon
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#aarch64-darwin --impure -b backup
```

## System Bootstrap Details

`scripts/setup-system.sh` supports Ubuntu, Arch Linux, and Apple Silicon macOS.
It installs Docker CE (Ubuntu) / Docker (Arch) / Docker Desktop (macOS), sets
Zsh as the login shell, configures global Git user info, installs Nix when
missing, and applies this Home Manager configuration.

Ubuntu and Arch Linux need a reboot before Docker group membership applies.
Set `REBOOT=1` to reboot automatically at the end. macOS does not reboot; open
Docker.app once to finish Docker Desktop setup.

## Update (pull + apply)

Quick update command (pull latest from GitHub, then apply):

```
dotfiles-sync
```

## Update lock inputs (optional)

If you want to refresh `flake.lock` inputs locally:

```
dotfiles-upgrade
```

## Local push guard

Enable local pre-push checks (blocks push if eval/build fails):

```
git config core.hooksPath .githooks
```

## Notes

- If you add new files to the flake, they must be `git add`'d before running
  `home-manager switch`, otherwise Nix will not see them.
- tmux plugins are managed by Home Manager, not TPM.
- AI tool workflow notes for `codex` and `gh copilot` live in
  [docs/ai-tools.md](./docs/ai-tools.md).
- Shared repo AI context can start from
  [docs/ai-context-template.md](./docs/ai-context-template.md).
