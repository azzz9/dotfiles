#!/usr/bin/env bash
# Moves pi's npm packages to the versions the current generation pins. The git
# packages need no reconcile: modules/pi.nix hands pi each flake input's store
# path, so pi already loads the pinned revision.
#
# modules/dotfiles.nix inlines this file into the `dotfiles` CLI.

# "<source>\t<installed version>" per versioned npm row. The reconcile and
# `dotfiles status` share it, so the report cannot disagree with the install.
pi_npm_rows() {
  local settings="$1" source name installed
  if [ ! -f "$settings" ]; then
    return 0
  fi
  while IFS= read -r source; do
    name="${source#npm:}"
    name="${name%@*}"
    if [ "${source##*@}" = "$source" ]; then
      continue
    fi
    installed="$(jq -r .version "${HOME}/.pi/agent/npm/node_modules/${name}/package.json" 2>/dev/null || true)"
    printf '%s\t%s\n' "$source" "${installed:--}"
  done < <(
    jq -r '.packages[] | if type == "object" then .source else . end
           | select(type == "string" and startswith("npm:"))' "$settings"
  )
}

pi_reconcile() {
  local settings source expected installed rows row
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
  mapfile -t rows < <(pi_npm_rows "$settings")

  for row in "${rows[@]}"; do
    IFS=$'\t' read -r source installed <<< "$row"
    expected="${source##*@}"
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
