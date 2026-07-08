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
|   +-- herdr.nix           # herdr agent multiplexer (tokyo-night theme, agent launchers)
|   +-- nvim.nix            # Neovim via nixvim
|   +-- nvim/lua/           # Lua configs loaded by nixvim extraConfigLua
|   +-- packages.nix        # Additional system packages
|   +-- solidity.nix        # Solidity toolchain
|   +-- lazygit.nix          # lazygit config (delta side-by-side)
+-- config/ai/
|   +-- AGENTS.md           # Core rules (read-only gate, language, dispatch)
|   +-- rules/              # On-demand rule files
|   +-- codex/              # Codex-specific config + default.rules
|   +-- skills/             # AI skills (symlinked to ~/.codex and ~/.copilot)
+-- scripts/setup-system.sh # Bootstrap script
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

`modules/herdr.nix` installs herdr + tmux (for the tmux skill) and
generates `~/.config/herdr/config.toml` via HM.
Theme: tokyo-night (built-in). Key bindings match the previous tmux
layout (prefix ctrl+b, / and - for splits, h/j/k/l for pane nav).
Agent launchers: prefix+shift+c (codex), prefix+shift+g (gh copilot).
tmux is kept as a package for the tmux skill (programmatic terminal
control via send-keys / capture-pane).

## AI config deployment model

`hosts/default.nix` creates **out-of-store symlinks** so edits in this
repo are immediately reflected at the target paths:

```
config/ai/AGENTS.md        -> ~/.codex/AGENTS.md
                           -> ~/.copilot/copilot-instructions.md
config/ai/rules/<name>.md  -> ~/.codex/rules/<name>.md
                           -> ~/.copilot/rules/<name>.md
config/ai/skills/<name>    -> ~/.codex/skills/<name>
                           -> ~/.copilot/skills/<name>
config/ai/codex/config.base.toml -> ~/.codex/dotfiles.config.toml
config/ai/codex/rules/default.rules -> ~/.codex/rules/default.rules
```

To add a new skill: create `config/ai/skills/<name>/SKILL.md` and add
the name to `skillNames` in `hosts/default.nix`.

To add a new rule: create `config/ai/rules/<name>.md`, add to `ruleNames`
in `hosts/default.nix`, and add a row to the On-demand Rules table in
`config/ai/AGENTS.md`.

## dotfiles CLI commands

| Command | Description |
|---------|-------------|
| `dotfiles apply` | Build + activate current checkout (no clean requirement) |
| `dotfiles sync` | Pull latest + apply (requires clean repo) |
| `dotfiles upgrade` | Update flake.lock inputs + apply (requires clean repo) |

All commands auto-detect host (`uname -m` + `uname -s`).

## Known sandbox limitations (Codex)

- `.git` directory is **read-only**. Commits require
  `sandbox_permissions="require_escalated"` or manual user execution.
- Network is **available** (`network_access = true`). `nix build` can
  download packages, but may be slow on first run.
- `~/.cache/nix` is **read-only**. Prefix nix commands with
  `XDG_CACHE_HOME=/tmp/nix-cache` to use a writable temp cache directory.
- tmux sockets are **inaccessible**. Cannot verify tmux config at runtime.

## Supported platforms

- `x86_64-linux` (WSL2 / Arch)
- `aarch64-darwin` (Apple Silicon Mac)
- `x86_64-darwin` (Intel Mac — deprecated, may be removed)

Host attribute auto-detected in flake.nix via `flake-utils` or manual
mapping.
