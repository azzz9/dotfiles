---
name: conversation-to-memory
description: Distill Codex or other coding-agent conversation logs into concise, durable Markdown knowledge memos. Use when asked to analyze past agent sessions, summarize conversation history, preserve decisions or reusable lessons, create/update a knowledge memo, or extract candidate skills and AGENTS.md guidance from logs.
---

# Conversation To Memory

Turn a bounded set of agent conversations into an evidence-backed memo that
helps future work. Preserve decisions and reusable lessons; omit a transcript.

## Choose the source and destination

1. Use logs explicitly provided by the user first. For local Codex history,
   inspect only the relevant files under `~/.codex/sessions/` and existing
   summaries under `~/.codex/memories/`.
2. Establish a bounded scope: a thread ID, date range, task, repository, or
   search terms. Search metadata and user messages before loading whole JSONL
   files. If several plausible threads remain and the distinction changes the
   memo, ask which ones to include.
3. Respect the requested destination. Otherwise, use an existing memory
   directory for personal agent history (`~/.codex/memories/rollout_summaries/`)
   or a repository documentation location only when the user asks for a
   project artifact. Do not modify `AGENTS.md`, skills, or source code merely
   because a memo identifies an improvement.

## Extract durable knowledge

Read the selected conversations chronologically. Separate facts into these
categories:

- **Outcome and decisions**: what was accepted, rejected, or intentionally
  deferred, including the reason when it is evidenced.
- **Reusable knowledge**: stable repository facts, commands, constraints,
  verification methods, and troubleshooting results that reduce future
  rediscovery.
- **Preference signals**: only repeated or explicit user preferences that
  should influence future collaboration.
- **Follow-ups**: unresolved questions, risks, or proposed work. Label them
  as unresolved; never present a proposal as an adopted decision.

Treat tool output and committed files as stronger evidence than agent
reasoning. Cross-check important claims against the current repository when
the memo will be used for ongoing work, and state the source reference for
non-obvious claims.

Never retain credentials, access tokens, private keys, or unrelated personal
details. Redact them if they appear in the source. Do not turn one-off command
output, speculative reasoning, or superseded configuration into durable
knowledge.

## Write the memo

Use this compact structure, omitting empty sections:

```markdown
# <task or topic>

<one-sentence outcome and scope.>

## Decisions

- <decision> — <reason or evidence>

## Reusable knowledge

- <durable fact or workflow>

## Preference signals

- <explicit or repeated preference>

## Follow-ups

- <open item, owner/context if known>

## References

- <session/log path, thread ID, commit, or verified file>
```

Use specific paths, commit IDs, and commands where they make the memo
actionable. Keep a memo short enough to scan; link to the original session
instead of duplicating long discussions. For multiple related sessions, add a
short per-task subsection rather than one chronological transcript.

## Handoff

Report the source scope, output path, and any uncertainty. When the user asks
what should be made durable, propose concrete follow-up artifacts separately:
a repository-specific skill, `AGENTS.md` guidance, an ADR, or no change.
