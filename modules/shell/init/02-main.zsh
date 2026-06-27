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
