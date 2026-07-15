# Source-Assistant Prompt Template

Use this in an upstream AI chat when it can access the ticket, comments, attachments, linked issues, and linked sources better than Codex can.

```markdown
I need to create an implementation brief for a coding agent from this ticket.

Please inspect this ticket thoroughly: ticket body, comments, attachments,
linked issues, and every linked source pasted in the ticket or comments.

CRITICAL RULES:
1. The consumer of this brief is a coding agent that cannot access
   external URLs. The brief MUST be self-contained. Copy all relevant
   content from tickets, comments, attachments, and linked sources
   directly into the brief. Never write "see <URL>" alone.
2. Do not include URLs in the brief. Tag each extract with a short
   source label such as [ticket body], [ticket comment #3], [linked
   spec], [attachment] instead.
3. Write the brief in the same language as the ticket. Technical terms
   (function names, type names, error codes, API paths, etc.) remain
   in their original language.
4. Do not paraphrase technical specifications. Copy exact interface
   definitions, variable names, types, data structures, processing
   steps, API contracts, and error codes verbatim into the brief.
   Summarize prose explanations, but preserve technical details as-is.
5. If two sources contradict each other, include both verbatim and
   mark the contradiction in Section 7. Do not pick one side.

Return a structured implementation brief using the exact headings and
format shown below.

## 1. Ticket Identity
| Field | Value |
|-------|-------|
| Key   | <key or "N/A"> |
| Title | <title> |

## 2. Source Extraction
- Authoritative source: <which source is authoritative if multiple
  overlap, described by name not URL>
- Extracted content:
  <Paste all relevant text, specs, tables, API responses, error
  messages, code snippets, etc. Tag each extract with a short source
  label such as [ticket body], [ticket comment #3], [linked spec],
  [attachment].>

## 3. Requirement Summary
- Current behavior: <1-3 sentences>
- Desired behavior: <1-3 sentences>
- Acceptance criteria:
  1. <criterion>
  2. <criterion>
- Non-goals: <explicit list>

## 4. Implementation Constraints
| Category | Constraint |
|----------|-----------|
| Compatibility | <value or "none identified"> |
| Security/Privacy | <value or "none identified"> |
| Data migration | <value or "none identified"> |
| Rollout/feature flag | <value or "none identified"> |
| Performance | <value or "none identified"> |
| API/UI contract | <value or "none identified"> |

## 5. Affected Components & Data Flow
- Components: <list affected modules, files, functions, tables, or
  services known from the ticket or linked sources>
- Processing flow: <numbered steps describing the internal logic for
  this change, copied from sources verbatim — do not paraphrase
  technical logic. If not described in sources, state so.>
- Data flow: <how data moves through the system for this change,
  or "not described in sources">
- State transitions: <if applicable, describe state changes; otherwise
  "N/A">

## 6. Test Strategy
- Test approach: <unit/integration/e2e/mock requirements>
- Hard-to-test areas: <list areas where testing is difficult and why>
- Existing test coverage for affected area: <if known from sources;
  otherwise "unknown — verify in repository">

## 7. Ambiguities & Decisions Needed
- If none, state "No ambiguities identified."
- Otherwise list each as:
  - <ambiguity>: <why it matters> (decision needed before implementation)
- If sources contradict each other, list each contradiction with both
  sides cited verbatim and marked as [CONTRADICTION]:
  - [CONTRADICTION] <source A says X> vs <source B says Y>
- Do not invent requirements. Mark inferred items as questions.

## 8. Coding-Agent Prompt Draft (optional)
- If sections 1-7 provide enough information for a coding agent, omit
  this section.
- If there are implementation hints that do not fit above, write a
  self-contained draft prompt here. Include what to inspect in the
  repository, the smallest reasonable scope, validation expectations,
  and when the coding agent should stop and ask for clarification.
```

# Conversation Plan and Handoff Template

Use this after the source assistant returns the structured implementation brief. First present the implementation plan in the conversation for human approval, then include a concise handoff summary that makes the final coding-agent prompt reviewable without printing the whole prompt by default. Do not write a plan file unless the human explicitly asks for one.

```markdown
## Implementation Plan

### Objective
<1-2 sentences: what user-visible or system behavior changes>

### Acceptance Criteria
1. <criterion>
2. <criterion>

### Intended Changes
| Target | File / Module | Change |
|--------|-------------|--------|
| <area> | <path>      | <what> |

### Interview Decisions Reflected
- <ambiguity from Step 3>: <adopted decision and how it shapes the plan>
- (if none: "No interview decisions -- 0 ambiguities in Step 3")

### Validation Plan
| Check    | Command | Baseline |
|----------|---------|----------|
| Tests    | <cmd>   | <pass/fail count> |
| Coverage | <cmd>   | <percentage> |
| Lint     | <cmd>   | <warnings count> |
| Build    | <cmd>   | <pass/fail> |

### Risks & Non-goals
- Risks: <list>
- Non-goals: <explicit list>

### Assumptions
- <assumption that would materially change the plan if wrong>

---

Handoff summary for approval:
- Implementation-agent objective:
- Scope and non-goals:
- Key constraints and assumptions:
- Stop-and-ask conditions:
- Validation requirements:

Full final prompt:
Not shown by default. I will hand off a complete prompt matching this approved plan and summary. Ask to see the exact prompt if you want to review the full text before approval.
```

After the human approves, hand off a complete prompt in this shape:

```markdown
You are implementing ticket <TICKET_KEY>: <TITLE>.

Ticket context:
- Key: <key or "N/A">
- Summary: <one-paragraph summary, self-contained — no URLs>
- Sources consulted: <brief list of source labels, e.g. [ticket body],
  [ticket comment #3], [linked spec] — no URLs>
- Current behavior: <what happens now>
- Desired behavior: <what should happen after this change>

Source extraction:
- Authoritative source: <source name, if one is clearly authoritative>
- Extracted content: <all relevant specs, tables, snippets, etc. copied
  here — the coding agent cannot access URLs>
- Ambiguities resolved before implementation: <Step 3 interview decisions>

Acceptance criteria:
- <testable criterion 1>
- <testable criterion 2>

Scope:
- In scope: <specific files, features, flows, or APIs>
- Out of scope: <explicit non-goals>

Important constraints:
- <compatibility, migration, permission, rollout, performance, security, or API contract constraints>

Repository instructions:
- First inspect the relevant code paths before editing.
- Discover and follow existing conventions for:
  - Error handling (try/catch, Result, panic/recover, etc.)
  - Naming (variables, functions, types, files)
  - File organization and module structure
  - Test style (test framework, naming, fixtures, mocking)
  - Logging and debug output
- Prefer the smallest coherent change that satisfies the acceptance criteria.
- Preserve existing patterns unless there is a clear reason to diverge.
- Do not introduce unrelated refactors.
- Follow the existing comment style and language in each file.
- If the ticket is ambiguous or requires a product decision, stop and ask before changing direction.

Implementation notes:
- <known design decision from Step 3 interview>
- <edge case handling>
- <implementation hints from source extraction>

Validation:
- Run the project's test suite. Compare against the baseline (which tests were passing before).
- Run lint/typecheck. New warnings compared to the baseline must be caused by this change.
- Run the formatter in check mode. New violations compared to the baseline must be caused by this change.
- Run the build command. If the baseline already had build failures, only new failures count.
- Verify that tests exist for the new behavior introduced by this change.
- Run `git status --short` and `git diff --stat` to verify that tracked and untracked changes are within scope.
- If a command cannot be run, explain why and what risk remains.

Final response:
- Summarize changed behavior.
- List files changed.
- List validation commands and results.
- Call out unresolved risks or follow-up needed.
```

Please approve this plan before implementation starts.

## Follow-Up Repair Prompt Template

```markdown
Continue work on ticket <TICKET_KEY>: <TITLE>.

Context:
- Original objective: <short objective>
- Existing implementation is already in the working tree or branch.
- Inspect the current diff before editing.

Required blocker fixes from review:
- [Blocker] <concrete issue and expected correction>
- [Blocker] <concrete issue and expected correction>

Optional findings to acknowledge but not block on:
- [Warning] <should fix if time permits, but can be ignored>
- [Info] <informational note, no action required>

Constraints:
- Do not redo unrelated parts of the implementation.
- Do not broaden the scope beyond the review findings.
- Preserve behavior that already satisfies the acceptance criteria.
- If a finding requires product clarification, stop and ask instead of guessing.

Validation:
- Rerun the project's test suite. Compare against the baseline.
- Rerun lint/typecheck and format checks. New issues compared to the baseline must be caused by this fix.
- Rerun the build command.
- Add or adjust tests if the fix changes behavior.
- Run `git status --short` and `git diff --stat` to verify that tracked and untracked changes are within scope.

Final response:
- Explain each fix.
- List validation results.
- Note anything intentionally left unchanged.
```
