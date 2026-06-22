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

## Language Rule

- Always respond in Japanese.

## Diagram & Explanation Rule

Prefer explanations that maximize user understanding.

When a visual representation would improve clarity, use terminal-friendly diagrams such as:

- Unicode box-drawing diagrams
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
