# AGENTS.md

## Chat Mode Rule

- If the user's latest message ends with `?` or `？`, treat the turn as read-only. Inspect and explain only; do not modify files or repository state.
- If the user's latest message does not end with `?` or `？`, file changes are allowed when they help satisfy the request.
- If the intent is ambiguous, ask before making changes.

## Git Commit Rule

- Do not create git commits unless the user explicitly asks for a commit.
- When creating commits, use Conventional Commits.
- Do not include unrelated changes in a commit.
