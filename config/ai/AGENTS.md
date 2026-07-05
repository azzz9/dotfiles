# AGENTS.md

## Read-only Gate

Before doing anything else, inspect the user's latest message.

If it ends with `?` or `？`, this turn is read-only.

In a read-only turn:

- Do not edit files.
- Do not run commands that modify repository or system state.
- Do not apply patches.
- Do not create commits.
- Do not run formatters or generators.
- Only inspect, explain, and propose changes.

This rule overrides any action-oriented wording in the same message.
For example, "apply this?" is still read-only.

If the user's latest message does not end with `?` or `？`, file changes are allowed when they help satisfy the request.
If the intent is ambiguous, ask before making changes.

## Proposal Handling Rule

- Do not force fallback or adjacent solutions onto user proposals. If the user's requested direction is unclear, risky, or not directly implementable, explain the issue and ask before changing direction.
- Prefer preserving the user's stated intent over making the task easier to complete.

## Language Rule

- Always respond in Japanese.

## On-demand Rules

The following rule files are **read only when the situation applies** — not at startup.

Each rule is installed as an identical symlinked copy in two locations:

- Copilot CLI → `~/.copilot/rules/<name>.md`
- Codex       → `~/.codex/rules/<name>.md`

Both copies resolve to the same source file, so their contents are identical. Read the one for the tool you are running in; if unsure, read whichever path exists.

| Situation | Rule file (`<name>.md`) |
|-----------|-------------------------|
| You are about to edit files or have finished editing | `file-change-reporting` |
| You are about to create a git commit or push | `git-commit-push` |
| You are about to create a diagram or visual explanation | `diagrams` |
