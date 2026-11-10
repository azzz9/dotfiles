---
name: workspace
description: "Create and close worktrees and Herdr workspaces. Isolate editing work, dispatch an independent task, and clean up worktrees. One task per worktree. If you are already in a worktree, do not create another."
---

# Workspace

## Contract

- Work that edits files starts in a linked worktree. Do not edit in the main repo. Herdr is required. Check `HERDR_ENV=1` and run `herdr worktree create --cwd <repo root> --branch pi/<slug>`. Stop if you are outside Herdr. Read-only work stays put.
- A worktree is not only for large tasks. It isolates editing work from the main repo.
- If you are already in a worktree, work there. Do not create another. Run `create` only from the main repo. The first checkout in `git worktree list` is the main repo; a different path means you are in a worktree.
- **Separate Before Serializing Shared State.** One task per worktree. Do not put concurrent writers in the same cwd.
- **Make Operations Idempotent.** `create` and `clean` must be safe to rerun.
- Dispatch is not `subagent()`. It is a separate pi session, and the child owns its checkout. The dispatcher does not edit and does not read the result back. Dispatch only independent tasks; do not create a child worktree of the current worktree.
- Cleaning is irreversible. Use only paths from `git worktree list`. Pause on `wip:N` and in-use worktrees. Proceed on clean, merged, and not-in-use.
- Keep branch refs. Delete a branch only when `wt-clean` closes one branch completely and merge proof exists.
- Do not pass `--force` to `create` or `clean`. Stop on uncommitted changes or in-use worktrees.
- Close the Herdr workspace and panes.

## Modes

Choose one at a time. `create` and `clean` are separate operations.

- **create** (no subagent; Herdr + child pi): create a worktree from the main repo and hand an independent task to the child. Follow `references/herdr-workspace.md`. If you are already in a worktree, work there.
- **clean** (no subagent; Herdr): wait until the child is `idle` or `done`, not `working` or `blocked`. The child must not run `wt-clean` itself: its own working state blocks the clean. Run `wt-clean pi/<slug> --repo <repo root>` from another pane. To keep the branch ref, use `git worktree remove` and do not delete the branch. For several, list candidates with `scripts/worktree-audit.sh`, check uncommitted and in-use worktrees, then delete.

## Stop

- Do not delete uncommitted changes, pinned chats, or in-use worktrees. Ask the user.
