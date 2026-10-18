---
name: nix-home-manager
description: "Guide for editing Nix flake + Home Manager configs. Use when modifying .nix files in this dotfiles repo to avoid syntax errors, build failures, and repeated trial-and-error."
---

# nix-home-manager

Verify in this order:

```bash
nix-instantiate --parse modules/some-file.nix > /dev/null   # syntax
nix fmt modules/some-file.nix                               # the repo formatter
nix eval --raw .#homeConfigurations.nix-desktop.activationPackage.drvPath 2>&1 | head -20
nix build --dry-run .#homeConfigurations.nix-desktop.activationPackage 2>&1 | tail -20
./scripts/check.sh                                          # the whole set
./scripts/check.sh --only <check>                           # one of them
```

## Rules

- Never pass `--impure`. `flake.nix` states the account (`user`) and each row's
  `homeDirectory`, `checkout`, and `skillsCheckout`, and the `link-path` check
  fails on `builtins.getEnv` or `builtins.currentSystem` under `flake.nix`,
  `hosts/`, `modules/`, or `dotfiles-cli.nix`.
- `git add` a new file before any Nix command. The flake sees tracked files
  only, and `scripts/`, `tests/`, `modules/herdr/worktree-layout/`, and the Lua
  tree are read by name, so an unadded file fails with `path ... does not exist`.
- `dotfiles upgrade` needs a clean tree. `dotfiles sync` refuses only on a
  change outside the pins (`upgrade_paths` in `scripts/dotfiles.sh`), then
  stashes the pins and pulls. `dotfiles apply` does not check.
- In the agent sandbox, prefix Nix with `XDG_CACHE_HOME=/tmp/nix-cache`, or Nix
  fails with `unable to open database file`.
- `hosts/default.nix` links the rules files out of the skills checkout, so an
  edit there is live without a rebuild.
- Activation calls `nix profile add`; `scripts/dotfiles.sh` rewrites
  `profile install` to `profile add` for Determinate Nix.

## Checks

`flake.nix` wires `checks.<system>` and `scripts/check.sh` invokes it.
`format` runs `nixfmt --check` over every `.nix` file, `statix` runs with the
repository's `statix.toml`, `stylua` checks `modules/nvim/lua`, and `deadnix`,
`shellcheck`, and `actionlint` are self-evident. `generated-configs` parses every
emitted TOML, YAML, zsh, and Lua file. `docs` compares README.md's machines table
and the skill's pin table against `flake.nix` and `scripts/dotfiles.sh`.
`gitleaks` scans the committed tree for secrets and reads no history, because a
flake copy carries no `.git`.
`bootstrap` drives `setup-system.sh` against fixture PATHs, and
`dotfiles-cli` drives `scripts/dotfiles.sh` against fixture git repositories,
with the nix build and the activation it feeds stubbed.

A failed check reads `nix log .#checks.<system>.<check>`.

## Asserts

- `modules/nvim.nix`: every `.lua` file under `modules/nvim/lua/` appears in
  `luaFiles`.
