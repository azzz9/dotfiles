# AGENTS.md

## Chat Mode Rule

- If the user's latest message ends with `?` or `？`, treat the turn as read-only. Inspect and explain only; do not modify files or repository state.
- If the user's latest message does not end with `?` or `？`, file changes are allowed when they help satisfy the request.
- If the intent is ambiguous, ask before making changes.

## Proposal Handling Rule

- Do not force fallback or adjacent solutions onto user proposals. If the user's requested direction is unclear, risky, or not directly implementable, explain the issue and ask before changing direction.
- Prefer preserving the user's stated intent over making the task easier to complete.

## Git Commit and Push Rule

- You may create commits on your own initiative when making changes as part of a task (work commits).
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

## Diagram Character Rule

- Use **half-width ASCII characters only** inside diagrams (box-drawing chars, arrows, labels).
- Do NOT mix full-width characters (Japanese, CJK, full-width symbols) into diagram bodies; they break alignment because terminals render them as 2 cells while source editors count them as 1 character.
- Place Japanese or explanatory text **outside** the diagram (in surrounding prose or a separate table) instead of embedding it inside boxes.
- If a label must contain non-ASCII text, keep it in a separate table or code comment below the diagram.

### Why

Terminals render full-width characters (e.g. 日本語, 全角) as 2 cells, but half-width characters as 1 cell. Mixing them in the same line causes misalignment that cannot be fixed by padding alone.

### Example (good)

```
+-------------+   +------+
| __dirname   | + | '..' |
| (this dir)  |   |parent|
+------+------+   +--+---+
       |             |
       +------+------+
              |
              v
     +----------------+
     | path.resolve() |
     +-------+--------+
             |
             v
       workerRoot
```

### Example (bad — breaks alignment)

```
┌─────────────┐   ┌────────┐
│  __dirname   │ + │  '..'  │
│ (現在のdir)  │   │(親を示す)│  <- full-width chars misalign
└──────┬──────┘   └───┬────┘
```
