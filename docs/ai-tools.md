# AI tools

This setup treats `codex` and `gh copilot` as different frontends over the same
project context, not as separate documentation consumers.

## Shell entrypoints

- `cdx`: launch Codex in tmux-friendly mode (`--no-alt-screen`)
- `gcp`: run `gh copilot ...`

## GitHub CLI defaults

`gh` is configured to:

- use `nvim` for PR / issue / comment editing
- prefer editor prompts over inline prompts
- keep aliases for the most common PR and repo flows

Useful aliases:

- `gh prs`: `gh pr status`
- `gh prv`: `gh pr view`
- `gh prw`: `gh pr view --web`
- `gh prc`: `gh pr create --fill`
- `gh pcd`: `gh pr checks`
- `gh rv`: `gh repo view --web`

## Shared project docs

When a repository needs AI-facing documentation, keep it shared:

1. Put project overview and bootstrap commands in `README.md`.
2. Put repo-specific engineering conventions in a single file such as
   `docs/ai-context.md`.
3. Put task-specific notes in issues / PR descriptions instead of creating
   separate Codex-only or Copilot-only docs.

That keeps `codex`, `gh copilot`, and normal human contributors aligned on the
same source of truth.
