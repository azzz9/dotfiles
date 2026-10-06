---
name: nix-home-manager
description: "Guide for editing Nix flake + Home Manager configs. Use when modifying .nix files in this dotfiles repo to avoid syntax errors, build failures, and repeated trial-and-error."
---

# nix-home-manager

Verify in this order:

```bash
nix-instantiate --parse modules/some-file.nix > /dev/null   # syntax
nix eval --raw .#homeConfigurations.desktop.activationPackage --impure 2>&1 | head -20
nix build --dry-run .#homeConfigurations.desktop.activationPackage --impure 2>&1 | tail -20
./scripts/check.sh                                          # the whole set
```

## Rules

- Pass `--impure`. `repoDir` reads `builtins.getEnv`, so without it the path
  resolves under an empty `HOME`.
- `git add` a new file before any Nix command. The flake sees tracked files
  only, and `scripts/`, `modules/herdr/worktree-layout/`, and the Lua tree are
  read by name, so an unadded file fails with `path ... does not exist`.
- `dotfiles sync` and `dotfiles upgrade` need a clean tree; `dotfiles apply`
  does not check.
- In the agent sandbox, prefix Nix with `XDG_CACHE_HOME=/tmp/nix-cache`, or Nix
  fails with `unable to open database file`.
- `hosts/default.nix` links `agents/AGENTS.md` and `agents/skills/*` out of
  store, so an edit in the checkout is live without a rebuild.
- Activation calls `nix profile add`; `scripts/dotfiles.sh` rewrites
  `profile install` to `profile add` for Determinate Nix.

## Checks

`flake.nix` wires `checks.<system>` and `scripts/check.sh` invokes it.
`deadnix`, `shellcheck`, and `actionlint` are self-evident. `bootstrap` drives
`setup-system.sh` against fixture PATHs. `generated-configs` parses every
emitted TOML, YAML, zsh, and Lua file, plus the activation order and the pi
package rows. `pi-reconcile` drives `pi_reconcile` with a stub `pi`.

## Asserts

- `modules/nvim.nix`: every `.lua` file under `modules/nvim/lua/` appears in
  `luaFiles`.
- `hosts/default.nix`: every `agents/skills/*` directory holds a `SKILL.md`, and
  a body containing `upstream:` needs a `LICENSE` beside it.

A failed check reads `nix log .#checks.<system>.<check>`.
