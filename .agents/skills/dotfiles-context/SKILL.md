---
name: dotfiles-context
description: "Quick reference for this Nix flake + Home Manager dotfiles repo: entry points, the AI config and herdr integration, the per-platform differences, and how to verify. Use when working in ~/src/github.com/azzz9/dotfiles."
---

# dotfiles-context Skill

Nix flake + Home Manager repo. Read this before exploring files.

## Layout

README.md lists every file. The entry points are `flake.nix` (inputs,
machines, outputs), `hosts/default.nix` (Home Manager entry and skill links),
`modules/` (one module per capability), `checks/default.nix` (the check set),
and `scripts/` (the `dotfiles` CLI and the bootstrap).

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
version differs from its spec. README.md has the rest of the pin story.

Provider extensions, `~/.pi/agent/pstack/models.json`, and the
`pi-hermes-memory` store are machine-local and deliberately not Nix-managed.
Install a provider extension under `~/.pi/agent/extensions/<name>/`, where pi
auto-discovers it.

To add a global skill: create `agents/skills/<name>/SKILL.md`; the link list
is derived, and the build fails if a directory has no `SKILL.md`. To add a
repo-local skill: create `.agents/skills/<name>/SKILL.md`; no Nix change is
needed.

## dotfiles CLI commands

`apply`, `sync`, and `upgrade` live in `scripts/dotfiles.sh`, which
`modules/dotfiles.nix` installs through `writeShellApplication` (so the build
shellchecks it). README.md owns the command table and the pin story.

Adding a pinned package means giving it `pname`, `version`, and a `src` built
from `${version}`, listing it in `pin_names`, and exposing it as a flake
package. codediff-watcher is the exception: its version comes from nixpkgs'
`vimPlugins.codediff-nvim`, so only its per-system hashes are hand-edited.

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
for m in desktop mac; do
  echo "== $m"
  nix --extra-experimental-features "nix-command flakes" eval --impure \
    --json ".#homeConfigurations.$m.config.xdg.configFile" --apply builtins.attrNames
  nix --extra-experimental-features "nix-command flakes" eval --impure \
    --json ".#homeConfigurations.$m.config.home.packages" --apply 'ps: map (p: p.name) ps'
done
```

Evaluation reads `$HOME`, so the `mac` attribute evaluated on Linux prints
Linux home paths. Compare names and keys, not absolute paths.

## Supported platforms

`x86_64-linux` (Ubuntu, Arch, NixOS) and `aarch64-darwin` (Apple Silicon).
README.md covers the bootstrap, the machine table, and the NixOS system layer,
including how to add a machine.
