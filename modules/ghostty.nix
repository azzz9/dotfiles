{ lib, pkgs, ... }:

lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
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
}
