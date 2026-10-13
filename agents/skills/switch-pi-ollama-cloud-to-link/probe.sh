#!/usr/bin/env bash
# Report what a pi install actually loads for Ollama Cloud.
#
# Runs against whatever `pi` is on PATH, so it proves the local box and a
# remote box alike:  ssh <host> 'bash -s' < pi-ollama-cloud-probe.sh
#
#   --call              after the checks, ask a real ollama-cloud model to reply
#   --model <id>        model for --call (default: cheapest catalog entry)
set -uo pipefail

CALL=0
MODEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --call) CALL=1; shift ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    *) echo "usage: $0 [--call] [--model <id>]" >&2; exit 2 ;;
  esac
done

pi_bin="$(command -v pi)" || { echo "FAIL: pi is not on PATH"; exit 1; }
echo "host=$(hostname) pi=$pi_bin version=$(pi --version 2>/dev/null)"

link="$HOME/.pi/agent/extensions/pi-ollama-cloud-link"
pkg="$HOME/.pi/agent/npm/node_modules/pi-ollama-cloud-link"
echo "package installed: $([ -d "$pkg" ] && echo yes || echo NO) ($pkg)"
if [ -L "$link" ]; then
  echo "discovery symlink: present -> $(readlink "$link")"
elif [ -e "$link" ]; then
  echo "discovery symlink: absent, extensions/ holds a real directory"
else
  echo "discovery symlink: ABSENT"
fi

out="$(mktemp)" err="$(mktemp)"
{ printf '%s\n' '{"id":"c1","type":"get_commands"}' '{"id":"c2","type":"get_available_models"}'; sleep 6; } \
  | "$pi_bin" --mode rpc --no-session >"$out" 2>"$err"

python3 - "$out" <<'PY'
import json, sys

cmds = models = None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        rec = json.loads(line)
    except json.JSONDecodeError:
        continue
    if rec.get("type") != "response":
        continue
    if rec.get("command") == "get_commands":
        cmds = rec.get("data", {}).get("commands", [])
    elif rec.get("command") == "get_available_models":
        models = rec.get("data", {}).get("models", [])

names = [c.get("name") for c in (cmds or [])]
print("ollama-setup command:", "PRESENT" if "ollama-setup" in names else "MISSING")

cloud = []
for m in (models or []):
    blob = " ".join(str(m.get(k, "")) for k in ("provider", "providerId", "id", "modelId"))
    if "ollama-cloud" in blob:
        cloud.append(m)
ids = sorted({str(m.get("id") or m.get("modelId")) for m in cloud})
print("ollama-cloud models:", len(ids), ids[:4])
if cloud:
    print("model object keys:", sorted(cloud[0].keys()))
PY

if [ -s "$err" ]; then
  echo "--- stderr (first 5 interesting lines) ---"
  grep -Ei "warn|error|fail" "$err" | head -5
fi
rm -f "$out" "$err"

if [ "$CALL" -eq 1 ]; then
  if [ -z "$MODEL" ]; then
    echo "FAIL: --call needs --model <id>"; exit 1
  fi
  echo "--- live completion via ollama-cloud/$MODEL ---"
  pi -p "Reply with the single word: pong" --provider ollama-cloud --model "$MODEL" \
    --no-session --no-tools --no-skills --no-context-files 2>&1 | tail -5
fi
