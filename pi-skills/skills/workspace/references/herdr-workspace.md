# Herdr workspace

Herdr is required. Check `HERDR_ENV=1` and use `herdr worktree create`. If you are already in a worktree, work there and do not create another.

## create

1. Run `git rev-parse --show-toplevel` for the repo root. Pick a slug of two to four lowercase words. The branch is `pi/<slug>`, and the same slug names the child agent, which must match `[a-z][a-z0-9_-]{0,31}` and be unique among live agents.
2. `herdr worktree create --cwd <repo root> --branch pi/<slug> --no-focus`
3. Read from the JSON:
   - `.result.root_pane.pane_id` is the shell the child goes into.
   - `.result.workspace.workspace_id` identifies the workspace to close later.
   - `.result.worktree.path` is the checkout the child works in.
4. `herdr agent start <slug> --kind pi --pane <pane>`
5. `herdr agent prompt <slug> "<brief>"`
   The prompt returns once the text and Enter are written. Do not wait for the child's turn.
6. Stop here. The child owns the work from this point.

The layout plugin creates tabs asynchronously. If `agent_pane_busy` appears, wait briefly and retry once.

## Brief

The child starts with zero context. The brief is everything it knows, so name the checkout path, the task, the done condition, and what to do with uncommitted work. Include the repository rules it should follow when they differ from the defaults.

## Handoff

The dispatcher hands the task over and stops. Do not read the child's result, wait for its turn to finish, or copy it back into this session. The child works in its own checkout, commits there, and answers the user directly. It does not close its own workspace.

Closing the child ends its pi process, and the session does not move into the parent pane. Reopen it later with `pi --continue`.

If the child blocks, the user answers it in the child pane. The dispatcher does not relay the question.

## clean

`wt-clean` refuses while the child is working or blocked, and a child pi running the command is always working. Wait for the child to settle, then run it from another pane, never from the child.

1. `herdr agent get <slug>` shows `idle` or `done`, not `working` or `blocked`.
2. `wt-clean pi/<slug> --repo <repo root>`

Close the checkout, workspace, and branch. If the branch is not merged, exit 1. Do not pass `--force`. Report the refusal and stop. To keep the branch ref, use `git worktree remove` and do not delete the branch.

For multiple worktrees, audit with `../scripts/worktree-audit.sh`, check uncommitted and in-use worktrees, then delete.
