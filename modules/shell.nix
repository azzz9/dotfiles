{ config, lib, pkgs, ... }:
let
  fzfCache = "${config.xdg.cacheHome}/zsh/fzf-integration.zsh";
  fastSyntaxHighlighting = pkgs.zsh-fast-syntax-highlighting;
in
{
  programs.zsh = {
    enable = true;
    # zsh-autocomplete runs compinit itself; Home Manager's compinit runs too
    # early for the plugin's setup model.
    enableCompletion = false;

    shellAliases = {
      "olc" = "ollama launch codex --model glm-5.2:cloud";
      # --- Minimal git aliases (replaces OMZ git plugin's 197 aliases) ---
      "g" = "git";
      "gwt" = "git worktree";
      "gc" = "git commit -v";
      # --- ls aliases (replaces OMZ directories.zsh) ---
      "ll" = "ls --color=tty -lh";
      "l" = "ls --color=tty -lah";
      "la" = "ls --color=tty -lAh";
      "ls" = "ls --color=tty";
      # --- diff colors (replaces OMZ theme-and-appearance.zsh) ---
      "diff" = "diff --color";
    };

    shellGlobalAliases = {
      "..." = "../..";
      "...." = "../../..";
    };

    plugins = [
      {
        name = "zsh-autocomplete";
        src = pkgs.zsh-autocomplete;
        file = "share/zsh-autocomplete/zsh-autocomplete.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        # Completion cache: writable location, skip security audit.
        ZSH_COMPDUMP="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-$HOST-''${ZSH_VERSION}"
        ZSH_DISABLE_COMPFIX=true
        DISABLE_AUTO_UPDATE=true
        mkdir -p "''${ZSH_COMPDUMP:h}"

        # zsh-autocomplete runs its async list-choices completion inside a
        # PTY (interactive mode).  In interactive zsh, `#` is NOT a comment
        # by default — it requires the `interactive_comments` option.  The
        # upstream compadd wrapper contains a commented-out line with braces
        # inside a $(...) block; without this option zsh parses the `#` as
        # a command and the braces cause "parse error in command substitution",
        # which prevents async candidates from rendering at all.
        setopt interactive_comments

        zstyle ':autocomplete:*' enabled yes
        # zsh-autocomplete's key-bindings module assumes terminfo[kcbt]
        # exists. Some terminals do not expose it, which aborts plugin init
        # before the completion widgets are installed.
        zstyle ':autocomplete:key-bindings' enabled no
      '')

      # --- Appearance: replaces OMZ theme-and-appearance.zsh ---
      # No subprocess calls — ls/diff colors are handled via shellAliases.
      (lib.mkOrder 555 ''
        autoload -U colors && colors
        setopt prompt_subst
      '')

      (lib.mkOrder 910 ''
        # fzf key-bindings: source cached integration (regenerated on
        # home-manager switch). Falls back to subprocess if cache missing.
        if [[ $options[zle] = on ]]; then
          # Let fzf keep Tab for ** completion, but fall back to
          # zsh-autocomplete's complete-word widget for normal completion.
          fzf_default_completion=complete-word
          if [[ -f "${fzfCache}" ]]; then
            source "${fzfCache}"
          elif command -v fzf >/dev/null 2>&1; then
            source <(fzf --zsh)
          fi
        fi
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
          codex -p dotfiles --no-alt-screen "$@"
        }

        # SECURITY: Running an AI coding agent as root is dangerous.
        # The agent can execute arbitrary shell commands with elevated
        # privileges. Only use scdx when root-level file access is
        # absolutely required (e.g. system-level config editing).
        scdx() {
          echo "scdx: WARNING - codex will run as root with full system access" >&2
          sudo "$HOME/.nix-profile/bin/codex" "$@"
        }

        gcp() {
          copilot \
            --allow-all-tools \
            --allow-url github.com \
            --allow-url api.github.com \
            --deny-tool 'shell(sudo:*)' \
            --deny-tool 'shell(dd:*)' \
            --deny-tool 'shell(mkfs:*)' \
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

        # git-wt shell integration — enables `git wt <branch>` auto-cd
        # and tab completion. Only the `git wt` subcommand is intercepted;
        # all other git commands pass through unchanged.
        if command -v git-wt >/dev/null 2>&1; then
          eval "$(git wt --init zsh)"
        fi

        # Jump to a ghq-managed repository selected with fzf.
        gqcd() {
          emulate -L zsh
          local dir
          dir="$(ghq list --full-path 2>/dev/null | fzf --prompt='ghq> ')" || return 1
          [[ -n "$dir" ]] && builtin cd "$dir"
        }

        # Jump to a sub-root (monorepo package) in the current tree via roots + fzf.
        rcd() {
          emulate -L zsh
          local dir
          dir="$(roots 2>/dev/null | fzf --prompt='roots> ')" || return 1
          [[ -n "$dir" ]] && builtin cd "$dir"
        }

        # Interactively switch git worktrees with fzf (uses git-wt listing).
        # NB: do not name the local "path" -- in zsh `path` is tied to `PATH`
        # and `local path` would empty PATH inside the function.
        wtcd() {
          emulate -L zsh
          local wt_path
          wt_path="$(git-wt 2>/dev/null | fzf --header-lines=1 | awk '{if ($1 == "*") print $2; else print $1}')" || return 1
          [[ -n "$wt_path" ]] && builtin cd "$wt_path"
        }
      '')

      # --- Terminal title: replaces OMZ termsupport.zsh ---
      (lib.mkOrder 935 ''
        if [[ -z "''${INSIDE_EMACS:-}" || "$INSIDE_EMACS" = vterm ]]; then
          _termsupport_precmd() {
            case "$TERM" in
              screen*|tmux*) print -Pn "\ek%15<..<%~%<<\e\\" ;;
              xterm*|rxvt*|alacritty*|st*|foot*|wezterm*|konsole*)
                print -Pn "\e]2;%n@%m: %~\a" ;;
            esac
          }
          _termsupport_preexec() {
            local cmd="''${1[(wr)^(*=*|sudo|ssh|mosh|-*)]:gs/%/%%}"
            case "$TERM" in
              screen*|tmux*) print -Pn "\ek$cmd\e\\" ;;
              xterm*|rxvt*|alacritty*|st*|foot*|wezterm*|konsole*)
                print -Pn "\e]2;%n@%m: $cmd\a" ;;
            esac
          }
          autoload -Uz add-zsh-hook
          add-zsh-hook precmd _termsupport_precmd
          add-zsh-hook preexec _termsupport_preexec
        fi
      '')

      (lib.mkOrder 990 ''
        # fast-syntax-highlighting: 4x faster than zsh-syntax-highlighting.
        # Sourced last so all ZLE widgets are defined before wrapping.
        source ${fastSyntaxHighlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh 2>/dev/null
      '')

      (lib.mkOrder 1000 ''
        export NVM_DIR="$HOME/.nvm"

        _lazy_load_nvm() {
          unset -f nvm node npm npx corepack _lazy_load_nvm
          if [ -s "$NVM_DIR/nvm.sh" ]; then
            . "$NVM_DIR/nvm.sh"
            [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
          else
            echo "nvm: NVM not found at $NVM_DIR/nvm.sh; using system node" >&2
          fi
        }

        nvm() { _lazy_load_nvm; nvm "$@"; }
        node() { _lazy_load_nvm; command node "$@"; }
        npm() { _lazy_load_nvm; command npm "$@"; }
        npx() { _lazy_load_nvm; command npx "$@"; }
        corepack() { _lazy_load_nvm; command corepack "$@"; }
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
