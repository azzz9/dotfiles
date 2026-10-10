# dotfiles

Home Manager + Nix flake setup for x86_64 Linux (Ubuntu, Arch, NixOS) and Apple
Silicon macOS. Every machine gets one user environment, described by a row in
`flake.nix`. A NixOS machine gets a system configuration from the same flake too.

## Install

Download
[setup-system.sh](https://raw.githubusercontent.com/azzz9/dotfiles/main/scripts/setup-system.sh)
with a browser, then run it. `MACHINE` names this machine and is required.

```bash
MACHINE=macbook \
GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" \
  bash ~/Downloads/setup-system.sh
```

With Git already installed, cloning first works too.

```bash
git clone https://github.com/azzz9/dotfiles.git ~/src/github.com/azzz9/dotfiles
MACHINE=macbook GIT_NAME="your-name" GIT_EMAIL="your-noreply@users.noreply.github.com" \
  ~/src/github.com/azzz9/dotfiles/scripts/setup-system.sh
```

The script installs the system packages it needs, and Nix when Nix is missing.
It clones the repository to `~/src/github.com/azzz9/dotfiles`, which is the ghq
root, so `ghq list` shows it with no registration. It applies the Home Manager
profile for `MACHINE`. On NixOS it also applies the system configuration, which
sets the hostname to `MACHINE`, and asks for your password once.

`MACHINE` must name a row the repository carries. The rows today are
`nix-desktop`, `macbook`, and `nix-server`, and `flake.nix`'s `machines` table is
the source. NixOS is the exception to the rule. There a new name adopts the
machine, by writing `hardware-configuration.nix`, copying
`/etc/nixos/configuration.nix` in, writing `default.nix`, and adding the row.

`git config core.hooksPath .githooks` in the checkout runs `scripts/check.sh`
before every push, the same set CI builds.

To apply by hand instead of running the bootstrap:

```bash
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#<machine> --impure -b backup
```

| Variable             | Default                                    | Purpose                                                                               |
| -------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------- |
| `MACHINE`            | required                                   | This machine's name. The `machines` row to apply, and the hostname the bootstrap sets. The rows today are `nix-desktop`, `macbook`, and `nix-server` |
| `DOTFILES_DIR`       | `~/src/github.com/azzz9/dotfiles`          | Checkout to clone or reuse                                                            |
| `MACHINE_CAPABILITY` | picked from the copied NixOS configuration | `desktop` or `headless`, the capability module a new NixOS machine imports            |
| `REBOOT`             | `0`                                        | Reboot at the end, where the setup asked for one                                      |

## Daily use

| Command            | Description                          |
| ------------------ | ------------------------------------ |
| `dotfiles apply`   | Build and apply the current checkout |
| `dotfiles audit`   | Check this machine's packages against open security issues |
| `dotfiles sync`    | Pull, then apply                     |
| `dotfiles upgrade` | Pull, move every pin, then apply     |

The machine's name is its hostname and its row key, so none of these needs an
argument. An argument names another machine, which is also the only reason to
give one.

`sync` parks the three files `upgrade` rewrites in a stash before it pulls, so a
machine that has not committed its own pins still takes the other machine's
commits. It refuses to run while any other file differs, because `apply` would
otherwise activate a half-finished edit. The stash stays until it is dropped or
popped, and the command for either is in the output.

`upgrade` pulls, moves the pins, and applies. It leaves the files it moved in the
working tree and names them. Commit and push those, or the other machines keep
their own pins.

The system configuration applies on its own:

```bash
sudo nixos-rebuild switch --flake ~/src/github.com/azzz9/dotfiles#<machine> --impure
```

## What is installed

| Area           | What                                                                          |
| -------------- | ----------------------------------------------------------------------------- |
| Shell          | Zsh, the prompt, fzf, and the `dotfiles` completion                           |
| Editor         | Neovim through nixvim, with the per-language servers, formatters, and linters |
| Git            | `git`, `gh`, `ghq`, `git-wt`, `delta`, `lazygit`                              |
| Terminals      | `herdr`, `hunk`, and `tuios`                                                  |
| Agents         | `pi` with the pstack skills and subagents                                     |
| Tools          | The file, JSON, media, and language toolchains the shell assumes              |
| Extra packages | The derivations nixpkgs lacks, pinned and bumped by `dotfiles upgrade`        |

Where it lives:

```
flake.nix             # the machines table, homeConfigurations, nixosConfigurations, checks
hosts/default.nix     # the Home Manager entry point and the skill links
hosts/platform/       # the per-platform differences, and the NixOS layer
modules/              # one module per capability, named for what it configures
agents/               # the AI agent rules and the global skills
scripts/              # the dotfiles CLI, the bootstrap, and the check set
.agents/skills/       # the skills that only make sense in this repository
```
