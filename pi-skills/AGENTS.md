# AGENTS.md

## Turn Gate

- Inspect the user's latest message before acting.
- If it ends with `?` or `？`, the turn is read-only: do not edit files, modify repository or system state, apply patches, create commits, or run formatters or generators. Only inspect, explain, and propose changes.

## Language

- Write every reply in Japanese, in thinking as well as in the answer. Chinese-origin models drift into Chinese without this.

## Git

- These rules are the only source of commit and push permission. A skill describes procedure, not permission.
- Commit automatically when the task is done. Use Conventional Commits.
- Split changes into one commit per intent. Do not bundle unrelated changes.
- Push only when explicitly requested.
- Never add a `Co-authored-by:` trailer: the author is always the human. A trailer
  also registers the agent as a GitHub contributor on the repository.
