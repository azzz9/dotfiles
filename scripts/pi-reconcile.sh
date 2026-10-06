#!/usr/bin/env bash
# Moves pi's npm packages to the versions the current generation pins. The git
# packages need no reconcile: modules/pi.nix hands pi each flake input's store
# path, so pi already loads the pinned revision.
#
# modules/dotfiles.nix inlines this file into the `dotfiles` CLI.
pi_reconcile() {
  local settings source name expected installed npm_sources
  settings="${HOME}/.pi/agent/settings.json"
  if [ ! -f "$settings" ]; then
    return 0
  fi

  # `pi install` with a versioned source is the only command that moves an
  # installed npm package, and the installed version is readable from the
  # package itself. The pinned version comes from the spec in settings.json.
  #
  # Read the list before any install runs: pi rewrites settings.json, and a
  # streamed read would race that write.
  mapfile -t npm_sources < <(
    jq -r '.packages[] | if type == "object" then .source else . end
           | select(type == "string" and startswith("npm:"))' "$settings"
  )

  for source in "${npm_sources[@]}"; do
    name="${source#npm:}"
    name="${name%@*}"
    expected="${source##*@}"
    # An unpinned source names no version, so there is nothing to compare.
    if [ "$expected" = "$source" ]; then
      continue
    fi
    installed="$(jq -r .version "${HOME}/.pi/agent/npm/node_modules/${name}/package.json" 2>/dev/null || true)"
    if [ "$installed" = "$expected" ]; then
      continue
    fi
    echo "dotfiles: installing ${source}"
    if ! pi install "$source" < /dev/null; then
      echo "dotfiles: could not install ${source}; rerun online: dotfiles apply" >&2
      return 1
    fi
  done
}
