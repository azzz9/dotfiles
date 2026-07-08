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
  outputs = { self, nixpkgs, ... }@inputs: {
    homeConfigurations = {
      "x86_64-linux" = ...;
      "aarch64-darwin" = ...;
    };
  };
}
```

### Module imports

`hosts/default.nix` imports modules:
```nix
imports = [
  ../modules/dotfiles.nix
  ../modules/shell.nix
  ../modules/tmux.nix
  ../modules/nvim.nix
  # ...
];
```

### lib helpers used in this repo

- `lib.concatMap` — flat-map over lists (used for skill/rule symlink generation)
- `builtins.listToAttrs` — convert list of attr pairs to attrset
- `builtins.getEnv "HOME"` — get home directory at evaluation time
- `builtins.elem` — check list membership

## Common pitfalls

### 1. New files must be `git add`'d

Nix flakes only see files tracked by git. If you create a new `.nix` file
or Lua file, **you must `git add` it** before `home-manager switch` or
`nix build` will see it. Untracked files are invisible to the flake.

### 2. --impure is required

This repo uses `builtins.getEnv "HOME"` and `builtins.getEnv "USER"`,
which are impure operations. Always pass `--impure`:

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
compatibility (see `modules/dotfiles.nix`).

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

## Useful one-liners

```bash
# Quick syntax check on all .nix files
find . -name '*.nix' -exec nix-instantiate --parse {} > /dev/null \;

# Eval a specific attribute
nix eval --raw .#homeConfigurations.x86_64-linux.activationPackage --impure

# Build and activate (inside sandbox — needs XDG_CACHE_HOME workaround)
XDG_CACHE_HOME=/tmp/nix-cache dotfiles apply

# Build and activate (outside sandbox)
dotfiles apply

# Update flake inputs
dotfiles upgrade
```
