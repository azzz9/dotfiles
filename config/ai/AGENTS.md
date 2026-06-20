# AGENTS.md

## Chat Mode Rule

- If the user's latest message ends with `?` or `？`, treat the turn as read-only. Inspect and explain only; do not modify files or repository state.
- If the user's latest message does not end with `?` or `？`, file changes are allowed when they help satisfy the request.
- If the intent is ambiguous, ask before making changes.

## Proposal Handling Rule

- Do not force fallback or adjacent solutions onto user proposals. If the user's requested direction is unclear, risky, or not directly implementable, explain the issue and ask before changing direction.
- Prefer preserving the user's stated intent over making the task easier to complete.

## Git Commit and Push Rule

- Never create commits or push changes proactively or on your own initiative.
- Do not create git commits unless the user explicitly asks for a commit.
- Do not push commits unless the user explicitly asks for a push.
- When creating commits, use Conventional Commits.
- Do not include unrelated changes in a commit.
