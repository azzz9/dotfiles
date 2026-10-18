#!/usr/bin/env bash
# The single check entry point. The check definitions live in flake.nix
# (checks.<system>) so the pre-push hook, CI, and a local run cannot drift.
#
#   scripts/check.sh                  build every check for this machine. The
#                                     generated-configs check depends on the
#                                     activation package, so that is built too.
#   scripts/check.sh --no-build       evaluate only, build nothing (CI's fast job)
#   scripts/check.sh --only <check>   build one check, which is the fast path
#                                     while iterating on a single failure
#
# Nothing here passes --impure: flake.nix states the account and the checkout
# paths, so the flake evaluates purely.
#
# A full run fetches the npm dependencies of the pinned packages from
# registry.npmjs.org, and that fetch fails in two transient ways: a 502 from the
# registry, or a truncated download that lands as a hash mismatch in the
# fixed-output derivation. Both leave CI red on a change that is fine, so a run
# repeats up to three times when, and only when, the failure looks transient.
# The attempt that failed keeps every path it did build in the store, so the
# next attempt repeats only what failed. A deterministic failure (a check that
# failed, a Nix syntax error) exits 1 on the first attempt.
set -euo pipefail

cd "$(dirname "$0")/.."
nix_cmd() { nix --extra-experimental-features "nix-command flakes" "$@"; }

# What "the registry or the network let us down" looks like, as opposed to
# "the repository is wrong".
transient_pattern='hash mismatch|502 Bad Gateway|unexpected EOF|Connection reset|TLS handshake timeout|unable to download'

usage() {
  cat <<'EOF'
usage: scripts/check.sh [--no-build | --only <check>]

  (no argument)     build every check for this machine
  --no-build        evaluate the home configurations and build nothing
  --only <check>    build one check by name (`scripts/check.sh --only deadnix`)
EOF
}

case "${1:-}" in
  --no-build)
    # `nix flake check --no-build` cannot serve as the fast path: deriving the
    # checks forces bun2nix's cache-entry-creator, whose own dependencies have to
    # be built, so it fails on a store that has not built hunk yet.
    hosts="$(nix_cmd eval --raw .#homeConfigurations --apply \
      'cs: builtins.concatStringsSep " " (builtins.attrNames cs)')"
    for host in $hosts; do
      echo "[check] evaluate homeConfigurations.$host"
      nix_cmd eval --raw ".#homeConfigurations.$host.activationPackage.drvPath" > /dev/null
    done
    echo "[check] ok (evaluation only)"
    exit 0
    ;;
  --only)
    check="${2:-}"
    if [ -z "$check" ]; then
      usage >&2
      exit 2
    fi
    # The check set is per system, and `builtins.currentSystem` is an impure
    # builtin, so name the system from the machine instead.
    case "$(uname -s)-$(uname -m)" in
      Linux-x86_64) system="x86_64-linux" ;;
      Darwin-arm64) system="aarch64-darwin" ;;
      *)
        echo "[check] unsupported machine: $(uname -s)-$(uname -m)" >&2
        exit 2
        ;;
    esac
    echo "[check] $check ($system)"
    nix_cmd build --no-link ".#checks.$system.$check"
    echo "[check] ok ($check)"
    exit 0
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    usage >&2
    exit 2
    ;;
esac

log="$(mktemp "${TMPDIR:-/tmp}/dotfiles-check.XXXXXX")"
trap 'rm -f "$log"' EXIT

echo "[check] nix flake check"
attempt=1
while :; do
  if nix_cmd flake check 2>&1 | tee "$log"; then
    echo "[check] ok (attempt $attempt)"
    exit 0
  fi
  if ! grep -Eq "$transient_pattern" "$log"; then
    echo "[check] failed; the failure is not a network one, so it is not retried" >&2
    exit 1
  fi
  if ((attempt >= 3)); then
    echo "[check] failed on attempt $attempt, every time on the network" >&2
    exit 1
  fi
  echo "[check] attempt $attempt failed on the network, retrying in $((attempt * 10))s" >&2
  sleep $((attempt * 10))
  ((++attempt))
done
