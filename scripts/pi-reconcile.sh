#!/usr/bin/env bash
# Moves pi's installed packages to what the current generation pins: git
# checkouts under <agent-dir>/git to the pinned revisions, npm packages to the
# versions their sources name. pi fetches even when a checkout is already
# current, so the local rev-parse and the installed-version read are what keep
# a converged `dotfiles apply` offline; pi is asked only where that check
# cannot prove it.
#
# modules/dotfiles.nix inlines this file into the `dotfiles` CLI;
# checks.pi-reconcile in flake.nix drives the function with a stub pi.
pi_reconcile() {
  pins="${HOME}/.pi/agent/.dotfiles-pi-pins"

  if [ ! -f "$pins" ]; then
    echo "dotfiles: no pi pins manifest at $pins; skipping the pi reconcile" >&2
    return 0
  fi

  while read -r spec rev; do
    checkout="${HOME}/.pi/agent/git/${spec}"
    if [ "$(git -C "$checkout" rev-parse HEAD 2>/dev/null || true)" = "$rev" ]; then
      continue
    fi
    # No @ref in the argument: pi reconciles the package to its declared
    # source, so settings.json stays the only place a spec is written down.
    echo "dotfiles: moving ${spec} to its pinned revision"
    if ! pi update "git:${spec}" < /dev/null; then
      echo "dotfiles: could not move ${spec}; rerun online: dotfiles apply" >&2
      return 1
    fi
  done < "$pins"

  # npm packages. `pi install` with a versioned source is the only command that
  # moves an installed npm package, and the installed version is readable from
  # the package itself. The pinned version comes from the spec in settings.json
  # rather than a second manifest, so there is nothing that could fall out of
  # sync with it.
  settings="${HOME}/.pi/agent/settings.json"
  if [ ! -f "$settings" ]; then
    return 0
  fi

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
