#!/usr/bin/env bash
# The `dotfiles` CLI. dotfiles-cli.nix installs this file through
# writeShellApplication and supplies these values:
#   DOTFILES_DIR       the checkout to build and activate, defaulted to this
#                      machine's checkout; the live links name that one regardless
#   DOTFILES_MACHINES  the homeConfigurations attributes that exist
set -euo pipefail

# Activation invokes Nix directly, so it needs the same features as the build.
export NIX_CONFIG="${NIX_CONFIG:-}"$'\nextra-experimental-features = nix-command flakes'

usage() {
  cat <<'EOF'
usage: dotfiles <command> [machine]

commands:
  apply      apply the current checkout, installing any pi package whose version differs from its pinned spec
  audit      check this machine's packages against open security issues
  status     report what is out of date here, changing nothing
  sync       pull latest changes, then apply
  upgrade    pull latest changes, update flake.lock inputs, then apply

audit reads this machine's store. --declared reads the packages flake.nix names
for it instead, which is what a runner without a store can do. --update records
what it found in scripts/audit-baseline.txt instead of failing on it.

machine: the name of the machine to apply or report on. This machine's
         hostname is the default. An unknown name is listed against the names
         flake.nix has.
EOF
}

repo="${DOTFILES_DIR:-$HOME/src/github.com/azzz9/dotfiles}"
machines="${DOTFILES_MACHINES:?DOTFILES_MACHINES is not set}"

command="${1:-}"
if [ -z "$command" ] || [ "$command" = "-h" ] || [ "$command" = "--help" ]; then
  usage
  exit 0
fi
shift

# audit is the only command that takes flags. Read them before the machine
# argument, so `dotfiles audit --update` does not read --update as a machine.
audit_update=0
audit_declared=0
if [ "$command" = "audit" ]; then
  while [ "${1:-}" = "--update" ] || [ "${1:-}" = "--declared" ]; do
    if [ "$1" = "--update" ]; then
      audit_update=1
    else
      audit_declared=1
    fi
    shift
  done
fi

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
lock_pid_file="$lock_dir/pid"
reclaim_dir="$lock_dir.reclaim"
reclaim_pid_file="$reclaim_dir/pid"
# Files a failed upgrade rewrites are restored from these; backup_file appends
# one entry per file, as "<backup>|<target>".
upgrade_backups=()
pin_scratch=""
patched_activate=""
have_lock=0
# modules/pinned-packages.nix holds every derivation that is not packaged by
# nixpkgs and carries its own version.
pins_file="modules/pinned-packages.nix"
# The derivations `nix-update` bumps, one per line. This file is the list, so a
# new pin is one line here and one derivation in $pins_file; the pin-names check
# fails when this file and flake.nix's packages disagree in either direction.
pin_names_file="modules/pin-names.txt"
pin_names=()
# The pi package rows live in modules/pi.nix; the upgrade rewrites their npm
# specs from the registry.
pi_module="modules/pi.nix"
# The three paths upgrade rewrites and prints for review. sync reads a dirty
# path here as this machine's own pin, never as a person's work in progress.
upgrade_paths=(flake.lock "$pins_file" "$pi_module")
# Remove the temp files and the lock on every exit path.
cleanup() {
  local backup
  for backup in "${upgrade_backups[@]}"; do
    rm -f "${backup%%|*}"
  done
  if [ -n "${pin_scratch:-}" ]; then rm -f "$pin_scratch"; fi
  if [ -n "${patched_activate:-}" ]; then rm -f "$patched_activate"; fi
  if [ "${have_lock:-0}" = 1 ] && [ "$(cat "$lock_pid_file" 2>/dev/null || true)" = "$$" ]; then
    rm -rf "$lock_dir"
  fi
}
trap cleanup EXIT

# One run at a time; a skipped run exits 1 so nothing reads as applied.
claim_lock() {
  local owner="" holder=""
  if mkdir "$lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" > "$lock_pid_file"
    return 0
  fi
  # The claim carries its pid within the same few microseconds. Wait out that
  # window before calling a pid-less directory abandoned.
  for _ in 1 2 3 4 5; do
    owner="$(cat "$lock_pid_file" 2>/dev/null || true)"
    [ -n "$owner" ] && break
    sleep 0.1
  done
  if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
    echo "dotfiles: another run ($owner) holds $lock_dir; nothing was changed" >&2
    holder="$(ps -p "$owner" -o args= 2>/dev/null | head -n 1)"
    if [ -n "$holder" ]; then
      echo "dotfiles: holder: $holder" >&2
    fi
    return 1
  fi
  # Serialize the reclaim. Two runs that both find a dead owner must not both
  # delete the lock and both write. A run killed inside this short window
  # leaves the gate behind, and the message names it.
  if ! mkdir "$reclaim_dir" 2>/dev/null; then
    echo "dotfiles: another run is reclaiming $lock_dir; nothing was changed" >&2
    echo "dotfiles: if no run is active, remove $reclaim_dir" >&2
    return 1
  fi
  printf '%s\n' "$$" > "$reclaim_pid_file"
  # Re-read under the gate: a new owner may have claimed the lock meanwhile.
  owner="$(cat "$lock_pid_file" 2>/dev/null || true)"
  if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
    rm -rf "$reclaim_dir"
    echo "dotfiles: another run ($owner) holds $lock_dir; nothing was changed" >&2
    return 1
  fi
  echo "dotfiles: reclaiming $lock_dir from a run that did not finish" >&2
  rm -rf "$lock_dir"
  if mkdir "$lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" > "$lock_pid_file"
    rm -rf "$reclaim_dir"
    return 0
  fi
  rm -rf "$reclaim_dir"
  echo "dotfiles: another run took $lock_dir first; nothing was changed" >&2
  return 1
}

# status reads, so it takes no lock and stays usable during an upgrade.
if [ "$command" != "status" ]; then
  if ! claim_lock; then
    exit 1
  fi
  have_lock=1
fi

# Services start with a minimal PATH, so add the directories Home Manager's
# activate script expects. Appended, never prepended: the runtime inputs have
# to win, because macOS' /usr/bin/sed is BSD sed and its /bin/bash is 3.2.
export PATH="$PATH:/run/current-system/sw/bin:/usr/bin:/bin"

nix_cmd() {
  nix --extra-experimental-features "nix-command flakes" "$@"
}

# BSD sed reads the argument after -i as a backup suffix, so an in-place edit
# that works on Linux breaks on macOS. Write a temp file and move it instead.
edit_in_place() {
  local file="$1" expr="$2" tmp
  tmp="$(mktemp "${file}.XXXXXX")"
  if ! sed "$expr" "$file" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$file"
}

# A linked worktree has a .git file rather than a .git directory, and
# DOTFILES_DIR may point at one, so test for existence and not for a directory.
if [ ! -e "$repo/.git" ]; then
  echo "dotfiles: $repo not found" >&2
  exit 1
fi

cd "$repo"

read_dirty_paths() {
  local line path
  own_dirty=()
  foreign_dirty=()
  while IFS= read -r line; do
    path="${line:3}"
    case " ${upgrade_paths[*]} " in
      *" $path "*) own_dirty+=("$path") ;;
      *) foreign_dirty+=("$path") ;;
    esac
  done < <(git status --porcelain --untracked-files=normal)
}

refuse_dirty() {
  echo "dotfiles $command: local or untracked changes found in $repo; skipping" >&2
  printf '%s\n' "$@" >&2
  echo "dotfiles $command: commit, stash, or discard local changes first" >&2
  exit 0
}

require_clean_repo() {
  read_dirty_paths
  if [ "${#own_dirty[@]}" -gt 0 ] || [ "${#foreign_dirty[@]}" -gt 0 ]; then
    refuse_dirty "${own_dirty[@]}" "${foreign_dirty[@]}"
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
    edit_in_place "$patched_activate" 's/profile install/profile add/g'
  elif ! grep -q 'profile add' "$patched_activate"; then
    echo "dotfiles: expected activation profile command not found" >&2
    exit 1
  fi
  bash "$patched_activate"
}

apply_home_and_reconcile() {
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

# Read after the pull, so a checkout that just gained the file can bump it. A
# missing or empty list fails instead of skipping every bump.
read_pin_names() {
  local line
  if [ ! -f "$pin_names_file" ]; then
    echo "dotfiles upgrade: $pin_names_file is missing; run git pull in $repo" >&2
    return 1
  fi
  pin_names=()
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue
    pin_names+=("$line")
  done < "$pin_names_file"
  if [ "${#pin_names[@]}" -eq 0 ]; then
    echo "dotfiles upgrade: $pin_names_file lists no package" >&2
    return 1
  fi
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

# `sort -V` ranks 0.2.0-rc.2 above 0.2.0. Compare a prerelease as a tilde
# suffix, which sorts before the release.
version_key() {
  case "$1" in
    *-*) printf '%s~%s' "${1%%-*}" "${1#*-}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# The npm rows carry a literal version in $pi_module, and this moves each one to
# the registry's latest, keeping the pin on any registry or ordering doubt. Two
# of them cannot be git sources: the rpiv workspace has no pi manifest at its
# root, and cc-safety-net's repository runs lefthook from a prepare script.
bump_npm_pins() {
  local latest ordering spec name current

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
    ordering="$(printf '%s\n' "$(version_key "$current")" "$(version_key "$latest")" | sort -V | tail -n 1)"
    if [ "$ordering" != "$(version_key "$latest")" ] || [ "$latest" = "$current" ]; then
      continue
    fi
    edit_in_place "$pi_module" "s|\"$spec\"|\"npm:$name@$latest\"|"
    echo "dotfiles upgrade: bumped the $name npm pin $current -> $latest"
  done < <(grep -o 'npm:[A-Za-z0-9@/._-]*@[0-9][0-9A-Za-z.+-]*' "$pi_module" | sort -u)
}

# Recomputes every npmDepsHash in modules/pi.nix from the package-lock.json of
# the flake input that flake.lock now pins. `nix flake update` moves those
# revisions, and a moved lockfile moves the fixed-output hash, so the build
# would otherwise stop on a hash mismatch. Each row is measured with a
# deliberately wrong hash and the real one is read back from the error.
refresh_pi_npm_hashes() {
  local input got
  while read -r input; do
    got="$(nix_cmd build --no-link --impure --expr "
      let
        flake = builtins.getFlake \"$repo\";
        pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
      in pkgs.fetchNpmDeps { src = flake.inputs.$input; hash = pkgs.lib.fakeHash; }
    " 2>&1 | sed -n 's/.*got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | head -n 1)" || true
    if [ -z "$got" ]; then
      echo "dotfiles upgrade: could not measure the $input npmDepsHash; kept its previous value" >&2
      continue
    fi
    if grep -q "{ input = \"$input\"; npmDepsHash = \"$got" "$pi_module"; then
      continue
    fi
    edit_in_place "$pi_module" "s|{ input = \"$input\"; npmDepsHash = \"[^\"]*\"|{ input = \"$input\"; npmDepsHash = \"$got\"|"
    echo "dotfiles upgrade: refreshed the $input npmDepsHash"
  done < <(sed -n 's/.*{ input = "\([^"]*\)"; npmDepsHash.*/\1/p' "$pi_module")
}

# The pin and the install under $HOME are two copies of the same version. Only
# the reconcile writes the second, and it needs the network, so a failed apply
# leaves the older package loading while every other line reads current.
status_reconcile() {
  local drift=() line source name installed expected count=0
  # A direct run of this file carries no reconcile readers, so say that instead
  # of reporting a match nothing checked.
  if ! declare -F pi_npm_rows >/dev/null; then
    printf 'reconcile: not compared, this script is not the installed dotfiles\n'
    return 0
  fi
  while IFS=$'\t' read -r source installed; do
    count=$((count + 1))
    name="${source#npm:}"
    name="${name%@*}"
    expected="${source##*@}"
    if [ "$installed" != "$expected" ]; then
      drift+=("pi ${name} is ${installed}, pinned ${expected}")
    fi
  done < <(pi_npm_rows "$HOME/.pi/agent/settings.json")
  # Every pi row is a store path today, so an empty set means there is nothing
  # to reconcile and the line would be a vacuous "matches".
  if [ "$count" -eq 0 ]; then
    return 0
  fi
  if [ "${#drift[@]}" -eq 0 ]; then
    printf 'reconcile: pi matches its pins\n'
    return 0
  fi
  for line in "${drift[@]}"; do
    printf 'reconcile: %s; run dotfiles apply\n' "$line"
  done
}

# How old the remote-tracking refs are. GNU stat spells the mtime -c %Y and BSD
# spells it -f %m, so try both instead of branching on uname.
status_fetch_age() {
  local stamp now days fetch_file
  # .git is a file in a linked worktree, so ask git where FETCH_HEAD lives.
  fetch_file="$(git rev-parse --git-path FETCH_HEAD)"
  stamp="$(stat -c %Y "$fetch_file" 2>/dev/null || stat -f %m "$fetch_file" 2>/dev/null || true)"
  if [ -z "$stamp" ]; then
    printf 'never'
    return 0
  fi
  now="$(date +%s)"
  days=$(((now - stamp) / 86400))
  if [ "$days" -ge 1 ]; then
    printf '%s day(s) ago' "$days"
  else
    printf 'today'
  fi
}

# What is out of date on this machine, changing nothing. The upstream count is
# as fresh as the last fetch, because status never fetches.
status_report() {
  local branch upstream counts ahead behind state_dir link running wanted host_machine hint stashes

  printf 'dotfiles status: %s\n' "$machine"
  printf 'repo:     %s\n' "$repo"

  branch="$(git rev-parse --abbrev-ref HEAD)"
  if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    counts="$(git rev-list --left-right --count "HEAD...$upstream")"
    ahead="${counts%%[[:space:]]*}"
    behind="${counts##*[[:space:]]}"
    hint=""
    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
      hint="; the branch diverged; rebase or merge before sync"
    elif [ "$behind" -gt 0 ]; then
      hint="; run dotfiles sync"
    elif [ "$ahead" -gt 0 ]; then
      hint="; push them"
    fi
    printf 'branch:   %s, %s ahead of %s, %s behind (last fetch: %s)%s\n' \
      "$branch" "$ahead" "$upstream" "$behind" "$(status_fetch_age)" "$hint"
  else
    printf 'branch:   %s, no upstream\n' "$branch"
  fi

  read_dirty_paths
  if [ "${#own_dirty[@]}" -gt 0 ]; then
    printf 'pins:     %s uncommitted: %s; commit and push them\n' "${#own_dirty[@]}" "${own_dirty[*]}"
  else
    printf 'pins:     committed\n'
  fi
  if [ "${#foreign_dirty[@]}" -gt 0 ]; then
    printf 'changes:  %s outside the pins: %s; commit, stash, or discard\n' "${#foreign_dirty[@]}" "${foreign_dirty[*]}"
  fi
  stashes="$(git stash list --format=%s | grep -c 'dotfiles sync:' || true)"
  if [ "${stashes:-0}" -gt 0 ]; then
    printf 'stash:    %s sync stash(es); review with git stash list\n' "$stashes"
  fi

  # The running generation is this machine's, so a row named for another
  # machine cannot be compared against it.
  host_machine="$(hostname)"
  host_machine="${host_machine%.local}"
  if [ "$machine" != "$host_machine" ]; then
    printf 'generation: not compared, %s is not this machine (%s)\n' "$machine" "$host_machine"
  else
    state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/home-manager"
    link="$state_dir/gcroots/current-home"
    if [ ! -e "$link" ]; then
      printf 'generation: none, no Home Manager generation is active here; run dotfiles apply\n'
    else
      # The derivation is what identifies the pin set. The output path moves
      # for reasons that are not a pin change, so it cannot answer this.
      running="$(nix-store -q --deriver "$link" 2>/dev/null || true)"
      wanted="$(nix_cmd eval --impure --raw "$repo#homeConfigurations.$machine.activationPackage.drvPath" 2>/dev/null || true)"
      if [ -z "$running" ] || [ -z "$wanted" ]; then
        printf 'generation: unknown, the running generation or this checkout could not be read\n'
      elif [ "$running" = "$wanted" ]; then
        printf 'generation: current, built from this checkout\n'
      else
        printf 'generation: stale, the running generation was built from another checkout or lock; run dotfiles apply\n'
      fi
    fi
  fi

  status_reconcile
}

case "$command" in
  apply)
    apply_home_and_reconcile
    ;;
  audit)
    audit_packages "$repo" "$machine" "$tmp_dir" "$pi_module" "$audit_update" "$audit_declared"
    ;;
  status)
    status_report
    ;;
  sync)
    read_dirty_paths
    # A person's change must not reach activate half-finished.
    if [ "${#foreign_dirty[@]}" -gt 0 ]; then
      refuse_dirty "${foreign_dirty[@]}"
    fi
    sync_stash=""
    if [ "${#own_dirty[@]}" -gt 0 ]; then
      git stash push -q -m "dotfiles sync: this machine's pins" -- "${own_dirty[@]}"
      sync_stash="$(git stash list | head -n 1 | cut -d: -f1)"
    fi
    if ! git pull --ff-only; then
      if [ -n "$sync_stash" ]; then
        git stash pop -q
        echo "dotfiles sync: restored this machine's pins after the failed pull" >&2
      fi
      exit 1
    fi
    apply_home_and_reconcile
    # The stash stays on purpose: the pulled pins have to be able to land, or a
    # pin bump committed on the other machine never takes effect here.
    if [ -n "$sync_stash" ]; then
      echo "dotfiles sync: the pins this machine had are in $sync_stash and are no longer active. Drop them with 'git stash drop $sync_stash', or bring them back with 'git stash pop' and another 'dotfiles apply'."
    fi
    ;;
  upgrade)
    require_clean_repo
    # Before the bump, so the new lock is computed on top of the newest flake.nix.
    if ! git pull --ff-only; then
      echo "dotfiles upgrade: the pull failed; the pins are untouched" >&2
      exit 1
    fi
    if ! read_pin_names; then
      exit 1
    fi
    pin_scratch="$(mktemp "$tmp_dir/dotfiles-pin-bump.XXXXXX")"
    for upgrade_path in "${upgrade_paths[@]}"; do
      backup_file "$upgrade_path"
    done
    if ! nix_cmd flake update; then
      restore_upgrade
      exit 1
    fi
    # After the flake update on purpose: a release that needs a newer toolchain
    # than the previous nixpkgs carried can still be bumped in the same run.
    bump_pins
    bump_npm_pins
    refresh_pi_npm_hashes
    if ! build_home; then
      restore_upgrade
      exit 1
    fi
    if ! activate_home; then
      restore_upgrade
      exit 1
    fi
    moved_files=""
    for moved_file in "${upgrade_paths[@]}"; do
      if ! git diff --quiet -- "$moved_file"; then
        moved_files="$moved_files $moved_file"
      fi
    done
    pi_reconcile
    # The pins just moved, which is when a nixpkgs fix lands and when a new
    # issue can start matching, so read the audit here. It stays a report: the
    # pins are already applied, and failing the run would call a finished
    # upgrade broken.
    audit_packages "$repo" "$machine" "$tmp_dir" "$pi_module" 0 0 ||
      echo "dotfiles upgrade: the audit above exited non-zero; the upgrade itself is applied" >&2
    # Last, because this is the only line asking for a decision, and the audit
    # output above would otherwise bury it.
    if [ -n "$moved_files" ]; then
      echo "dotfiles upgrade: these files moved; review and commit them, or the other machines keep their own pins:$moved_files"
    fi
    ;;
  *)
    echo "dotfiles: unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
