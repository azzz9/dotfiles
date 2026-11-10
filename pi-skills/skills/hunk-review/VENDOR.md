# hunk-review vendor record

- Upstream: https://github.com/modem-dev/hunk
- Commit: 3910f11fd8b1c83efce5b35e4335d18252c6321a
- Date: 2026-10-25
- License: MIT. See `LICENSE`.
- Vendored under: `skills/hunk-review/`

## Local changes

- The frontmatter adds `license`, `metadata.upstream`, and `metadata.note` for pi.
- The TUI warning says not to run interactive commands in the agent's own terminal.
- A missing session launches `hunk diff` in a new Herdr pane; without Herdr it asks the user to
  start Hunk.
- The common-errors entry for no active session retries through Herdr first.
- Inline review comments are written in Japanese.
- Omitted: the rest of the upstream repository.
