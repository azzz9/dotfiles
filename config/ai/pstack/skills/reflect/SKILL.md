---
name: reflect
description: Spawn three parallel review workers over the active runtime history, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

## When to invoke

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## Process

### 1. Locate the active history

Read the pstack runtime contract from `config/ai/pstack/runtime.md` in this
repository or `~/.agents/pstack/runtime.md` after installation. Use the
current runtime's history location. The parent finds its own history record before fanning out. Use only the
active workspace and never search another runtime's private history.

Do not assume a filename, directory depth, or JSON shape. Inspect the runtime's
session metadata first and read only the matching conversation.

The current runtime may store parent and worker records separately. Preserve
that distinction when matching a conversation.

Use the runtime's history adapter to inspect candidate metadata and identify
the record containing the conversation's opening user prompt. Do not parse a
specific file format or field path in the shared skill. If no record resolves,
write a tight digest of the session and pass that instead.

### 2. Spawn three reviewers in parallel

Use three native worker calls when the runtime supports parallel delegation.
Give each worker the history reference and the review lens. Preserve MCP access
when the review needs external context. If the runtime cannot provide three
workers, run the lenses serially and state that limitation.

| Lens | configured role or parent model | Prompt template |
|---|---|---|
| Judgment | `reflect judgment` from the runtime contract | `references/judgment-reviewer.md` |
| Tooling | `reflect tooling` from the runtime contract | `references/tooling-reviewer.md` |
| Divergent | `reflect divergent` from the runtime contract | `references/divergent-reviewer.md` |
| Synthesizer | `reflect synthesizer` from the runtime contract | `references/synthesizer.md` |

Pass each template verbatim, substituting the runtime history reference or
digest where marked. Reviewers return findings in the worker response.

### 3. Synthesize

Use one native worker for synthesis when available. Give it the full reviewer
outputs and retain access to the sources needed to verify citations. Use
`references/synthesizer.md` with each reviewer's full output inlined where
marked. The synthesizer returns a structured Accepted / Rejected / Backlog
list.

### 4. Structural enforcement check

Sanity-check the synthesizer's Accepted list. For any item that would be enforced more reliably by a lint rule, script, metadata flag, or runtime check, move it from Accepted to Backlog. See the **encode-lessons-in-structure** principle skill.

### 5. Apply

Before applying any Accepted edit, present the synthesizer's full Accepted/Rejected/Backlog output to the user and wait for explicit approval. The user picks which subset to apply and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

Backlog items file to whatever devex / backlog tracker your team uses automatically. Only the Accepted list waits for approval.

For each approved Accepted item, follow the Routing field exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): parent does directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): use the current runtime's skill authoring workflow and run its draft, validation, and iteration loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): revise the description with the current runtime's skill authoring workflow.
- `new skill: <kebab-name>`: use the current runtime's skill authoring workflow. Do not invent a second skill format.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done. Skip this step if it doesn't.

### 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
