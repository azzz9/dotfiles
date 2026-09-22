# dotfiles

Home Manager + Nix flake setup (not a NixOS user).

## Quick start (new machine)

Prerequisites: `curl` and `git`

### 1. Clone & bootstrap

```bash
git clone https://github.com/azzz9/dotfiles.git ~/src/github.com/azzz9/dotfiles
GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" \
  ~/src/github.com/azzz9/dotfiles/scripts/setup-system.sh
```

The script installs system dependencies, installs Nix if needed, configures
Git/Zsh/Docker, and applies the Home Manager flake for the current platform
and user.

Optional overrides:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTFILES_DIR` | `~/src/github.com/azzz9/dotfiles` | Clone location |
| `DOTFILES_REPO_URL` | `https://github.com/azzz9/dotfiles.git` | Repo URL |
| `HM_HOST` | auto-detect | Home Manager attribute (e.g. `x86_64-linux`) |
| `REBOOT` | `0` | Reboot after setup |

### 2. Manual apply (alternative)

```bash
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#x86_64-linux --impure -b backup

# Apple Silicon
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#aarch64-darwin --impure -b backup
```

## Day-to-day commands

| Command | Description |
|---------|-------------|
| `dotfiles apply` | Build and apply the current checkout |
| `dotfiles sync` | Pull latest, then apply (requires clean repo) |
| `dotfiles upgrade` | Refresh `flake.lock` inputs, then apply (requires clean repo; restores `flake.lock` on failure) |

Copilot CLI and omp are not installed by this flake; install them
separately when using the related shell functions or herdr launchers.

## Repository layout

```
dotfiles/
+-- flake.nix                  # homeConfigurations: x86_64-linux, aarch64-darwin
+-- hosts/default.nix          # HM entry point, AI symlinks (copilot)
+-- modules/
|   +-- dotfiles.nix           # `dotfiles` CLI (apply / sync / upgrade)
|   +-- git.nix                # Git config + ghq + git-wt defaults
|   +-- gh.nix                 # GitHub CLI aliases
|   +-- shell.nix              # Zsh + helpers (gqcd, rcd, wtcd, dev)
|   +-- herdr.nix              # herdr multiplexer and system notifications
|   +-- ghostty.nix            # macOS Ghostty configuration (Ghostty external)
|   +-- nvim.nix               # Neovim (via nixvim)
|   +-- packages.nix           # Additional system packages
|   +-- solidity.nix           # Solidity toolchain
|   +-- lazygit.nix            # lazygit config
+-- config/ai/                 # AI agent config (copilot)
|   +-- AGENTS.md              # Core rules (read-only gate, language, dispatch)
|   +-- rules/                 # On-demand rule files (read when needed)
|   +-- skills/                # Reusable AI skills
+-- scripts/setup-system.sh    # Bootstrap script
+-- .githooks/pre-push         # Local pre-push checks
+-- .github/workflows/ci.yml   # CI: static checks + builds
```

## Local push guard

```bash
git config core.hooksPath .githooks
```

Runs `nix flake check`, `shellcheck`, `actionlint`, and a Home Manager build
before push.

## CI

CI runs static checks (shellcheck, actionlint, `nix flake check`, HM eval) and
builds for `x86_64-linux` and `aarch64-darwin`.

### Binary cache (optional)

Create a [Cachix](https://cachix.org) cache and set these repository
variables/secrets:

| Name | Type | Purpose |
|------|------|---------|
| `CACHIX_NAME` | Variable | Cache name |
| `CACHIX_AUTH_TOKEN` | Secret | Auth token for push/pull |

When `CACHIX_NAME` is set, the CI workflow automatically configures Cachix
for build caching. Without it, only the public nixpkgs cache is used.

## Notes

- If you add new files to the flake, they must be `git add`'d before running
  `home-manager switch`, otherwise Nix will not see them.
- Ghostty is configured by Home Manager only on macOS; the application itself
  is installed outside Nix and the UDEV Gothic NF font is installed by the
  macOS bootstrap.
- AI agent rules are shared with Copilot through out-of-store links;
  `show-me` is used for implementation-first explanations and `explain` for
  structured technical explanations.
