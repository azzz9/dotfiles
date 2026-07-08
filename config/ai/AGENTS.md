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

## Sandbox Awareness

When running inside Codex sandbox:

- `.git` is **read-only**. Commits require `sandbox_permissions="require_escalated"`.
- Network is **available** (`network_access = true` in codex config). `nix build` can download packages.
- `~/.cache/nix` is **read-only**. Prefix nix commands with `XDG_CACHE_HOME=/tmp/nix-cache` to use a writable cache.
- tmux sockets are **inaccessible**. Cannot verify the tmux skill (send-keys control) at runtime.

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

## On-demand Skills

The following skills are installed as symlinked copies in two locations:

- Copilot CLI → `~/.copilot/skills/<name>/SKILL.md`
- Codex       → `~/.codex/skills/<name>/SKILL.md`

Read the skill when the situation applies — not at startup.

| Situation | Skill (`<name>`) |
|-----------|------------------|
| Working inside `~/src/github.com/azzz9/dotfiles` specifically | `dotfiles-context` |
| Editing `.nix` files or running `nix` / `home-manager` commands | `nix-home-manager` |
| Creating Conventional Commits | `conventional-commit` |
| Reviewing a diff with difit | `difit-review` |
| Reviewing diffs interactively with a live Hunk session | `hunk-review` |
| Stress-testing a plan or design before building | `grill-me` / `grilling` / `grill-with-docs` |
| Turning a ticket into a coding-agent prompt | `agent-dev-workflow` |
| Solidity-specific agent dev workflow | `solidity-agent-dev-workflow` |
| Remote-controlling tmux sessions for interactive CLIs | `tmux` |
| Creating ASCII art or text-based diagrams | `ascii-art-diagrams` |
| Building or sharpening a domain model | `domain-modeling` |
