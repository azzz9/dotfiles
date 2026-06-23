# Repository & worktree workflow (ghq + roots + git-wt + fzf)

Manage remote-repo clones with `ghq`, explore monorepo roots with `roots`,
juggle git worktrees with `git-wt`, and pick anything interactively with `fzf`.

## Tool roles

```
 ghq get <url>        roots               git wt <branch>
 +---------+          +-------+           +---------+
 | ghq     |          | roots |           | git-wt  |
 +----+----+          +---+---+           +----+----+
      |                   |                   |
      | ghq list -p        | roots             | git-wt
      v                   v                   v
   +-----+              +-----+             +-----+
   | fzf |              | fzf |             | fzf |
   +--+--+              +--+--+             +--+--+
      |                    |                   |
      v                    v                   v
   cd repo             cd sub-root          cd worktree

 gqcd                  rcd                  wtcd
```

Three parallel fzf-driven jumps, plus `git wt <branch>` which auto-cds
via the shell-integration `git()` wrapper.

| Tool     | Role                                          | Installed via        |
|----------|-----------------------------------------------|----------------------|
| ghq      | Clone/list remote repos under `~/src`         | nixpkgs              |
| roots    | Find root dirs (monorepo packages) in a tree  | buildGoModule (k1LoW)|
| git-wt   | `git wt` subcommand: create/switch/delete wt  | nixpkgs              |
| fzf      | Fuzzy selector for all of the above           | nixpkgs              |

## Defaults (set by `modules/git.nix`)

```
ghq.root        = ~/src              # ~/src/github.com/owner/repo
wt.basedir      = ../{gitroot}-wt   # worktrees next to repo as <repo>-wt
wt.copyignored  = true              # carry .env etc. into new worktrees
```

Override per repo: `git config wt.basedir .wt` / `git config wt.copyignored false`.

## Shell helpers (fzf-driven, defined in `modules/shell.nix`)

| Command | What it does                                  | Pipeline                        |
|---------|-----------------------------------------------|---------------------------------|
| `gqcd`  | Jump to a ghq-managed repo                    | `ghq list --full-path \| fzf`   |
| `rcd`   | Jump to a sub-root in the current tree        | `roots \| fzf`                  |
| `wtcd`  | Switch worktrees interactively                | `git-wt \| fzf`                 |

> `git wt <branch>` itself auto-cds via the `git()` wrapper from
> `eval "$(git wt --init zsh)"`. Only `git wt` is intercepted; all other
> git commands pass through unchanged.

## git-wt subcommands

```
git wt                       # list all worktrees
git wt <branch|worktree|path># switch (create worktree/branch if needed)
git wt -b <branch> <worktree># create worktree with a different branch name
git wt -d <target>           # delete worktree + branch (safe)
git wt -D <target>           # force delete
git wt -m [<old>] <new>      # rename worktree dir + branch (safe)
git wt -M [<old>] <new>      # force rename
git wt --json                # machine-readable list
```

Target can be a branch name, a worktree dir name (relative to `wt.basedir`),
or a filesystem path. The default branch (main/master) is protected from
accidental delete/rename unless `--allow-delete-default` is passed.

## Daily flow

```bash
# 1. Grab a repo
ghq get https://github.com/owner/repo

# 2. Jump to it
gqcd            # fzf over ghq list, Enter to cd

# 3. Start work on a branch in an isolated worktree (auto-cd)
git wt PROJ-123

# 4. Switch between worktrees
wtcd            # fzf over git-wt list, Enter to cd

# 5. In a monorepo, jump to a package
rcd             # fzf over roots, Enter to cd

# 6. Done with the branch
git wt -d PROJ-123
```

## ghq commands

```
ghq get [-p] <repository>   # clone (use -p for private/SSH)
ghq get -u                  # update all managed repos
ghq list [-p]               # list repos (-p prints full paths)
ghq root                    # print the ghq root directory
ghq look <query>            # cd to a repo (non-fzf, by name match)
```

## roots commands

```
roots                        # list roots in current tree
roots -p 3                   # explore up to 3 parent root dirs
roots -d 5                   # explore sub-roots up to depth 5
roots --root-file go.mod     # treat go.mod as a root marker
roots --fast                  # fast mode
```

Default root markers: `.git/config`, `go.mod`, `package.json`, `Cargo.toml`.

## Useful per-repo git-wt config

```
git config wt.basedir "../{gitroot}-wt"      # alongside repo (default)
git config wt.basedir ".git/wt"             # inside .git (tools ignore it)
git config --add wt.hook "npm install"      # run after creating a worktree
git config wt.copyignored true              # copy .env-style files
git config wt.copyuntracked true            # copy untracked files too
git config wt.nocd create                   # tmux recipe: no cd on create
```

## Tips

- `ghq` clones into `~/src/<host>/<owner>/<repo>`; `roots` then lets you
  hop between package roots inside any of those trees.
- Worktrees live at `<repo>-wt/<branch>` (outside the repo) so linters and
  tools that walk parent dirs do not scan them.
- `wt.copyignored=true` keeps `.env` files usable across worktrees without
  committing them.
- The `git()` wrapper only intercepts `git wt <branch>`; aliases like
  `gst`, `gca` from the oh-my-zsh git plugin still work.
