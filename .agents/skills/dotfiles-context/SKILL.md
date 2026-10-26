---
name: dotfiles-context
description: "Quick reference for this Nix flake + Home Manager dotfiles repo: entry points, the AI config and herdr integration, the per-platform differences, and how to verify. Use when working in ~/src/github.com/azzz9/dotfiles."
---

# dotfiles-context Skill

Nix flake + Home Manager repo. Read this before exploring files.

## Layout

The entry points are `flake.nix` (inputs, machines, outputs), `hosts/default.nix`
(Home Manager entry and rules links), `modules/` (one module per capability),
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
`modules/herdr.nix` reinstalls the pi integration on every activation. The
hermes integration is installed the same way by `modules/hermes.nix`, which
only nix-server imports.

The `herdr.auto-title` plugin stays machine-local, like the pi provider
extensions. Install it by hand with `herdr plugin install
kryptamine/herdr-auto-title --yes`, and Herdr updates it. Dotfiles links the
local `worktree-layout` plugin and reinstalls the pi integration on every
activation, and it never writes under `~/.config/herdr-auto-title/`. The hermes
integration, which reports a hermes session to herdr so a pane can be resumed,
comes from `modules/hermes.nix` and exists on nix-server alone.

## AI config deployment model

`hosts/default.nix` links the three rules files from the `skills` flake input,
so `flake.lock` pins them:

```
<skills input>/AGENTS.md          -> ~/.pi/agent/AGENTS.md
<skills input>/APPEND_SYSTEM.md   -> ~/.pi/agent/APPEND_SYSTEM.md
```

The input is the same one `modules/pi.nix` hands pi, so the rules and the skill
files come from one revision. Editing `~/src/github.com/azzz9/skills` has no
effect until the pin moves. To move it, run `nix flake update skills` and then
`dotfiles apply`.

Repo-local skills are the only skills this repo ships. They sit in
`.agents/skills/` at the repo root, where pi discovers them as project skills
once the project is trusted.

The skills repository (`skills`) ships the skills and the two files that load on every turn:
`APPEND_SYSTEM.md`, which pi appends to the system prompt, and `AGENTS.md`, which pi reads as a
context file. Both link from the `skills` flake input, so `flake.lock` pins them.

pstack is the subagent layer. Its `pstack` flake input carries the 65 skills and the Pi extension
that registers `agent`, `send_message`, `list_agents`, `stop_agent`, `ask_user_question`, and
`schedule_wakeup`. `modules/pi.nix` also writes `~/.pi/agent/pstack-models.md`, the sheet whose
`pi models:` line maps pstack's Claude family names to this host's providers. Both machines get a
Nix-managed sheet: `pstackModelsLinux` and `pstackModelsMac` in `modules/pi.nix`, picked by
`linuxProviders`.

`modules/pi.nix` owns the package rows. Four rows are `flake = false` inputs in
`flake.nix`, and the rest are published tarballs Nix unpacks into the store. Every
row reaches `settings.json` as a store path, so `flake.lock` and the version and
hash in `modules/pi.nix` are the pins.
`pi_reconcile` has no npm row left to install; it and the `status` reconcile
line stay for a row that is still a `spec`. The tarball rows move by hand, with
the hash from `nix store prefetch-file`; a runtime dependency needs its own
`deps` entry. The pins are below.

`dsh` is not managed here. It is installed on this machine only, under
`~/.local/share/dsh` with its Node runtime from mise, and `~/.local/bin/dsh`
with `dsh-install` are its launchers. Nothing in the flake or the CLI touches
it, so a machine without that local install simply has no `dsh`.

The CLI itself comes from upstream's own flake, the `pi` input at
`github:earendil-works/pi`, which builds pi from source. `modules/pi.nix` and
`dotfiles-cli.nix` take `piFlake.packages.<system>.pi` from it, so the
derivation is upstream's, built against upstream's nixpkgs pin rather than ours.
The input tracks main, and `nix flake update pi` moves it.

Provider extensions are machine-local and
deliberately not Nix-managed. Install a provider extension under
`~/.pi/agent/extensions/<name>/`, where pi auto-discovers it.

To add a repo-local skill: create `.agents/skills/<name>/SKILL.md`; no Nix
change is needed.

## dotfiles CLI commands

`apply`, `audit`, `rollback`, `status`, `sync`, and `upgrade` live in
`scripts/dotfiles.sh`, which `modules/dotfiles.nix` installs through
`writeShellApplication` (so the build shellchecks it). README.md owns the
command table. `sync` and `upgrade` refuse any dirty path before they move,
because activation would otherwise pick up a half-finished edit. `apply` has no
dirty gate and activates the current tree. `upgrade` runs
`scripts/bump-pins.sh`, builds, applies, reinstalls the two GitHub Herdr plugins
(`herdr plugin update` keeps the recorded ref, so it cannot move a tag), and
reports the audit without failing.
`apply`, `sync`, `upgrade`, and `rollback` record the applied commit in
`~/.local/state/dotfiles/applied.log`, and `rollback` applies the most recent
applied commit that differs from the current one. `status` reads and never fetches: it
reports the distance from the last fetched upstream, the uncommitted pin files,
whether the running Home Manager generation's derivation matches the one the
checkout evaluates to, and whether the pi npm rows sit on their pins. The last
one is the only reader of the mutable npm prefix besides the reconcile, so it is
what sees a reconcile that failed offline. Only a run that
mutates takes the lock, so `status` stays usable during a run; a second
mutating run exits 1 rather than reading as applied, and a lock left by a killed
run is reclaimed through the pid inside it. On NixOS these commands change the
user environment only; the system layer is the `machines` repository, and a
change there needs its own `nixos-rebuild switch --flake` run.

`audit` is the only command that reaches the network. It reads the store
closure of the running system and of the Home Manager generation, matches those
package names against the open issues NixOS/nixpkgs labels
`1.severity: security`, and reads the npm advisories for the rows
`modules/pi.nix` pins. `osv-scanner`
adds the transitive dependencies of the npm packages pi installed, from the
lockfile pi leaves in `~/.pi/agent/npm`. `--declared` reads the packages flake.nix names for the machine instead, which
is a subset of the closure. Every match is printed and the report does not fail:
the list is read after a pin bump, and most of it is a nixpkgs fix that has not
landed yet.

The audit is run by hand, on the machine whose store it reads. The pin bump is
not: the `Upgrade` workflow moves them weekly and merges the pull request. Run
`dotfiles audit` after a bump; it prints every match and does not fail.

## Pins

`scripts/bump-pins.sh` moves every flake input and every `nix-update` pin in one
run. Run it by hand, run `scripts/check.sh` (the pre-push hook does too), then
commit and push. The `Upgrade` workflow runs the same script on a runner every
Monday, builds the result on both platforms, and squash-merges the
`chore/pin-upgrade` pull request, so no machine has to be the one to move them.

| Pin | Moves with |
|-----|------------|
| nixpkgs and every other flake input | `nix flake update`, which rewrites `flake.lock` |
| the pi packages | `flake.lock` alone, because `modules/pi.nix` hands pi each input's store path |
| the pi npm tarballs | `scripts/bump-pi-tarballs.py`: the registry's latest, the version a parent names for a vendored dependency, and a hash from `nix store prefetch-file` |
| `modules/pinned-packages.nix` | `nix-update`, one name at a time |

`modules/pi.nix` pins each pi extension as a published npm tarball, and the
runtime dependencies it vendors under node_modules are pinned the same way.
`bump_pi_tarballs` runs `scripts/bump-pi-tarballs.py`, which moves every row to
the registry's latest and keeps a vendored dependency on the version its
parent's package.json names. The `nix-update` names live in
`modules/pin-names.txt`, one flake package name per line, and the
`pin-names` check fails when that file and `flake.nix`'s packages disagree in
either direction.

A `nix-update` run that fails, for example because a release needs a newer Go
than nixpkgs carries, restores that one file and warns, so one blocked release
does not stop the run. A failed build or activation fails `scripts/check.sh`, so
nothing is committed until it passes.

`codediff-watcher` pins the watcher version that codediff-nvim's installer
downloads, and `bump-pins.sh` reads it from the pinned plugin and measures both
platform archives, so the version and its hashes move in one step. Its own build
fails when the plugin's `watcher.lua` names a different one, so the two never
drift silently.

Adding a pinned package means giving it `pname`, `version`, and a `src` built
from `${version}`, listing it in `pin_names`, and exposing it as a flake
package.

## Machines

One table in `flake.nix` names every machine. The key is the machine's hostname,
which is also the `homeConfigurations` attribute. The rows are `nix-desktop`,
`macbook`, and `nix-server`. A row names the user environment only; the system
configuration of a NixOS machine lives in the `machines` repository, which this
flake does not depend on.

The bootstrap sets the hostname from `MACHINE`: `scutil` on macOS,
`hostnamectl` and the `127.0.1.1` line of `/etc/hosts` on Ubuntu and Arch, and
`networking.hostName` through the system switch on NixOS. So the row key, the
machine name, and the hostname agree, and the CLI needs no argument. The CLI
reads `hostname` itself and drops a trailing `.local`, which is the suffix
macOS reports its mDNS name with.

Adding a machine is one bootstrap run with `MACHINE=<name>`. On NixOS the run
also writes the machine's directory and row in the `machines` checkout. On
macOS, Ubuntu, and Arch it stops and prints the row to add instead, because the
repository carries the machine's settings and the script cannot invent them.

Renaming means the row key, the directory under `machines/<name>/` in the
`machines` repository for a NixOS row, and `networking.hostName`, then a run with
`MACHINE=<new name>`.
Rename the row first. With the old key still in the repository, a NixOS run with
a new name adopts a second machine rather than renaming the one in front of you.

A machine whose installed `dotfiles` predates a rename still carries the old name
list, so its first apply runs the checkout's script instead:

```bash
DOTFILES_DIR=$PWD DOTFILES_MACHINES="nix-desktop macbook nix-server" bash scripts/dotfiles.sh apply <name>
```

## NixOS system layer

The system layer is not in this repository. `azzz9/machines` holds it, and this
flake neither imports it nor pins it. The bootstrap clones it on NixOS, adopts a
new machine there, and switches the system from that checkout.

`machines/<name>/` is one directory per NixOS machine, and
the directory name is the machine name. `default.nix` is the entry point,
`hardware-configuration.nix` comes from `nixos-generate-config` on that machine,
and anything that fits only one machine, such as its GPU, sits beside them as
`hardware-<part>.nix`. `configuration.nix` holds the machine's own settings,
copied from `/etc/nixos` at adoption, and that is where they are edited from then
on.

`modules/` there holds the capability modules, and nothing
device-specific. `common.nix` has what every NixOS machine shares, `desktop.nix`
the GUI stack, `fcitx5.nix` the fcitx5 input method and its Meltype addon, and
`headless.nix` the minimum for a machine without a display.
Every scalar there is a `lib.mkDefault`, so a machine's `configuration.nix` wins.
Two cannot be defaults: the user's `shell`, which the adoption drops from the
copy, and `services.displayManager.defaultSession`, which NixOS itself defaults.

That repository's flake feeds `nixosConfigurations.<machine>`, so the system
configuration needs no `/etc/nixos` wiring:

```bash
sudo nixos-rebuild switch --flake ~/src/github.com/azzz9/machines#<machine>
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
CI runs the same set on every push and pull request, and on `main` every day at
18:00 UTC, which is what builds a pin bump: the job token's squash merge starts
no CI. It evaluates every machine with `scripts/check.sh --no-build`, then
builds the checks and every activation package for `x86_64-linux` and
`aarch64-darwin`.

An optional Cachix cache speeds CI up. Set the repository variable `CACHIX_NAME`
and the secret `CACHIX_AUTH_TOKEN` and the workflow configures the cache. Without
a token CI uses the public cache only.

`upgrade.yml` is the one scheduled workflow. It runs `scripts/bump-pins.sh`,
builds the result with `scripts/check.sh` on `x86_64-linux` and
`aarch64-darwin`, and opens `chore/pin-upgrade`, which it squash-merges. Main
requires a pull request but no approval and no required check, so the merge is
the workflow's own call; `dotfiles sync` on a machine is what applies it, and a
required check added later would stall the merge, because CI never runs on a
job-token pull request. The macOS build is also what puts the bumped darwin
store paths in the cache the macbook pulls from. The audit is not part of it:
it reads the packages a machine has, and most of its matches wait on a nixpkgs
fix. Opening the pull request needs "Allow GitHub Actions to create and approve
pull requests" in the repository's Actions settings.

## Checks

`checks/default.nix` holds the check set and `flake.nix` wires it into
`checks.<system>`. The `nix-home-manager` skill lists what each check covers
and the asserts that fail evaluation.

## OS differences

No shared module tests the platform. A machine names its platform by importing
`hosts/linux.nix` or `hosts/darwin.nix` in its `home` list, and the import is
what carries that platform's PATH, GC scheduling, terminal config placement,
and package set. `hosts/default.nix` asserts that one was imported.

| Where | What it carries |
|------|------------------|
| `hosts/darwin.nix` | sessionPath entries, the GC launchd argument split, and Ghostty's `config` containing both fragments |
| `hosts/linux.nix` | sessionPath entry, the XDG user dirs, wl-clipboard, Ghostty's binary and `config.ghostty` |
| `modules/pi.nix` | the `dotfiles.pi.linuxProviders` option, which `hosts/linux.nix` turns on for the Linux provider set |
| `modules/pinned-packages.nix` | the per-system codediff-watcher hash and `autoPatchelfHook` on Linux |

A per-machine Home Manager difference would need `home = [ ... ];` in that
machine's row. The `nix-server` row's list carries `modules/hermes.nix`, the
Hermes Agent user service, whose state directory is `~/.hermes` (config.yaml,
.env, auth.json, all hand-managed). Regenerate the lists instead of grepping
for conditionals:

```bash
for m in nix-desktop macbook nix-server; do
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
