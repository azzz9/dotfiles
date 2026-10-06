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
MACHINE=macbook \
GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" \
  bash ~/Downloads/setup-system.sh
```

`MACHINE` is required and names this machine. It is the `machines` row in
`flake.nix` that this machine applies, and the hostname the script sets on the
machine, so the installed `dotfiles` needs no argument afterwards. macOS,
Ubuntu, and Arch must name a row the repository already carries, and the script
prints the one line to add when it does not. NixOS may name a new machine, and
the adoption writes that row. `macbook` in that block is this repository's
macOS row.

The script prepares missing tools, clones the repository, and applies the
Home Manager configuration. Nix provides a missing Git or curl to the setup
process, and the script reuses any command that already exists. Home Manager
then installs Git permanently.

The default checkout is `~/src/github.com/azzz9/dotfiles`, regardless of where
you run the script. This matches the configured ghq root, `~/src`, so
`ghq list` includes `github.com/azzz9/dotfiles` after setup. ghq finds
repository directories under its root. No separate registration is needed.

The script reuses an existing checkout at the selected path and never moves it,
and it reuses any command that already exists.

If Git is already available, cloning first is also supported:

```bash
git clone https://github.com/azzz9/dotfiles.git ~/src/github.com/azzz9/dotfiles
MACHINE=macbook GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" \
  ~/src/github.com/azzz9/dotfiles/scripts/setup-system.sh
```

The script installs system dependencies, installs Nix if needed, configures
Git/Zsh/Docker, and applies the Home Manager flake for this machine and user.

On NixOS, the script needs nothing prepared in the repository. It uses the
existing Nix installation, applies standalone Home Manager, and then applies
the system configuration with the command below, where `<machine>` is the name
`MACHINE` gives. It asks for your password once to run that step.

```bash
sudo nixos-rebuild switch --flake ~/src/github.com/azzz9/dotfiles#<machine> --impure
```

Adoption writes the machine into the flake when the repository does not carry
it yet: `machines/<machine>/hardware-configuration.nix` from
`nixos-generate-config`, a copy of `/etc/nixos/configuration.nix` as
`machines/<machine>/configuration.nix`, `default.nix` importing the shared
modules, and the machine row in `flake.nix`. The copy drops two lines. The row
owns `networking.hostName`, and the user's `shell` leaves because NixOS gives
that option the uniq type, where two definitions are an error even when the
values agree. It stages all four files with `git add`, because Nix sees tracked
files only. A machine the repository already carries is left alone, so a second
run changes nothing.

Git and Zsh come from Home Manager. The script gives the setup process a
temporary Git and curl when they are missing. Every scalar the shared modules
set is a `lib.mkDefault`, so what the copied configuration says wins, with two
exceptions that cannot be defaults: the user's shell, for the reason above, and
`services.displayManager.defaultSession`, which NixOS itself defaults.

Bootstrap and `dotfiles` enable the Nix features their subprocesses need and
preserve an existing `NIX_CONFIG`.

Variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTFILES_DIR` | `~/src/github.com/azzz9/dotfiles` | Checkout to clone or reuse and apply |
| `DOTFILES_REPO_URL` | `https://github.com/azzz9/dotfiles.git` | Repo URL |
| `MACHINE` | required | This machine's name: the `machines` row to apply, and the hostname the bootstrap sets |
| `MACHINE_CAPABILITY` | picked from the copied configuration | `desktop` or `headless`, the NixOS capability module the adoption imports (NixOS only) |
| `REBOOT` | `0` | Reboot after setup |

Set `DOTFILES_DIR` to use a different checkout. A checkout outside `~/src` does
not appear in `ghq list` under the default ghq configuration.

### 2. Manual apply (alternative)

```bash
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#nix-desktop --impure -b backup

# Apple Silicon Mac
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#macbook --impure -b backup
```

## Day-to-day commands

| Command | Description |
|---------|-------------|
| `dotfiles apply` | Build and apply the current checkout, installing any pi npm package whose version differs from its pinned spec |
| `dotfiles sync` | Pull latest, then apply. Stashes the pins a previous `upgrade` left behind, so the pull can fast-forward, and refuses when any other file is changed |
| `dotfiles upgrade` | Pull latest, bump the pinned derivations with `nix-update` and the npm pins from the registry, then refresh `flake.lock` inputs and apply (requires clean repo; restores `flake.lock`, the pins file, and `modules/pi.nix` on failure) |

`dotfiles sync` refuses when a file outside the three pins `upgrade` rewrites
differs, because `apply` would otherwise activate a half-finished edit. It
stashes the pins before it pulls, so the pull fast-forwards even when both
machines moved `flake.lock`, and it names the stash in its output. The stashed
pins stay inactive until you drop the stash, or run `git stash pop` and
`dotfiles apply` again.

`dotfiles upgrade` moves every kind of pin this repo has. It pulls the checkout
first, so on a clean tree it covers everything `dotfiles sync` does before it
moves the pins. Packages nixpkgs manages move with `flake.lock`.
The pi packages move with `flake.lock` alone,
because `modules/pi.nix` hands pi each input's store path. The npm-only
packages (the two rpiv ones, which ship from a workspace no git source can
key; `cc-safety-net`,
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
differs from its pinned spec.

codediff-watcher's version is read from nixpkgs' codediff-nvim at eval time,
so the watcher and the plugin never disagree; the per-system release hashes
stay hand-edited when the plugin itself moves.

pi and herdr are installed by this flake. Provider packages, model choices,
and the pi-hermes-memory memory store are machine-local; see the
`dotfiles-context` skill.

### Machines

A machine has one name, and both layers use it. The `machines` row key in
`flake.nix` is the `homeConfigurations` attribute and, for a row that carries
an `nixos` path, the `nixosConfigurations` attribute too. The current rows are
`nix-desktop`, `macbook`, and `nix-server`.

The bootstrap sets the hostname from `MACHINE`: `scutil` on macOS,
`hostnamectl` and the `127.0.1.1` line of `/etc/hosts` on Ubuntu and Arch, and
`networking.hostName` through the system switch on NixOS. So the row key, the
machine name, and the hostname agree, and no one types a hostname by hand.

The installed `dotfiles` CLI reads `hostname`, drops a trailing `.local`
macOS reports its mDNS name with, and applies that name. An argument names
another machine, and an unknown name fails with the list. A hostname the table
does not have fails the same way. The bootstrap sets the hostname from
`MACHINE`, so the two names agree and the CLI needs no argument.

Renaming a machine means the row key, the directory under
`hosts/platform/nixos/machines/` for a NixOS row, and `networking.hostName`,
then a run with `MACHINE=<new name>`. Rename the row first. With the old key in
the repository and a new name in `MACHINE`, a NixOS run adopts a second machine
instead of renaming the one in front of you.

A machine that has not applied since a rename still carries the old name list in
its installed `dotfiles`, so its first apply runs the checkout's script instead:

```bash
DOTFILES_DIR=$PWD DOTFILES_MACHINES="nix-desktop macbook nix-server" bash scripts/dotfiles.sh apply macbook
```

```bash
# Both are the same attribute on a machine named macbook.
dotfiles apply
dotfiles apply macbook
```

Differences between platforms live in guard clauses inside the modules
(`pkgs.stdenv.hostPlatform.isDarwin` and `isLinux`), not in per-machine files.
`MACHINE` is the bootstrap script's one knob: the machine it applies and the
name it sets the hostname to.

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
+|       +-- machines/<name>/ #     this machine: default, hardware, configuration
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
module. `common.nix` has the settings every NixOS machine shares. `desktop.nix`
has the GUI stack. `headless.nix` has the minimum for a machine without a
display.

`hosts/platform/nixos/` feeds `nixosConfigurations.<machine>` in the same flake.
macOS never evaluates it, and no other platform does either.

The system configuration is a flake output, so applying it needs no `/etc/nixos`
wiring:

```bash
sudo nixos-rebuild switch --flake ~/src/github.com/azzz9/dotfiles#nix-desktop --impure
```

The bootstrap adopts the machine and then runs that command, so a machine the
repository does not carry yet needs no preparation. It applies the machine
`MACHINE` names, which is required (see the bootstrap invocation above for
`GIT_NAME` and `GIT_EMAIL`):

```bash
MACHINE=nix-desktop ~/src/github.com/azzz9/dotfiles/scripts/setup-system.sh
```

### Adding a machine

Run the bootstrap on the new machine, as in Quick start. It writes
`hardware-configuration.nix`, copies `/etc/nixos/configuration.nix` in as
`configuration.nix`, writes `default.nix`, adds the machine row, and switches the
system. It picks `desktop.nix` when the copied configuration drives a GUI
(`services.xserver`, `services.displayManager`, `services.desktopManager`,
`programs.hyprland`, or `programs.plasma`) and `headless.nix` otherwise, prints
the pick, and `MACHINE_CAPABILITY=desktop` or `=headless` overrides it.

Two things the script cannot know:

- The machine's own settings are the ones the installer left in `/etc/nixos`.
  They arrive as `machines/<name>/configuration.nix`, and that file is where
  they are edited from then on. Every value the shared modules set is a
  `lib.mkDefault`, so a setting this file makes wins.
- A rename still needs the step in [Machines](#machines): apply once with the
  checkout's script and the old name list, because the installed `dotfiles`
  carries the old list until that apply.

When the disk layout changes, regenerate the hardware file the same way and copy
it in. Drop its three header comment lines and any lambda argument the body does
not use, so the `deadnix` check passes.

## Local push guard

```bash
git config core.hooksPath .githooks
```

Runs `scripts/check.sh`, the same check set CI builds. The checks are defined
once in `checks/default.nix`, which `flake.nix` wires into `checks.<system>`.

## CI

CI evaluates every machine attribute with `scripts/check.sh --no-build`, then
builds the checks and every activation package for `x86_64-linux` and
`aarch64-darwin`.

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
- AI agent rules and skills deploy from `agents/` and `.agents/skills/` through
  out-of-store links. `show-me` explains implementations first and `explain`
  writes structured technical explanations.
