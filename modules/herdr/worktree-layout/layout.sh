#!/usr/bin/env bash
set -euo pipefail

herdr=${HERDR_BIN_PATH:-herdr}

# Boundary: the event payload is the only untrusted input. Parse it once here;
# everything after this point relies on these two values being present.
event=${HERDR_PLUGIN_EVENT_JSON:-}
if [[ -z $event ]]; then
  printf 'worktree-layout: HERDR_PLUGIN_EVENT_JSON is not set\n' >&2
  exit 1
fi

ws=$(jq -r '.data.workspace.workspace_id // ""' <<<"$event")
worktree=$(jq -r '.data.worktree.path // ""' <<<"$event")
if [[ -z $ws ]]; then
  printf 'worktree-layout: event carries no workspace id\n' >&2
  exit 1
fi
if [[ -z $worktree ]]; then
  printf 'worktree-layout: event carries no worktree path\n' >&2
  exit 1
fi

# Reopening a checkout must not alter an existing layout. Only a pristine
# workspace is ours: one tab holding one root pane.
tabs=$("$herdr" tab list --workspace "$ws")
first_tab=$(jq -r '.result.tabs[0].tab_id // ""' <<<"$tabs")
root_pane=$("$herdr" pane list --workspace "$ws" |
  jq -r --arg tab "$first_tab" '[.result.panes[] | select(.tab_id == $tab)] | if length == 1 then .[0].pane_id else empty end')
if (($(jq '.result.tabs | length' <<<"$tabs") != 1)) || [[ -z $root_pane ]]; then
  exit 0
fi

# One line per pane: "<tab group>|<command>". Group keys only determine layout;
# Auto Title owns the visible tab names. An empty command leaves a plain shell.
labels=()
commands=()
while IFS='|' read -r label command; do
  labels+=("$label")
  commands+=("$command")
done <<'LAYOUT'
agents|pi
agents|
agents|
diff|nvim -c CodeDiff
git|lazygit
scratch|
scratch|
LAYOUT

total=${#labels[@]}
start=0
while ((start < total)); do
  label=${labels[start]}
  end=$start
  while ((end < total)) && [[ ${labels[end]} == "$label" ]]; do
    ((++end))
  done
  n=$((end - start))

  if ((start == 0)); then
    # The workspace already owns this tab and its single root pane.
    pane=$root_pane
  else
    pane=$("$herdr" tab create --workspace "$ws" --cwd "$worktree" --no-focus |
      jq -r '.result.root_pane.pane_id')
  fi

  for ((k = start; k < end; k++)); do
    if ((k > start)); then
      # --ratio is the fraction the pane being split keeps, so 1/(n-i+2) for
      # pane i leaves n equal columns. bash has no float arithmetic.
      ratio=$(awk -v n="$n" -v i="$((k - start + 1))" 'BEGIN { printf "%.10f\n", 1 / (n - i + 2) }')
      pane=$("$herdr" pane split "$pane" --direction right --cwd "$worktree" --ratio "$ratio" --no-focus |
        jq -r '.result.pane.pane_id')
    fi
    if [[ -n ${commands[k]} ]]; then
      "$herdr" pane run "$pane" "${commands[k]}"
    fi
  done

  start=$end
done
