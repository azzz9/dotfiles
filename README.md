# dotfiles

Home Manager + Nix flake setup.(I'm not a NixOS user.)

## Install (new machine)

Prerequisites: `curl` and `git`

1. Install Nix (recommended installer):

```
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
```

2. Clone this repo:

```
git clone https://github.com/azzz9/dotfiles.git ~/dotfiles
```

3. Apply the Home Manager config (no prior install needed):

```
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#default --impure
```

## System bootstrap (Docker + Zsh + Git)

This script supports Ubuntu and Arch Linux only. It installs Docker CE
(Ubuntu) / Docker (Arch), sets Zsh as the login shell, and configures global
Git user info for the current user. It reboots at the end.

```
GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" ./scripts/setup-system.sh
```

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

## Local push guard

Enable local pre-push checks (blocks push if eval/build fails):

```
git config core.hooksPath .githooks
```

## Notes

- If you add new files to the flake, they must be `git add`'d before running
  `home-manager switch`, otherwise Nix will not see them.
- tmux plugins are managed by Home Manager, not TPM.
- WSL only: this config uses `im-select.exe` to switch IME back to English on
  InsertLeave. Place it at `/mnt/c/im-select.exe` or update the path in
  `modules/nvim.nix`.
- AI tool workflow notes for `codex` and `gh copilot` live in
  [docs/ai-tools.md](./docs/ai-tools.md).
- Shared repo AI context can start from
  [docs/ai-context-template.md](./docs/ai-context-template.md).
