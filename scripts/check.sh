#!/usr/bin/env bash
# The single check entry point. The check definitions live in flake.nix
# (checks.<system>) so the pre-push hook, CI, and a local run cannot drift.
#
#   scripts/check.sh             build the checks for this machine. The
#                               generated-configs check depends on the
#                               activation package, so that is built too.
#   scripts/check.sh --no-build  evaluate only, build nothing (CI's fast job)
#
# A full run fetches the npm dependencies of the pinned packages from
# registry.npmjs.org, and that fetch fails in two transient ways: a 502 from the
# registry, or a truncated download that lands as a hash mismatch in the
# fixed-output derivation. Both leave CI red on a change that is fine, so a full
# run repeats up to three times, and only for a failure that looks like one of
# them. A tree that does not evaluate, or a derivation that fails to build,
# fails the same way on every attempt: retrying it would only relabel the
# failure as flakiness and delay the report by a minute.
# The attempt that failed keeps every path it did build in the store, so the next
# attempt repeats only what failed.
set -euo pipefail

cd "$(dirname "$0")/.."
nix_cmd() { nix --extra-experimental-features "nix-command flakes" "$@"; }

if [ "${1:-full}" = "--no-build" ]; then
  # `nix flake check --no-build` cannot serve as the fast path: it refuses the
  # import-from-derivation that evaluating a home configuration needs, because
  # modules/hermes.nix reads uv.lock out of the hermes source. `nix eval` allows
  # it, and the loop names every machine rather than this host's platform.
  hosts="$(nix_cmd eval --impure --raw --expr \
    'builtins.concatStringsSep " " (builtins.attrNames (builtins.getFlake (builtins.toString ./.)).homeConfigurations)')"
  for host in $hosts; do
    echo "[check] evaluate homeConfigurations.$host"
    nix_cmd eval --impure --raw ".#homeConfigurations.$host.activationPackage.drvPath" > /dev/null
  done
  echo "[check] ok (evaluation only)"
  exit 0
fi

log="$(mktemp "${TMPDIR:-/tmp}/dotfiles-check.XXXXXX")"
trap 'rm -f "$log"' EXIT

run_check() {
  local status
  set +e
  nix_cmd flake check --impure 2>&1 | tee "$log"
  status="${PIPESTATUS[0]}"
  set -e
  return "$status"
}

# The fetch failures the header names, and nothing else.
transient() {
  grep -qiE 'hash mismatch|HTTP error 5[0-9][0-9]|Could not resolve host|Connection (reset|refused)|Temporary failure in name resolution|timed out|TLS' "$1"
}

# The line a reader, or a scheduled check that reads only the end of the log,
# needs: what failed, not just that something did. A bare "error:" only
# introduces a trace, so take the first line that carries the message itself: a
# failing check names the option or file, and a build failure names the
# derivation.
failure_line() {
  local line
  line="$(grep -m1 -E 'error: *[^[:space:]]' "$log" || true)"
  if [ -z "$line" ]; then
    line="$(tail -n 1 "$log")"
  fi
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
  echo "[check] failed: $line" >&2
}

echo "[check] nix flake check"
attempt=1
while :; do
  if run_check; then
    echo "[check] ok (attempt $attempt)"
    exit 0
  fi
  if ! transient "$log"; then
    echo "[check] the error above is not a fetch failure, so it is not retried" >&2
    failure_line
    exit 1
  fi
  if ((attempt >= 3)); then
    echo "[check] failed on attempt $attempt" >&2
    failure_line
    exit 1
  fi
  echo "[check] attempt $attempt failed on a fetch; retrying in $((attempt * 10))s" >&2
  sleep $((attempt * 10))
  ((++attempt))
done
