# tuios workspace

tuios is required. Check `TUIOS_ENV=1` and use `tuios worktree new`. If you are already in a worktree, work there and do not create another.

## create

1. Run `git rev-parse --show-toplevel` for the repo root and note the base branch. Pick a slug of two to four lowercase words. The branch is `pi/<slug>`, and the session name defaults to `<repo>-pi-<slug>` (slashes become hyphens).
2. Run:
   `tuios worktree new pi/<slug> --base <base> --agent pi --detach --prompt "<brief>"`
3. Wait for the command to return. It creates the worktree, starts the detached session and agent, waits until the agent reaches its prompt, and delivers the brief.
4. Stop here. The child owns the work from this point.

Do not pre-create the worktree with `git worktree add` or open an empty shell with `tuios new`; `tuios worktree new --agent pi` handles both atomically. Use `--json` if you need to inspect the created session name or worktree path.

## Brief

The child starts with zero context. The brief is everything it knows, so name the branch or checkout, the task, the done condition, and what to do with uncommitted work. Include the repository rules it should follow when they differ from the defaults.

## Handoff

The dispatcher hands the task over and stops. Do not read the child's result, wait for its turn to finish, or copy it back into this session. The child works in its own checkout, commits there, and answers the user directly. It does not remove its own worktree or session.

Closing the child ends its pi process, and the session does not move into the parent pane. Reopen it later with `pi --continue`.

If the child blocks on `needs_input`, the user answers it in the child session. The dispatcher does not relay the question.

## clean

Removing an active child's worktree fails or leaves the process in a gone directory, and a child pi running `tuios worktree rm` against itself cannot cleanly finish. Wait for the child to settle, then run the cleanup from another pane, never from the child.

1. Run `tuios worktree ls --json` and confirm the target session is `idle` or `done`, not `working` or `needs_input`, and check its `changes` and `merged` fields.
2. Run `tuios worktree rm <session>` (for example `<repo>-pi-<slug>`).

`tuios worktree rm` refuses if the worktree has uncommitted changes or unreferenced commits on a detached HEAD. Do not pass `--force` or `--stash` without asking; report the refusal and stop.

`tuios worktree rm` removes the checkout and kills the session, keeping the branch ref. Delete the branch (`git branch -d pi/<slug>`) only when closing one branch completely and merge proof exists.

For multiple worktrees, audit with `scripts/worktree-audit.sh`, check uncommitted and in-use worktrees, then delete.
