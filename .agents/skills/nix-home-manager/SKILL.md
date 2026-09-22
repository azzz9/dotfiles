---
name: nix-home-manager
description: "Guide for editing Nix flake + Home Manager configs. Use when modifying .nix files in this dotfiles repo to avoid syntax errors, build failures, and repeated trial-and-error."
---

# nix-home-manager Skill

Practical reference for working with Nix flakes and Home Manager in this
dotfiles repo. Load this skill before editing `.nix` files.

## Always verify syntax before building

```bash
# 1. Parse check (fast, no evaluation)
nix-instantiate --parse modules/some-file.nix > /dev/null

# 2. Eval check (catches type errors, attribute issues)
nix eval --raw .#homeConfigurations.x86_64-linux.activationPackage --impure 2>&1 | head -20

# 3. Dry-run build (catches build-time issues without downloading)
nix build --dry-run .#homeConfigurations.x86_64-linux.activationPackage --impure 2>&1 | tail -20

# 4. The full check set (deadnix, shellcheck, actionlint, generated-configs)
./scripts/check.sh
```

**Order matters**: parse -> eval -> dry-run -> full build. Catch errors
early to avoid wasting time.

## Common Nix patterns in this repo

### mkOutOfStoreSymlink (out-of-store symlinks)

```nix
config.lib.file.mkOutOfStoreSymlink "${repo}/path/to/source"
```

Creates a symlink from the HM-managed target to a file **inside** the
repo checkout. Edits to the repo file are immediately reflected at the
target. Used for AGENTS.md, rules, and skills deployment.

### flake.nix structure

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # ...
  };
  outputs = { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      # repoDir, mkHomeConfiguration, mkChecks live here too.
    in
    {
      homeConfigurations = nixpkgs.lib.genAttrs supportedSystems mkHomeConfiguration;
      checks = nixpkgs.lib.genAttrs supportedSystems mkChecks;
    };
}
```

`flake.nix` also owns `supportedSystems` and `repoDir`, which reach the modules
through `extraSpecialArgs`. Do not re-derive either in a module.

### Module imports

`hosts/default.nix` imports modules:
```nix
imports = [
  ../modules/dotfiles.nix
  ../modules/pi.nix
  ../modules/shell.nix
  ../modules/herdr.nix
  ../modules/hunk.nix
  ../modules/nvim.nix
  # ...
];
```

### lib helpers used in this repo

- `lib.concatMap` flat-maps over lists, used for the skill symlinks.
- `builtins.listToAttrs` turns a list of name/value pairs into an attrset.
- `builtins.getEnv "HOME"` reads the home directory at evaluation time.
- `builtins.elem` checks list membership.
- `builtins.readDir` derives a registry from disk instead of hand-listing it.
- `builtins.pathExists` asserts a derived entry is complete.
- `lib.subtractLists` gives the two directions of a registry diff.

## Checks and asserts

`checks.<system>` in `flake.nix` holds the whole verification layer, and
`scripts/check.sh` only invokes it. `nix flake check --impure` builds:

| check | catches |
|-------|---------|
| `deadnix` | unused let bindings and function arguments |
| `shellcheck` | script errors in `scripts/` and `.githooks/pre-push` |
| `actionlint` | workflow errors |
| `generated-configs` | malformed emitted TOML, YAML, `zsh`, or Lua |

Two asserts guard registries that must stay in step with the filesystem:

- `modules/nvim.nix`: `luaFiles` must equal the `.lua` files under
  `modules/nvim/lua/`. Adding a file without listing it fails evaluation.
- `hosts/default.nix`: every directory in `config/ai/skills` must contain a
  `SKILL.md`; the link list itself is derived, not listed.

## Common pitfalls

### 1. New files must be `git add`'d

Nix flakes only see files tracked by git. If you create a new `.nix` file,
Lua file, or script, **you must `git add` it** before `home-manager switch` or
`nix build` will see it. Untracked files are invisible to the flake. This bites
for real here: `scripts/dotfiles.sh` and `modules/pi.nix` are read by name, so an
unadded file fails with `path ... does not exist`.

### 2. --impure is required

This repo uses `builtins.getEnv "HOME"`, `"USER"`, and `"DOTFILES_DIR"`,
which are impure operations. Always pass `--impure`, including to
`nix flake check`, or `repoDir` resolves to a path under an empty HOME:

```bash
nix build .#homeConfigurations.x86_64-linux.activationPackage --impure
```

### 3. Dirty tree warnings

`dotfiles sync` and `dotfiles upgrade` require a clean git tree. Use
`dotfiles apply` when you have uncommitted changes (it does not check).

### 4. Sandbox nix cache workaround

Network access is enabled (`network_access = true`), but `~/.cache/nix`
is on a read-only filesystem in the sandbox. Prefix nix commands with
`XDG_CACHE_HOME=/tmp/nix-cache` to redirect the cache to a writable
temp directory:

```bash
XDG_CACHE_HOME=/tmp/nix-cache nix build .#homeConfigurations.x86_64-linux.activationPackage --impure
XDG_CACHE_HOME=/tmp/nix-cache nix search nixpkgs <package>
```

Without this, nix fails with `unable to open database file
(fetcher-cache-v4.sqlite)`.

### 5. Home Manager activation

After `nix build`, the `activate` script runs `nix profile add/install`.
This repo patches `profile install` -> `profile add` for Determinate Nix
compatibility (see `scripts/dotfiles.sh`).

## Debugging checklist

| Symptom | Check |
|---------|-------|
| File not found in flake | `git add` the file, then retry |
| `error: impure` | Add `--impure` flag |
| `index.lock` error | `.git` is read-only in sandbox; escalate |
| `nix flake show` fails | `~/.cache/nix` unwritable; use `XDG_CACHE_HOME=/tmp/nix-cache` |
| Build hangs | First download may be slow; ensure `XDG_CACHE_HOME` is set |
| Syntax error | `nix-instantiate --parse <file>` first |
| Type/attr error | `nix eval --raw .#...` to find the issue |
| Activation fails | Check `profile add` vs `profile install` patch |
| `luaFiles is out of sync` assert | add the file to `luaFiles` in `modules/nvim.nix` |
| `without SKILL.md` assert | add `SKILL.md` to that `config/ai/skills/<name>/` directory |
| A flake check fails | `nix log .#checks.<system>.<check>` for the tool output |

## Useful one-liners

```bash
# Quick syntax check on all .nix files
find . -name '*.nix' -exec nix-instantiate --parse {} > /dev/null \;

# Eval a specific attribute
nix eval --raw .#homeConfigurations.x86_64-linux.activationPackage --impure

# The whole check set, the same one CI builds
./scripts/check.sh

# Build and activate (inside the sandbox, needs the XDG_CACHE_HOME workaround)
XDG_CACHE_HOME=/tmp/nix-cache dotfiles apply

# Build and activate (outside the sandbox)
dotfiles apply

# Update flake inputs
dotfiles upgrade
```
