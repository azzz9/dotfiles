---
name: agent-dev-workflow
description: "Orchestrate a source-assistant to coding-agent development workflow: draft prompts for an upstream AI chat that can read tickets, comments, attachments, and linked sources; convert that output into implementation-ready coding-agent prompts; investigate the repository to close Material Ambiguity before implementation; review completed diffs with separate agents and hunk-review; and turn review findings into follow-up prompts. Use when the user creates coding-agent prompts from an issue tracker or other source system, passes them to a coding agent, and iterates with review feedback."
---

# Agent Dev Workflow

Coordinate the user's normal development loop:

1. Create a prompt for the source assistant to inspect the ticket and all pasted/linked sources.
2. Use the source assistant output as the source for a coding-agent implementation prompt.
3. Investigate the repository and interview the user to close Material Ambiguity before implementation.
4. Produce the coding-agent prompt and spawn a separate agent for implementation.
5. Validate: run tests, lint, format, build, and coverage checks. Fix regressions before review.
6. Review the result with a separate agent, then fix blockers in an automated loop until none remain.
7. Launch Hunk via Herdr for the human's final review of the diff.
8. Commit with Conventional Commits, then ask the human to confirm before pushing.
9. Ask the human to approve PR creation, then poll for review comments and fix until approved (every push requires human permission).

Human involvement is limited to: answering interview questions, approving the plan, and verifying behavior. Everything else (investigation, design, implementation, review, follow-up) is driven by the agent.

## Inputs

Prefer concrete source material over assumptions:

- Ticket key, title, or a short description of the work item.
- Source assistant output, if already generated.
- Links or references that the source assistant can access.
- Repository context, target branch, changed files, or intended implementation area.
- Existing agent output, Hunk comments, failing checks, or reviewer feedback for follow-up loops.

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

### 3. Investigate and Interview

Investigate the repository directly to complement the source-assistant output (or to work without it when no ticket exists). The source assistant covers the ticket's outside (body, comments, links); this step covers the repository's inside (code, docs, tests, past plans).

Explore the codebase:

- Existing configuration and code paths related to the ticket.
- Relevant tests and their current expectations.
- Docs, README sections, and past plan files.
- Any patterns or conventions the implementation must follow.

Run the existing test suite and record the baseline:
- Which tests are currently failing (if any).
- Coverage percentage (if available).
- Lint/typecheck warnings or errors (if any pre-existing).
- Format violations (if any pre-existing).
- Build status (does it currently build successfully?).

This baseline is used in Step 6 to distinguish pre-existing issues from regressions caused by the implementation.

Cross-reference with source-assistant output:

- Detect contradictions between the ticket description and repository reality.
- Add details the source assistant could not see (e.g., directories, files, or conventions that exist in the repo but not in the ticket).
- Mark anything the source assistant inferred that is not supported by the repository.

Identify Material Ambiguity -- uncertainty that could change one of:

- Implementation direction.
- Verification approach.
- Rollout strategy.
- Data handling.
- Permissions or security.
- User-visible behavior.

Only these qualify as interview questions. Do not ask about things that are essentially decided or that do not affect the implementation direction.

Return questions one at a time in this format:

```text
Q1. <question>

Current as-is:
<what the code or repo currently does>

This resolves:
<which ambiguity this question addresses>

Why user choice is needed:
<why this requires a human decision rather than being discoverable from the repository>

How this changes the plan:
<what implementation impact the answer has — which files, tests, or rollout paths differ>

A) <option>
<what this means for implementation>

B) <option>
<what this means for implementation>

C) <option>
<what this means for implementation>

Recommendation:
<recommended option and rationale>

Please choose A, B, or C.
```

Rules:
- Each option must be genuinely selectable, not a placeholder that will never be chosen.
- Maximum 3 options per question.
- Do not ask questions whose answer can be discovered from the repository.

If no ticket exists and no source assistant was used, start directly from this step.

### 4. Produce the Coding-Agent Prompt

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

The implementation prompt must be isolated from investigation noise. Include only the adopted plan, change targets, completion criteria, and required tests. Do not include:

- Discarded design alternatives or rejected approaches.
- Files examined during investigation that are not part of the change.
- Intermediate reasoning or exploration notes from Step 3.

Rationale: carrying investigation context into implementation causes the coding agent to drag in unnecessary assumptions and stale ideas that were explicitly rejected.

### 5. Hand Off to a Separate Implementation Agent

Spawn a separate agent for implementation to avoid carrying investigation context (discarded ideas, rejected approaches, exploration notes) into the build phase.

Use whichever mechanism is available in your environment:

- **Codex**: `codex exec --ephemeral --sandbox workspace-write -o output.txt "<implementation prompt>"`
- **Copilot CLI**: `copilot -p "<implementation prompt>" -s --allow-tool='write, shell' --no-ask-user`
- **Manual**: output a copy-pasteable block for the user to paste into a fresh agent session.

The handoff prompt must be self-contained:

- Include the final prompt only, not the intermediate discussion.
- Include unresolved questions only if the coding agent must stop and ask them.
- Preserve links and ticket keys when available.

### 6. Validate

After the implementation agent completes, run validation before sending the diff to a review agent. The Main Agent runs these checks:

- **Tests**: run the project's test suite. Any test that was passing in the Step 3 baseline but now fails is a regression.
- **Coverage**: compare against the Step 3 baseline. Must not decrease. If coverage tools are unavailable, skip silently.
- **New tests**: verify that tests exist for the new behavior introduced by this change. If no tests were added, flag this as a finding for the review agent.
- **Lint / typecheck**: run the project's linter and type checker. New warnings compared to the Step 3 baseline must be caused by the implementation.
- **Format**: run the project's formatter in check mode. New violations compared to the Step 3 baseline must be caused by the implementation. If no formatter is configured, skip silently.
- **Build**: run the project's build command. If the Step 3 baseline already had build failures, only new failures count.
- **Diff scope**: verify with `git diff --stat` that changes are within the intended scope.

If any check fails, re-enter the Fix-and-Reinspect Loop with the failure output as the fix prompt. Do not proceed to review until all checks pass.

### 7. Review with a Separate Agent

Spawn a separate agent for review to avoid confirmation bias. The review agent must not carry the investigation or implementation context.

Use whichever mechanism is available in your environment:

- **Codex**: `codex exec review --uncommitted --ephemeral -o review.txt "Focus on acceptance criteria coverage and behavioral regressions"`
- **Copilot CLI**: `copilot -p '/review the changes on this branch. Focus on bugs and security issues.' -s --allow-tool='shell(git:*)' --no-ask-user`
- **Manual**: output a review prompt for the user to paste into a fresh agent session.

The review agent should classify findings as:

- **Blocker**: must be fixed before proceeding (bugs, security, regressions, scope violations, missing tests for critical behavior).
- **Warning**: should be fixed if time permits, but can be ignored (style, minor naming, optional improvements).
- **Info**: informational notes, no action required.

If no blockers are found, proceed to Final Human Review. The human can decide whether to address warnings or info.

### Fix-and-Reinspect Loop

Turn review findings into a focused repair prompt. The prompt should:

- Reference the original ticket key or implementation prompt.
- List only concrete required fixes.
- Distinguish blockers from optional cleanup.
- Tell the coding agent to inspect the existing diff before editing.
- Require rerunning relevant validation.
- Forbid unrelated refactors unless the user explicitly asks for them.

Execute the fix by spawning a new implementation agent (same mechanism as Step 5). Do not fix in the Main Agent context -- it carries investigation bias. The fix prompt is self-contained and includes the current diff context, so the implementation agent does not need prior session history.

After the fix, re-review with a separate review agent (same mechanism as Step 7). Do not fall back to `git diff` in the Main Agent -- every iteration must use a separate review agent to maintain context separation.

The fix loop only addresses blockers. Warnings and info findings are acknowledged but do not block progression. When no blockers remain, proceed to Final Human Review.

Loop guard: if the fix-and-reinspect loop runs more than 3 iterations without converging on blockers, stop and escalate to the human with a summary of persistent findings. Do not loop indefinitely.

Only stop for human input before the guard limit when a blocker requires a product or design decision rather than a straightforward code correction.

### Final Human Review

Once the agent finds no blockers, launch Hunk for the human to review the diff in the TUI:

```bash
herdr status                                       # verify Herdr is available
herdr pane split --current --direction right --cwd . --focus
herdr pane run <pane_id> "hunk diff"
```

If Herdr is not running, ask the user to launch `hunk diff` in their terminal.

After the Hunk session is live, add summary comments explaining what was checked and why, so the human can verify efficiently:

```bash
hunk session comment apply --repo . --stdin   # batch-add review notes
```

If the human finds issues:

1. Apply the fixes.
2. Re-enter the Fix-and-Reinspect Loop (fix → validate → separate review agent).
3. Ask for human review again when the agent finds no blockers.

The human may also choose to address warnings or info findings at this stage.

### 8. Commit and Push

Once the human approves the diff, commit the changes using Conventional Commits:

```bash
git add <relevant files>
git commit -m "type(scope): subject"   # see conventional-commit skill
```

Use the `conventional-commit` skill for message format and staging rules. Do not push without explicit human confirmation.

After the human confirms, push:

```bash
git push
```

### 9. Post-PR Review Loop

Ask the human for permission before creating the PR:

```bash
gh pr create --title "<conventional commit subject>" --body "<description>"
```

Then poll for review comments:

```bash
gh pr view --comments                              # check PR comments
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments   # inline review comments
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews   # review summaries
```

If actionable comments exist:

1. Create a follow-up fix prompt (same structure as the Fix-and-Reinspect Loop). Run validation (Step 6) after each fix.
2. Execute the fix by spawning a new implementation agent (same mechanism as Step 5).
3. Re-review with a separate review agent (same mechanism as Step 7).
4. Commit with Conventional Commits and capture the commit hash.
5. Reply to each addressed review comment via the GitHub API:

   ```bash
   gh api --method POST repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
     -f body="Addressed in commit <hash>: <how this comment was resolved>"
   ```
6. Ask the human for permission to push, then push.
7. Re-poll for comments.

Continue until no actionable comments remain. The human does not participate in the fix-and-reinspect part of this loop, but every push requires explicit human permission.

When no comments remain, notify the human that the PR is merge-ready.

## Output Modes

Choose the output that matches the user's current stage:

- **Source-assistant prompt**: produce the prompt the user should run in the source system.
- **Source output to coding prompt**: convert source-assistant output into a coding-agent prompt.
- **Investigate and interview**: explore the repository and return Material Ambiguity questions.
- **Validate**: run tests, lint, build, and coverage checks before review.
- **Diff review**: spawn a separate review agent (Codex: `codex exec review`, Copilot: `/review`) or `hunk-review` (human final review).
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
