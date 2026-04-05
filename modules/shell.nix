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
      (lib.mkOrder 900 ''
        dotfiles-sync() {
          local host="''${1:-default}"
          local repo="$HOME/dotfiles"

          if [ ! -d "$repo/.git" ]; then
            echo "dotfiles-sync: $repo not found" >&2
            return 1
          fi

          (
            cd "$repo" || return 1

            if ! git diff --quiet || ! git diff --cached --quiet; then
              echo "dotfiles-sync: local changes found in $repo; commit or stash first" >&2
              return 1
            fi

            git pull --ff-only
          ) || return 1

          nix run nixpkgs#home-manager -- switch --flake "$repo#$host" --impure
        }

        dotfiles-upgrade() {
          local host="''${1:-default}"
          local repo="$HOME/dotfiles"

          if [ ! -d "$repo" ]; then
            echo "dotfiles-upgrade: $repo not found" >&2
            return 1
          fi

          (cd "$repo" && nix flake update) || return 1
          nix run nixpkgs#home-manager -- switch --flake "$repo#$host" --impure
        }
      '')
      (lib.mkOrder 920 ''
        autoload -U promptinit
        promptinit
        prompt pure
      '')
      (lib.mkOrder 930 ''
        unalias cdx 2>/dev/null || true
        unalias gcp 2>/dev/null || true

        cdx() {
          codex --no-alt-screen "$@"
        }

        gcp() {
          gh copilot "$@"
        }
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

  home.packages = [
    pkgs.pure-prompt
  ];
}
