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

## File Change Reporting Rule

When an agent modifies files, it must present a change summary after all edits are complete and before any commit.

Do NOT show raw diffs in the chat output. The user can review diffs with `git diff` or `git log -p`. The agent's job is to interpret the changes, not to re-display them.

### Output format

1. **File table**: List every modified file with a one-line description of what changed. Use a Markdown table.
2. **Per logical change**: Group related file changes into a logical change section. For each logical change, provide:
   - **Rationale**: Why the change was made — what problem it solves or what feature it adds.
   - **Effect**: What the change does at runtime or build time. Mention any behavior that changes for the user.
   - **Risks**: Trade-offs, potential side effects, or edge cases. If there are no meaningful risks, write "None" and move on.

### Example

```markdown
### Changed files

| File | Change |
|------|--------|
| modules/packages.nix | + typescript package |
| modules/nvim.nix | + vim.g.tsserver_path setting |
| modules/nvim/lua/plugins/nvim-lspconfig.lua | + ts_ls cmd with --tsserver-path |

### Fix: ts_ls unable to find tsserver

Rationale:
  typescript-language-server requires the tsserver binary, but the
  typescript package was not installed.

Effect:
  TypeScript LSP starts without errors. Completion, go-to-definition,
  and hover now work for TS/JS files.

Risks:
  Global tsserver may differ from a project's local TypeScript version.
  IDE features are unaffected; compilation uses the project's own tsc.
```

If a turn makes only trivial changes (formatting, typos), a single-line
rationale per file in the table is sufficient — skip the per-change sections.

## Git Commit and Push Rule

- Do not create commits unless the user explicitly asks for a commit.
- Do not push commits unless the user explicitly asks for a push.
- When creating commits, use Conventional Commits.
- Do not include unrelated changes in a commit.

## Diagram & Explanation Rule

Prefer explanations that maximize user understanding.

When a visual representation would improve clarity, use terminal-friendly diagrams such as:

- ASCII box-drawing diagrams (`+`, `-`, `|`, `<`, `>`, `^`, `v`)
- Trees
- Tables
- Timelines
- Flowcharts
- Dependency graphs

Prefer diagrams over long paragraphs when explaining:

- Architectures
- Workflows
- Data flow
- State transitions
- Component relationships
- Multi-step processes

Provide concrete examples whenever possible.

For technical explanations:

1. Show the high-level picture.
2. Show a visual diagram if useful.
3. Explain the details.
4. Provide a concrete example.
5. Discuss edge cases and trade-offs.

Keep diagrams concise, readable, and terminal-friendly.
Avoid Mermaid unless explicitly requested.
Maximum diagram width: 100 characters.

### Diagram Character Rule

- Use **half-width ASCII characters only** inside diagrams (box-drawing chars, arrows, labels).
- Do NOT mix full-width characters (Japanese, CJK, full-width symbols) into diagram bodies; they break alignment because terminals render them as 2 cells while source editors count them as 1 character.
- Place Japanese or explanatory text **outside** the diagram (in surrounding prose or a separate table) instead of embedding it inside boxes.
- If a label must contain non-ASCII text, keep it in a separate table or code comment below the diagram.

Terminals render full-width characters (e.g. 日本語, 全角) as 2 cells, but half-width characters as 1 cell. Mixing them in the same line causes misalignment that cannot be fixed by padding alone.


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
| Building or sharpening a domain model | `domain-modeling` |
