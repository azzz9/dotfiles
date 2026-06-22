---
name: agent-dev-workflow
description: "Orchestrate a source-assistant to coding-agent development workflow: draft prompts for an upstream AI chat that can read tickets, comments, attachments, and linked sources; convert that output into implementation-ready coding-agent prompts; run a grill-me clarification loop; review completed diffs with difit-review; and turn review findings into follow-up prompts. Use when the user creates coding-agent prompts from an issue tracker or other source system, passes them to a coding agent, and iterates with review feedback."
---

# Agent Dev Workflow

Coordinate the user's normal development loop:

1. Create a prompt for the source assistant to inspect the ticket and all pasted/linked sources.
2. Use the source assistant output as the source for a coding-agent implementation prompt.
3. Use `grill-me` / `grilling` to close ambiguity before implementation.
4. After implementation, use `difit-review` to inspect the diff.
5. Convert review findings into a focused follow-up prompt.
6. Repeat until the diff is acceptable.

## Inputs

Prefer concrete source material over assumptions:

- Ticket key, title, or a short description of the work item.
- Source assistant output, if already generated.
- Links or references that the source assistant can access.
- Repository context, target branch, changed files, or intended implementation area.
- Existing agent output, difit comments, failing checks, or reviewer feedback for follow-up loops.

Assume this environment often cannot access the original ticket or its linked sources directly. In that case, produce a source-assistant prompt for the user to run in the source system rather than asking for manual exports first.

## Workflow

### 1. Draft the Source-Assistant Prompt

Create a prompt for the upstream AI chat that can access the ticket and linked sources. The prompt should ask it to inspect the ticket body, comments, attachments, linked issues, and every pasted or linked source visible from the work item.

Ask the source assistant to return structured output:

- Ticket summary and key.
- Linked sources inspected.
- Goal, desired behavior, current behavior, and acceptance criteria.
- Scope and explicit non-goals.
- Constraints, migration risks, compatibility concerns, permissions, API/UI contracts, and rollout notes.
- Ambiguities, conflicting information, and decisions needed before implementation.
- A final coding-agent prompt draft using [prompt-template.md](./references/prompt-template.md).

### 2. Normalize the Source-Assistant Output

Treat source-assistant output as an extracted design draft, not as unquestionable truth.

Extract and restate:

- Goal: what user-visible or system behavior must change.
- Scope: what is in and out.
- Acceptance criteria: testable outcomes.
- Constraints: compatibility, rollout, performance, security, migrations, permissions, API contracts.
- Unknowns: missing decisions, ambiguous language, likely hidden dependencies.

If the ticket mixes multiple independent changes, split them into separate implementation units before writing a prompt.

If source-assistant output is too vague, write a tighter follow-up prompt for the source assistant rather than guessing.

### 3. Produce the Coding-Agent Prompt

Use [prompt-template.md](./references/prompt-template.md) when drafting the prompt.

The prompt must include:

- Ticket summary and link/key.
- Source summary, including the links the source assistant actually inspected.
- Concrete objective.
- Repository exploration instructions.
- Implementation constraints.
- Validation commands to run or discover.
- Required final response format.
- Explicit non-goals.
- A rule to stop and ask before changing direction when assumptions are risky.

Keep the prompt direct enough that a coding agent can execute it without reading the original ticket.

### 4. Grill the Prompt

Invoke or emulate `grill-me` before implementation. Ask one question at a time and prefer questions that prevent costly rework:

- What exactly counts as done?
- Which edge case decides the design?
- What is the intended behavior for existing data or existing users?
- What API/UI contract must remain stable?
- What should not be changed?
- How will this be tested?

For source-assistant-driven tickets, prioritize questions about:

- Which linked source is authoritative if sources conflict.
- Whether examples are exhaustive or illustrative.
- Which linked sources are in scope for this ticket.
- Whether the source assistant inferred anything not explicitly supported by the ticket or linked sources.

After each answer, update the prompt. Do not keep stale assumptions in the final prompt.

### 5. Hand Off to the Coding Agent

When the prompt is ready, output a copy-pasteable block for the coding agent.

Make the handoff self-contained:

- Include the final prompt only, not the intermediate discussion.
- Include unresolved questions only if the coding agent must stop and ask them.
- Preserve links and ticket keys when available.

### 6. Review the Result

After the coding agent produces changes, use `difit-review` on the relevant diff.

Review for:

- Acceptance criteria coverage.
- Behavioral regressions.
- Missing tests or weak validation.
- Overbroad changes outside the ticket scope.
- Unhandled edge cases surfaced during grilling.
- Security, migration, and compatibility risks.

When possible, comment inside difit instead of only summarizing in chat.

### 7. Create the Follow-Up Prompt

Turn review findings into a focused repair prompt. The prompt should:

- Reference the original ticket key or implementation prompt.
- List only concrete required fixes.
- Distinguish blockers from optional cleanup.
- Tell the coding agent to inspect the existing diff before editing.
- Require rerunning relevant validation.
- Forbid unrelated refactors unless the user explicitly asks for them.

Run `grill-me` again if a review finding implies a product or design decision rather than a straightforward code correction.

## Output Modes

Choose the output that matches the user's current stage:

- **Source-assistant prompt**: produce the prompt the user should run in the source system.
- **Source output to coding prompt**: convert source-assistant output into a coding-agent prompt.
- **Prompt grilling**: ask the next highest-value clarification question only.
- **Diff review**: use `difit-review` and report the difit URL or findings.
- **Review to repair prompt**: produce the follow-up coding-agent prompt.
- **Workflow status**: show the current stage, blockers, and next action.

## Guardrails

- Preserve the user's stated implementation direction unless it is impossible or conflicts with the ticket.
- Do not treat source-assistant output as authoritative when it conflicts with explicit ticket or linked-source facts.
- Do not turn vague ticket text or AI summaries into hidden requirements; surface ambiguity.
- Do not commit or push unless the user explicitly asks.
- Do not mix unrelated tickets in the same prompt.
- Keep prompts operational: a coding agent should know what to inspect, what to change, what to test, and when to stop.
