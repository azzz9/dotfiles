---
name: agent-dev
description: "Orchestrate a source-assistant to coding-agent development workflow: draft prompts for an upstream AI chat that can read tickets, comments, attachments, and linked sources; convert that output into implementation-ready coding-agent prompts; investigate the repository to close Material Ambiguity before implementation; review completed diffs with separate agents and hunk-review; and turn review findings into follow-up prompts. Use when the user creates coding-agent prompts from an issue tracker or other source system, passes them to a coding agent, and iterates with review feedback."
---

# Agent Dev Workflow

Coordinate the user's normal development loop:

1. Create a prompt for the source assistant to inspect the ticket and all pasted/linked sources.
2. Use the source assistant output as the source for a coding-agent implementation prompt.
3. Investigate the repository and interview the user to close Material Ambiguity before implementation.
4. Produce the implementation plan and coding-agent prompt.
5. Ask the human to approve the plan before starting implementation.
6. Hand off to a separate implementation agent only after approval.
7. Validate: run tests, lint, format, build, and coverage checks. Fix regressions before review.
8. Review the result with a separate agent, then fix blockers in an automated loop until none remain.
9. Launch Hunk via Herdr for the human's final review of the diff.
10. Commit with Conventional Commits, then ask the human to confirm before pushing.
11. Ask the human to approve PR creation, then poll for review comments and fix until approved (every push requires human permission).

Human involvement is limited to: answering interview questions, approving the plan, and verifying behavior. Everything else (investigation, design, implementation, review, follow-up) is driven by the agent.

## Inputs

Prefer concrete source material over assumptions:

- Ticket key, title, or a short description of the work item.
- Source assistant output, if already generated.
- Links or references that the source assistant can access.
- Repository context, target branch, changed files, or intended implementation area.
- Existing agent output, Hunk comments, failing checks, or reviewer feedback for follow-up loops.

Assume this environment often cannot access the original ticket or its linked sources directly. In that case, produce a source-assistant prompt for the user to run in the source system rather than asking for manual exports first.

The ticket key and title are required at PR creation (Step 11). If the source assistant was used, these come from Section 1 of the brief. If no source assistant was used and the user has not provided a ticket key or title, ask the user before proceeding to PR creation.

## Working Files

Some artifacts are written to `.agent-dev/` to survive context loss during long sessions. Use the ticket key as the file ID (or `YYYYMMDD` if no ticket exists):

| File | Written at | Purpose |
|-----|-----------|---------|
| `.agent-dev/<key>_brief.md` | Step 1 (after source assistant returns) | Preserves the full brief for re-reading if context grows long |
| `.agent-dev/<key>_baseline.md` | Step 3 (after baseline recording) | Preserves test/coverage/lint/build numbers for Step 7 comparison |

Add `.agent-dev/` to `.git/info/exclude` (not `.gitignore` — this keeps the repo clean without committing). If `.git` is read-only (e.g. sandboxed environments), skip this step and avoid staging the directory manually. Do not commit these files.

## Workflow

### 1. Draft the Source-Assistant Prompt

Create a prompt for the upstream AI chat that can access the ticket and linked sources. Ask it to return structured output following the template in [prompt-template.md](./references/prompt-template.md). Save the returned brief to `.agent-dev/<key>_brief.md`.

### 2. Normalize the Source-Assistant Output

Treat source-assistant output as an extracted design draft, not as unquestionable truth. Extract and restate: goal, scope, acceptance criteria, constraints, and unknowns. If the ticket mixes multiple independent changes, split them into separate implementation units. If output is too vague, write a tighter follow-up prompt rather than guessing.

### 3. Investigate and Interview

Investigate the repository directly, run the existing test suite to record a baseline, and cross-reference with source-assistant output. Identify Material Ambiguity and interview the user one question at a time.

**Read [investigate.md](./references/investigate.md) for the full investigation checklist, Material Ambiguity format, and interview question template.**

### 4. Produce the Conversation Plan and Coding-Agent Prompt

Use the **Implementation Plan** template in [prompt-template.md](./references/prompt-template.md) to present the plan. Present a concise handoff summary (objective, scope, constraints, validation requirements). Print the full prompt only when the human asks or the handoff is risky. The prompt must be self-contained: include ticket summary, concrete objective, repository exploration instructions, implementation constraints, validation commands, required response format, explicit non-goals, and a stop-and-ask rule. Do not include discarded alternatives or exploration notes.

### 5. Human Approval Gate

Stop after presenting the plan. Do not spawn an implementation agent, edit files, or begin implementation until the human explicitly approves. If the human asks questions or requests changes, revise first and ask for approval again.

### 6. Hand Off to a Separate Implementation Agent

Spawn a separate agent for implementation to avoid carrying investigation context. Use whichever mechanism is available: `codex exec --ephemeral --sandbox workspace-write -o output.txt "<prompt>"`, Copilot CLI, or a manual copy-paste block. The handoff prompt must be self-contained — include only the final prompt, not intermediate discussion.

### 7-8. Validate, Review, and Fix-and-Reinspect Loop

After implementation, run validation (tests, coverage, lint, format, build, diff scope). Then spawn a separate review agent to classify findings as Blocker, Warning, or Info. If blockers exist, enter the Fix-and-Reinspect Loop (fix → validate → re-review with a separate agent). Loop guard: max 3 iterations.

**Read [review.md](./references/review.md) for the full validation checklist, review agent invocation, and fix-and-reinspect loop details.**

### 9. Final Human Review

Once the agent finds no blockers, launch Hunk for the human to review the diff in the TUI. Add summary comments explaining what was checked and why.

**Read [final-review.md](./references/final-review.md) for Hunk launch commands and comment application details.**

### 10-11. Commit, Push, and Post-PR Review Loop

Commit with Conventional Commits, confirm with human before pushing. Ask for the base branch, create the PR, then poll for review comments and fix in a loop until merge-ready. Every push requires explicit human permission.

**Read [pr-loop.md](./references/pr-loop.md) for PR creation, template, comment polling, and the post-PR fix loop.**

## Output Modes

Choose the output that matches the user's current stage:

- **Source-assistant prompt**: produce the prompt the user should run in the source system.
- **Source output to coding prompt**: convert source-assistant output into a coding-agent prompt.
- **Investigate and interview**: explore the repository and return Material Ambiguity questions.
- **Plan approval**: present the implementation plan and handoff summary, then stop until approved.
- **Validate**: run tests, lint, build, and coverage checks before review.
- **Diff review**: spawn a separate review agent or `hunk-review` (human final review).
- **Review to repair prompt**: produce the follow-up coding-agent prompt.
- **Commit and push**: commit with Conventional Commits, confirm with human, push.
- **Post-PR review loop**: poll PR comments, fix, push, repeat until merge-ready.
- **Workflow status**: show the current stage, blockers, and next action.

## Guardrails

- Preserve the user's stated implementation direction unless it is impossible or conflicts with the ticket.
- Do not treat source-assistant output as authoritative when it conflicts with explicit ticket or linked-source facts.
- Do not turn vague ticket text or AI summaries into hidden requirements; surface ambiguity.
- Do not commit or push unless the user explicitly asks.
- Do not mix unrelated tickets in the same prompt.
- Keep prompts operational: a coding agent should know what to inspect, what to change, what to test, and when to stop.
- Do not push, create PRs, or perform any external GitHub operation without explicit human permission.
