# Settings only Linux needs. Everything shared lives in ../default.nix.
{ config, lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # English XDG user directories. The updater names them after the locale, so
  # Home Manager writes the names and disables the updater.
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    # Pinned so a later state version bump cannot silently drop the variables.
    setSessionVariables = true;
  };
  # The updater can write a real file here before the first activation, and
  # Home Manager's clobber guard would abort the switch.
  xdg.configFile."user-dirs.dirs".force = true;
}
