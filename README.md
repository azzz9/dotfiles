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

pi and herdr are installed by this flake. Provider packages and model choices
are machine-local; see the `dotfiles-context` skill.

## Repository layout

```
dotfiles/
+-- flake.nix                  # homeConfigurations + checks for both systems
+-- hosts/default.nix          # HM entry point, skill symlinks
+-- modules/
|   +-- dotfiles.nix           # wraps scripts/dotfiles.sh as the `dotfiles` CLI
|   +-- pi.nix                 # pi settings and the settings.json merge
|   +-- git.nix                # Git config + ghq + git-wt defaults
|   +-- gh.nix                 # GitHub CLI aliases
|   +-- shell.nix              # Zsh: aliases, plugins, init ordering
|   +-- shell/init/            # Sourced init scripts (dev/deva, prompt, fzf)
|   +-- herdr.nix              # herdr multiplexer and system notifications
|   +-- hunk.nix               # hunk diff review TUI
|   +-- ghostty.nix            # macOS Ghostty configuration (Ghostty external)
|   +-- nvim.nix               # Neovim (via nixvim)
|   +-- packages.nix           # Additional system packages
|   +-- solidity.nix           # Solidity toolchain
|   +-- lazygit.nix            # lazygit config
+-- config/ai/                 # AI agent config (pi)
|   +-- AGENTS.md              # Core rules (turn gate, show-me gate, git rules)
|   +-- skills/                # Global skills (linked to ~/.agents/skills)
+-- scripts/dotfiles.sh        # the `dotfiles` CLI
+-- scripts/check.sh           # the checks the pre-push hook and CI run
+-- scripts/setup-system.sh    # Bootstrap script
+-- .agents/skills/            # Project-scoped skills (this repo only)
+-- .githooks/pre-push         # Local pre-push checks
+-- .github/workflows/ci.yml   # CI: static checks + builds
```

## Local push guard

```bash
git config core.hooksPath .githooks
```

Runs `scripts/check.sh`, the same check set CI builds. The checks are defined
once in `flake.nix` under `checks.<system>`.

## CI

CI evaluates the flake with `scripts/check.sh --no-build`, then builds the
checks and the activation package for `x86_64-linux` and `aarch64-darwin`.
Because the checks live in `flake.nix`, a local run, the pre-push hook, and CI
cannot disagree.

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
- AI agent rules are linked into pi through out-of-store links;
  `show-me` is used for implementation-first explanations and `explain` for
  structured technical explanations.
- `dotfiles-context` and `nix-home-manager` are project-scoped pi skills under
  `.agents/skills/`, so they load only in this repo.
