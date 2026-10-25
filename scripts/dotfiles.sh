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
  rollback   apply the commit that was applied before the current one
  status     report what is out of date here, changing nothing
  sync       check out main, pull, then apply
  upgrade    move every pin to its latest, then build and apply

audit reads this machine's store and lists every match. --declared reads the
packages flake.nix names for it instead, which is the subset a machine without a
store can read.

upgrade moves every pin with scripts/bump-pins.sh, then builds and applies.
To move one flake input, run `nix flake update <input>`, commit flake.lock,
then `dotfiles apply`.

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

# audit is the only command that takes a flag. Read it before the machine
# argument, so `dotfiles audit --declared` does not read --declared as a machine.
audit_declared=0
if [ "$command" = "audit" ] && [ "${1:-}" = "--declared" ]; then
  audit_declared=1
  shift
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
patched_activate=""
have_lock=0
# modules/pi.nix holds the package rows; the audit reads their npm versions.
pi_module="modules/pi.nix"
# The files a pin bump touches. status reads a dirty path here as this machine's
# own pin, never as a person's work in progress.
pin_paths=(flake.lock modules/pinned-packages.nix modules/pi.nix modules/pin-names.txt)
# The commits this checkout applied, oldest first, one "<sha> <time>" per line.
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
applied_log="$state_dir/applied.log"
# Remove the temp files and the lock on every exit path.
cleanup() {
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
    case " ${pin_paths[*]} " in
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

last_applied_sha() {
  [ -f "$applied_log" ] || return 0
  tail -n 1 "$applied_log" | awk '{print $1}'
}

# The most recent applied commit that differs from the current one. That is
# where `rollback` goes, even after a previous rollback.
previous_applied_sha() {
  local current
  current="$(git rev-parse HEAD)"
  [ -f "$applied_log" ] || return 0
  tac "$applied_log" | awk -v current="$current" '$1 != current { print $1; exit }'
}

record_applied() {
  local sha
  sha="$(git rev-parse HEAD)"
  mkdir -p "$state_dir"
  if [ "$(last_applied_sha)" != "$sha" ]; then
    printf '%s %s\n' "$sha" "$(date -Iseconds)" >> "$applied_log"
  fi
}

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
  applied="$(last_applied_sha)"
  if [ -z "$applied" ]; then
    applied="never"
  fi
  printf 'applied:  %s\n' "${applied:0:7}"

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
    record_applied
    ;;
  audit)
    audit_packages "$repo" "$machine" "$tmp_dir" "$pi_module" "$audit_declared"
    ;;
  rollback)
    previous="$(previous_applied_sha)"
    if [ -z "$previous" ]; then
      echo "dotfiles rollback: no earlier applied commit is recorded" >&2
      exit 1
    fi
    git checkout --detach "$previous"
    apply_home_and_reconcile
    record_applied
    echo "dotfiles rollback: applied ${previous:0:7}; run 'dotfiles sync' when you want main back"
    ;;
  status)
    status_report
    ;;
  sync)
    read_dirty_paths
    if [ "${#own_dirty[@]}" -gt 0 ] || [ "${#foreign_dirty[@]}" -gt 0 ]; then
      refuse_dirty "${own_dirty[@]}" "${foreign_dirty[@]}"
    fi
    git checkout main
    git pull --ff-only
    apply_home_and_reconcile
    record_applied
    ;;
  upgrade)
    read_dirty_paths
    if [ "${#own_dirty[@]}" -gt 0 ] || [ "${#foreign_dirty[@]}" -gt 0 ]; then
      refuse_dirty "${own_dirty[@]}" "${foreign_dirty[@]}"
    fi
    if ! bash scripts/bump-pins.sh; then
      echo "dotfiles upgrade: the pin bump failed; nothing was applied" >&2
      exit 1
    fi
    apply_home_and_reconcile
    record_applied
    # `herdr plugin update` only refetches the ref recorded at install time, so a
    # tag or commit never moves. Installing again takes the latest.
    if command -v herdr >/dev/null 2>&1; then
      for source in ChmaraX/herdr-nvim kryptamine/herdr-auto-title; do
        if ! herdr plugin install "$source" --yes >/dev/null; then
          echo "dotfiles upgrade: could not reinstall the $source herdr plugin; the upgrade itself is applied" >&2
        fi
      done
    fi
    # The pins just moved, which is when a new issue can start matching. Stay a
    # report: the pins are already applied, and failing would call a finished
    # upgrade broken.
    audit_packages "$repo" "$machine" "$tmp_dir" "$pi_module" 0 ||
      echo "dotfiles upgrade: the audit above could not run; the upgrade itself is applied" >&2
    if [ -n "$(git status --porcelain -- "${pin_paths[@]}")" ]; then
      echo "dotfiles upgrade: these files moved; review and commit them, or the other machines keep their own pins:"
      git status --porcelain -- "${pin_paths[@]}"
    fi
    ;;
  *)
    echo "dotfiles: unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
