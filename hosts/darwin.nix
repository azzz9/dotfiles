# Settings only macOS needs. A machine takes this module by importing it, so
# the shared modules carry no platform test.
{ config, lib, pkgs, ... }:
{
  imports = [ ../modules/meltype.nix ];

  dotfiles.platform = "darwin";

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

  # Ghostty loads `config` after `config.ghostty`, and versions before 1.2.3
  # only read `config`, so this name works on either version.
  xdg.configFile."ghostty/config" = {
    text = builtins.readFile ../modules/ghostty/config.ghostty
      + builtins.readFile ../modules/ghostty/config.macos;
    force = true;
  };
}
