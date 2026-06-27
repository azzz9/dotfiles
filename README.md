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

Manual Home Manager apply (use the system-specific attribute):

```
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#x86_64-linux --impure -b backup

# Apple Silicon
nix run nixpkgs#home-manager -- switch --flake ~/dotfiles#aarch64-darwin --impure -b backup
```

## Apply and update

Build and apply the current checkout:

```
dotfiles apply
```

Require a clean repo, pull latest changes from GitHub, then build and apply:

```
dotfiles sync
```

Require a clean repo, refresh `flake.lock` inputs, then build and apply.
If the update, build, or activation fails, `flake.lock` is restored:

```
dotfiles upgrade
```


## Local push guard

Enable local pre-push checks (blocks push if eval/build fails):

```
git config core.hooksPath .githooks
```

## CI binary cache (optional)

To speed up CI builds, create a [Cachix](https://cachix.org) cache and set
these repository variables/secrets:

| Name | Type | Purpose |
|------|------|---------|
| `CACHIX_NAME` | Variable | Cache name |
| `CACHIX_AUTH_TOKEN` | Secret | Auth token for push/pull |

When `CACHIX_NAME` is set, the CI workflow automatically configures Cachix
for build caching. Without it, only the public nixpkgs cache is used.

## Notes

- If you add new files to the flake, they must be `git add`'d before running
  `home-manager switch`, otherwise Nix will not see them.
- tmux plugins are managed by Home Manager, not TPM.
- AI tool workflow notes for `codex` and `gh copilot` live in
  [docs/ai-tools.md](./docs/ai-tools.md).
- Shared repo AI context can start from
  [docs/ai-context-template.md](./docs/ai-context-template.md).
