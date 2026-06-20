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
        # Keep completion cache writable and avoid Oh My Zsh's startup audit.
        ZSH_COMPDUMP="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-$HOST-''${ZSH_VERSION}"
        ZSH_DISABLE_COMPFIX=true
        DISABLE_AUTO_UPDATE=true
        mkdir -p "''${ZSH_COMPDUMP:h}"

        zstyle ':autocomplete:*' enabled yes
      '')
      (lib.mkOrder 900 ''
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
        unalias gwt 2>/dev/null || true

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
          emulate -L zsh

          local root target print_only=0 command_mode=0

          case "''${1:-}" in
            -h|--help)
              print -r -- "usage: gtr [--print] [repo-relative-path]"
              print -r -- "       gtr              # cd to git repository root"
              print -r -- "       gtr src          # cd to <repo-root>/src"
              print -r -- "       gtr --print      # print git repository root"
              print -r -- "       gtr -- <command> # run a command from git repository root"
              return 0
              ;;
            -p|--print)
              print_only=1
              shift
              ;;
            --)
              command_mode=1
              shift
              ;;
          esac

          root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
            print -u2 -r -- "gtr: not inside a git repository"
            return 1
          }

          if (( print_only )); then
            print -r -- "$root"
            return 0
          fi

          if (( command_mode )); then
            if (( $# == 0 )); then
              builtin cd "$root"
            else
              (builtin cd "$root" && "$@")
            fi
            return
          fi

          if (( $# == 0 )); then
            builtin cd "$root"
            return
          fi

          target="$root/$1"
          if [[ -d "$target" ]]; then
            builtin cd "$target"
          elif [[ -e "$target" ]]; then
            builtin cd "''${target:h}"
          else
            print -u2 -r -- "gtr: repo-relative path not found: $1"
            return 1
          fi
        }

        _gtr() {
          emulate -L zsh

          local root
          root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1

          _arguments \
            '(-p --print)'{-p,--print}'[print the git repository root]' \
            '(-h --help)'{-h,--help}'[show help]' \
            '--[run a command from the git repository root]' \
            '1:repo-relative path:_files -W "$root"'
        }

        compdef _gtr gtr

        _gwt_worktree_paths() {
          git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p'
        }

        _gwt_select_worktree() {
          emulate -L zsh

          local query="''${1:-}" selected
          local -a matches

          if [[ -n "$query" ]]; then
            matches=("''${(@f)$(_gwt_worktree_paths | grep -i -e "$query")}")
          else
            matches=("''${(@f)$(_gwt_worktree_paths)}")
          fi

          case "''${#matches[@]}" in
            0)
              print -u2 -r -- "gwt: no matching worktree"
              return 1
              ;;
            1)
              print -r -- "$matches[1]"
              return 0
              ;;
          esac

          if command -v fzf >/dev/null 2>&1; then
            selected="$(printf '%s\n' "$matches[@]" | fzf --prompt='worktree> ')" || return 1
            print -r -- "$selected"
          else
            print -u2 -r -- "gwt: multiple matching worktrees; refine the query:"
            printf '%s\n' "$matches[@]" >&2
            return 1
          fi
        }

        _gwt_default_base() {
          if [[ -n "''${GWT_BASE:-}" ]]; then
            print -r -- "$GWT_BASE"
            return
          fi

          if git show-ref --verify --quiet refs/remotes/origin/main; then
            print -r -- "origin/main"
          elif git show-ref --verify --quiet refs/heads/main; then
            print -r -- "main"
          elif git show-ref --verify --quiet refs/remotes/origin/master; then
            print -r -- "origin/master"
          elif git show-ref --verify --quiet refs/heads/master; then
            print -r -- "master"
          else
            print -r -- "HEAD"
          fi
        }

        _gwt_default_path() {
          emulate -L zsh

          local root="$1" branch="$2"
          local repo_name safe_branch base_dir

          repo_name="''${root:t}"
          safe_branch="''${branch//\//-}"
          base_dir="''${GWT_DIR:-$HOME/worktrees}"

          print -r -- "$base_dir/$repo_name/$safe_branch"
        }

        gwt() {
          emulate -L zsh

          local root repo_name branch base worktree_path selected

          case "''${1:-}" in
            -h|--help)
              print -r -- "usage: gwt [query]"
              print -r -- "       gwt new <branch> [base] [path]"
              print -r -- "       gwt list"
              print -r -- "       gwt prune"
              print -r -- ""
              print -r -- "default directory: \''${GWT_DIR:-$HOME/worktrees}/<repo>/<branch>"
              print -r -- "default base: \''${GWT_BASE:-origin/main, main, origin/master, master, or HEAD}"
              print -r -- "examples:"
              print -r -- "       gwt new PROJ-123"
              print -r -- "       gwt new feature/foo origin/develop"
              print -r -- "       gwt PROJ-123"
              return 0
              ;;
            list|ls)
              git worktree list
              return
              ;;
            prune)
              git worktree prune
              return
              ;;
            new|add)
              shift
              branch="''${1:-}"
              base="''${2:-$(_gwt_default_base)}"

              if [[ -z "$branch" ]]; then
                print -u2 -r -- "gwt: branch name required"
                print -u2 -r -- "usage: gwt new <branch> [base] [path]"
                return 2
              fi

              root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
                print -u2 -r -- "gwt: not inside a git repository"
                return 1
              }

              worktree_path="''${3:-$(_gwt_default_path "$root" "$branch")}"

              if git show-ref --verify --quiet "refs/heads/$branch"; then
                git worktree add "$worktree_path" "$branch" || return
              else
                git worktree add -b "$branch" "$worktree_path" "$base" || return
              fi

              builtin cd "$worktree_path"
              return
              ;;
          esac

          selected="$(_gwt_select_worktree "''${1:-}")" || return
          builtin cd "$selected"
        }

        _gwt() {
          emulate -L zsh

          local -a commands
          commands=(
            'new:create a worktree and cd into it'
            'add:create a worktree and cd into it'
            'list:list worktrees'
            'ls:list worktrees'
            'prune:prune stale worktree metadata'
          )

          _arguments \
            '1:command or query:->cmd' \
            '2:branch/base/path:_guard "^-*" "value"' \
            '*::args:_guard "^-*" "value"'

          case "$state" in
            cmd)
              _describe -t commands 'gwt command' commands
              ;;
          esac
        }

        compdef _gwt gwt
      '')
      (lib.mkOrder 980 ''
        # Ensure zsh-autocomplete keeps Tab; fzf's integration rebinds it.
        bindkey -M main '^I' complete-word
        bindkey -M emacs '^I' complete-word
        bindkey -M vicmd '^I' complete-word
      '')
      (lib.mkOrder 1000 ''
        export NVM_DIR="$HOME/.nvm"

        _lazy_load_nvm() {
          unset -f nvm node npm npx corepack _lazy_load_nvm
          [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
          [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
        }

        nvm() {
          _lazy_load_nvm
          nvm "$@"
        }

        node() {
          _lazy_load_nvm
          command node "$@"
        }

        npm() {
          _lazy_load_nvm
          command npm "$@"
        }

        npx() {
          _lazy_load_nvm
          command npx "$@"
        }

        corepack() {
          _lazy_load_nvm
          command corepack "$@"
        }
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
