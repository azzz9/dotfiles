{ ... }:
{
  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font Mono" ];

  xdg.configFile."lazygit/config.yml".text = ''
    gui:
      showIcons: true
      nerdFontsVersion: "3"

    git:
      pagers:
        - colorArg: always
          pager: delta --dark --paging=never --side-by-side
  '';
  xdg.configFile."lazygit/config.yml".force = true;
}
