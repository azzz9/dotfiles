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

# dev: arrange the current tab into a dev layout (nvim + AI agent + free shell).
# Layout B:
#   +----------+--------+
#   |  nvim    |  AI    |
#   |          |  agent |
#   +----------+--------+
#   |     free shell    |
#   +-------------------+
# Rearranges the current tab in place: all other panes are killed (with a
# confirmation prompt when any has a running process) and the tab is renamed
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

  if [[ "${HERDR_ENV:-}" != 1 ]]; then
    echo "dev: not inside a herdr session (HERDR_ENV not set)" >&2
    return 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "dev: python3 is required to parse herdr JSON output" >&2
    return 1
  fi

  local current_json current_pane current_tab
  current_json="$(herdr pane current 2>/dev/null)" || {
    echo "dev: could not read current herdr pane" >&2
    return 1
  }
  current_pane="$(printf '%s' "$current_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')" || return 1
  current_tab="$(printf '%s' "$current_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["tab_id"])')" || return 1

  # Collect the panes to kill (everything except the active one) and detect
  # whether any of them has a running process that is not just an idle shell.
  local pane pane_list has_process=0
  local -a kill_panes
  pane_list="$(
    herdr pane list 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
current = sys.argv[1]
tab = sys.argv[2]
for pane in data["result"]["panes"]:
    pane_id = pane["pane_id"]
    if pane.get("tab_id") == tab and pane_id != current:
        print(pane_id)
' "$current_pane" "$current_tab"
  )" || return 1
  kill_panes=(${(f)pane_list})

  for pane in "${kill_panes[@]}"; do
    local proc
    proc="$(herdr pane process-info --pane "$pane" 2>/dev/null)"
    if ! grep -qE '(^|/)(zsh|bash|fish|sh|dash|ksh|mksh|csh|tcsh)( |$)' <<< "$proc" 2>/dev/null; then
      has_process=1
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
    herdr pane close "$pane" 2>/dev/null
  done

  # Rename the current tab to a unique name based on the current directory.
  local base="$(basename "$PWD")"
  local name="$base"
  local n=1
  while herdr tab list 2>/dev/null | python3 -c 'import json,sys; [print(tab["label"]) for tab in json.load(sys.stdin)["result"]["tabs"]]' | grep -qx "$name" 2>/dev/null; do
    n=$((n + 1))
    name="${base}${n}"
  done
  herdr tab rename "$current_tab" "$name" 2>/dev/null

  # Layout B: nvim (left, 70% width) | AI agent (right, 30% width)
  #           free shell (bottom, 25% height, full width)
  #
  # Split down first to create the full-width free shell pane, then split
  # the top (nvim) pane right to create the AI agent pane. This ordering
  # ensures the bottom pane spans the full width.

  # Step 1: Split nvim pane down -> free shell (25% height), keep focus on nvim.
  herdr pane split "$current_pane" --direction down --ratio 0.25 --cwd "$PWD" --no-focus >/dev/null || {
    echo "dev: failed to create free shell pane" >&2
    return 1
  }

  # Step 2: Split nvim pane right -> AI agent (30% width), keep focus on nvim.
  local split_json agent_pane
  split_json="$(herdr pane split "$current_pane" --direction right --ratio 0.7 --cwd "$PWD" --no-focus 2>/dev/null)" || {
    echo "dev: failed to create AI agent pane" >&2
    return 1
  }
  agent_pane="$(printf '%s' "$split_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')" || return 1

  herdr pane run "$agent_pane" "$cmd" || {
    echo "dev: failed to start AI agent in pane $agent_pane" >&2
    return 1
  }

  # Normalize the nested right split as well. For `--direction right`, Herdr's
  # ratio is the left pane width, so 0.7 means nvim:AI = 7:3.
  local right_ratio right_resize_plan right_resize_direction right_resize_amount
  right_ratio="$(
    herdr pane layout --pane "$current_pane" 2>/dev/null | python3 -c '
import json, sys
layout = json.load(sys.stdin)["result"]["layout"]
for split in layout.get("splits", []):
    if split.get("direction") == "right":
        print(split["ratio"])
        break
'
  )"
  if [[ -n "$right_ratio" ]]; then
    right_resize_plan="$(python3 -c '
import sys
current = float(sys.argv[1])
target = 0.7
delta = target - current
if abs(delta) >= 0.01:
    print(("right" if delta > 0 else "left") + " " + str(abs(delta)))
' "$right_ratio")"
    if [[ -n "$right_resize_plan" ]]; then
      right_resize_direction="${right_resize_plan%% *}"
      right_resize_amount="${right_resize_plan#* }"
      herdr pane resize --pane "$current_pane" --direction "$right_resize_direction" --amount "$right_resize_amount" >/dev/null 2>&1 \
        || echo "dev: warning: could not normalize layout width" >&2
    fi
  else
    echo "dev: warning: could not read layout width ratio" >&2
  fi

  # Herdr can rebalance the root split after the nested right split. Read the
  # effective root ratio and nudge it back so the top row is 75%.
  local root_ratio resize_plan resize_direction resize_amount
  root_ratio="$(
    herdr pane layout --pane "$current_pane" 2>/dev/null | python3 -c '
import json, sys
layout = json.load(sys.stdin)["result"]["layout"]
for split in layout.get("splits", []):
    if split.get("id") == "split_0_root" or split.get("direction") == "down":
        print(split["ratio"])
        break
'
  )"
  if [[ -n "$root_ratio" ]]; then
    resize_plan="$(python3 -c '
import sys
current = float(sys.argv[1])
target = 0.75
delta = target - current
if abs(delta) >= 0.01:
    print(("down" if delta > 0 else "up") + " " + str(abs(delta)))
' "$root_ratio")"
    if [[ -n "$resize_plan" ]]; then
      resize_direction="${resize_plan%% *}"
      resize_amount="${resize_plan#* }"
      herdr pane resize --pane "$current_pane" --direction "$resize_direction" --amount "$resize_amount" >/dev/null 2>&1 \
        || echo "dev: warning: could not normalize layout height" >&2
    fi
  else
    echo "dev: warning: could not read layout height ratio" >&2
  fi

  # Focus back to the nvim pane.
  herdr pane focus --direction left 2>/dev/null
  nvim
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
