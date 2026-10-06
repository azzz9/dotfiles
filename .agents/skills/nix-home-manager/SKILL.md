---
name: nix-home-manager
description: "Guide for editing Nix flake + Home Manager configs. Use when modifying .nix files in this dotfiles repo to avoid syntax errors, build failures, and repeated trial-and-error."
---

# nix-home-manager Skill

Reference for working with Nix flakes and Home Manager in this repo. Load this
skill before editing `.nix` files.

## Verify in this order

```bash
nix-instantiate --parse modules/some-file.nix > /dev/null   # syntax
nix eval --raw .#homeConfigurations.desktop.activationPackage --impure 2>&1 | head -20
nix build --dry-run .#homeConfigurations.desktop.activationPackage --impure 2>&1 | tail -20
./scripts/check.sh                                          # the whole set
```

## Rules this repo enforces

- Pass `--impure` to every Nix command. `repoDir` reads `builtins.getEnv`, so
  without it the path resolves under an empty `HOME`.
- `git add` a new file before any Nix command. The flake sees tracked files
  only, and `scripts/`, `modules/herdr/worktree-layout/`, and the Lua tree are
  read by name, so an unadded file fails with `path ... does not exist`.
- `dotfiles sync` and `dotfiles upgrade` need a clean tree. `dotfiles apply`
  does not check.
- In the agent sandbox, prefix Nix with `XDG_CACHE_HOME=/tmp/nix-cache`.
  `~/.cache/nix` is read-only there, and Nix fails with `unable to open
  database file`.
- `hosts/default.nix` links `agents/AGENTS.md` and `agents/skills/*` with
  `mkOutOfStoreSymlink`, so an edit in the checkout takes effect without a
  rebuild.
- Activation calls `nix profile add`; `scripts/dotfiles.sh` rewrites
  `profile install` to `profile add` for Determinate Nix.

## Asserts that fail evaluation

- `modules/nvim.nix`: every `.lua` file under `modules/nvim/lua/` appears in
  `luaFiles`.
- `hosts/default.nix`: every directory in `agents/skills` holds a `SKILL.md`,
  and a skill whose body says `upstream:` holds a `LICENSE` beside it.

## Checks

`flake.nix` wires `checks.<system>`, and `scripts/check.sh` only invokes it.
The pre-push hook and CI build the same set, so they cannot disagree.

| check | catches |
|-------|---------|
| `deadnix` | unused let bindings and function arguments |
| `shellcheck` | script errors in `scripts/` and `.githooks/pre-push` |
| `actionlint` | workflow errors |
| `bootstrap` | `setup-system.sh` against fixture PATHs |
| `generated-configs` | malformed emitted TOML, YAML, `zsh`, or Lua; the activation order; the pi package rows |
| `pi-reconcile` | `pi_reconcile` against a stub `pi` |

## Debugging

| Symptom | Check |
|---------|-------|
| File not found in flake | `git add` the file |
| `error: impure` | add `--impure` |
| `index.lock` error | `.git` is read-only in the sandbox; escalate |
| Syntax error | `nix-instantiate --parse <file>` |
| Type or attribute error | `nix eval --raw .#... --impure` |
| A flake check fails | `nix log .#checks.<system>.<check>` |
| `luaFiles is out of sync` | add the file to `luaFiles` in `modules/nvim.nix` |
| `without SKILL.md` | add `SKILL.md` to that `agents/skills/<name>/` |
