---
name: conversation-to-memory
description: Distill Codex or other coding-agent conversation logs into clear, durable Markdown knowledge notes for beginners. Use when asked to analyze past agent sessions, turn a discussion into an explanatory memo, preserve decisions or reusable lessons, create/update a knowledge note, or extract candidate skills and AGENTS.md guidance from logs.
---

# Conversation To Memory

Turn a bounded set of agent conversations into an evidence-backed knowledge
note that explains the subject to a reader who did not attend the discussion.
Preserve decisions and reusable lessons; omit the transcript.

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

Read the selected conversations chronologically. Identify the teaching thread:
the reader's natural question, the mechanism that answers it, the tempting
but incomplete alternative, and a concrete example that makes the trade-off
visible. Then separate durable facts into these categories:

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
the note will be used for ongoing work. Distinguish verified facts, design
decisions, and inferences; do not flatten them into equally certain claims.

Never retain credentials, access tokens, private keys, or unrelated personal
details. Redact them if they appear in the source. Do not turn one-off command
output, speculative reasoning, or superseded configuration into durable
knowledge.

## Write an explanatory knowledge note

Write in the user's language. Prefer a self-contained tutorial over a terse
meeting record. Use descriptive numbered headings, short subsections, small
examples, comparison tables, and compact ASCII diagrams where they materially
clarify a relationship. Define jargon on first use.

Start with the reader's intuitive question, then explain the mechanism, its
consequences, and the trade-off. Include a rejected or incomplete alternative
when it prevents a likely misunderstanding. Use precise caveats for
engine-specific or version-specific behavior rather than presenting it as a
universal rule.

Use this structure, adapting section names to the topic and omitting only
sections that have no evidence:

```markdown
# <topic>

## 0. このノートの目的

<対象読者、扱う範囲、結論の輪郭を1-3文で示す。>

---

## 1. <最初の直感的な疑問または核心>

### 1.1 <なぜそう考えたくなるか>

<読者が抱く自然な疑問を示す。>

### 1.2 <何が起きるか>

<具体例、コード、または小さな図で仕組みを示す。>

### 1.3 <設計上の意味>

<なぜその仕組みや判断が必要かを因果で説明する。>

> **教訓**: <この節で持ち帰るべき一文>

---

## 2. <代替案または比較>

| 観点 | 方式A | 方式B |
| --- | --- | --- |
| <比較軸> | <内容> | <内容> |

<選択基準、適用条件、例外を説明する。>

---

## 3. まとめ

| 概念 | 要点 |
| --- | --- |
| <概念> | <持ち帰る内容> |

### 根本的な心構え

- **<原則>**: <理由と実務上の意味>

## References

- <会話ログ、thread ID、コミット、検証済み資料>
```

Use specific paths, commit IDs, commands, and external documentation only
when they make the explanation auditable or actionable. Keep the note focused:
link to the original session instead of duplicating long discussions. For
multiple related sessions, synthesize one coherent explanation rather than a
chronological transcript.

## Handoff

Report the source scope, output path, and any uncertainty. When the user asks
what should be made durable, propose concrete follow-up artifacts separately:
a repository-specific skill, `AGENTS.md` guidance, an ADR, or no change.
