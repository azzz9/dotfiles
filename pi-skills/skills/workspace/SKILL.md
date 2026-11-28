---
name: workspace
description: "Create and close worktrees and tuios sessions. Isolate editing work, dispatch an independent task, and clean up worktrees. One task per worktree. If you are already in a worktree, do not create another."
---

# Workspace

## Contract

- Work that edits files starts in a linked worktree. Do not edit in the main repo. tuios is required. Check `TUIOS_ENV=1` and run `tuios worktree new pi/<slug> --base <base> --agent pi --detach --prompt "<brief>"`. Stop if you are outside tuios. Read-only work stays put.
- A worktree is not only for large tasks. It isolates editing work from the main repo.
- If you are already in a worktree, work there. Do not create another. Run `create` only from the main repo. The first checkout in `git worktree list` is the main repo; a different path means you are in a worktree.
- **Separate Before Serializing Shared State.** One task per worktree. Do not put concurrent writers in the same cwd.
- **Make Operations Idempotent.** `create` and `clean` must be safe to rerun.
- Dispatch is not `subagent()`. It is a separate pi session, and the child owns its checkout. The dispatcher does not edit and does not read the result back. Dispatch only independent tasks; do not create a child worktree of the current worktree.
- Cleaning is irreversible. Use only paths from `git worktree list` and sessions from `tuios worktree ls`. Pause on `wip:N` and in-use worktrees. Proceed on clean, merged, and not-in-use.
- Keep branch refs. Delete a branch only when closing one branch completely after removing its worktree and merge proof exists.
- Do not pass `--force` or `--stash` to `create` or `clean` without user confirmation. Stop on uncommitted changes or in-use worktrees.
- Close the tuios worktree session and its panes with `tuios worktree rm`.

## Modes

Choose one at a time. `create` and `clean` are separate operations.

- **create** (no subagent; tuios + child pi): create a worktree from the main repo and hand an independent task to the child. Follow `references/tuios-workspace.md`. If you are already in a worktree, work there.
- **clean** (no subagent; tuios): wait until the child is `idle` or `done`, not `working` or `needs_input`. The child must not run `tuios worktree rm` on itself. Run `tuios worktree rm <session>` from another pane, and run `git branch -d pi/<slug>` only when closing a merged branch completely. To keep the branch ref, omit branch deletion. For several, list candidates with `scripts/worktree-audit.sh`, check uncommitted and in-use worktrees, then delete.

## Stop

- Do not delete uncommitted changes, pinned chats, or in-use worktrees. Ask the user.
