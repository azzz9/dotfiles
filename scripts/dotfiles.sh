#!/usr/bin/env bash
# The `dotfiles` CLI. modules/dotfiles.nix installs this file through
# writeShellApplication and supplies two values from flake.nix:
#   DOTFILES_DIR               the checkout to build and activate
#   DOTFILES_SUPPORTED_HOSTS   the homeConfigurations attributes that exist
# `apply` also runs pi_reconcile from scripts/pi-reconcile.sh after activation,
# so a build that moved a pi package pin lands its checkout too.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: dotfiles <command> [host]

commands:
  apply      apply the current checkout, reconciling stale pi package checkouts
  sync       pull latest changes, then apply
  upgrade    update flake.lock inputs, then apply
EOF
}

repo="${DOTFILES_DIR:?DOTFILES_DIR is not set; run the installed dotfiles command}"
supported_hosts="${DOTFILES_SUPPORTED_HOSTS:?DOTFILES_SUPPORTED_HOSTS is not set}"

command="${1:-}"
if [ -z "$command" ] || [ "$command" = "-h" ] || [ "$command" = "--help" ]; then
  usage
  exit 0
fi
shift

# Auto-detect system if no host argument is given.
# macOS reports "arm64"; Nix expects "aarch64".
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then
  arch="aarch64"
fi
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
host="${1:-$arch-$os}"

# flake.nix owns the host list; fail here rather than inside nix eval.
case " $supported_hosts " in
  *" $host "*) ;;
  *)
    echo "dotfiles: unsupported host: $host" >&2
    echo "dotfiles: supported hosts: $supported_hosts" >&2
    exit 2
    ;;
esac

tmp_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
lock_dir="$tmp_dir/dotfiles.lockdir"
lock_backup=""
pin_backup=""
pin_scratch=""
patched_activate=""
have_lock=0
# modules/pinned-packages.nix holds every derivation that is not packaged by
# nixpkgs and carries its own version; `nix-update` bumps the ones named here.
pins_file="modules/pinned-packages.nix"
pin_names=(solhint roots prettier-plugin-solidity prettier-plugin-solidity-dist)
trap 'if [ -n "$patched_activate" ]; then rm -f "$patched_activate"; fi; if [ -n "$lock_backup" ]; then rm -f "$lock_backup"; fi; if [ -n "$pin_backup" ]; then rm -f "$pin_backup"; fi; if [ -n "$pin_scratch" ]; then rm -f "$pin_scratch"; fi; if [ "$have_lock" = 1 ]; then rmdir "$lock_dir" 2>/dev/null || true; fi' EXIT
if ! mkdir "$lock_dir" 2>/dev/null; then
  echo "dotfiles: already running; skipping"
  exit 0
fi
have_lock=1

# Services start with a minimal PATH, so add the directories Home Manager's
# activate script expects alongside the runtime inputs on PATH.
export PATH="/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

nix_cmd() {
  nix --extra-experimental-features "nix-command flakes" "$@"
}

if [ ! -d "$repo/.git" ]; then
  echo "dotfiles: $repo not found" >&2
  exit 1
fi

cd "$repo"

require_clean_repo() {
  status="$(git status --porcelain --untracked-files=normal)"
  if [ -n "$status" ]; then
    echo "dotfiles $command: local or untracked changes found in $repo; skipping" >&2
    echo "$status" >&2
    echo "dotfiles $command: commit, stash, or discard local changes first" >&2
    exit 0
  fi
}

build_home() {
  activation_path="$(nix_cmd build --no-link --print-out-paths "$repo#homeConfigurations.$host.activationPackage" --impure)"
  patched_activate="$(mktemp "$tmp_dir/dotfiles-activate.XXXXXX")"
  cp "$activation_path/activate" "$patched_activate"
}

activate_home() {
  # Determinate Nix only has `nix profile add`, while older Home Manager
  # activate scripts call `nix profile install`. The elif guard fails loudly
  # if Home Manager switches to another command form.
  if grep -q 'profile install' "$patched_activate"; then
    sed -i 's/profile install/profile add/g' "$patched_activate"
  elif ! grep -q 'profile add' "$patched_activate"; then
    echo "dotfiles: expected activation profile command not found" >&2
    exit 1
  fi
  bash "$patched_activate"
}

apply_home() {
  build_home
  activate_home
  # Activation writes the new pins into settings.json, so the reconcile follows it.
  pi_reconcile
}

restore_lock() {
  if [ -n "$lock_backup" ] && [ -f "$lock_backup" ]; then
    cp "$lock_backup" flake.lock
    echo "dotfiles upgrade: restored flake.lock after failure" >&2
  fi
}

restore_pins() {
  if [ -n "$pin_backup" ] && [ -f "$pin_backup" ]; then
    cp "$pin_backup" "$pins_file"
    echo "dotfiles upgrade: restored $pins_file after failure" >&2
  fi
}

restore_upgrade() {
  restore_lock
  restore_pins
}

# Bump each derivation pinned in $pins_file on its own. nix-update prints its
# own "Update X -> Y" lines. A bump that fails (for example a new release
# needs a newer Go than nixpkgs carries) restores only that pin's state and
# warns, so one blocked release does not keep the whole upgrade from running.
bump_pins() {
  for name in "${pin_names[@]}"; do
    cp "$pins_file" "$pin_scratch"
    echo "dotfiles upgrade: bumping $name"
    if ! nix-update --flake "$name"; then
      cp "$pin_scratch" "$pins_file"
      echo "dotfiles upgrade: bumping $name failed; kept its previous pin" >&2
    fi
  done
}

case "$command" in
  apply)
    apply_home
    ;;
  sync)
    require_clean_repo
    git pull --ff-only
    apply_home
    ;;
  upgrade)
    require_clean_repo
    pin_backup="$(mktemp "$tmp_dir/dotfiles-pins.XXXXXX")"
    pin_scratch="$(mktemp "$tmp_dir/dotfiles-pin-bump.XXXXXX")"
    cp "$pins_file" "$pin_backup"
    lock_backup="$(mktemp "$tmp_dir/dotfiles-flake-lock.XXXXXX")"
    cp flake.lock "$lock_backup"
    if ! nix_cmd flake update; then
      restore_upgrade
      exit 1
    fi
    # After the flake update on purpose: a release that needs a newer toolchain
    # than the previous nixpkgs carried can still be bumped in the same run.
    bump_pins
    if ! build_home; then
      restore_upgrade
      exit 1
    fi
    if ! activate_home; then
      restore_upgrade
      exit 1
    fi
    moved_files=""
    for moved_file in flake.lock "$pins_file"; do
      if ! git diff --quiet -- "$moved_file"; then
        moved_files="$moved_files $moved_file"
      fi
    done
    if [ -n "$moved_files" ]; then
      echo "dotfiles upgrade: these files moved; review and commit them to keep the next apply on these pins:$moved_files"
    fi
    pi_reconcile
    ;;
  *)
    echo "dotfiles: unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
