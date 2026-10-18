#!/usr/bin/env bash
set -euo pipefail

herdr=${HERDR_BIN_PATH:-herdr}

# Boundary: the event payload is the only untrusted input. Parse it once here;
# everything after this point relies on the workspace id being present.
event=${HERDR_PLUGIN_EVENT_JSON:-}
if [[ -z $event ]]; then
  printf 'worktree-layout: HERDR_PLUGIN_EVENT_JSON is not set\n' >&2
  exit 1
fi

ws=$(jq -r '.data.workspace.workspace_id // ""' <<<"$event")
if [[ -z $ws ]]; then
  printf 'worktree-layout: event carries no workspace id\n' >&2
  exit 1
fi

# worktree.create and worktree.open also emit workspace.created, where the
# checkout arrives as workspace provenance instead of a worktree record.
base=$(jq -r '.data.worktree.path // ""' <<<"$event")
worktree_provenance=$(jq -r '.data.workspace.worktree != null' <<<"$event")
if [[ -z $base && $worktree_provenance == true ]]; then
  exit 0
fi

# Reopening a checkout must not alter an existing layout. Only a pristine
# workspace is ours: one tab holding one root pane.
tabs=$("$herdr" tab list --workspace "$ws")
first_tab=$(jq -r '.result.tabs[0].tab_id // ""' <<<"$tabs")
panes=$("$herdr" pane list --workspace "$ws" |
  jq -c --arg tab "$first_tab" '[.result.panes[] | select(.tab_id == $tab)]')
root_pane=$(jq -r 'if length == 1 then .[0].pane_id else empty end' <<<"$panes")
if (($(jq '.result.tabs | length' <<<"$tabs") != 1)) || [[ -z $root_pane ]]; then
  exit 0
fi

# A worktree event names the checkout. A plain new workspace reports no path, so
# its base directory is the cwd Herdr gave the root pane.
if [[ -z $base ]]; then
  base=$(jq -r '.[0].cwd // ""' <<<"$panes")
fi

# Herdr takes --cwd as optional, so a workspace whose base directory is unknown
# still gets its tab and splits. Appending the flag here keeps the expansion of an
# empty array out of the two call sites, which system Bash 3.2 on macOS aborts.
herdr_at_base() {
  if [[ -n $base ]]; then
    "$herdr" "$@" --cwd "$base"
  else
    "$herdr" "$@"
  fi
}

# One line per pane: "<tab group>|<command>". Group keys only determine layout;
# Auto Title owns the visible tab names. An empty command leaves a plain shell.
labels=()
commands=()
while IFS='|' read -r label command; do
  labels+=("$label")
  commands+=("$command")
done <<'LAYOUT'
agents|
diff|nvim -c CodeDiff
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
    pane=$(herdr_at_base tab create --workspace "$ws" --no-focus |
      jq -r '.result.root_pane.pane_id')
  fi

  for ((k = start; k < end; k++)); do
    if ((k > start)); then
      # --ratio is the fraction the pane being split keeps, so 1/(n-i+2) for
      # pane i leaves n equal columns. bash has no float arithmetic.
      ratio=$(awk -v n="$n" -v i="$((k - start + 1))" 'BEGIN { printf "%.10f\n", 1 / (n - i + 2) }')
      pane=$(herdr_at_base pane split "$pane" --direction right --ratio "$ratio" --no-focus |
        jq -r '.result.pane.pane_id')
    fi
    if [[ -n ${commands[k]} ]]; then
      "$herdr" pane run "$pane" "${commands[k]}"
    fi
  done

  start=$end
done
