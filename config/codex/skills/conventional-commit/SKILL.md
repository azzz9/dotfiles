---
name: conventional-commit
description: Create focused Git commits using Conventional Commits. Use when the user explicitly asks Codex to commit, make a commit, create a git commit, or run a conventional commit workflow; do not use for general code changes unless committing is explicitly requested.
---

# Conventional Commit

## Overview

Create a focused git commit only after the user explicitly asks for one. Inspect the worktree, avoid unrelated changes, and write a Conventional Commit message.

## Workflow

1. Confirm the user explicitly asked to create a commit.
   - Continue only for requests such as "commit", "commitして", "create a commit", or "conventional commit".
   - If the user asks for advice about commits but does not ask to create one, explain or propose a message without running `git commit`.

2. Inspect repository state.
   - Run `git status --short`.
   - Inspect staged changes with `git diff --cached`.
   - Inspect unstaged changes with `git diff`.
   - If untracked files may be relevant, inspect filenames and contents before staging them.

3. Keep the commit focused.
   - Stage only files related to the requested commit.
   - Leave unrelated user changes unstaged.
   - Ask before staging ambiguous files or mixing independent changes.
   - Do not amend, reset, rebase, force-push, clean files, or discard changes unless explicitly requested.

4. Choose a Conventional Commit message.
   - Format: `type(scope): subject`.
   - Allowed common types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `build`.
   - Use `chore` for tooling, dotfiles, configuration, dependencies, or maintenance.
   - Scope is optional; use it when it clarifies the affected area.
   - Keep the subject concise, imperative, and lowercase unless a proper noun is required.

5. Commit.
   - Run `git commit -m "<message>"` after staging the intended changes.
   - If commit fails because hooks or checks fail, report the failure and leave the worktree intact.
   - After committing, run `git status --short` and report the commit hash and any remaining uncommitted changes.

## Examples

- `chore(ai): configure assistant permissions`
- `fix(tmux): restore prefix binding`
- `docs(readme): update setup notes`
