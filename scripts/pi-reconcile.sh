#!/usr/bin/env bash
# Moves the pi package checkouts under <agent-dir>/git to the revisions the
# current generation pins. pi fetches even when a checkout is already on the
# pinned revision, so the local rev-parse is what keeps a converged
# `dotfiles apply` offline; pi is asked only where that check cannot prove it.
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
}
