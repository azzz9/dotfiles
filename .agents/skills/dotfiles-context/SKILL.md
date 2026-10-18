---
name: dotfiles-context
description: "Quick reference for this Nix flake + Home Manager dotfiles repo: entry points, the AI config and herdr integration, the per-platform differences, and how to verify. Use when working in ~/src/github.com/azzz9/dotfiles."
---

# dotfiles-context Skill

Nix flake + Home Manager repo. Read this before exploring files.

## Layout

The entry points are `flake.nix` (inputs, machines, outputs), `hosts/default.nix`
(Home Manager entry and rules links), `modules/` (one module per capability),
`checks/default.nix` (the check set), `scripts/` (the `dotfiles` CLI, the
bootstrap, and the audit), and `tests/` (the fixture suites those checks drive).

`flake.nix` states the account (`user`) and each row's `homeDirectory`,
`checkout`, and `skillsCheckout`, so the flake evaluates purely: no command in
this repository passes `--impure`. The one exception is
`refresh_pi_npm_hashes`, which reads the checkout through `builtins.getFlake`
and says so on the line.

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

`hosts/default.nix` links the three rules links out of store, so an edit in
the skills checkout is live:

```
<skills checkout>/AGENTS.md          -> ~/.pi/agent/AGENTS.md
<skills checkout>/AGENTS.md          -> ~/.dsh/AGENTS.md
<skills checkout>/APPEND_SYSTEM.md   -> ~/.pi/agent/APPEND_SYSTEM.md
```

All three links name `skillsCheckout`, defaulting to
`~/src/github.com/azzz9/skills`, never the checkout that ran the switch. A
worktree activation therefore leaves them on the main checkout, and deleting the
worktree breaks nothing.

The pinned dsh-agent-instructions 0.2.0-rc.2 reads only
`$DSH_HOME/AGENTS.md` as the user-global file; pi does not read that path.

Repo-local skills are the only skills this repo ships. They sit in
`.agents/skills/` at the repo root, where pi discovers them as project skills
once the project is trusted.

The skills repository (`skills`) ships the skills, the `comment-sicko` subagent, and the
four delegation tiers (`fast`, `standard`, `deep`, `intent`), plus the two files that load on
every turn: `APPEND_SYSTEM.md`, which pi appends to the system prompt, and `AGENTS.md`, which pi
reads as a context file. Both are linked out of the skills checkout, so an edit there is live.

`modules/pi.nix` owns the package rows. The four package inputs are
`flake = false` inputs in `flake.nix`, rendered into `settings.json` as store
paths, so `flake.lock` is the only pin; `pi_reconcile` installs any npm row whose
version differs from its spec. The pins are below.

`modules/dsh.nix` installs the `dsh` and `dsh-tui` wrappers, and
`modules/dsh-pin.nix` pins both versions. The module is guarded with `lib.mkIf`
on Linux, so the macbook carries no wrapper, no `~/.dsh/AGENTS.md` link, and no
provider overlay; `dsh_reconcile` returns on Darwin for the same reason. The CLI
is not a derivation:
`dsh_reconcile` installs it into `~/.local/share/dsh` because it builds native
modules at install time, then keeps the dsh-tui plugin in the mutable
`~/.dsh/profiles/dsh-tui` on the pinned version. The wrapper launches the
mise-installed Node 24.18.0, because the CLI's require-builtin addon rejects
the Nix 22.23.2 and 24.21.0 builds; `DSH_NODE` overrides the path.

`modules/dsh/ollama-cloud.patch.yml` declares the ollama-cloud provider route
and the default model, and the `dsh-tui` wrapper passes it with `--patch` so it
layers after the profile's own patch file. The route names
`OLLAMA_CLOUD_API_KEY`, resolved per request from the launching environment
first and then the harness credential store; the key stays machine-local.

The CLI itself comes from upstream's own flake, the `pi` input at
`github:earendil-works/pi`, which builds pi from source. `modules/pi.nix` and
`dotfiles-cli.nix` take `piFlake.packages.<system>.pi` from it, so the
derivation is upstream's, built against upstream's nixpkgs pin rather than ours.
The input tracks main, and `nix flake update pi` moves it.

Provider extensions are machine-local and
deliberately not Nix-managed. Install a provider extension under
`~/.pi/agent/extensions/<name>/`, where pi auto-discovers it.

The delegation assignment is the exception. `modules/pi/model-tiers.nix` holds one
row per machine, and each row carries the model and the thinking effort for a tier
agent, the PR reviewer, or `comment-sicko`. `modules/pi.nix` renders those rows
into the `subagents` key of `settings.json` with the same merge as every other
key, so the assert there fails evaluation on a malformed slug, an undefined
thinking value, or an agent name absent from both pinned packages.

The macbook row names explicit `github-copilot/<id>` slugs, which its Copilot
Enterprise plan allows. Copilot Free and Copilot Student are the plans that
cannot name a model (auto selection only), and there an explicit slug is
answered with 400 `model_not_supported`.

To add a repo-local skill: create `.agents/skills/<name>/SKILL.md`; no Nix
change is needed.

## dotfiles CLI commands

`apply`, `audit`, `sync`, and `upgrade` live in `scripts/dotfiles.sh`, which
`modules/dotfiles.nix` installs through `writeShellApplication` (so the build
shellchecks it). README.md owns the command table. `sync` runs a gate first: any
change outside the four files `upgrade` rewrites makes it refuse, because
activation would otherwise pick up a half-finished edit. `apply` has no such
gate and activates the current tree.

`audit` is the only command that reaches the network. It reads the store
closure of the running system and of the Home Manager generation, matches those
package names against the open issues NixOS/nixpkgs labels
`1.severity: security`, and reads the npm advisories for the rows
`modules/pi.nix` pins. `--declared` reads the packages flake.nix names for the
machine instead, which is a subset of the closure and all a runner without a
store can read. `scripts/audit-baseline.txt` holds what was already read, and
only a match outside it fails the command, so the file is part of the working
tree like the pins `upgrade` moves. Only the store audit reads or prunes that
file.

`upgrade` reads the audit as its last step and treats it as a report, because
the pins it just moved are where a nixpkgs fix lands.

## Pins

`upgrade` moves every pin this repository has, in one run, and leaves the files
it moved in the working tree for a commit.

| Pin | Moves with |
|-----|------------|
| nixpkgs and every other flake input | `nix flake update`, which rewrites `flake.lock` |
| the pi packages | `flake.lock` alone, because `modules/pi.nix` hands pi each input's store path |
| the npm-only pi packages | a registry-queried bump in `modules/pi.nix` plus `pi_reconcile` |
| `modules/dsh-pin.nix` | a registry-queried bump of the `dsh` CLI and `dsh-tui` versions plus `dsh_reconcile`; its Node runtime is pinned by hand |
| `modules/pinned-packages.nix` | `nix-update`, one name at a time |

The npm-source rows are the ones `modules/pi.nix` writes as an `npm:` spec, each
with its reason recorded on the row. `bump_npm_pins` finds them with one
`grep -o 'npm:...'` and moves each to the registry's latest. The `nix-update`
names are `solhint`, `roots`, `prettier-plugin-solidity`,
`prettier-plugin-solidity-dist`, and `herdr-nvim`; the `docs` check fails when
one of them has no row in this table.

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
`nixosConfigurations` attribute for a row that carries a `nixos` path. README.md
carries the rendered table, and the `docs` check compares it against this
attrset. A row without a `nixos` path has a user environment only, which is
every non-NixOS machine.

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
sudo nixos-rebuild switch --flake ~/src/github.com/azzz9/dotfiles#<machine>
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
`x86_64-linux` and `aarch64-darwin`. `scripts/check.sh --only <check>` builds a
single check by name for the local loop, and the full run retries only when the
failure names the registry or the network, so a deterministic failure fails on
the first attempt.

An optional Cachix cache speeds CI up. Set the repository variable `CACHIX_NAME`
and the secret `CACHIX_AUTH_TOKEN` and the workflow configures the cache. Without
a token CI uses the public cache only.

Three other workflows sit beside CI. `Audit` runs weekly and on demand, reads the
packages the flake declares, and is not in the push path: it needs the network,
and upstream issue churn must not fail an unrelated push. `Upgrade` runs weekly
and on demand and moves every pin with `dotfiles upgrade --pins-only`, then opens
or updates the `chore/pin-upgrade` pull request, so CI verifies the pins on both
platforms before any machine applies them. A machine therefore only needs
`dotfiles sync`; `dotfiles upgrade` stays the by-hand way to move a pin.

## Formatting and checks

`nix fmt` runs `nixfmt` through the flake's `formatter`, and `nix develop` gives
`nixfmt`, `deadnix`, `statix`, `stylua`, `shellcheck`, and `actionlint`.
`modules/nvim/lua/languages.lua` names `nixfmt` and `stylua` for conform.nvim, so
an editor save and the checks agree. `statix.toml` disables W20 only, because the
modules write the flat `a.b = ...; a.c = ...;` form on purpose.

`checks/default.nix` holds the check set and `flake.nix` wires it into
`checks.<system>`. The `nix-home-manager` skill lists what each check covers
and the asserts that fail evaluation.

## OS differences

Conditionals live in the files below, each next to what it configures.

| File | What it separates |
|------|-------------------|
| `hosts/default.nix` | the dsh module and its AGENTS.md link on Linux |
| `hosts/platform/darwin.nix` | sessionPath entries and the GC launchd argument split |
| `hosts/platform/linux.nix` | sessionPath entries and the XDG user dirs |
| `modules/ghostty.nix` | `config` against `config.ghostty`, with different content |
| `modules/hunk.nix` | the ld-linux wrapper on Linux, upstream on Darwin |
| `modules/packages.nix` | unar, xclip, wl-clipboard on Linux, terminal-notifier on Darwin |
| `modules/pinned-packages.nix` | the per-system codediff-watcher hash and `autoPatchelfHook` on Linux |

A per-machine Home Manager difference would need `home = [ ... ];` in that
machine's row. The `nix-server` row's list carries `modules/hermes.nix`, the
Hermes Agent user service, whose state directory is `~/.hermes` (config.yaml,
.env, auth.json, all hand-managed). Regenerate the lists instead of grepping
for conditionals:

```bash
for m in nix-desktop macbook nix-server; do
  echo "== $m"
  nix --extra-experimental-features "nix-command flakes" eval \
    --json ".#homeConfigurations.$m.config.xdg.configFile" --apply builtins.attrNames
  nix --extra-experimental-features "nix-command flakes" eval \
    --json ".#homeConfigurations.$m.config.home.packages" --apply 'ps: map (p: p.name) ps'
done
```

Each row states its own home directory, so the `macbook` attribute evaluated on
Linux still prints `/Users/azzz`. Compare names and keys, not absolute paths.

## Supported platforms

`x86_64-linux` (Ubuntu, Arch, NixOS) and `aarch64-darwin` (Apple Silicon).
README.md covers install and daily use. The bootstrap, the machine table, and the
NixOS system layer are above.
