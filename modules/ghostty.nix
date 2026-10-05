{ lib, pkgs, ... }:

let
  # Settings both machines use.
  shared = ''
    font-family = "RobotoMonoNoto-Mono"
    font-size = 10
    adjust-cell-width = -10%
    alpha-blending = linear
    background = #101010
    background-opacity = 0.9
  '';

  # macOS-only settings. The Linux build parses these keys and ignores them.
  macOnly = ''
    # Match the Kanagawa Dragon palette used by Neovim.
    theme = Kanagawa Dragon

    font-thicken = true
    font-thicken-strength = 128

    # Treat Option as Alt so herdr's pane navigation works consistently.
    macos-option-as-alt = true
  '';
in
{
  imports = [
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      # Ghostty itself is installed and updated outside Nix (Homebrew or the
      # official application). This module manages only its user configuration.
      #
      # Ghostty loads `config` after `config.ghostty`, and versions before 1.2.3
      # only read `config`, so this name works on either version.
      xdg.configFile."ghostty/config" = {
        text = shared + macOnly;
        force = true;
      };
    })

    (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      xdg.configFile."ghostty/config.ghostty" = {
        text = shared;
        force = true;
      };
    })
  ];
}
