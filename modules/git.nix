{ lib, pkgs, ... }:
{
  # Sensible ghq + git-wt defaults without taking over the whole ~/.gitconfig.
  # NB: activation scripts run with a minimal PATH, so reference git explicitly.
  home.activation.ghqWtDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    git() { '${pkgs.git}/bin/git' "$@"; }

    # ghq clones into ~/src (conventional layout: ~/src/github.com/owner/repo)
    git config --global ghq.root "$HOME/src"

    # git-wt worktrees sit alongside the repo as <repo>-wt
    git config --global wt.basedir "../{gitroot}-wt"
    # SECURITY: wt.copyignored copies gitignored files such as .env into new
    # worktrees, so secrets end up in multiple locations. Keep worktree
    # directories out of backups and shared paths, or set `wt.copyignored false`
    # per repo (or globally) to skip the copy.
    git config --global wt.copyignored true

    # hunk is the git pager; it falls back to normal paging for non-diff output.
    git config --global core.pager "hunk pager"

    # Sign commits by default with SSH keys. user.signingkey is machine-specific
    # and set by hand: git config --global user.signingkey ~/.ssh/signing_key.pub
    git config --global gpg.format ssh
    git config --global commit.gpgsign true

    unset -f git
  '';
}
