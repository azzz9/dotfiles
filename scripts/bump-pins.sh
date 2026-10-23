#!/usr/bin/env bash
# Moves every pin this repository carries, in one run. The Pins workflow runs
# this weekly; to move a single flake input by hand, use
# `nix flake update <input>` and commit the lock.
#
# nix-update has to be on PATH for the derivations in modules/pinned-packages.nix,
# and python3 for the pi tarball bump.
set -euo pipefail

cd "$(dirname "$0")/.."
export NIX_CONFIG="${NIX_CONFIG:-}"$'\nextra-experimental-features = nix-command flakes'

nix_cmd() {
  nix --extra-experimental-features "nix-command flakes" "$@"
}

pins_file="modules/pinned-packages.nix"
pi_module="modules/pi.nix"
# The derivations `nix-update` bumps, one per line. This file is the list, so a
# new pin is one line here and one derivation in $pins_file; the pin-names check
# fails when this file and flake.nix's packages disagree in either direction.
pin_names_file="modules/pin-names.txt"
pin_names=()
pin_scratch="$(mktemp "${TMPDIR:-/tmp}/dotfiles-pin-bump.XXXXXX")"
pi_scratch="$(mktemp "${TMPDIR:-/tmp}/dotfiles-pi-bump.XXXXXX")"
trap 'rm -f "$pin_scratch" "$pi_scratch"' EXIT

read_pin_names() {
  local line
  if [ ! -f "$pin_names_file" ]; then
    echo "bump-pins: $pin_names_file is missing" >&2
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
    echo "bump-pins: $pin_names_file lists no package" >&2
    return 1
  fi
}

# Bump each derivation pinned in $pins_file on its own. nix-update prints its
# own "Update X -> Y" lines. A bump that fails (for example a new release
# needs a newer Go than nixpkgs carries) restores only that pin's state and
# warns, so one blocked release does not keep the whole run from moving.
bump_pins() {
  for name in "${pin_names[@]}"; do
    cp "$pins_file" "$pin_scratch"
    echo "bump-pins: bumping $name"
    if ! nix-update --flake "$name"; then
      cp "$pin_scratch" "$pins_file"
      echo "bump-pins: bumping $name failed; kept its previous pin" >&2
    fi
  done
}

# codediff-watcher's version is the one codediff-nvim's installer downloads, and
# each release names one archive per platform. Read that version from the pinned
# plugin, then measure every archive so the version and its hashes move in one
# step; the watcher's own build check fails when the plugin and the pin drift.
bump_codediff_watcher() {
  cp "$pins_file" "$pin_scratch"
  if ! update_codediff_watcher; then
    cp "$pin_scratch" "$pins_file"
    echo "bump-pins: bumping codediff-watcher failed; kept its previous pin" >&2
  fi
}

update_codediff_watcher() {
  local current version src hash system os arch old url
  current="$(sed -n 's/^  codediffWatcherVersion = "\([^"]*\)";$/\1/p' "$pins_file")"
  if [ -z "$current" ]; then
    echo "bump-pins: no codediffWatcherVersion in $pins_file" >&2
    return 1
  fi
  if ! src="$(nix_cmd build --no-link --print-out-paths --impure --expr "
    let
      flake = builtins.getFlake \"$PWD\";
      pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
    in pkgs.vimPlugins.codediff-nvim.src
  ")"; then
    echo "bump-pins: no built codediff-nvim source; kept the pin at $current" >&2
    return 1
  fi
  version="$(sed -n 's/^local VERSION = "\([^"]*\)"$/\1/p' "$src/lua/codediff/core/installer/watcher.lua")"
  if [ -z "$version" ] || [ "$version" = "$current" ]; then
    return 0
  fi
  for system in x86_64-linux aarch64-darwin; do
    case "$system" in
      x86_64-linux) os=linux; arch=x64 ;;
      aarch64-darwin) os=macos; arch=arm64 ;;
    esac
    url="https://github.com/esmuellert/codediff/releases/download/v${version}/codediff-watcher-${version}-${os}-${arch}.tar.gz"
    old="$(sed -n "/^    \"$system\" = {/,/^    };/ s/^      hash = \"\([^\"]*\)\";$/\1/p" "$pins_file")"
    if ! hash="$(nix_cmd store prefetch-file --json "$url" | sed -n 's/.*"hash": *"\([^"]*\)".*/\1/p')" || [ -z "$hash" ] || [ -z "$old" ]; then
      echo "bump-pins: could not measure codediff-watcher for $system; kept the pin at $current" >&2
      return 1
    fi
    sed -i "s|$old|$hash|" "$pins_file"
  done
  sed -i "s|^  codediffWatcherVersion = \"$current\";|  codediffWatcherVersion = \"$version\";|" "$pins_file"
  echo "bump-pins: bumped codediff-watcher $current -> $version"
}

# The pi rows pin published npm tarballs, and the dependencies they vendor under
# node_modules are rows too. The helper follows the registry and keeps a
# vendored dependency on the version its parent names. The whole set is
# restored on any doubt, because a parent and its dependencies move together.
bump_pi_tarballs() {
  cp "$pi_module" "$pi_scratch"
  if ! python3 scripts/bump-pi-tarballs.py; then
    cp "$pi_scratch" "$pi_module"
    echo "bump-pins: bumping the pi tarballs failed; kept their previous pins" >&2
  fi
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
        flake = builtins.getFlake \"$PWD\";
        pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
      in pkgs.fetchNpmDeps { src = flake.inputs.$input; hash = pkgs.lib.fakeHash; }
    " 2>&1 | sed -n 's/.*got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | head -n 1)" || true
    if [ -z "$got" ]; then
      echo "bump-pins: could not measure the $input npmDepsHash; kept its previous value" >&2
      continue
    fi
    if grep -q "{ input = \"$input\"; npmDepsHash = \"$got" "$pi_module"; then
      continue
    fi
    sed -i "s|{ input = \"$input\"; npmDepsHash = \"[^\"]*\"|{ input = \"$input\"; npmDepsHash = \"$got\"|" "$pi_module"
    echo "bump-pins: refreshed the $input npmDepsHash"
  done < <(sed -n 's/.*{ input = "\([^"]*\)"; npmDepsHash.*/\1/p' "$pi_module")
}

if ! read_pin_names; then
  exit 1
fi
if ! nix_cmd flake update; then
  echo "bump-pins: nix flake update failed; nothing was bumped" >&2
  exit 1
fi
# After the flake update on purpose: a release that needs a newer toolchain
# than the previous nixpkgs carried can still be bumped in the same run.
bump_pins
bump_codediff_watcher
bump_pi_tarballs
refresh_pi_npm_hashes
