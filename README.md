# dotfiles

Home Manager + Nix flake setup for x86_64 Linux (Ubuntu, Arch, NixOS) and
Apple Silicon macOS.

## Quick start (new machine)

Start with Bash and the operating system's base utilities, internet access,
and administrator access for system package installation on Ubuntu, Arch, or
macOS. NixOS uses its built-in Nix. Git, Home Manager, npm, Node.js, and other
development tools do not need to be installed beforehand. On Ubuntu and Arch,
the script installs curl before downloading Nix; macOS includes curl.

### 1. Download & bootstrap (no Git needed)

Download [setup-system.sh](https://raw.githubusercontent.com/azzz9/dotfiles/main/scripts/setup-system.sh)
using a browser and run the downloaded file:

```bash
GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" \
  bash ~/Downloads/setup-system.sh
```

The script prepares missing tools, clones the repository, and applies the
Home Manager configuration. Nix provides a missing Git or curl to the setup
process, and the script reuses any command that already exists. Home Manager
then installs Git permanently.

The default checkout is `~/src/github.com/azzz9/dotfiles`, regardless of where
you run the script. This matches the configured ghq root, `~/src`, so
`ghq list` includes `github.com/azzz9/dotfiles` after setup. ghq finds
repository directories under its root. No separate registration is needed.

The script reuses an existing Git checkout at the selected path instead of
cloning again. Running from a checkout elsewhere does not move or change that
checkout. Without `DOTFILES_DIR`, the script still clones or reuses the default
path and applies that checkout.

If Git is already available, cloning first is also supported:

```bash
git clone https://github.com/azzz9/dotfiles.git ~/src/github.com/azzz9/dotfiles
GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" \
  ~/src/github.com/azzz9/dotfiles/scripts/setup-system.sh
```

The script installs system dependencies, installs Nix if needed, configures
Git/Zsh/Docker, and applies the Home Manager flake for the current platform
and user.

On NixOS, the script uses the existing Nix installation and applies standalone
Home Manager. It temporarily provides Git and curl if needed, and Home Manager
installs Git and Zsh permanently. Set the login shell and enable Docker in your
NixOS system configuration, merging these options with your existing user
definition:

```nix
{ pkgs, ... }: {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.zsh.enable = true;
  users.users."your-user".shell = pkgs.zsh;
  virtualisation.docker.enable = true;
  users.users."your-user".extraGroups = [ "docker" ];
}
```

Apply those system changes with `sudo nixos-rebuild switch`, then log out and
back in for the shell and Docker group membership to take effect.

Bootstrap and `dotfiles` enable the required Nix features for their subprocesses
automatically, preserving existing `NIX_CONFIG` settings. The system option
above also enables them for Nix commands you run directly.

Optional overrides:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTFILES_DIR` | `~/src/github.com/azzz9/dotfiles` | Checkout to clone or reuse and apply |
| `DOTFILES_REPO_URL` | `https://github.com/azzz9/dotfiles.git` | Repo URL |
| `HM_HOST` | auto-detect | Home Manager attribute (e.g. `x86_64-linux`) |
| `REBOOT` | `0` | Reboot after setup |

Set `DOTFILES_DIR` to use a different checkout. This override may be outside
`~/src`, in which case `ghq list` does not include that checkout under the
default ghq configuration. An unset or empty `DOTFILES_DIR` uses the default
path.

### 2. Manual apply (alternative)

```bash
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#x86_64-linux --impure -b backup

# Apple Silicon
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#aarch64-darwin --impure -b backup
```

## Day-to-day commands

| Command | Description |
|---------|-------------|
| `dotfiles apply` | Build and apply the current checkout, reconciling pi packages to their pinned revision or version |
| `dotfiles sync` | Pull latest, then apply (requires clean repo) |
| `dotfiles upgrade` | Bump the pinned derivations with `nix-update` and the npm pins from the registry, then refresh `flake.lock` inputs and apply (requires clean repo; restores `flake.lock`, the pins file, and `modules/pi.nix` on failure) |

`dotfiles upgrade` moves every kind of pin this repo has. Packages nixpkgs
manages move with `flake.lock`. The git-sourced pi packages move with
`flake.lock` plus the reconcile step. The npm-only packages (the three rpiv
ones, which ship from a workspace no git source can key; `cc-safety-net`,
whose repository needs `lefthook` at install time; and `pi-hermes-memory`,
which publishes to npm and pulls its `better-sqlite3` addon prebuilt)
move with a registry-queried version bump plus the same reconcile. The
derivations pinned in `modules/pinned-packages.nix` (solhint,
prettier-plugin-solidity and its dist, roots) are bumped by `nix-update`
with per-name backups, and a failed upgrade restores `flake.lock`, the pins
file, and `modules/pi.nix`. No pin the upgrade moves needs a hand-typed
version or hash; a bump that cannot build (for example a new release needs
a newer Go than nixpkgs ships) keeps its previous pin and warns instead of
failing the whole upgrade. `apply` moves any pi package that drifted: a git
checkout lands on its pinned revision, an npm package is installed at its
pinned version. The reconcile step is baked into the installed CLI at build
time, so the first `dotfiles apply` or `dotfiles upgrade` after this change
lands activates the new generation without reconciling anything; the one
after that reconciles.

codediff-watcher's version is read from nixpkgs' codediff-nvim at eval time,
so the watcher and the plugin never disagree; the per-system release hashes
stay hand-edited when the plugin itself moves.

pi and herdr are installed by this flake. Provider packages, model choices,
and the pi-hermes-memory memory store are machine-local; see the
`dotfiles-context` skill.

## Repository layout

```
dotfiles/
+-- flake.nix                  # homeConfigurations + checks for both systems
+-- hosts/default.nix          # HM entry point, skill symlinks
+-- nixos/                     # NixOS system configuration (this machine)
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
|   +-- pinned-packages.nix   # nixpkgs-missing derivations, bumped by nix-update
|   +-- lazygit.nix            # lazygit config
+-- config/ai/                 # AI agent config (pi)
|   +-- AGENTS.md              # Core rules (turn gate, show-me gate, git rules)
|   +-- skills/                # Global skills (linked to ~/.agents/skills)
+-- scripts/dotfiles.sh        # the `dotfiles` CLI
+-- scripts/pi-reconcile.sh    # moves pi packages to their pinned revisions and versions
+-- scripts/check.sh           # the checks the pre-push hook and CI run
+-- scripts/setup-system.sh    # Bootstrap script
+-- .agents/skills/            # Project-scoped skills (this repo only)
+-- .githooks/pre-push         # Local pre-push checks
+-- .github/workflows/ci.yml   # CI: static checks + builds
```

## System configuration (NixOS)

The NixOS system configuration lives in `nixos/`. You edit `configuration.nix`
by hand. `hardware-configuration.nix` is generated by `nixos-generate-config`
and copied back into the repository.

`nixos/` is a separate layer from the Home Manager flake, so no other platform
evaluates it. macOS is unaffected.

Wire the machine once so `nixos-rebuild` reads the tracked file:

```bash
sudo mv /etc/nixos/configuration.nix /etc/nixos/configuration.nix.before-dotfiles
sudo ln -s ~/dotfiles/nixos/configuration.nix /etc/nixos/configuration.nix
```

Nix resolves the relative import of `hardware-configuration.nix` through the
symlink, so the repository copy is the one that builds. Apply system changes
with `sudo nixos-rebuild switch`.

When the disk layout changes, regenerate the hardware file:

```bash
sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
cp /tmp/hardware-configuration.nix ~/dotfiles/nixos/hardware-configuration.nix
```

Remove any argument the generated file does not use, so the `deadnix` check
passes.

## Local push guard

```bash
git config core.hooksPath .githooks
```

Runs `scripts/check.sh`, the same check set CI builds. The checks are defined
once in `flake.nix` under `checks.<system>`.

## CI

CI evaluates both Home Manager configurations with `scripts/check.sh
--no-build`, then builds the checks and the activation package for
`x86_64-linux` and `aarch64-darwin`. Because the checks live in `flake.nix`, a
local run, the pre-push hook, and CI cannot disagree.

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
