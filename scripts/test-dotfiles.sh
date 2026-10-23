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

# Answers the two nix calls the CLI makes, and refuses every other one, so a
# scenario that strays into upgrade's `nix flake update` cannot pass silently.
# The shebang names this bash, because a Nix sandbox has no /usr/bin/env for the
# stub to exec.
cat > "$work/stores" <<'STUB'
/nix/store/00000000000000000000000000000000-fixturepkg-1.2.3
/nix/store/00000000000000000000000000000000-otherpkg-4.5.6
STUB
cat > "$work/bin/nix" <<STUB
#!$BASH
case " \$* " in
  *" build --no-link --print-out-paths "*) printf '%s\n' "$work/fakeout" ;;
  *" path-info -r "*) cat "$work/stores" ;;
  # The declared audit reads package names through nix eval.
  *" eval "*--apply*) printf '%s\n' '["fixturepkg-1.2.3","otherpkg-4.5.6"]' ;;
  # status compares the running generation's derivation with the one this
  # checkout evaluates to.
  *" eval "*drvPath*) cat "$work/checkout.drv" ;;
  # upgrade's flake update is refused unless a scenario asks for it, so a
  # scenario that strays into the bump cannot pass silently.
  *" flake update "*)
    if [ -f "$work/allow-flake-update" ]; then exit 0; fi
    printf 'nix stub: refusing %s\n' "\$*" >&2; exit 99 ;;
  *) printf 'nix stub: refusing %s\n' "\$*" >&2; exit 99 ;;
esac
STUB
chmod +x "$work/bin/nix"

# Answers the audit's two reads. The scenarios overwrite the two files.
printf '[]\n' > "$work/issues.json"
printf '{}\n' > "$work/advisories.json"
cat > "$work/bin/curl" <<STUB
#!$BASH
case " \$* " in
  *"api.github.com/repos/NixOS/nixpkgs/issues"*) cat "$work/issues.json" ;;
  *"advisories/bulk"*) cat "$work/advisories.json" ;;
  *"registry.npmjs.org/"*) printf '{"dist-tags":{"latest":"9.9.9"}}\n' ;;
  *) printf 'curl stub: refusing %s\n' "\$*" >&2; exit 99 ;;
esac
STUB
chmod +x "$work/bin/curl"

# Answers the OSV read, so a scenario decides what it sees.
printf '{"results":[]}\n' > "$work/osv.json"
cat > "$work/bin/osv-scanner" <<STUB
#!$BASH
cat "$work/osv.json"
STUB
chmod +x "$work/bin/osv-scanner"

# status asks the hostname and the running generation. The hostname file lets a
# scenario be a different machine without rewriting the stub.
printf 'test\n' > "$work/hostname"
cat > "$work/bin/hostname" <<STUB
#!$BASH
cat "$work/hostname"
STUB
chmod +x "$work/bin/hostname"

cat > "$work/bin/nix-store" <<STUB
#!$BASH
case " \$* " in
  *" -q --deriver "*) cat "$work/running.drv" ;;
  *) printf 'nix-store stub: refusing %s\n' "\$*" >&2; exit 99 ;;
esac
STUB
chmod +x "$work/bin/nix-store"

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
  install -Dm644 "$(dirname "$src")/audit.sh" "$seed/scripts/audit.sh"
  install -Dm644 "$(dirname "$src")/pi-reconcile.sh" "$seed/scripts/pi-reconcile.sh"
  mkdir -p "$seed/modules"
  printf 'lock v1\n' > "$seed/flake.lock"
  printf 'pins v1\n' > "$seed/modules/pinned-packages.nix"
  printf '# fixture pins\nsolhint\nroots\n' > "$seed/modules/pin-names.txt"
  printf 'pi v1\n' > "$seed/modules/pi.nix"
  printf 'nvim v1\n' > "$seed/modules/nvim.nix"
  git -C "$seed" add -A
  git -C "$seed" commit -qm init
  git -C "$seed" push -q origin main
  git clone -q "$origin" "$other"
  git -C "$other" config user.name other
  git -C "$other" config user.email other@example.invalid
  # The stubs read these, so a scenario never sees the previous one's answers.
  printf '[]\n' > "$work/issues.json"
  printf '{}\n' > "$work/advisories.json"
  printf '{"results":[]}\n' > "$work/osv.json"
  rm -f "$work/allow-flake-update"
  rm -rf "$XDG_RUNTIME_DIR/dotfiles.lockdir" "$HOME/.local/state/home-manager"
  rm -rf "$HOME/.local/state/dotfiles"
  rm -rf "$HOME/.pi"
  printf 'test\n' > "$work/hostname"
  printf '/nix/store/00000000000000000000000000000000-home-manager-generation.drv\n' > "$work/running.drv"
  cp "$work/running.drv" "$work/checkout.drv"
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
  git -C "$other" rev-parse HEAD
}

# The runner carries the two values dotfiles.sh reads and the scripts it runs.
# The two reconcile scripts are stubbed because they install packages from the
# network.
write_runner() {
  {
    printf 'export DOTFILES_DIR=%s\n' "$machine"
    printf 'DOTFILES_MACHINES=test\n'
    # The real reader comes in with its file, so `status` reads the same layout
    # the reconcile does. The installer is stubbed after it, because it reaches
    # the network.
    tail -n +2 "$machine/scripts/pi-reconcile.sh"
    printf 'pi_reconcile() { echo "[stub] pi_reconcile"; }\n'
    tail -n +2 "$machine/scripts/audit.sh"
    tail -n +2 "$machine/scripts/dotfiles.sh"
  } > "$runner"
}

# A HOME whose pi row sits on the fixture pin. A scenario calls this, then
# moves the installed version off it.
match_reconcile() {
  mkdir -p "$HOME/.pi/agent/npm/node_modules/fixturepkg"
  printf '{"packages":["npm:fixturepkg@1.0.0"]}\n' > "$HOME/.pi/agent/settings.json"
  printf '{"version":"1.0.0"}\n' > "$HOME/.pi/agent/npm/node_modules/fixturepkg/package.json"
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
  cli_out="$(PATH="$work/bin:$PATH" bash "$runner" "$@" test 2>&1)" || rc=$?
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

scenario 'sync refuses a dirty tree'
fixture
machine_clone
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
printf 'nvim v2-mine\n' > "$machine/modules/nvim.nix"
run_cli sync
refusal="dotfiles sync: local or untracked changes found in $machine; skipping
modules/nvim.nix
dotfiles sync: commit, stash, or discard local changes first"
expect_eq 'sync exits 0 when it refuses' 0 "$cli_rc"
expect_out_has 'the refusal lists the dirty path' "$refusal"
expect_out_lacks 'the refusal does not activate' '[stub] activate'
expect_eq 'sync leaves the edit untouched' 'nvim v2-mine' "$(cat "$machine/modules/nvim.nix")"
expect_eq 'sync leaves the edit modified' ' M modules/nvim.nix' "$(git -C "$machine" status --porcelain)"
expect_eq 'sync leaves HEAD where it was' "$head_before" "$(git -C "$machine" rev-parse HEAD)"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'sync refuses a dirty pin'
fixture
machine_clone
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
printf 'lock v2-mine\n' > "$machine/flake.lock"
run_cli sync
expect_eq 'sync exits 0 when it refuses' 0 "$cli_rc"
expect_out_has 'the refusal lists the pin' 'flake.lock'
expect_out_lacks 'the refusal does not activate' '[stub] activate'
expect_eq 'sync leaves the pin alone' 'lock v2-mine' "$(cat "$machine/flake.lock")"
expect_eq 'sync drops no stash' '' "$(git -C "$machine" stash list)"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'sync applies a clean tree'
fixture
machine_clone
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
run_cli sync
expect_eq 'sync exits 0 on a clean tree' 0 "$cli_rc"
expect_out_has 'sync activates the pulled checkout' '[stub] activate (profile add)'
expect_out_has 'sync runs pi_reconcile' '[stub] pi_reconcile'
expect_eq 'sync lands the pulled nvim change' 'nvim v2-other' "$(cat "$machine/modules/nvim.nix")"
expect_eq 'sync leaves a clean tree' '' "$(git -C "$machine" status --porcelain)"
expect_eq 'sync leaves HEAD on the pulled commit' "$(git -C "$origin" rev-parse main)" "$(git -C "$machine" rev-parse HEAD)"
expect_eq 'sync records the applied commit' "$(git -C "$origin" rev-parse main)" "$(tail -n 1 "$HOME/.local/state/dotfiles/applied.log" | awk '{print $1}')"
expect_origin_unmoved 'sync leaves the origin branch alone'
scenario_end

scenario 'rollback applies the commit applied before the current one'
fixture
machine_clone
run_cli sync
first="$(git -C "$machine" rev-parse HEAD)"
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
run_cli sync
expect_eq 'the second sync lands the newer commit' 'nvim v2-other' "$(cat "$machine/modules/nvim.nix")"
run_cli rollback
expect_eq 'rollback exits 0' 0 "$cli_rc"
expect_eq 'rollback checks out the earlier applied commit' "$first" "$(git -C "$machine" rev-parse HEAD)"
expect_eq 'rollback lands the earlier content' 'nvim v1' "$(cat "$machine/modules/nvim.nix")"
expect_out_has 'rollback reports where it landed' "applied ${first:0:7}"
run_cli rollback
expect_eq 'a second rollback returns to the later commit' "$(git -C "$origin" rev-parse main)" "$(git -C "$machine" rev-parse HEAD)"
scenario_end

scenario_end

scenario 'audit fails on a store match the baseline does not hold'
fixture
machine_clone
printf '[{"number":111,"title":"fixturepkg: security issues < 1.2.4"}]\n' > "$work/issues.json"
printf 'npm:fixturepkg@1.0.0\n' > "$machine/modules/pi.nix"
run_cli audit
expect_eq 'audit exits 1 on a new store match' 1 "$cli_rc"
expect_out_has 'audit names the matched package and its version' 'new   #111 fixturepkg 1.2.3'
expect_out_has 'audit names the issue' 'https://github.com/NixOS/nixpkgs/issues/111'
expect_out_has 'audit points at --update' 'record them with dotfiles audit --update'
expect_eq 'audit writes no baseline without --update' '' "$(cat "$machine/scripts/audit-baseline.txt" 2>/dev/null)"
scenario_end

scenario 'audit passes on a match the baseline holds'
fixture
machine_clone
printf '[{"number":111,"title":"fixturepkg: security issues < 1.2.4"}]\n' > "$work/issues.json"
printf 'npm:fixturepkg@1.0.0\n' > "$machine/modules/pi.nix"
printf 'nixpkgs 111 fixturepkg # 1.2.3\nnixpkgs 999 ghostpkg # 1.0\n' > "$machine/scripts/audit-baseline.txt"
run_cli audit
expect_eq 'audit exits 0 when the baseline holds the match' 0 "$cli_rc"
expect_out_has 'audit marks the held match as known' 'known #111 fixturepkg'
expect_out_has 'audit reports a line the store no longer matches' '1 recorded match(es) no longer apply'
expect_out_has 'audit reports ok' 'dotfiles audit: ok'
scenario_end

scenario 'audit --update records the match and a rerun passes'
fixture
machine_clone
printf '[{"number":111,"title":"fixturepkg: security issues < 1.2.4"}]\n' > "$work/issues.json"
printf 'npm:fixturepkg@1.0.0\n' > "$machine/modules/pi.nix"
run_cli audit --update
expect_eq 'audit --update exits 0' 0 "$cli_rc"
expect_out_has 'audit --update leaves the file for a commit' 'commit scripts/audit-baseline.txt'
expect_eq 'audit --update records the store match' 'nixpkgs 111 fixturepkg # 1.2.3' "$(cat "$machine/scripts/audit-baseline.txt")"
run_cli audit
expect_eq 'a rerun exits 0' 0 "$cli_rc"
expect_out_has 'a rerun reports ok' 'dotfiles audit: ok'
scenario_end

scenario 'audit fails on an npm advisory'
fixture
machine_clone
printf '[]\n' > "$work/issues.json"
printf 'npm:fixturepkg@1.0.0\n' > "$machine/modules/pi.nix"
printf '{"fixturepkg":[{"id":123,"severity":"high","title":"Command Injection","vulnerable_versions":"<1.0.1"}]}\n' > "$work/advisories.json"
run_cli audit
expect_eq 'audit exits 1 on an npm advisory' 1 "$cli_rc"
expect_out_has 'audit names the advisory range' 'new   fixturepkg 1.0.0 high <1.0.1'
expect_out_has 'audit names the advisory title' 'Command Injection'
expect_out_has 'audit names the npm pin that is behind' 'behind fixturepkg 1.0.0 -> 9.9.9'
scenario_end

scenario 'audit reads the tarball rows and their deps'
fixture
machine_clone
printf '[{"number":111,"title":"fixturepkg: security issues < 1.2.4"}]\n' > "$work/issues.json"
printf '{"fixturepkg":[{"id":123,"severity":"high","title":"Command Injection","vulnerable_versions":"<1.0.1"}]}\n' > "$work/advisories.json"
cat > "$machine/modules/pi.nix" <<'EOF'
{
  rows = [
    { tarball = {
        name = "fixturepkg";
        version = "1.0.0";
        url = "https://registry.npmjs.org/fixturepkg/-/fixturepkg-1.0.0.tgz";
        hash = "sha256-x";
        deps = [{
          name = "fixturedep";
          version = "2.0.0";
          url = "https://registry.npmjs.org/fixturedep/-/fixturedep-2.0.0.tgz";
          hash = "sha256-y";
        }];
      };
    }
  ];
}
EOF
run_cli audit
expect_eq 'audit exits 1 on the tarball advisory' 1 "$cli_rc"
expect_out_has 'audit reads the tarball row version' 'new   fixturepkg 1.0.0 high'
expect_out_has 'audit counts the row and its dep' 'npm - 2 rows'
expect_out_has 'audit reads the vendored dependency' 'behind fixturedep 2.0.0 -> 9.9.9'
scenario_end

scenario 'audit reads osv'
fixture
machine_clone
printf '{"results":[{"packages":[{"package":{"name":"fixturepkg","version":"1.2.3"},"vulnerabilities":[{"id":"GHSA-aaaa"}]}]}]}\n' > "$work/osv.json"
mkdir -p "$HOME/.pi/agent/npm"
printf '{}\n' > "$HOME/.pi/agent/npm/package-lock.json"
run_cli audit
expect_eq 'audit exits 1 on the new source' 1 "$cli_rc"
expect_out_has 'audit names the osv match' 'new   GHSA-aaaa fixturepkg@1.2.3'
run_cli audit --update
expect_eq 'audit --update exits 0' 0 "$cli_rc"
baseline="$(cat "$machine/scripts/audit-baseline.txt")"
expect_eq 'audit --update records the osv match' present "$(out_has "$baseline" 'osv GHSA-aaaa fixturepkg@1.2.3')"
scenario_end

scenario 'audit --declared reports a new match without failing'
fixture
machine_clone
printf '[{"number":111,"title":"fixturepkg: security issues < 1.2.4"}]\n' > "$work/issues.json"
printf 'nixpkgs 999 ghostpkg # 1.0\n' > "$machine/scripts/audit-baseline.txt"
run_cli audit --declared
expect_eq 'audit --declared exits 0 on a new match' 0 "$cli_rc"
expect_out_has 'audit --declared names its source' 'declared - 2 packages'
expect_out_has 'audit --declared matches a declared name' 'new   #111 fixturepkg 1.2.3'
expect_out_has 'audit --declared says the workflow records it' 'the Audit workflow records these'
expect_out_lacks 'audit --declared does not call a store-only line stale' 'no longer apply'
run_cli audit --declared --update
expect_eq 'audit --declared --update exits 0' 0 "$cli_rc"
expect_out_has 'audit --declared --update leaves the file for a commit' 'commit scripts/audit-baseline.txt'
baseline="$(cat "$machine/scripts/audit-baseline.txt")"
expect_eq 'audit --declared --update adds the new match' present "$(out_has "$baseline" 'nixpkgs 111 fixturepkg # 1.2.3')"
expect_eq 'audit --declared --update keeps the line only the store holds' present "$(out_has "$baseline" 'nixpkgs 999 ghostpkg # 1.0')"
run_cli audit --declared
expect_eq 'a rerun after the record exits 0' 0 "$cli_rc"
expect_out_has 'a rerun after the record reports no new match' '(0 new)'
scenario_end

scenario 'a run holding the lock makes the next one fail'
fixture
machine_clone
mkdir -p "$XDG_RUNTIME_DIR/dotfiles.lockdir"
printf '%s\n' "$$" > "$XDG_RUNTIME_DIR/dotfiles.lockdir/pid"
run_cli apply
expect_eq 'apply exits 1 while another run holds the lock' 1 "$cli_rc"
expect_out_has 'apply names the holder' "another run ($$) holds"
expect_out_lacks 'a refused apply does not activate' '[stub] activate'
expect_eq 'a refused apply leaves the lock in place' "$$" "$(cat "$XDG_RUNTIME_DIR/dotfiles.lockdir/pid")"
scenario_end

scenario 'apply reclaims a lock its owner no longer holds'
fixture
machine_clone
mkdir -p "$XDG_RUNTIME_DIR/dotfiles.lockdir"
sleep 0.01 & dead_pid=$!
wait "$dead_pid"
printf '%s\n' "$dead_pid" > "$XDG_RUNTIME_DIR/dotfiles.lockdir/pid"
run_cli apply
expect_eq 'apply exits 0 after reclaiming the lock' 0 "$cli_rc"
expect_out_has 'apply says it reclaimed the lock' 'reclaiming'
expect_out_has 'apply activates after reclaiming' '[stub] activate (profile add)'
expect_eq 'apply leaves no lock behind' absent "$(test -d "$XDG_RUNTIME_DIR/dotfiles.lockdir" && echo present || echo absent)"
scenario_end

scenario 'apply reclaims a lock directory that carries no pid'
fixture
machine_clone
mkdir -p "$XDG_RUNTIME_DIR/dotfiles.lockdir"
run_cli apply
expect_eq 'apply exits 0 after reclaiming a pid-less lock' 0 "$cli_rc"
expect_out_has 'apply activates after reclaiming' '[stub] activate (profile add)'
scenario_end

scenario 'two runs reclaiming one stale lock do not both write'
fixture
machine_clone
# Hold the winner in the activation stub, so the second run arrives while the
# first owns the lock instead of after it released it.
printf '#!/usr/bin/env bash\nsleep 0.3\necho "[stub] activate (profile add)"\n' > "$work/fakeout/activate"
sleep 0.01 & dead=$!
wait "$dead"
mkdir -p "$XDG_RUNTIME_DIR/dotfiles.lockdir"
printf '%s\n' "$dead" > "$XDG_RUNTIME_DIR/dotfiles.lockdir/pid"
( set +e; PATH="$work/bin:$PATH" bash "$runner" apply test > "$work/first.out" 2>&1; echo $? > "$work/first.rc" ) &
( set +e; PATH="$work/bin:$PATH" bash "$runner" apply test > "$work/second.out" 2>&1; echo $? > "$work/second.rc" ) &
wait
activations=0
for f in "$work/first.out" "$work/second.out"; do
  if grep -q '\[stub\] activate (profile add)' "$f"; then
    activations=$((activations + 1))
  fi
done
expect_eq 'only one of the two reclaimers activates' 1 "$activations"
expect_eq 'the other reclaimer exits non-zero' 1 "$(cat "$work/first.rc" "$work/second.rc" | grep -vc '^0$')"
printf '#!/usr/bin/env bash\necho "[stub] activate (profile add)"\n' > "$work/fakeout/activate"
scenario_end

scenario 'status reports the checkout and a current generation'
fixture
machine_clone
match_reconcile
mkdir -p "$HOME/.local/state/home-manager/gcroots"
ln -sfn "$work/fakeout" "$HOME/.local/state/home-manager/gcroots/current-home"
run_cli status
expect_eq 'status exits 0' 0 "$cli_rc"
expect_out_has 'status names the machine' 'dotfiles status: test'
expect_out_has 'status names the branch and its distance' 'branch:   main, 0 ahead of origin/main, 0 behind'
expect_out_has 'status reports committed pins' 'pins:     committed'
expect_out_has 'status reports the generation as current' 'generation: current'
expect_out_has 'status reports the reconcile as matching' 'reconcile: pi matches its pins'
expect_eq 'status leaves the tree alone' '' "$(git -C "$machine" status --porcelain)"
expect_eq 'status stashes nothing' '' "$(git -C "$machine" stash list)"
expect_origin_unmoved 'status leaves the origin branch alone'
scenario_end

scenario 'status names a diverged branch instead of sync'
fixture
machine_clone
printf 'nvim v2-mine\n' > "$machine/modules/nvim.nix"
git -C "$machine" commit -qam 'chore(nvim): mine'
push_from_other modules/pi.nix 'pi v2-other' 'chore(pi): other'
git -C "$machine" fetch -q
run_cli status
expect_eq 'status exits 0 on a diverged branch' 0 "$cli_rc"
expect_out_has 'status names the divergence' 'the branch diverged; rebase or merge before sync'
expect_out_lacks 'status does not recommend sync on a diverged branch' '; run dotfiles sync'
scenario_end

scenario 'status names what is behind and what is uncommitted'
fixture
machine_clone
mkdir -p "$HOME/.local/state/home-manager/gcroots"
ln -sfn "$work/fakeout" "$HOME/.local/state/home-manager/gcroots/current-home"
push_from_other modules/nvim.nix 'nvim v2-other' 'chore(nvim): other'
git -C "$machine" fetch -q
printf 'lock v2-mine\n' > "$machine/flake.lock"
printf '/nix/store/11111111111111111111111111111111-home-manager-generation.drv\n' > "$work/checkout.drv"
run_cli status
expect_eq 'status exits 0' 0 "$cli_rc"
expect_out_has 'status names the commit it is behind' '0 ahead of origin/main, 1 behind'
expect_out_has 'status names the pin left uncommitted' 'pins:     1 uncommitted: flake.lock'
expect_out_has 'status points at a commit' '; commit and push them'
expect_out_has 'status points at sync' '; run dotfiles sync'
expect_out_has 'status reports the generation as stale' 'generation: stale'
expect_eq 'status does not pull' "$head_before" "$(git -C "$machine" rev-parse HEAD)"
scenario_end

scenario 'status names the packages that are behind their pins'
fixture
machine_clone
match_reconcile
printf '{"version":"0.9.0"}\n' > "$HOME/.pi/agent/npm/node_modules/fixturepkg/package.json"
run_cli status
expect_eq 'status exits 0 with drift' 0 "$cli_rc"
expect_out_has 'status names the pi package that is behind' 'reconcile: pi fixturepkg is 0.9.0, pinned 1.0.0'
expect_out_lacks 'status does not claim a match' 'reconcile: pi matches its pins'
expect_eq 'status leaves the tree alone' '' "$(git -C "$machine" status --porcelain)"
scenario_end

scenario 'status does not compare another machine to this generation'
fixture
machine_clone
mkdir -p "$HOME/.local/state/home-manager/gcroots"
ln -sfn "$work/fakeout" "$HOME/.local/state/home-manager/gcroots/current-home"
printf 'other-host\n' > "$work/hostname"
run_cli status
expect_eq 'status exits 0' 0 "$cli_rc"
expect_out_has 'status says the row is not this machine' 'generation: not compared, test is not this machine (other-host)'
scenario_end

if [ "$failures" -gt 0 ]; then
  printf '\n%s assertion(s) failed\n' "$failures"
  exit 1
fi
printf '\nall assertions passed\n'
