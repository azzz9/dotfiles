#!/usr/bin/env bash
# The `dotfiles` CLI. modules/dotfiles.nix installs this file through
# writeShellApplication and supplies two values from flake.nix:
#   DOTFILES_DIR       the checkout to build and activate
#   DOTFILES_MACHINES  the homeConfigurations attributes that exist
set -euo pipefail

# Activation invokes Nix directly, so it needs the same features as the build.
export NIX_CONFIG="${NIX_CONFIG:-}"$'\nextra-experimental-features = nix-command flakes'

usage() {
  cat <<'EOF'
usage: dotfiles <command> [machine]

commands:
  apply      apply the current checkout, installing any pi npm package whose version differs from its pinned spec
  sync       pull latest changes, then apply
  upgrade    update flake.lock inputs, then apply

machine: the name of the machine to apply. This machine's hostname is the
         default. An unknown name is listed against the names flake.nix has.
EOF
}

repo="${DOTFILES_DIR:?DOTFILES_DIR is not set; run the installed dotfiles command}"
machines="${DOTFILES_MACHINES:?DOTFILES_MACHINES is not set}"

command="${1:-}"
if [ -z "$command" ] || [ "$command" = "-h" ] || [ "$command" = "--help" ]; then
  usage
  exit 0
fi
shift

# A machine argument names the attribute to apply. Otherwise this machine's
# hostname does, minus the .local suffix macOS reports its mDNS name with.
machine="${1:-}"
if [ -z "$machine" ]; then
  machine="$(hostname)"
  machine="${machine%.local}"
fi

# flake.nix owns the machine list; fail here rather than inside nix eval.
case " $machines " in
  *" $machine "*) ;;
  *)
    echo "dotfiles: unknown machine: $machine" >&2
    echo "dotfiles: machines: $machines" >&2
    exit 2
    ;;
esac

tmp_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
lock_dir="$tmp_dir/dotfiles.lockdir"
# Files a failed upgrade rewrites are restored from these; backup_file appends
# one entry per file, as "<backup>|<target>".
upgrade_backups=()
pin_scratch=""
patched_activate=""
have_lock=0
# modules/pinned-packages.nix holds every derivation that is not packaged by
# nixpkgs and carries its own version; `nix-update` bumps the ones named here.
pins_file="modules/pinned-packages.nix"
# The @juicesharp/rpiv packages stay npm-installed; their shared version lives
# in one line of modules/pi.nix, which the upgrade rewrites from the registry.
pi_module="modules/pi.nix"
pin_names=(solhint roots prettier-plugin-solidity prettier-plugin-solidity-dist herdr-nvim)
trap 'for backup in "${upgrade_backups[@]}"; do rm -f "${backup%%|*}"; done; if [ -n "$pin_scratch" ]; then rm -f "$pin_scratch"; fi; if [ -n "$patched_activate" ]; then rm -f "$patched_activate"; fi; if [ "$have_lock" = 1 ]; then rmdir "$lock_dir" 2>/dev/null || true; fi' EXIT
if ! mkdir "$lock_dir" 2>/dev/null; then
  echo "dotfiles: already running; skipping"
  exit 0
fi
have_lock=1

# Services start with a minimal PATH, so add the directories Home Manager's
# activate script expects. Appended, never prepended: the runtime inputs have
# to win, because macOS' /usr/bin/sed is BSD sed and its /bin/bash is 3.2.
export PATH="$PATH:/run/current-system/sw/bin:/usr/bin:/bin"

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
  activation_path="$(nix_cmd build --no-link --print-out-paths "$repo#homeConfigurations.$machine.activationPackage" --impure)"
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

apply_home_and_reconcile_pi() {
  build_home
  activate_home
  pi_reconcile
}

backup_file() {
  local backup
  backup="$(mktemp "$tmp_dir/dotfiles-upgrade-backup.XXXXXX")"
  cp "$1" "$backup"
  upgrade_backups+=("$backup|$1")
}

# Restores every file the upgrade rewrote from its backup. Runs on the
# upgrade's failure paths only.
restore_upgrade() {
  local entry backup target
  for entry in "${upgrade_backups[@]}"; do
    backup="${entry%%|*}"
    target="${entry#*|}"
    if [ -f "$backup" ]; then
      cp "$backup" "$target"
      echo "dotfiles upgrade: restored $target after failure" >&2
    fi
  done
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

# The latest version published for an npm package; empty on any doubt.
registry_latest() {
  local encoded
  encoded="$(printf '%s' "$1" | sed 's|/|%2F|')"
  curl -fsS --max-time 30 "https://registry.npmjs.org/${encoded}" | jq -r '."dist-tags".latest'
}

# npm rows cannot be git sources: the rpiv workspace has no pi manifest at its
# root, and cc-safety-net's repository runs lefthook from a prepare script. They
# are therefore pinned by a version string in $pi_module, which this moves to
# the registry's latest, keeping the pin on any registry or ordering doubt.
bump_npm_pins() {
  local pinned latest ordering spec name current

  # The three rpiv packages ship under one version, so one line covers them.
  pinned="$(sed -n 's/^  rpivVersion = "\([0-9][0-9.]*\)";$/\1/p' "$pi_module")"
  if [ -z "$pinned" ]; then
    echo "dotfiles upgrade: no rpivVersion line found in $pi_module; kept the rpiv pin" >&2
  else
    latest="$(registry_latest "@juicesharp/rpiv-todo" || true)"
    if [ -z "$latest" ] || [ "$latest" = "null" ]; then
      echo "dotfiles upgrade: no registry latest for @juicesharp/rpiv-todo; kept the rpiv pin at $pinned" >&2
    elif [ "$latest" != "$pinned" ]; then
      ordering="$(printf '%s\n' "$pinned" "$latest" | sort -V | tail -n 1)"
      if [ "$ordering" != "$latest" ]; then
        echo "dotfiles upgrade: registry latest $latest is older than the rpiv pin $pinned; kept the pin" >&2
      else
        sed -i 's/^  rpivVersion = "[0-9][0-9.]*";$/  rpivVersion = "'"$latest"'";/' "$pi_module"
        echo "dotfiles upgrade: bumped the rpiv npm pin $pinned -> $latest"
      fi
    fi
  fi

  # npm rows carry their own version, for example `npm:cc-safety-net@2.4.6`.
  while read -r spec; do
    name="${spec#npm:}"
    name="${name%@*}"
    current="${spec##*@}"
    latest="$(registry_latest "$name" || true)"
    if [ -z "$latest" ] || [ "$latest" = "null" ]; then
      echo "dotfiles upgrade: no registry latest for $name; kept the pin at $current" >&2
      continue
    fi
    ordering="$(printf '%s\n' "$current" "$latest" | sort -V | tail -n 1)"
    if [ "$ordering" != "$latest" ] || [ "$latest" = "$current" ]; then
      continue
    fi
    sed -i "s|\"$spec\"|\"npm:$name@$latest\"|" "$pi_module"
    echo "dotfiles upgrade: bumped the $name npm pin $current -> $latest"
  done < <(grep -o 'npm:[A-Za-z0-9@/._-]*@[0-9][0-9A-Za-z.+-]*' "$pi_module" | sort -u)
}

case "$command" in
  apply)
    apply_home_and_reconcile_pi
    ;;
  sync)
    require_clean_repo
    git pull --ff-only
    apply_home_and_reconcile_pi
    ;;
  upgrade)
    require_clean_repo
    pin_scratch="$(mktemp "$tmp_dir/dotfiles-pin-bump.XXXXXX")"
    backup_file "$pins_file"
    backup_file "$pi_module"
    backup_file flake.lock
    if ! nix_cmd flake update; then
      restore_upgrade
      exit 1
    fi
    # After the flake update on purpose: a release that needs a newer toolchain
    # than the previous nixpkgs carried can still be bumped in the same run.
    bump_pins
    bump_npm_pins
    if ! build_home; then
      restore_upgrade
      exit 1
    fi
    if ! activate_home; then
      restore_upgrade
      exit 1
    fi
    moved_files=""
    for moved_file in flake.lock "$pins_file" "$pi_module"; do
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
