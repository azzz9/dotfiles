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
    # SECURITY: wt.copyignored copies gitignored files (e.g. .env, .env.local)
    # into new worktrees so they remain usable without committing secrets.
    # This is convenient but means secret files exist in multiple locations.
    # Ensure worktree directories are not shared or backed up to untrusted
    # destinations. Set to false per-repo if a project has no ignored files
    # or if you prefer to re-create them manually: git config wt.copyignored false
    git config --global wt.copyignored true

    unset -f git
  '';
}
