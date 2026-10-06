#!/usr/bin/env bash
set -euo pipefail

herdr_auto_title_reconcile() {
  local manifest="${HOME}/.local/share/dotfiles/herdr-auto-title-pin"
  local spec commit extra registry count row kind owner repo resolved enabled managed_path

  if [ ! -r "$manifest" ]; then
    echo "dotfiles: missing Auto Title pin manifest at $manifest" >&2
    return 1
  fi
  if ! IFS=' ' read -r spec commit extra < "$manifest" || [ -z "$spec" ] || [ -z "$commit" ] || [ -n "$extra" ]; then
    echo "dotfiles: malformed Auto Title pin manifest at $manifest" >&2
    return 1
  fi
  if [ "$(wc -l < "$manifest")" -ne 1 ] || [[ ! "$spec" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    echo "dotfiles: malformed Auto Title pin manifest at $manifest" >&2
    return 1
  fi

  if ! registry="$(herdr plugin list --json)"; then
    echo "dotfiles: could not read Herdr plugin registry" >&2
    return 1
  fi
  if ! printf '%s' "$registry" | jq -e '(.result | type) == "object" and .result.type == "plugin_list" and (.result.plugins | type) == "array"' >/dev/null 2>&1; then
    echo "dotfiles: malformed Herdr plugin registry JSON" >&2
    return 1
  fi
  count="$(printf '%s' "$registry" | jq '[.result.plugins[] | select(.plugin_id == "herdr.auto-title")] | length')"
  if [ "$count" -gt 1 ]; then
    echo "dotfiles: duplicate herdr.auto-title registrations; refusing to change the registry" >&2
    return 1
  fi
  if [ "$count" -eq 0 ]; then
    if ! CGO_ENABLED=0 herdr plugin install "$spec" --ref "$commit" --yes; then
      echo "dotfiles: Herdr could not install herdr.auto-title at $commit" >&2
      return 1
    fi
    echo 'herdr plugin action invoke herdr.auto-title.restart'
    return 0
  fi

  row="$(printf '%s' "$registry" | jq -c '.result.plugins[] | select(.plugin_id == "herdr.auto-title")')"
  if ! jq -e '(.source | type) == "object" and (.enabled | type) == "boolean"' <<< "$row" >/dev/null; then
    echo "dotfiles: malformed herdr.auto-title registration; refusing to change the registry" >&2
    return 1
  fi
  kind="$(jq -r '.source.kind' <<< "$row")"
  owner="$(jq -r '.source.owner // ""' <<< "$row")"
  repo="$(jq -r '.source.repo // ""' <<< "$row")"
  resolved="$(jq -r '.source.resolved_commit // ""' <<< "$row")"
  enabled="$(jq -r '.enabled' <<< "$row")"
  managed_path="$(jq -r '.source.managed_path // .plugin_root // ""' <<< "$row")"

  if [ "$kind" = local ]; then
    echo "dotfiles: herdr.auto-title is a local plugin; recover with: herdr plugin unlink herdr.auto-title, then dotfiles apply" >&2
    return 1
  fi
  if [ "$kind" != github ] || [ "$owner/$repo" != "$spec" ]; then
    echo "dotfiles: herdr.auto-title is registered from a different source; recover with: herdr plugin uninstall herdr.auto-title, then dotfiles apply" >&2
    return 1
  fi
  if ! jq -e '(.source.resolved_commit | type) == "string" and (.source.resolved_commit | test("^[0-9a-f]{40}$")) and ((.source.managed_path // .plugin_root | type) == "string")' <<< "$row" >/dev/null; then
    echo "dotfiles: malformed herdr.auto-title source; refusing to change the registry" >&2
    return 1
  fi
  if [ -z "$managed_path" ] || [ ! -d "$managed_path" ]; then
    echo "dotfiles: herdr.auto-title managed checkout is missing; recover with: herdr plugin uninstall herdr.auto-title, then dotfiles apply" >&2
    return 1
  fi

  if [ "$resolved" != "$commit" ]; then
    if ! CGO_ENABLED=0 herdr plugin install "$spec" --ref "$commit" --yes; then
      echo "dotfiles: Herdr could not update herdr.auto-title to $commit" >&2
      return 1
    fi
    echo 'herdr plugin action invoke herdr.auto-title.restart'
    return 0
  fi

  if [ "$enabled" = false ]; then
    if ! herdr plugin enable herdr.auto-title; then
      echo "dotfiles: Herdr could not enable herdr.auto-title" >&2
      return 1
    fi
    echo 'herdr plugin action invoke herdr.auto-title.restart'
  fi
}
