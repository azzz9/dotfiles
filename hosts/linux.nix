# Settings only Linux needs. A machine takes this module by importing it, so
# the shared modules carry no platform test.
{ config, pkgs, ... }:
{
  dotfiles.platform = "linux";
  dotfiles.pi.linuxProviders = true;

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

  # Ghostty's binary and its config live together here. nvim sets
  # clipboard=unnamedplus, so yanking needs wl-copy on Wayland.
  home.packages = [ pkgs.ghostty pkgs.wl-clipboard ];

  xdg.configFile."ghostty/config.ghostty" = {
    text = builtins.readFile ../modules/ghostty/config.ghostty;
    force = true;
  };
}
