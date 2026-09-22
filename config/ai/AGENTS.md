# AGENTS.md

## Turn Gate

- Inspect the user's latest message before acting.
- If it ends with `?` or `？`, the turn is read-only: do not edit files, modify repository or system state, apply patches, create commits, or run formatters or generators. Only inspect, explain, and propose changes.

## Answering Questions

- Before answering a question, load the installed `show-me` skill from the active skills directory (for example, `~/.agents/skills/show-me/SKILL.md`); reuse it if it is already loaded.
- Loading or using show-me alone is read-only and does not authorize creating or changing files.

## Git

- Commit only when explicitly requested, use Conventional Commits, and exclude unrelated changes.
- Push only when explicitly requested.
