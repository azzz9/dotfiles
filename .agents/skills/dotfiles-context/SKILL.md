---
name: dotfiles-context
description: "Quick reference for this Nix flake + Home Manager dotfiles repo. Use when working in ~/src/github.com/azzz9/dotfiles to avoid re-exploring the repository structure every session."
---

# dotfiles-context Skill

This is a Nix flake + Home Manager dotfiles repository. Read this skill
before exploring files so you start with full context.

## Repository layout

```
dotfiles/
+-- flake.nix                # inputs, outputs, homeConfigurations, checks
+-- hosts/default.nix        # HM entry point, skill symlinks, machine basics
+-- modules/
|   +-- dotfiles.nix         # wraps scripts/dotfiles.sh as the `dotfiles` CLI
|   +-- pi.nix               # pi packages and the settings.json merge
|   +-- git.nix              # git config + ghq + git-wt defaults
|   +-- gh.nix               # GitHub CLI aliases
|   +-- shell.nix            # zsh: aliases, plugins, init script ordering
|   +-- shell/init/          # zsh init scripts sourced by shell.nix; dev()/deva() live here
|   +-- herdr.nix            # herdr multiplexer + Windows toast bridge
|   +-- hunk.nix             # hunk diff review TUI (Linux ld-linux wrapper)
|   +-- ghostty.nix          # macOS Ghostty configuration (Ghostty external)
|   +-- nvim.nix             # Neovim via nixvim
|   +-- nvim/lua/            # Lua configs loaded by nixvim extraConfigLua
|   +-- packages.nix         # Additional system packages
|   +-- solidity.nix         # Solidity toolchain
|   +-- lazygit.nix          # lazygit config (delta stdin filter)
+-- config/ai/
|   +-- AGENTS.md            # Core rules (turn gate, show-me gate, git rules)
|   +-- skills/              # Global skills (linked to ~/.agents/skills)
+-- .agents/skills/          # Project-scoped skills (this repo only)
+-- scripts/
|   +-- dotfiles.sh          # the `dotfiles` CLI (apply / sync / upgrade)
|   +-- check.sh             # runs the flake checks; used by the hook and CI
|   +-- setup-system.sh      # Bootstrap script
+-- .githooks/pre-push       # Pre-push checks
+-- .github/workflows/ci.yml # CI
```

## Neovim config structure

nvim is managed by **nixvim** (not lazy.nvim). Plugins are declared in
`modules/nvim.nix` via `programs.nixvim`. Lua overrides live in
`modules/nvim/lua/` and are loaded via `extraConfigLua` / `extraPlugins`.

Key Lua files:
- `modules/nvim/lua/core.lua` — core settings
- `modules/nvim/lua/ui.lua` — UI / diagnostics
- `modules/nvim/lua/languages.lua` — per-language LSP / formatter / linter
- `modules/nvim/lua/plugins/*.lua` — individual plugin configs
- `modules/nvim/lua/plugins/dap/*.lua` — DAP per-language configs

## herdr config

`modules/herdr.nix` installs herdr and generates `~/.config/herdr/config.toml`
via HM. Theme: kanagawa (built-in). Splits are prefix ctrl+b with `/` and `-`,
pane navigation is alt+h/j/k/l, tabs and workspaces are alt+shift+h/j/k/l.
No agent launcher is bound.
Completion notifications use herdr's system delivery backend with a 15-second
delay; the WSL Windows toast bridge remains enabled. Herdr's pi integration is
reinstalled on every activation.

## AI config deployment model

`hosts/default.nix` deploys AI config using out-of-store symlinks so
edits in this repo are immediately reflected at the target path:

```
config/ai/AGENTS.md                  -> ~/.pi/agent/AGENTS.md
config/ai/skills/<name>              -> ~/.agents/skills/<name>
```

Skills come in two scopes. Every directory under `config/ai/skills` is linked
into `~/.agents/skills/` and visible in all projects; the link list comes from
`builtins.readDir`, so there is no list to keep in sync. The two skills that
only make sense here sit in `.agents/skills/` at the repo root instead, where pi
discovers them as project skills once the project is trusted. Neither is linked
globally, so neither costs tokens in other projects.

pstack is not vendored as a tree. pi consumes the personal fork
`git:github.com/azzz9/pi-pstack@<sha>` (pinned in `hosts/default.nix`) with
`npm:pi-subagents` alongside it. The fork carries the pi-native port plus local
harness fixes (pi session paths, pi subagent parameters, no Cursor cloud agents,
review-automation naming, the `todo` tool). It ships the skills, the
`comment-sicko` and `poteto-agent` subagents through its `pi.subagents.agents`
manifest, and an extension that injects the role-model table, provides sticky
`/poteto-mode`, and controls the skill catalog with `/pstack`. The plugins
`npm:@juicesharp/rpiv-todo` and `npm:@juicesharp/rpiv-ask-user-question` supply
the `todo` and `ask_user_question` tools the playbooks call.
`npm:@juicesharp/rpiv-btw` adds the `/btw` side-question overlay. The three are
pinned to one rpiv release train, so they move together.

Moving that pin takes two steps. Edit the sha, run `dotfiles apply`, then run
`pi update git:github.com/azzz9/pi-pstack`. Activation only reconciles
`settings.json`. Without the update the checkout stays on the old ref.

The fork's bundled scripts (`skills/poteto-mode/scripts`) install their own
dependencies on first run through `bootstrap.ts`, so no manual `bun install` is
needed. `bun` also comes from `programs.pi-coding-agent.extraPackages`, which
puts it on PATH for pi only, and from `modules/packages.nix` for plain shells.

Provider packages are deliberately absent from that list. Subscriptions, model
catalogs, quotas, and API keys differ per machine, so a provider extension is
installed locally into `~/.pi/agent/extensions/<name>/` where pi auto-discovers
it, or with a local `pi install`. The same rule covers model choices. pstack
role models live in `~/.pi/agent/pstack/models.json`, which is machine-local
and deliberately not Nix-managed. `~/.pi/agent/pstack/models.md` is the readable
record of the same choices, including the budget reasoning the JSON cannot
carry. It sits inside the pstack directory, so the agent dir root matches a
fresh `/setup-pstack` exactly.

The inline rules that remain in `config/ai/AGENTS.md` are the turn gate, the
show-me gate, and the git rules. pi reads them through the symlink at
`~/.pi/agent/AGENTS.md`, so no separate rule files are needed. The
`.agents/skills` path is the shared user scope for local skills consumed by pi.

To add a global skill: create `config/ai/skills/<name>/SKILL.md`; the link list
is derived, and the build fails if a directory has no `SKILL.md`. To add a
repo-local skill: create `.agents/skills/<name>/SKILL.md`; no Nix change is
needed.

## dotfiles CLI commands

`apply`, `sync`, and `upgrade` are implemented in `scripts/dotfiles.sh`, which
`modules/dotfiles.nix` installs through `writeShellApplication` (so the build
shellchecks it). The command table lives in `README.md`.

## Checks

`flake.nix` defines `checks.<system>`: deadnix, shellcheck (scripts and the
pre-push hook), actionlint, and generated-configs (parses the emitted TOML,
YAML, zsh, and Lua). The pre-push hook and CI both run `scripts/check.sh`, so
the check set has one definition. Registry drift is caught by asserts instead:
`modules/nvim.nix` compares `luaFiles` with `modules/nvim/lua/`, and
`hosts/default.nix` requires a `SKILL.md` in every skill directory.

## Supported platforms

- `x86_64-linux` (WSL2 / Arch)
- `aarch64-darwin` (Apple Silicon Mac)

`flake.nix` owns `supportedSystems`. `scripts/setup-system.sh` and the
`dotfiles` CLI detect `uname -m` / `uname -s`, and the CLI rejects a host
outside that list. `HM_HOST` overrides the detection.
