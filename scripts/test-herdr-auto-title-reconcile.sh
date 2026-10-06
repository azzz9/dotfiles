#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export PATH="$tmp/bin:$PATH"
export HERDR_CALLS="$tmp/calls"
export HERDR_LIST="$tmp/list.json"
target=kryptamine/herdr-auto-title
rev=0cf776db9a9450f1b190b4f3d787674c7a9d3ddb
managed="$HOME/.config/herdr/plugins/github/herdr.auto-title-managed"
mkdir -p "$HOME/.local/share/dotfiles" "$tmp/bin" "$managed"
printf '%s %s\n' "$target" "$rev" > "$HOME/.local/share/dotfiles/herdr-auto-title-pin"

# A Herdr that answers from HERDR_LIST and records every argument list. Each
# case below judges the call log, so the stub holds no state of its own.
cat > "$tmp/bin/herdr" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$HERDR_CALLS"
case "${1:-} ${2:-}" in
  "plugin list") cat "$HERDR_LIST" ;;
esac
STUB
chmod +x "$tmp/bin/herdr"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# One registration row, and an empty call log to judge the next run against.
registry() { # kind owner repo commit enabled
  printf '{"id":"c","result":{"type":"plugin_list","plugins":[{"plugin_id":"herdr.auto-title","enabled":%s,"plugin_root":"%s","source":{"kind":"%s","owner":"%s","repo":"%s","resolved_commit":"%s","managed_path":"%s"}}]}}\n' \
    "$5" "$managed" "$1" "$2" "$3" "$4" "$managed" > "$HERDR_LIST"
  : > "$HERDR_CALLS"
}

# shellcheck source=scripts/herdr-auto-title-reconcile.sh
source "$repo/scripts/herdr-auto-title-reconcile.sh"

# These cases are the quiet ones, where a wrong answer still exits 0 on a real
# machine. A failed install or an update to a bad revision fails the activation
# loudly, so it needs no test here.

# The locked commit, enabled, is left alone. A reinstall at this point would
# rebuild on every apply and keep succeeding.
registry github kryptamine herdr-auto-title "$rev" true
herdr_auto_title_reconcile > "$tmp/out"
[ "$(cat "$HERDR_CALLS")" = 'plugin list --json' ] || fail 'a matching registration was changed'
[ ! -s "$tmp/out" ] || fail 'a matching registration printed output'

# A missing registration installs the locked revision, not a branch head.
printf '{"id":"c","result":{"type":"plugin_list","plugins":[]}}\n' > "$HERDR_LIST"
: > "$HERDR_CALLS"
herdr_auto_title_reconcile > "$tmp/out"
[ "$(cat "$HERDR_CALLS")" = "plugin list --json
plugin install $target --ref $rev --yes" ] || fail 'the installer did not receive the locked revision'

# A registry that cannot be read, or names the plugin twice, is refused
# untouched.
for bad in '{broken' '{"result":{"type":"plugin_list","plugins":{}}}'; do
  printf '%s\n' "$bad" > "$HERDR_LIST"
  : > "$HERDR_CALLS"
  if herdr_auto_title_reconcile >/dev/null 2>&1; then fail "accepted a bad registry: $bad"; fi
  [ "$(cat "$HERDR_CALLS")" = 'plugin list --json' ] || fail "a bad registry was changed: $bad"
done

registry github kryptamine herdr-auto-title "$rev" true
jq '.result.plugins += .result.plugins' "$HERDR_LIST" > "$tmp/dup.json"
mv "$tmp/dup.json" "$HERDR_LIST"
if herdr_auto_title_reconcile >/dev/null 2>&1; then fail 'accepted duplicate registrations'; fi

# A registration dotfiles does not own is refused with its recovery command.
while IFS='|' read -r kind owner unowned recovery; do
  registry "$kind" "$owner" "$unowned" "$rev" true
  if herdr_auto_title_reconcile >/dev/null 2> "$tmp/err"; then fail "accepted a $kind registration"; fi
  grep -F "$recovery herdr.auto-title" "$tmp/err" >/dev/null || fail "the $kind recovery command is missing"
done <<'CASES'
local|||herdr plugin unlink
github|another|repository|herdr plugin uninstall
CASES

printf 'herdr-auto-title reconcile behavior checks passed\n'
