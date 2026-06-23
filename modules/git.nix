{ lib, pkgs, ... }:
{
  # Sensible defaults for ghq + git-wt so the workflow is comfortable
  # out of the box without taking over the entire ~/.gitconfig.
  # NB: activation scripts run with a minimal PATH, so reference git explicitly.
  home.activation.ghqWtDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    git() { '${pkgs.git}/bin/git' "$@"; }

    # ghq clones into ~/src (conventional layout: ~/src/github.com/owner/repo)
    git config --global ghq.root "$HOME/src"

    # git-wt: place worktrees alongside the repo as <repo>-wt
    git config --global wt.basedir "../{gitroot}-wt"
    # Carry over gitignored files (e.g. .env) into new worktrees
    git config --global wt.copyignored true

    unset -f git
  '';
}
