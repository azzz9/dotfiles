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
Git/Zsh/Docker, and applies the Home Manager flake for this machine and user.

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
| `MACHINE` | this machine's hostname | Machine whose Home Manager profile the bootstrap applies, and whose NixOS system configuration it checks (NixOS only) |
| `REBOOT` | `0` | Reboot after setup |

Set `DOTFILES_DIR` to use a different checkout. This override may be outside
`~/src`, in which case `ghq list` does not include that checkout under the
default ghq configuration. An unset or empty `DOTFILES_DIR` uses the default
path.

### 2. Manual apply (alternative)

```bash
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#desktop --impure -b backup

# Apple Silicon Mac
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#mac --impure -b backup
```

## Day-to-day commands

| Command | Description |
|---------|-------------|
| `dotfiles apply` | Build and apply the current checkout, installing any pi npm package whose version differs from its pinned spec |
| `dotfiles sync` | Pull latest, then apply (requires clean repo) |
| `dotfiles upgrade` | Bump the pinned derivations with `nix-update` and the npm pins from the registry, then refresh `flake.lock` inputs and apply (requires clean repo; restores `flake.lock`, the pins file, and `modules/pi.nix` on failure) |

`dotfiles upgrade` moves every kind of pin this repo has. Packages nixpkgs
manages move with `flake.lock`. The pi packages Nix supplies move with
`flake.lock` alone, because `modules/pi.nix` hands pi each input's store path.
The npm-only packages (the three rpiv
ones, which ship from a workspace no git source can key; `cc-safety-net`,
whose repository builds its extension at install time; and `pi-hermes-memory`,
which publishes to npm and pulls its `better-sqlite3` addon prebuilt)
move with a registry-queried version bump plus the reconcile. The
derivations pinned in `modules/pinned-packages.nix` (solhint,
prettier-plugin-solidity and its dist, roots) are bumped by `nix-update`
with per-name backups, and a failed upgrade restores `flake.lock`, the pins
file, and `modules/pi.nix`. No pin the upgrade moves needs a hand-typed
version or hash; a bump that cannot build (for example a new release needs
a newer Go than nixpkgs ships) keeps its previous pin and warns instead of
failing the whole upgrade. `apply` installs any npm package whose version
differs from its pinned spec. The reconcile step is baked into the installed CLI at build
time, so the first `dotfiles apply` or `dotfiles upgrade` after this change
lands activates the new generation without reconciling anything; the one
after that reconciles.

codediff-watcher's version is read from nixpkgs' codediff-nvim at eval time,
so the watcher and the plugin never disagree; the per-system release hashes
stay hand-edited when the plugin itself moves.

pi and herdr are installed by this flake. Provider packages, model choices,
and the pi-hermes-memory memory store are machine-local; see the
`dotfiles-context` skill.

### Machines

A machine has one name, and both layers use it. That name is the machine's
hostname, so nothing has to be passed in. The `machines` row key in
`flake.nix` is the `homeConfigurations` attribute and, for a row that carries
an `nixos` path, the `nixosConfigurations` attribute too. The current rows are
`desktop` and `mac`.

The installed `dotfiles` CLI reads `hostname`, drops a trailing `.local`
macOS reports its mDNS name with, and applies that name. An argument names
another machine, and an unknown name fails with the list. A hostname the table
does not have fails the same way, so set the hostname once per machine:

```bash
# macOS
sudo scutil --set HostName mac
```

A machine that has not applied since a rename still carries the old name list in
its installed `dotfiles`, so its first apply runs the checkout's script instead:

```bash
DOTFILES_DIR=$PWD DOTFILES_MACHINES="desktop mac" bash scripts/dotfiles.sh apply mac
```

```bash
# Both are the same attribute on a machine named mac.
dotfiles apply
dotfiles apply mac
```

Differences between platforms live in guard clauses inside the modules
(`pkgs.stdenv.hostPlatform.isDarwin` and `isLinux`), not in per-machine files.
`MACHINE` overrides the hostname in the bootstrap script.

## Repository layout

```
dotfiles/
+-- flake.nix                  # machines, homeConfigurations, nixosConfigurations, checks
+-- hosts/default.nix          # HM entry point, skill symlinks
+-- hosts/platform/            # per-platform settings
+|   +-- linux.nix             #   HM: Linux differences
+|   +-- darwin.nix            #   HM: macOS differences
+|   +-- nixos/                #   the NixOS platform
+|       +-- home.nix         #     HM: NixOS differences (add when needed)
+|       +-- modules/         #     shared NixOS capability modules
+|       +-- machines/<name>/ #     this machine: default.nix + hardware files
+-- checks/default.nix         # the check set, wired into checks.<system>
+-- modules/
|   +-- dotfiles.nix           # wraps scripts/dotfiles.sh as the `dotfiles` CLI
|   +-- pi.nix                 # pi settings and the settings.json merge
|   +-- git.nix                # Git config + ghq + git-wt defaults
|   +-- gh.nix                 # GitHub CLI aliases
|   +-- shell.nix              # Zsh: aliases, plugins, init ordering
|   +-- shell/init/            # Sourced init scripts (prompt, fzf)
|   +-- herdr.nix              # herdr multiplexer and system notifications
|   +-- hunk.nix               # hunk diff review TUI
|   +-- ghostty.nix            # macOS Ghostty configuration (Ghostty external)
|   +-- nvim.nix               # Neovim (via nixvim)
|   +-- packages.nix           # Additional system packages
|   +-- pinned-packages.nix   # nixpkgs-missing derivations, bumped by nix-update
|   +-- lazygit.nix            # lazygit config
+-- agents/                    # AI agent config (pi)
|   +-- AGENTS.md              # Core rules (turn gate, show-me gate, git rules)
|   +-- skills/                # Global skills (linked to ~/.agents/skills)
+-- scripts/dotfiles.sh        # the `dotfiles` CLI
+-- scripts/pi-reconcile.sh    # installs pi npm packages at their pinned versions
+-- scripts/check.sh           # the checks the pre-push hook and CI run
+-- scripts/setup-system.sh    # Bootstrap script
+-- .agents/skills/            # Project-scoped skills (this repo only)
+-- .githooks/pre-push         # Local pre-push checks
+-- .github/workflows/ci.yml   # CI: static checks + builds
```

## System configuration (NixOS)

`hosts/platform/nixos/` holds the NixOS platform. `modules/` inside it are the
shared capability modules, and `machines/<name>/` is one directory per machine.
The directory name is the machine name. `default.nix` is the NixOS entry point,
edited by hand. `hardware-configuration.nix` is generated by
`nixos-generate-config` on that machine and copied back into the repository.
Anything that fits only one machine, such as its GPU, lives in this directory
too as `hardware-<part>.nix`. So `nixosConfigurations.<name>` builds from one
directory here, and an HM difference that only NixOS needs would sit beside it
too as `hosts/platform/nixos/home.nix`.

`hosts/platform/nixos/modules/` holds the NixOS capability modules, and nothing
device-specific. No file there mentions `hardware.*`, a drive, or a kernel
module. `common.nix` has the settings both machines share. `desktop.nix` has
the GUI stack. `headless.nix` has the minimum for a machine without a display.

`hosts/platform/nixos/` feeds `nixosConfigurations.<machine>` in the same flake.
macOS never evaluates it, and no other platform does either.

The system configuration is a flake output, so applying it needs no `/etc/nixos`
wiring:

```bash
sudo nixos-rebuild switch --flake ~/src/github.com/azzz9/dotfiles#desktop --impure
```

The bootstrap checks that a machine is complete and prints that command. It
reads this machine's hostname, unless `MACHINE` names another one (see the
bootstrap invocation above for `GIT_NAME` and `GIT_EMAIL`):

```bash
MACHINE=desktop ~/src/github.com/azzz9/dotfiles/scripts/setup-system.sh
```

### Adding a machine

On the new machine, generate the hardware file and copy it back:

```bash
sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
cp /tmp/hardware-configuration.nix ~/src/github.com/azzz9/dotfiles/hosts/platform/nixos/machines/<name>/hardware-configuration.nix
```

Remove any argument the generated file does not use, so the `deadnix` check
passes. In `machines/<name>/default.nix`, set `networking.hostName`, the boot
loader, and `system.stateVersion` (copy the value from the machine's current
system). Import either `desktop.nix` or `headless.nix`. Then add the machine to
`machines` in `flake.nix`, which is what exposes `nixosConfigurations.<name>`
and gives the machine its one name; the table key has to match
`networking.hostName`, which is the hostname the CLI reads. Setup stops before
printing the apply command while the hardware file is missing.

When the disk layout changes, regenerate the hardware file the same way.

## Local push guard

```bash
git config core.hooksPath .githooks
```

Runs `scripts/check.sh`, the same check set CI builds. The checks are defined
once in `checks/default.nix`, which `flake.nix` wires into `checks.<system>`.

## CI

CI evaluates every machine attribute with `scripts/check.sh --no-build`, then
builds the checks and every activation package for `x86_64-linux` and
`aarch64-darwin`. Because the checks live in `flake.nix`, a local run, the
pre-push hook, and CI cannot disagree.

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
