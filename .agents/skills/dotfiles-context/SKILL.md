---
name: dotfiles-context
description: "Quick reference for this Nix flake + Home Manager dotfiles repo: entry points, the AI config and herdr integration, the per-platform differences, and how to verify. Use when working in ~/src/github.com/azzz9/dotfiles."
---

# dotfiles-context Skill

Nix flake + Home Manager repo. Read this before exploring files.

## Layout

The entry points are `flake.nix` (inputs, machines, outputs), `hosts/default.nix`
(Home Manager entry and skill links), `modules/` (one module per capability),
`checks/default.nix` (the check set), and `scripts/` (the `dotfiles` CLI, the
bootstrap, and the check set).

## Neovim config structure

nvim is managed by nixvim. Plugins are declared in `modules/nvim.nix` via
`programs.nixvim`; Lua overrides live in `modules/nvim/lua/` (`core.lua`,
`ui.lua`, `languages.lua` for per-language LSP, formatter, and linter, then
`plugins/*.lua` and `plugins/dap/*.lua`).

## herdr config

`modules/herdr.nix` installs herdr and generates `~/.config/herdr/config.toml`
via HM: the kanagawa theme, prefix ctrl+b splits, alt+h/j/k/l pane navigation,
alt+shift+h/j/k/l tabs and workspaces, and no agent launcher. Completion
notifications use herdr's system delivery backend with a 15-second delay, and
herdr's pi integration is reinstalled on every activation.

The `herdr.auto-title` plugin stays machine-local, like the pi provider
extensions. Install it by hand with `herdr plugin install
kryptamine/herdr-auto-title --yes`, and Herdr updates it. Dotfiles links the
local `worktree-layout` plugin and reinstalls the pi integration on every
activation, and it never writes under `~/.config/herdr-auto-title/`.

## AI config deployment model

`hosts/default.nix` links AI config out of store, so an edit here is live:

```
agents/AGENTS.md                     -> ~/.pi/agent/AGENTS.md
agents/skills/<name>                 -> ~/.agents/skills/<name>
```

Skills come in two scopes. Every directory under `agents/skills` is linked
into `~/.agents/skills/` and visible in all projects; the link list comes from
`builtins.readDir`, so there is no list to keep in sync. The two skills that
only make sense here sit in `.agents/skills/` at the repo root instead, where pi
discovers them as project skills once the project is trusted.

pstack (`pi-pstack`) ships the skills, the `comment-sicko` and `poteto-agent`
subagents, and an extension that injects the role-model table and `/poteto-mode`.

`modules/pi.nix` owns the package rows. The five package inputs are
`flake = false` inputs in `flake.nix`, rendered into `settings.json` as store
paths, so `flake.lock` is the only pin; `pi_reconcile` installs any npm row whose
version differs from its spec. The pins are below.

Provider extensions, `~/.pi/agent/pstack/models.json`, and the
`pi-hermes-memory` store are machine-local and deliberately not Nix-managed.
Install a provider extension under `~/.pi/agent/extensions/<name>/`, where pi
auto-discovers it.

To add a global skill: create `agents/skills/<name>/SKILL.md`; the link list
is derived, and the build fails if a directory has no `SKILL.md`. To add a
repo-local skill: create `.agents/skills/<name>/SKILL.md`; no Nix change is
needed.

## dotfiles CLI commands

`apply`, `audit`, `sync`, and `upgrade` live in `scripts/dotfiles.sh`, which
`modules/dotfiles.nix` installs through `writeShellApplication` (so the build
shellchecks it). README.md owns the command table. `apply` and `sync` run a
gate first: any change outside the three files `upgrade` rewrites makes them
refuse, because activation would otherwise pick up a half-finished edit.

`audit` is the only command that reaches the network. It reads the store
closure of the running system and of the Home Manager generation, matches those
package names against the open issues NixOS/nixpkgs labels
`1.severity: security`, and reads the npm advisories for the rows
`modules/pi.nix` pins. `scripts/audit-baseline.txt` holds what was already read,
and only a match outside it fails the command, so the file is part of the
working tree like the pins `upgrade` moves.

## Pins

`upgrade` moves every pin this repository has, in one run, and leaves the files
it moved in the working tree for a commit.

| Pin | Moves with |
|-----|------------|
| nixpkgs and every other flake input | `nix flake update`, which rewrites `flake.lock` |
| the pi packages | `flake.lock` alone, because `modules/pi.nix` hands pi each input's store path |
| the npm-only pi packages | a registry-queried bump in `modules/pi.nix` plus `pi_reconcile` |
| `modules/pinned-packages.nix` | `nix-update`, one name at a time |

The npm-only rows are the two `rpiv` packages, which ship from a workspace no
git source can key, `cc-safety-net`, whose repository builds its extension at
install time, and `pi-hermes-memory`, which publishes to npm and pulls its
`better-sqlite3` addon prebuilt. The `nix-update` names are `solhint`, `roots`,
`prettier-plugin-solidity` and its dist, and `herdr-nvim`.

A `nix-update` run that fails, for example because a release needs a newer Go
than nixpkgs carries, restores that one file and warns, so one blocked release
does not stop the run. A failed build or activation restores `flake.lock`, the
pins file, and `modules/pi.nix`.

`codediff-watcher`'s version is read from nixpkgs' `codediff-nvim` at eval time,
so the watcher and the plugin never disagree; its per-system release hashes stay
hand-edited when the plugin itself moves.

Adding a pinned package means giving it `pname`, `version`, and a `src` built
from `${version}`, listing it in `pin_names`, and exposing it as a flake
package.

## Machines

One table in `flake.nix` names every machine. The key is the machine's hostname,
which is also the `homeConfigurations` attribute, and the
`nixosConfigurations` attribute for a row that carries a `nixos` path. The rows
are `nix-desktop`, `macbook`, and `nix-server`. A row without a `nixos` path has
a user environment only, which is every non-NixOS machine.

The bootstrap sets the hostname from `MACHINE`: `scutil` on macOS,
`hostnamectl` and the `127.0.1.1` line of `/etc/hosts` on Ubuntu and Arch, and
`networking.hostName` through the system switch on NixOS. So the row key, the
machine name, and the hostname agree, and the CLI needs no argument. The CLI
reads `hostname` itself and drops a trailing `.local`, which is the suffix
macOS reports its mDNS name with.

Adding a machine is one bootstrap run with `MACHINE=<name>`. On NixOS the run
also writes the machine's directory. On macOS, Ubuntu, and Arch it stops and
prints the row to add instead, because the repository carries the machine's
settings and the script cannot invent them.

Renaming means the row key, the directory under `hosts/platform/nixos/machines/`
for a NixOS row, and `networking.hostName`, then a run with `MACHINE=<new name>`.
Rename the row first. With the old key still in the repository, a NixOS run with
a new name adopts a second machine rather than renaming the one in front of you.

A machine whose installed `dotfiles` predates a rename still carries the old name
list, so its first apply runs the checkout's script instead:

```bash
DOTFILES_DIR=$PWD DOTFILES_MACHINES="nix-desktop macbook nix-server" bash scripts/dotfiles.sh apply <name>
```

## NixOS system layer

`hosts/platform/nixos/machines/<name>/` is one directory per NixOS machine, and
the directory name is the machine name. `default.nix` is the entry point,
`hardware-configuration.nix` comes from `nixos-generate-config` on that machine,
and anything that fits only one machine, such as its GPU, sits beside them as
`hardware-<part>.nix`. `configuration.nix` holds the machine's own settings,
copied from `/etc/nixos` at adoption, and that is where they are edited from then
on.

`hosts/platform/nixos/modules/` holds the capability modules, and nothing
device-specific. `common.nix` has what every NixOS machine shares, `desktop.nix`
the GUI stack, and `headless.nix` the minimum for a machine without a display.
Every scalar there is a `lib.mkDefault`, so a machine's `configuration.nix` wins.
Two cannot be defaults: the user's `shell`, which the adoption drops from the
copy, and `services.displayManager.defaultSession`, which NixOS itself defaults.

`hosts/platform/nixos/` feeds `nixosConfigurations.<machine>` in the same flake.
No other platform evaluates it. The system configuration is a flake output, so it
needs no `/etc/nixos` wiring:

```bash
sudo nixos-rebuild switch --flake ~/src/github.com/azzz9/dotfiles#<machine> --impure
```

The adoption picks `desktop.nix` when the copied configuration drives a GUI
(`services.xserver`, `services.displayManager`, `services.desktopManager`,
`programs.hyprland`, or `programs.plasma`), and `headless.nix` otherwise.
`MACHINE_CAPABILITY` overrides the pick. When the disk layout changes, regenerate
the hardware file the same way, drop its three header comment lines and every
lambda argument the body does not use, so the `deadnix` check passes, and copy it
in.

## CI and the push guard

`git config core.hooksPath .githooks` runs `scripts/check.sh` before every push.
CI runs the same set: it evaluates every machine with `scripts/check.sh
--no-build`, then builds the checks and every activation package for
`x86_64-linux` and `aarch64-darwin`.

An optional Cachix cache speeds CI up. Set the repository variable `CACHIX_NAME`
and the secret `CACHIX_AUTH_TOKEN` and the workflow configures the cache. Without
a token CI uses the public cache only.

## Checks

`checks/default.nix` holds the check set and `flake.nix` wires it into
`checks.<system>`. The `nix-home-manager` skill lists what each check covers
and the asserts that fail evaluation.

## OS differences

Conditionals live in the five files below, each next to what it configures.

| File | What it separates |
|------|-------------------|
| `hosts/default.nix` | sessionPath entries and the GC launchd argument split on Darwin, the XDG user dirs on Linux |
| `modules/ghostty.nix` | `config` against `config.ghostty`, with different content |
| `modules/hunk.nix` | the ld-linux wrapper on Linux, upstream on Darwin |
| `modules/packages.nix` | unar, xclip, wl-clipboard on Linux, terminal-notifier on Darwin |
| `modules/pinned-packages.nix` | the per-system codediff-watcher hash and `autoPatchelfHook` on Linux |

A per-machine Home Manager difference would need `home = [ ... ];` in that
machine's row. Regenerate the lists instead of grepping for conditionals:

```bash
for m in nix-desktop macbook; do
  echo "== $m"
  nix --extra-experimental-features "nix-command flakes" eval --impure \
    --json ".#homeConfigurations.$m.config.xdg.configFile" --apply builtins.attrNames
  nix --extra-experimental-features "nix-command flakes" eval --impure \
    --json ".#homeConfigurations.$m.config.home.packages" --apply 'ps: map (p: p.name) ps'
done
```

Evaluation reads `$HOME`, so the `macbook` attribute evaluated on Linux prints
Linux home paths. Compare names and keys, not absolute paths.

## Supported platforms

`x86_64-linux` (Ubuntu, Arch, NixOS) and `aarch64-darwin` (Apple Silicon).
README.md covers install and daily use. The bootstrap, the machine table, and the
NixOS system layer are above.
