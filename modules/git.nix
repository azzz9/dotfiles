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
    # A copied node_modules never works: pnpm's package symlinks are dropped and
    # npm's .bin shims break once dereferenced. Keep node_modules out of the copy
    # and let a hook install from the lockfile instead.
    git config --global wt.nocopy 'node_modules/'
    git config --global wt.hook 'if [ -f pnpm-lock.yaml ]; then corepack pnpm install --frozen-lockfile; elif [ -f package-lock.json ]; then npm ci; fi'

    # hunk is the git pager; it falls back to normal paging for non-diff output.
    git config --global core.pager "hunk pager"

    # Sign commits by default with SSH keys. user.signingkey is machine-specific
    # and set by hand: git config --global user.signingkey ~/.ssh/signing_key.pub
    git config --global gpg.format ssh
    git config --global commit.gpgsign true

    unset -f git
  '';
}
