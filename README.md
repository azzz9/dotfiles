# dotfiles

Home Manager + Nix flake setup for x86_64 Linux (Ubuntu, Arch, NixOS) and Apple
Silicon macOS. Every machine gets one user environment, described by a row in
`flake.nix`. The NixOS system layer of a machine lives in its own repository,
[azzz9/machines](https://github.com/azzz9/machines), which this repository does
not depend on.

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
profile for `MACHINE`. On NixOS it also clones the machines repository, adopts
the machine there when the row is new, and applies the system configuration,
which sets the hostname to `MACHINE`. The system switch asks for your password
once.

`MACHINE` must name a row the repository carries. The rows today are
`nix-desktop`, `macbook`, and `nix-server`, and `flake.nix`'s `machines` table is
the source. NixOS is the exception to the rule. There a new name adopts the
machine in the machines repository, by writing `hardware-configuration.nix`,
copying `/etc/nixos/configuration.nix` in, writing `default.nix`, and adding the
row to that repository's table.

`git config core.hooksPath .githooks` in the checkout runs `scripts/check.sh`
before every push, the same set CI builds.

To apply by hand instead of running the bootstrap:

```bash
nix run nixpkgs#home-manager -- switch --flake ~/src/github.com/azzz9/dotfiles#<machine> --impure -b backup
```

| Variable             | Default                                    | Purpose                                                                               |
| -------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------- |
| `MACHINE`            | required                                   | This machine's name. The `machines` row to apply, and the hostname the bootstrap sets. The rows today are `nix-desktop`, `macbook`, and `nix-server` |
| `DOTFILES_DIR`       | `~/src/github.com/azzz9/dotfiles`          | Checkout to clone or reuse, and the checkout to build. The live links name the machines row's `checkout` instead |
| `MACHINE_CAPABILITY` | picked from the copied NixOS configuration | `desktop` or `headless`, the capability module a new NixOS machine imports            |
| `REBOOT`             | `0`                                        | Reboot at the end, where the setup asked for one                                      |

## Daily use

| Command            | Description                          |
| ------------------ | ------------------------------------ |
| `dotfiles apply`   | Build and apply, then install any `pi` package whose version differs |
| `dotfiles audit`   | Check this machine's packages against open security issues |
| `dotfiles rollback`| Apply the commit applied before the current one |
| `dotfiles status`  | Report what is out of date here, changing nothing |
| `dotfiles sync`    | Check out `main`, pull, then apply   |
| `dotfiles upgrade` | Move every pin to its latest, then build and apply |

The machine's name is its hostname and its row key, so none of these needs an
argument. An argument names another machine, which is also the only reason to
give one.

`audit` is run by hand. Run it on the machine after a pin bump; it prints every
match, including the ones only a nixpkgs fix can clear.

`sync` refuses any dirty path, because `apply` would otherwise activate a
half-finished edit. It checks out `main`, so a machine that rolled back returns
to the head of `main` with another `sync`.

`status` shows the applied commit from `~/.local/state/dotfiles/applied.log`
against `origin/main`, and `rollback` applies the commit applied before the
current one. Both read the log, so "which commit was working" does not depend on
memory.

`dotfiles upgrade` moves every pin with `scripts/bump-pins.sh`, builds and
applies, reinstalls the GitHub Herdr plugins, and reports the audit. `herdr
plugin update` only refetches the ref recorded at install, so the plugin step
installs again to take the latest. Review the moved pin files, run
`scripts/check.sh` (the pre-push hook runs it too), and commit. To move one flake
input, run `nix flake update <input>`, commit `flake.lock`, then `dotfiles apply`.

The `Upgrade` workflow does the same bump without a checkout: every Monday it
runs `scripts/bump-pins.sh`, builds the result with `scripts/check.sh` on Linux
and macOS, and opens the `chore/pin-upgrade` pull request, which it squash-merges
as soon as both builds pass. Applying stays on the machine, so `dotfiles sync` is
what moves it. The audit stays by hand too, because it reads the packages that
machine has.

The npm rows in `modules/pi.nix` are tarballs, and `bump-pins.sh` moves them to
their registry latest, keeping each vendored dependency on the version its
parent names.

`status` changes nothing and never fetches. It reports how far the checkout is
from the upstream as of the last fetch, which of the three pin files are
uncommitted, whether the running Home Manager generation was built from this
checkout's lock, and whether any npm row pi still installs itself sits on its
pin. That last line is empty while every row is a store path, and catches a
reconcile that could not reach the network when a row is a `spec`:
`apply` then exits non-zero, but every other report still reads current.

One run at a time: a second `dotfiles` run exits 1 while another holds the lock,
and a lock left behind by a killed run is reclaimed instead of blocking every
run after it.

On a NixOS machine, `apply`, `sync`, and `rollback` change the user environment
only. The system layer is a separate checkout, and a change there needs the
system command below as well.

```bash
sudo nixos-rebuild switch --flake ~/src/github.com/azzz9/machines#<machine>
```

## What is installed

| Area           | What                                                                          |
| -------------- | ----------------------------------------------------------------------------- |
| Shell          | Zsh, the prompt, fzf, and the `dotfiles` completion                           |
| Editor         | Neovim through nixvim, with the per-language servers, formatters, and linters |
| Git            | `git`, `gh`, `ghq`, `git-wt`, `delta`, `lazygit`                              |
| Terminals      | `herdr`                                                                        |
| Agents         | `pi` with the skills and pstack                                               |
| Hermes Agent   | The agent service on `nix-server` only, from the `hermes-agent` flake input   |
| Tools          | The file, JSON, media, and language toolchains the shell assumes              |
| Extra packages | The derivations nixpkgs lacks, pinned and bumped by `scripts/bump-pins.sh`     |

Where it lives:

```
flake.nix             # the machines table, homeConfigurations, homeManagerModules, checks
hosts/default.nix     # the Home Manager entry point and the rules links
hosts/linux.nix       # what a Linux machine's home adds, imported by its row
hosts/darwin.nix      # what the macOS machine's home adds, imported by its row
modules/              # one module per capability, named for what it configures
scripts/              # the dotfiles CLI, the bootstrap, and the check set
.agents/skills/       # the skills that only make sense in this repository
```
