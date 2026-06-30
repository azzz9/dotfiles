# fzf key-bindings: source cached integration (regenerated on
# home-manager switch). Falls back to subprocess if cache missing.
if [[ $options[zle] = on ]]; then
  # Let fzf keep Tab for ** completion, but fall back to
  # zsh-autocomplete's complete-word widget for normal completion.
  fzf_default_completion=complete-word
  if [[ -f "${_dotfiles_fzf_cache}" ]]; then
    source "${_dotfiles_fzf_cache}"
  elif command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
  fi
fi

# Keep SSH user@host readable across terminal themes.
zstyle ':prompt:pure:user' color 'default'
zstyle ':prompt:pure:host' color 'default'

autoload -U promptinit
promptinit
prompt pure

cdx() {
  codex -p dotfiles --no-alt-screen "$@"
}

# olc: like cdx but uses the glm-5.2:cloud model via the Ollama
# provider. Loads the dotfiles profile (config.base.toml) for all
# base settings (personality, sandbox, approvals, etc.), then
# overrides model and provider on the command line. The ollama
# provider is declared in config.base.toml so it is available
# without a separate ollama-launch profile.
olc() {
  codex -p dotfiles -m glm-5.2:cloud \
  -c 'model_provider="ollama-launch"' \
  -c "model_catalog_json=\"$HOME/.codex/model.json\"" \
  --no-alt-screen "$@"
}

# SECURITY: Running an AI coding agent as root is dangerous.
# The agent can execute arbitrary shell commands with elevated
# privileges. Only use scdx when root-level file access is
# absolutely required (e.g. system-level config editing).
#scdx() {
#  echo "scdx: WARNING - codex will run as root with full system access" >&2
#  sudo "$HOME/.nix-profile/bin/codex" "$@"
#}

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

# dev: arrange the current window into a dev layout (nvim + AI agent + free shell).
# Layout: nvim (65% width) | AI agent (35% width, 75% height) + free (25% height)
# Rearranges the current window in place: all other panes are killed (with a
# confirmation prompt when any has a running process) and the window is renamed
# after the current directory.
# Usage: dev [cdx|olc|gcp]  (default: cdx)
dev() {
  local agent="${1:-cdx}"
  local cmd
  case "$agent" in
    cdx)   cmd="cdx" ;;
    olc)   cmd="olc" ;;
    gcp)   cmd="gcp" ;;
    *)     echo "usage: dev [cdx|olc|gcp]" >&2; return 1 ;;
  esac

  # Collect the panes to kill (everything except the active one) and detect
  # whether any of them has a running process that is not just an idle shell.
  local current_pane
  current_pane="$(tmux display-message -p '#{pane_id}')"
  local pane pane_cmd has_process=0
  local kill_panes=()
  for pane in $(tmux list-panes -F '#{pane_id}' 2>/dev/null); do
    if [[ "$pane" != "$current_pane" ]]; then
      kill_panes+=("$pane")
      pane_cmd="$(tmux display-message -p -t "$pane" '#{pane_current_command}')"
      case "$pane_cmd" in
        zsh|bash|fish|sh|dash|ksh|mksh|csh|tcsh) ;;  # idle shell
        *) has_process=1 ;;
      esac
    fi
  done

  # Confirm before discarding panes that have running processes.
  if (( ${#kill_panes[@]} > 0 )) && (( has_process )); then
    printf 'dev: %d pane(s) with running processes will be killed. Continue? [y/N] ' "${#kill_panes[@]}"
    local reply
    read -r reply
    if [[ "$reply" != [yY]* ]]; then
      echo "aborted." >&2
      return 1
    fi
  fi

  for pane in "${kill_panes[@]}"; do
    tmux kill-pane -t "$pane"
  done

  # Rename the current window to a unique name based on the current directory.
  local base="$(basename "$PWD")"
  local name="$base"
  local n=1
  local cur_win
  cur_win="$(tmux display-message -p '#{window_name}')"
  while tmux list-windows -F '#{window_name}' 2>/dev/null | grep -v -F -x "$cur_win" | grep -qx "$name"; do
    n=$((n + 1))
    name="${base}${n}"
  done
  tmux rename-window "$name"

  # Remaining pane becomes the nvim pane.
  tmux send-keys "nvim" Enter
  # Split right: AI agent pane (35% width, nvim gets 65%)
  tmux split-window -h -l 35% -c "$PWD"
  tmux send-keys "$cmd" Enter
  # Split AI agent pane vertically: free shell (25% height, AI agent gets 75%)
  tmux split-window -v -l 25% -c "$PWD"
  # Focus nvim
  tmux select-pane -t 0
}

_dev() {
  _arguments '1:agent:(cdx olc gcp)'
}
compdef _dev dev

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

# --- Completion for `dotfiles` command and aliases ---
# Keep host list in sync with flake.nix `supportedSystems`.
_dotfiles() {
  local -a commands=(
    'apply:apply the current checkout'
    'sync:pull latest changes, then apply'
    'upgrade:update flake.lock inputs, then apply'
  )
  local -a hosts=(x86_64-linux aarch64-darwin)
  _arguments -C \
    '(-h --help)'{-h,--help}'[show help]' \
    '1:command:->commands' \
    '2:host:->hosts'
  case $state in
    commands) _describe -t commands 'dotfiles command' commands ;;
    hosts)    _describe -t hosts 'host' hosts ;;
  esac
}

compdef _dotfiles dotfiles

# fast-syntax-highlighting: a faster, async-capable rewrite of
# zsh-syntax-highlighting. Auto-initializes on source (sets up its
# ZLE hooks and FAST_HIGHLIGHT state); no ZSH_HIGHLIGHT_HIGHLIGHTERS
# needed. Sourced last so all ZLE widgets are defined before wrapping.
# NB: bracketed-paste reverse-video is handled separately via
# zle_highlight[paste] above (zsh core), independent of this plugin.
source "${_dotfiles_fsh_plugin}" 2>/dev/null

# Drop build-time path variables now that both consumers have run.
unset _dotfiles_fzf_cache _dotfiles_fsh_plugin
