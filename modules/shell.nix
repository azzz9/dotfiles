{ config, lib, pkgs, ... }:
let
  zshCacheDir = "${config.xdg.cacheHome}/zsh";
  fzfCache = "${zshCacheDir}/fzf-integration.zsh";
  fastSyntaxHighlighting = pkgs.zsh-fast-syntax-highlighting;

  initDir = ./shell/init;
  readZsh = file: builtins.readFile (initDir + "/${file}");

  # Nix-resolved paths injected as zsh variables before the init scripts,
  # so the sourced .zsh files stay pure (no Nix interpolation). Mirrors
  # the nvim/lua pattern: a generated preamble + readFile'd config files.
  # The variables are unset at the end of 02-main.zsh (after the last
  # consumer) so they do not leak into the interactive shell environment.
  initPreamble = ''
    # Paths resolved at build time from Nix; referenced by init scripts.
    _dotfiles_fzf_cache="${fzfCache}"
    _dotfiles_fsh_plugin="${fastSyntaxHighlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
  '';
in
{
  programs.zsh = {
    enable = true;
    # zsh-autocomplete runs compinit itself; Home Manager's compinit runs too
    # early for the plugin's setup model.
    enableCompletion = false;

    shellAliases = {
      "ll" = "ls --color=tty -lh";
      "l" = "ls --color=tty -lah";
      "la" = "ls --color=tty -lAh";
      "ls" = "ls --color=tty";
      # --- diff colors (replaces OMZ theme-and-appearance.zsh) ---
      "diff" = "diff --color";
    };

    plugins = [
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete;
        file = "share/zsh-autocomplete/zsh-autocomplete.plugin.zsh";
      }
    ];

    # Three bands preserve the original ordering relative to Home Manager's
    # own generated content (plugin sourcing < 910, shellInit at 1000):
    #   500  preamble        build-time path variables
    #   550  01-setup.zsh     BEFORE plugins (ZSH_COMPDUMP, zstyle, appearance)
    #   910  02-main.zsh      AFTER plugins (fzf, prompt, functions, title, fsh)
    #  1100  03-tail.zsh      AFTER shellInit (nvm lazy-load, tmux auto-start)
    initContent = lib.mkMerge [
      (lib.mkOrder 500 initPreamble)
      (lib.mkOrder 550 (readZsh "01-setup.zsh"))
      (lib.mkOrder 910 (readZsh "02-main.zsh"))
      (lib.mkOrder 1100 (readZsh "03-tail.zsh"))
    ];
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
  };

  home.packages = [
    pkgs.pure-prompt
  ];

  # Regenerate fzf key-binding cache and invalidate compdump on activation.
  home.activation.zshPerformanceCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
    if command -v ${pkgs.fzf}/bin/fzf >/dev/null 2>&1; then
      ${pkgs.fzf}/bin/fzf --zsh > "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/fzf-integration.zsh"
    fi
    rm -f "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-"*
  '';
}
