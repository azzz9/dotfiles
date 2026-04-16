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
Git/Zsh/Docker, and applies the Home Manager flake for the current platform.

Optional overrides:

```
DOTFILES_DIR=~/dotfiles
DOTFILES_REPO_URL=https://github.com/azzz9/dotfiles.git
HM_HOST=x86_64-linux
NO_REBOOT=1
```

Manual Home Manager apply:

```
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#default --impure

# Apple Silicon
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#aarch64-darwin --impure
```

## System Bootstrap Details

`scripts/setup-system.sh` supports Ubuntu, Arch Linux, and Apple Silicon macOS.
It installs Docker CE (Ubuntu) / Docker (Arch) / Docker Desktop (macOS), sets
Zsh as the login shell, configures global Git user info, installs Nix when
missing, and applies this Home Manager configuration.

Ubuntu and Arch Linux reboot at the end so Docker group membership applies.
macOS does not reboot; open Docker.app once to finish Docker Desktop setup.

## Update (pull + apply)

Quick update via zsh function (pull latest from GitHub, then apply):

```
dotfiles-sync
```

## Update lock inputs (optional)

If you want to refresh `flake.lock` inputs locally:

```
dotfiles-upgrade
```

## Auto sync

`dotfiles-sync` is also scheduled automatically by a user timer:

- run: once about 2 minutes after login/startup
- safety: if local uncommitted changes exist in `~/dotfiles`, it skips

Useful commands:

```
systemctl --user status dotfiles-sync.timer
journalctl --user -u dotfiles-sync.service -n 100 --no-pager
```

The automatic timer is Linux-only. On macOS, run `dotfiles-sync` manually.

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
