#!/usr/bin/env bash
set -euo pipefail

if [[ "${HERDR_ENV:-}" != 1 || -z "${HERDR_PANE_ID:-}" ]]; then
  printf '%s\n' 'Run this check from a Herdr-managed pane.' >&2
  exit 1
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
helper="$tmp_dir/consume-input.ts"
runner="$tmp_dir/resume-pi.sh"
session_file="$tmp_dir/resume.jsonl"
test_pane=

cleanup() {
  if [[ -n "$test_pane" ]]; then
    herdr pane close "$test_pane" >/dev/null 2>&1 || true
  fi
  rm -f -- "$helper" "$runner" "$session_file"
  rmdir "$tmp_dir"
}
trap cleanup EXIT

cat >"$helper" <<'EOF'
export default function (pi) {
  pi.on("input", () => ({ action: "handled" }));
}
EOF

state_extension="$HOME/.pi/agent/extensions/herdr-agent-state.ts"
prompt_extension="$HOME/.pi/agent/extensions/prompt-display.ts"

wait_for_idle() {
  for _ in {1..100}; do
    agent=$(herdr agent get "$test_pane" 2>/dev/null || true)
    if jq -e '.result.agent.agent == "pi" and .result.agent.agent_status == "idle"' >/dev/null <<<"$agent"; then
      return 0
    fi
    sleep 0.1
  done
  herdr pane read "$test_pane" --source visible --lines 30 >&2
  printf '%s\n' 'Pi did not become idle in the test pane.' >&2
  return 1
}

wait_for_token() {
  local key="$1"
  local expected="$2"
  for _ in {1..100}; do
    agent=$(herdr agent get "$test_pane" 2>/dev/null || true)
    actual=$(jq -r --arg key "$key" '.result.agent.tokens[$key] // empty' <<<"$agent")
    if [[ "$actual" == "$expected" ]]; then
      return 0
    fi
    sleep 0.1
  done
  herdr pane read "$test_pane" --source visible --lines 30 >&2
  printf 'Expected %s token: %s\n' "$key" "$expected" >&2
  printf 'Actual %s token:   %s\n' "$key" "$actual" >&2
  return 1
}

start_test_pane() {
  test_pane=$(herdr pane split --current --direction down --cwd "$root" --no-focus | jq -er '.result.pane.pane_id')
}

start_test_pane
herdr pane run "$test_pane" pi \
  --no-session \
  --no-tools \
  --no-skills \
  --no-prompt-templates \
  --no-context-files \
  --no-extensions \
  --extension "$state_extension" \
  --extension "$prompt_extension" \
  --extension "$helper"
wait_for_idle

input=$(printf '%*s' 84 '' | tr ' ' P)
herdr pane send-text "$test_pane" "$input"
herdr pane send-keys "$test_pane" enter
wait_for_token prompt "${input:0:80}"
printf '%s\n' 'PASS: the typed prompt appears in Herdr metadata, capped at 80 characters.'

branch=$(git -C "$root" rev-parse --abbrev-ref HEAD)
if [[ "$branch" == HEAD ]]; then
  printf '%s\n' 'SKIP: the checkout is on a detached HEAD, so no branch token is reported.'
else
  wait_for_token git_branch "$branch"
  printf '%s\n' 'PASS: the pane reports the branch of its working directory.'
fi

input='prompt display update verification'
herdr pane send-text "$test_pane" "$input"
herdr pane send-keys "$test_pane" enter
wait_for_token prompt "$input"
printf '%s\n' 'PASS: a newer prompt replaces the previous value.'
herdr pane close "$test_pane" >/dev/null
test_pane=

python3 - "$session_file" "$root" <<'PY'
import datetime
import json
import pathlib
import sys
import uuid

path = pathlib.Path(sys.argv[1])
now = datetime.datetime.now(datetime.timezone.utc)
timestamp = now.isoformat(timespec="milliseconds").replace("+00:00", "Z")
header = {
    "type": "session",
    "version": 3,
    "id": str(uuid.uuid4()),
    "timestamp": timestamp,
    "cwd": sys.argv[2],
}
entry = {
    "type": "message",
    "id": "a1b2c3d4",
    "parentId": None,
    "timestamp": timestamp,
    "message": {
        "role": "user",
        "content": "session resume prompt verification",
        "timestamp": int(now.timestamp() * 1000),
    },
}
path.write_text(json.dumps(header) + "\n" + json.dumps(entry) + "\n")
PY

cat >"$runner" <<EOF
#!/usr/bin/env bash
exec pi --session "$session_file" --no-tools --no-skills --no-prompt-templates --no-context-files --no-extensions --extension "$state_extension" --extension "$prompt_extension"
EOF
chmod +x "$runner"
start_test_pane
herdr pane run "$test_pane" "$runner"
wait_for_idle
wait_for_token prompt 'session resume prompt verification'
printf '%s\n' 'PASS: the latest user prompt is restored from the active session branch.'
herdr pane close "$test_pane" >/dev/null
test_pane=

python3 - "$session_file" "$root" <<'PY'
import datetime
import json
import pathlib
import sys
import uuid

path = pathlib.Path(sys.argv[1])
now = datetime.datetime.now(datetime.timezone.utc)
timestamp = now.isoformat(timespec="milliseconds").replace("+00:00", "Z")
header = {
    "type": "session",
    "version": 3,
    "id": str(uuid.uuid4()),
    "timestamp": timestamp,
    "cwd": sys.argv[2],
}
entries = [
    {
        "type": "message",
        "id": "a1b2c3d4",
        "parentId": None,
        "timestamp": timestamp,
        "message": {
            "role": "user",
            "content": "older session prompt",
            "timestamp": int(now.timestamp() * 1000),
        },
    },
    {
        "type": "message",
        "id": "b2c3d4e5",
        "parentId": "a1b2c3d4",
        "timestamp": timestamp,
        "message": {
            "role": "user",
            "content": "   ",
            "timestamp": int(now.timestamp() * 1000),
        },
    },
]
path.write_text("\n".join(json.dumps(entry) for entry in [header, *entries]) + "\n")
PY

start_test_pane
herdr pane report-metadata "$test_pane" --source dotfiles:pi-prompt --seq 1 --token prompt=stale
herdr pane run "$test_pane" "$runner"
wait_for_idle
wait_for_token prompt ''
printf '%s\n' 'PASS: a latest user message without text clears an older prompt.'
