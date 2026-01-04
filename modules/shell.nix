{ lib, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    oh-my-zsh = {
      enable = true;
      theme = "";
      plugins = [
        "git"
        "vi-mode"
        "z"
        "fzf"
      ];
    };
    plugins = [
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete;
        file = "share/zsh-autocomplete/zsh-autocomplete.plugin.zsh";
      }
    ];
    syntaxHighlighting.enable = true;
    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        zstyle ':autocomplete:*' enabled yes
      '')
      (lib.mkOrder 980 ''
        # Ensure zsh-autocomplete keeps Tab; fzf's integration rebinds it.
        bindkey -M main '^I' complete-word
        bindkey -M emacs '^I' complete-word
        bindkey -M vicmd '^I' complete-word
      '')
      (lib.mkOrder 1000 ''
        export PATH="$HOME/.npm-global/bin:$PATH"
      '')
    ];
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
