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

# git-wt shell integration: `git wt <branch>` auto-cd. Only that subcommand
# is intercepted; everything else passes through.
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

# Completion for `dotfiles`; keep the machine list in sync with flake.nix.
_dotfiles() {
  local -a commands=(
    'apply:apply the current checkout'
    'sync:pull latest changes, then apply'
    'upgrade:update flake.lock inputs, then apply'
  )
  # Machine names injected from flake.nix.
  local -a machines=("${_dotfiles_machines[@]}")
  _arguments -C \
    '(-h --help)'{-h,--help}'[show help]' \
    '1:command:->commands' \
    '2:machine:->machines'
  case $state in
    commands) _describe -t commands 'dotfiles command' commands ;;
    machines) _describe -t machines 'machine' machines ;;
  esac
}

compdef _dotfiles dotfiles

# Sourced last so every ZLE widget exists before fast-syntax-highlighting wraps
# it. The bracketed-paste fix above is zsh core, independent of this plugin.
source "${_dotfiles_fsh_plugin}" 2>/dev/null

unset _dotfiles_fzf_cache _dotfiles_fsh_plugin _dotfiles_machines
