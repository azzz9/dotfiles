{ lib, pkgs, ... }:

{
  imports = [
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      # Ghostty itself is installed and updated outside Nix (Homebrew or the
      # official application). This module manages only its user configuration.
      xdg.configFile."ghostty/config" = {
        text = ''
          # Match the Kanagawa Dragon palette used by Neovim.
          theme = Kanagawa Dragon

          font-family = "UDEV Gothic NF"
          font-thicken = true
          font-thicken-strength = 128

          # Treat Option as Alt so herdr's pane navigation works consistently.
          macos-option-as-alt = true
        '';
        force = true;
      };
    })

    (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      # Linux Ghostty reads both config and config.ghostty, and config.ghostty wins.
      xdg.configFile."ghostty/config.ghostty" = {
        text = ''
          font-family = "RobotoMonoNoto-Mono"
          font-size = 10
          adjust-cell-width = -10%
          alpha-blending = linear
          background = #101010
          background-opacity = 0.9
        '';
        force = true;
      };
    })
  ];
}
