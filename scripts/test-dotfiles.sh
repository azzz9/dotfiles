#!/usr/bin/env bash
# Drives scripts/dotfiles.sh against fixture git repositories. The CLI's own
# git, stash, and reporting behavior runs for real; only the nix build and the
# side effects after it are stubbed, so nothing here reaches a live machine.
#
#   test-dotfiles.sh <path/to/dotfiles.sh>
#
# The check runs inside a Nix sandbox: no network, no writable path outside
# $TMPDIR, and nothing read from $HOME.
set -euo pipefail

src="$(realpath "${1:?usage: test-dotfiles.sh <path/to/dotfiles.sh>}")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Without these git would read the reviewer's ~/.gitconfig and /etc/gitconfig.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export XDG_RUNTIME_DIR="$work/run" HOME="$work/home"
mkdir -p "$XDG_RUNTIME_DIR" "$HOME" "$work/bin" "$work/fakeout"

origin="$work/origin.git"
seed="$work/seed"
other="$work/other"
machine="$work/machine"
runner="$work/runner.sh"

# Answers only the build the CLI performs, naming a directory that holds an
# activate script. Every other invocation fails, so a scenario that strays
# into upgrade's `nix flake update` cannot pass silently. The shebang names this
# bash, because a Nix sandbox has no /usr/bin/env for the stub to exec.
cat > "$work/bin/nix" <<STUB
#!$BASH
case " \$* " in
  *" build --no-link --print-out-paths "*) printf '%s\n' "$work/fakeout" ;;
  *) printf 'nix stub: refusing %s\n' "\$*" >&2; exit 99 ;;
esac
STUB
chmod +x "$work/bin/nix"

cat > "$work/fakeout/activate" <<'STUB'
#!/usr/bin/env bash
echo "[stub] activate (profile add)"
STUB

# A bare origin, a seed that carries the CLI under test, and one clone per
# machine. The seed pushes the commits both machines start from.
fixture() {
  rm -rf "$origin" "$seed" "$other" "$machine"
  git init -q --bare -b main "$origin"
  git init -q -b main "$seed"
  git -C "$seed" config user.name seed
  git -C "$seed" config user.email seed@example.invalid
  git -C "$seed" remote add origin "$origin"
  install -Dm644 "$src" "$seed/scripts/dotfiles.sh"
  mkdir -p "$seed/modules"
  printf 'lock v1\n' > "$seed/flake.lock"
  printf 'pins v1\n' > "$seed/modules/pinned-packages.nix"
  printf 'pi v1\n' > "$seed/modules/pi.nix"
  printf 'nvim v1\n' > "$seed/modules/nvim.nix"
  git -C "$seed" add -A
  git -C "$seed" commit -qm init
  git -C "$seed" push -q origin main
  git clone -q "$origin" "$other"
  git -C "$other" config user.name other
  git -C "$other" config user.email other@example.invalid
}

machine_clone() {
  git clone -q "$origin" "$machine"
  git -C "$machine" config user.name machine
  git -C "$machine" config user.email machine@example.invalid
  write_runner
}

push_from_other() {
  printf '%s\n' "$2" > "$other/$1"
  git -C "$other" commit -qam "$3"
  git -C "$other" push -q
}

# What modules/dotfiles.nix builds: the two values, then the CLI body with its
# shebang dropped. The stub replaces scripts/pi-reconcile.sh, which installs
# npm packages from the network.
write_runner() {
  {
    printf 'export DOTFILES_DIR=%s\n' "$machine"
    printf 'DOTFILES_MACHINES=test\n'
    printf 'pi_reconcile() { echo "[stub] pi_reconcile"; }\n'
    tail -n +2 "$machine/scripts/dotfiles.sh"
  } > "$runner"
}

failures=0

expect_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'ok: %s\n' "$label"
  else
    printf 'not ok: %s\n  expected: %s\n  actual: %s\n' "$label" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

out_has() {
  case "$1" in
    *"$2"*) printf present ;;
    *) printf absent ;;
  esac
}

expect_out_has() { expect_eq "$1" present "$(out_has "$cli_out" "$2")"; }
expect_out_lacks() { expect_eq "$1" absent "$(out_has "$cli_out" "$2")"; }

run_cli() {
  local rc=0
  origin_before="$(git -C "$origin" rev-parse main)"
  head_before="$(git -C "$machine" rev-parse HEAD)"
  cli_out="$(PATH="$work/bin:$PATH" bash "$runner" "$1" test 2>&1)" || rc=$?
  cli_rc="$rc"
}

expect_origin_unmoved() {
  expect_eq "$1" "$origin_before" "$(git -C "$origin" rev-parse main)"
}

scenario() {
  printf '\n== %s\n' "$1"
  scenario_failures="$failures"
}

# One failing assertion hides the state that explains it, so echo it.
scenario_end() {
  if [ "$failures" != "$scenario_failures" ]; then
    printf '   output: %s\n' "$(printf '%s' "$cli_out" | tr '\n' '|')"
    printf '   status: %s\n' "$(git -C "$machine" status --porcelain | tr '\n' '|')"
    printf '   stash: %s\n' "$(git -C "$machine" stash list | tr '\n' '|')"
  fi
}

printf 'dotfiles CLI check: %s\n' "$src"

scenario 'sync refuses an edit outside the pins'
fixture
machine_clone
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
printf 'nvim v2-mine\n' > "$machine/modules/nvim.nix"
run_cli sync
# The whole refusal, because git's own error text also names the path.
refusal="dotfiles sync: local or untracked changes found in $machine; skipping
modules/nvim.nix
dotfiles sync: commit, stash, or discard local changes first"
expect_eq 'sync exits 0 when it refuses' 0 "$cli_rc"
expect_out_has 'the refusal lists the foreign path' "$refusal"
expect_out_lacks 'the refusal does not list the pins' 'flake.lock'
expect_out_lacks 'the refusal does not activate' '[stub] activate'
expect_eq 'sync leaves the foreign edit untouched' 'nvim v2-mine' "$(cat "$machine/modules/nvim.nix")"
expect_eq 'sync leaves the foreign edit modified' ' M modules/nvim.nix' "$(git -C "$machine" status --porcelain)"
expect_eq 'sync stashes nothing when it refuses' '' "$(git -C "$machine" stash list)"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'sync stashes the pins, pulls, and applies'
fixture
machine_clone
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
printf 'lock v2-mine\n' > "$machine/flake.lock"
run_cli sync
expect_eq 'sync exits 0' 0 "$cli_rc"
expect_out_has 'sync activates the pulled checkout' '[stub] activate (profile add)'
expect_out_has 'sync runs pi_reconcile' '[stub] pi_reconcile'
expect_out_has 'sync names the stash holding the pins' "dotfiles sync: the pins this machine had are in stash@{0} and are no longer active."
expect_eq 'sync lands the pulled nvim change' 'nvim v2-other' "$(cat "$machine/modules/nvim.nix")"
expect_eq 'sync drops the stashed pin from the tree' 'lock v1' "$(cat "$machine/flake.lock")"
expect_eq 'sync leaves a clean tree' '' "$(git -C "$machine" status --porcelain)"
expect_eq 'sync keeps the pins in stash@{0}' "stash@{0}: On main: dotfiles sync: this machine's pins" "$(git -C "$machine" stash list)"
expect_eq 'sync leaves HEAD on the pulled commit' "$(git -C "$origin" rev-parse main)" "$(git -C "$machine" rev-parse HEAD)"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'sync lands the flake.lock the other machine pushed'
fixture
machine_clone
push_from_other flake.lock 'lock v3-other' 'chore(deps): other'
printf 'lock v2-mine\n' > "$machine/flake.lock"
run_cli sync
expect_eq 'sync exits 0' 0 "$cli_rc"
expect_out_has 'sync names the stash holding the pins' "dotfiles sync: the pins this machine had are in stash@{0} and are no longer active."
expect_eq 'sync lands the pushed flake.lock' 'lock v3-other' "$(cat "$machine/flake.lock")"
expect_eq 'sync leaves a clean tree' '' "$(git -C "$machine" status --porcelain)"
expect_eq 'sync keeps the pins in stash@{0}' "stash@{0}: On main: dotfiles sync: this machine's pins" "$(git -C "$machine" stash list)"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'sync restores the pins when the pull cannot fast-forward'
fixture
machine_clone
printf 'nvim v2-mine\n' > "$machine/modules/nvim.nix"
git -C "$machine" commit -qam 'chore(nvim): mine'
push_from_other modules/pi.nix 'pi v2-other' 'chore(pi): other'
printf 'lock v2-mine\n' > "$machine/flake.lock"
run_cli sync
expect_eq 'sync exits 1 when the pull cannot fast-forward' 1 "$cli_rc"
expect_out_lacks 'sync does not activate after a failed pull' '[stub] activate'
expect_out_has 'sync reports the pins it restored' "restored this machine's pins after the failed pull"
expect_eq 'sync keeps the local flake.lock content' 'lock v2-mine' "$(cat "$machine/flake.lock")"
expect_eq 'sync leaves the flake.lock modified' ' M flake.lock' "$(git -C "$machine" status --porcelain)"
expect_eq 'sync pops the stash after the failed pull' '' "$(git -C "$machine" stash list)"
expect_eq 'sync leaves the branch where it was' "$head_before" "$(git -C "$machine" rev-parse HEAD)"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'sync applies a clean tree without stashing'
fixture
machine_clone
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
run_cli sync
expect_eq 'sync exits 0 on a clean tree' 0 "$cli_rc"
expect_out_has 'sync activates the pulled checkout' '[stub] activate (profile add)'
expect_out_has 'sync runs pi_reconcile' '[stub] pi_reconcile'
expect_out_lacks 'sync reports no stash on a clean tree' 'stash@{0}'
expect_eq 'sync lands the pulled nvim change' 'nvim v2-other' "$(cat "$machine/modules/nvim.nix")"
expect_eq 'sync leaves a clean tree' '' "$(git -C "$machine" status --porcelain)"
expect_eq 'sync stashes nothing on a clean tree' '' "$(git -C "$machine" stash list)"
expect_eq 'sync leaves HEAD on the pulled commit' "$(git -C "$origin" rev-parse main)" "$(git -C "$machine" rev-parse HEAD)"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'sync refuses when the pins and a foreign edit are both dirty'
fixture
machine_clone
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
printf 'lock v2-mine\n' > "$machine/flake.lock"
printf 'nvim v2-mine\n' > "$machine/modules/nvim.nix"
run_cli sync
refusal="dotfiles sync: local or untracked changes found in $machine; skipping
modules/nvim.nix
dotfiles sync: commit, stash, or discard local changes first"
dirty=" M flake.lock
 M modules/nvim.nix"
expect_eq 'sync exits 0 when it refuses' 0 "$cli_rc"
expect_out_has 'the refusal lists the foreign path' "$refusal"
expect_out_lacks 'the refusal does not list the pins' 'flake.lock'
expect_out_lacks 'the refusal does not activate' '[stub] activate'
expect_eq 'sync keeps both edits in place' "$dirty" "$(git -C "$machine" status --porcelain)"
expect_eq 'sync stashes nothing when it refuses' '' "$(git -C "$machine" stash list)"
expect_eq 'sync leaves the pin content alone' 'lock v2-mine' "$(cat "$machine/flake.lock")"
expect_eq 'sync leaves the foreign edit alone' 'nvim v2-mine' "$(cat "$machine/modules/nvim.nix")"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'upgrade refuses a mixed tree before it rewrites any pin'
fixture
machine_clone
printf 'lock v2-mine\n' > "$machine/flake.lock"
printf 'nvim v2-mine\n' > "$machine/modules/nvim.nix"
run_cli upgrade
# upgrade rewrites the pins, so its refusal lists the dirty pins as well as the
# foreign path. sync's refusal names only the foreign path, because sync stashes
# the pins and pulls over them.
dirty=" M flake.lock
 M modules/nvim.nix"
upgrade_refusal="dotfiles upgrade: local or untracked changes found in $machine; skipping
flake.lock
modules/nvim.nix
dotfiles upgrade: commit, stash, or discard local changes first"
expect_eq 'upgrade exits 0 when it refuses' 0 "$cli_rc"
expect_out_has 'the refusal lists both the pins and the foreign path' "$upgrade_refusal"
expect_out_lacks 'upgrade never runs nix flake update' 'flake update'
expect_out_lacks 'upgrade does not activate' '[stub] activate'
expect_eq 'upgrade keeps both edits in place' "$dirty" "$(git -C "$machine" status --porcelain)"
expect_eq 'upgrade stashes nothing' '' "$(git -C "$machine" stash list)"
expect_eq 'upgrade leaves the pin content alone' 'lock v2-mine' "$(cat "$machine/flake.lock")"
expect_eq 'upgrade leaves the foreign edit alone' 'nvim v2-mine' "$(cat "$machine/modules/nvim.nix")"
expect_origin_unmoved 'upgrade leaves the origin branch alone'
scenario_end

if [ "$failures" -gt 0 ]; then
  printf '\n%s assertion(s) failed\n' "$failures"
  exit 1
fi
printf '\nall assertions passed\n'
