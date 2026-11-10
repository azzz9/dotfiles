# The pi package this repository ships: the rules pi loads on every turn
# (AGENTS.md, APPEND_SYSTEM.md), the skills, and the extensions. pi loads the
# store path this builds in place, as it loaded the old `skills` flake input.
{ pkgs }:
let
  inherit (pkgs) lib;
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.difference ./. ./default.nix;
  };
in
pkgs.runCommand "pi-skills" { } ''
  cp -r ${src} $out
''
