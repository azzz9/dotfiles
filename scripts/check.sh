#!/usr/bin/env bash
# The single check entry point. The check definitions live in flake.nix
# (checks.<system>) so the pre-push hook, CI, and a local run cannot drift.
#
#   scripts/check.sh             build the checks for this machine. The
#                               generated-configs check depends on the
#                               activation package, so that is built too.
#   scripts/check.sh --no-build  evaluate only, build nothing (CI's fast job)
set -euo pipefail

cd "$(dirname "$0")/.."
nix_cmd() { nix --extra-experimental-features "nix-command flakes" "$@"; }

if [ "${1:-full}" = "--no-build" ]; then
  # `nix flake check --no-build` cannot serve as the fast path: deriving the
  # checks forces bun2nix's cache-entry-creator, whose own dependencies have to
  # be built, so it fails on a store that has not built hunk yet.
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
nix_cmd flake check --impure
echo "[check] ok"
