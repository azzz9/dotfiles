{ ... }:
{
  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font Mono" ];

  xdg.configFile."lazygit/config.yml".text = ''
    gui:
      showIcons: true
      nerdFontsVersion: "3"

    git:
      diffRenderers:
        - name: delta
          type: stdinFilter
          colorArg: always
          command: delta --dark --paging=never --wrap-max-lines=0
  '';
  xdg.configFile."lazygit/config.yml".force = true;
}
