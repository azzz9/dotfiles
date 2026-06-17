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
          local host="''${1:-${pkgs.stdenv.hostPlatform.system}}"
          command dotfiles-sync-run "$host"
        }

        dotfiles-upgrade() {
          local host="''${1:-${pkgs.stdenv.hostPlatform.system}}"
          local repo="$HOME/dotfiles"

          if [ ! -d "$repo" ]; then
            echo "dotfiles-upgrade: $repo not found" >&2
            return 1
          fi

          (cd "$repo" && nix flake update) || return 1
          nix run nixpkgs#home-manager -- switch --flake "$repo#$host" --impure -b backup
        }
      '')
      (lib.mkOrder 920 ''
        # Keep SSH user@host readable across terminal themes.
        zstyle ':prompt:pure:user' color 'default'
        zstyle ':prompt:pure:host' color 'default'

        autoload -U promptinit
        promptinit
        prompt pure
      '')
      (lib.mkOrder 930 ''
        unalias cdx 2>/dev/null || true
        unalias scdx 2>/dev/null || true
        unalias gcp 2>/dev/null || true
        unalias gtr 2>/dev/null || true

        cdx() {
          codex --no-alt-screen "$@"
        }

        scdx() {
          sudo "$HOME/.nix-profile/bin/codex" "$@"
        }

        gcp() {
          copilot \
            --allow-all-tools \
            --allow-url github.com \
            --allow-url api.github.com \
            --deny-tool 'shell(sudo:*)' \
            --deny-tool 'shell(rm:*)' \
            --deny-tool 'shell(find:*)' \
            --deny-tool 'shell(dd:*)' \
            --deny-tool 'shell(mkfs:*)' \
            --deny-tool 'shell(chmod:*)' \
            --deny-tool 'shell(chown:*)' \
            --deny-tool 'shell(git clean)' \
            --deny-tool 'shell(git reset)' \
            --deny-tool 'shell(git push)' \
            "$@"
        }

        gtr() {
          local root
          root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
            echo "gtr: not inside a git repository" >&2
            return 1
          }
          cd "$root"
        }
      '')
      (lib.mkOrder 980 ''
        # Ensure zsh-autocomplete keeps Tab; fzf's integration rebinds it.
        bindkey -M main '^I' complete-word
        bindkey -M emacs '^I' complete-word
        bindkey -M vicmd '^I' complete-word
      '')
      (lib.mkOrder 1000 ''
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
      '')
      (lib.mkOrder 1100 ''
        if [[ -o interactive \
          && -z "''${TMUX:-}" \
          && "''${TMUX_AUTO_START:-1}" != 0 \
          && "''${TERM:-}" != dumb ]] && command -v tmux >/dev/null 2>&1; then
          exec tmux new-session -A -s main
        fi
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
