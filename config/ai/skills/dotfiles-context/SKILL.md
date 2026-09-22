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
+-- flake.nix               # inputs, outputs, homeConfigurations
+-- hosts/default.nix        # HM entry point, AI symlinks, skill list
+-- modules/
|   +-- dotfiles.nix         # dotfiles CLI (apply / sync / upgrade)
|   +-- git.nix             # Git config + ghq + git-wt defaults
|   +-- gh.nix              # GitHub CLI aliases
|   +-- shell.nix           # Zsh + fzf + autocomplete + dev()
|   +-- herdr.nix           # herdr agent multiplexer (kanagawa theme, agent launchers)
|   +-- ghostty.nix         # macOS Ghostty configuration (Ghostty external)
|   +-- nvim.nix            # Neovim via nixvim
|   +-- nvim/lua/           # Lua configs loaded by nixvim extraConfigLua
|   +-- packages.nix        # Additional system packages
|   +-- solidity.nix        # Solidity toolchain
|   +-- lazygit.nix          # lazygit config (delta stdin filter)
+-- config/ai/
|   +-- AGENTS.md           # Core rules + inline rules (read-only gate, language, etc.)
|   +-- skills/             # Local AI skills
+-- scripts/setup-system.sh # Bootstrap script
+-- .githooks/pre-push       # Pre-push checks
+-- .github/workflows/ci.yml # CI

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

`modules/herdr.nix` installs herdr and generates
`~/.config/herdr/config.toml` via HM.
Theme: kanagawa (built-in). Key bindings retain the former pane layout
(prefix ctrl+b, / and - for splits, h/j/k/l for pane nav).
Agent launcher: prefix+shift+g (gh copilot).
Completion notifications use herdr's system delivery backend with a
15-second delay; the WSL Windows toast bridge remains enabled.

## AI config deployment model

`hosts/default.nix` deploys AI config using out-of-store symlinks so
edits in this repo are immediately reflected at the target path:

```
config/ai/AGENTS.md                  -> ~/.copilot/copilot-instructions.md
config/ai/skills/<name>              -> ~/.agents/skills/<name>
                                    -> ~/.copilot/skills/<name>
```

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

Moving that pin takes two steps. Edit the sha, run `dotfiles apply`, then run
`pi update git:github.com/azzz9/pi-pstack`. Activation only reconciles
`settings.json`. Without the update the checkout stays on the old ref.

The fork's bundled scripts (`skills/poteto-mode/scripts`) install their own
dependencies on first run through `bootstrap.ts`, so no manual `bun install` is
needed. `bun` comes from `programs.pi-coding-agent.extraPackages`.

Provider packages are deliberately absent from that list. Subscriptions, model
catalogs, quotas, and API keys differ per machine, so a provider extension is
installed locally into `~/.pi/agent/extensions/<name>/` where pi auto-discovers
it, or with a local `pi install`. The same rule covers model choices. pstack
role models live in `~/.pi/agent/pstack/models.json`, which is machine-local
and deliberately not Nix-managed. `~/.agents/pstack-models.md` is kept as the
readable record of the same choices.

All rules (file-change-reporting, git-commit-push, diagrams) are inline
in `config/ai/AGENTS.md`. Copilot CLI reads them via the AGENTS.md symlink, so
no separate rule files or `.instructions.md` generation are needed. The
`.agents/skills` path is the shared user scope for local skills consumed by pi
and Copilot; the copilot-specific links remain for compatibility.

To add a local skill: create `config/ai/skills/<name>/SKILL.md` and add
the name to `localSkillNames` in `hosts/default.nix`.

## dotfiles CLI commands

| Command | Description |
|---------|-------------|
| `dotfiles apply` | Build + activate current checkout (no clean requirement) |
| `dotfiles sync` | Pull latest + apply (requires clean repo) |
| `dotfiles upgrade` | Update flake.lock inputs + apply (requires clean repo) |

All commands auto-detect host (`uname -m` + `uname -s`).

## Supported platforms

- `x86_64-linux` (WSL2 / Arch)
- `aarch64-darwin` (Apple Silicon Mac)
- `x86_64-darwin` (Intel Mac — deprecated, may be removed)

Host attribute auto-detected in flake.nix via `flake-utils` or manual
mapping.
