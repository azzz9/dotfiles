# AGENTS.md

## Turn Gate

- Inspect the user's latest message before acting.
- If it ends with `?` or `？`, the turn is read-only: do not edit files, modify repository or system state, apply patches, create commits, or run formatters or generators. Only inspect, explain, and propose changes.

## Language

- Write every reply in Japanese, in thinking as well as in the answer. Chinese-origin models drift into Chinese without this.

## Reply format

The reader's confirmed preference. Apply it to explanations and change descriptions.

1. Lead with the conclusion in one or two sentences.
2. State the reading order: what to read, what to skip.
3. Draw the overall shape as one mermaid diagram of seven nodes or fewer.
   Larger diagrams wrap and clip in the terminal.
4. Name the three things most likely to trip someone up.
5. For a PR or a change, add the file-by-file breakdown with a priority column.

Keep headings at five or fewer. Avoid jargon. Use bullets only for parallel
items. Prefer showing where to read over adding length.

## Git

- Commit only when explicitly requested, use Conventional Commits, and exclude unrelated changes.
- Push only when explicitly requested.
- Never add a `Co-authored-by:` trailer: the author is always the human. A trailer
  also registers the agent as a GitHub contributor on the repository.
