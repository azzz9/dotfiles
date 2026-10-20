#!/usr/bin/env bash
# Moves every pin this repository carries, in one run. The Pins workflow runs
# this weekly; to move a single flake input by hand, use
# `nix flake update <input>` and commit the lock.
#
# nix-update has to be on PATH for the derivations in modules/pinned-packages.nix.
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
trap 'rm -f "$pin_scratch"' EXIT

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
      echo "bump-pins: no registry latest for $name; kept the pin at $current" >&2
      continue
    fi
    ordering="$(printf '%s\n' "$(version_key "$current")" "$(version_key "$latest")" | sort -V | tail -n 1)"
    if [ "$ordering" != "$(version_key "$latest")" ] || [ "$latest" = "$current" ]; then
      continue
    fi
    sed -i "s|\"$spec\"|\"npm:$name@$latest\"|" "$pi_module"
    echo "bump-pins: bumped the $name npm pin $current -> $latest"
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
bump_npm_pins
refresh_pi_npm_hashes
