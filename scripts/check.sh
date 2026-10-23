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
# run repeats up to three times. The attempt that failed keeps every path it did
# build in the store, so the next attempt repeats only what failed. A real
# failure fails all three and still exits 1.
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

echo "[check] nix flake check"
attempt=1
while ! nix_cmd flake check --impure; do
  if ((attempt >= 3)); then
    echo "[check] failed on attempt $attempt" >&2
    exit 1
  fi
  echo "[check] attempt $attempt failed, retrying in $((attempt * 10))s" >&2
  sleep $((attempt * 10))
  ((++attempt))
done
echo "[check] ok (attempt $attempt)"
