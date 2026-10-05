# Settings only macOS needs. Everything shared lives in ../default.nix.
# The guard stays here because `imports` cannot read `pkgs` without forcing
# `config`, and the Home Manager module system reports that as infinite recursion.
{ config, lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  # The Nix profile directories are not on the login shell's default PATH on
  # macOS, and Homebrew's own shellenv runs after these entries.
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  # nix.gc.options is one string and launchd takes one argument per element, so
  # the arguments are split at the launchd layer.
  launchd.agents.nix-gc.config.ProgramArguments = lib.mkForce [
    "${pkgs.nix}/bin/nix-collect-garbage"
    "--delete-older-than"
    "30d"
  ];
}
