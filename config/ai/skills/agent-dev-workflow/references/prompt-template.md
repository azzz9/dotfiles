# Source-Assistant Prompt Template

Use this in an upstream AI chat when it can access the ticket, comments, attachments, linked issues, and linked sources better than Codex can.

```markdown
I need to create an implementation prompt for a coding agent from this ticket.

Please inspect this ticket thoroughly: ticket body, comments, attachments, linked issues, and every URL or linked source pasted in the ticket or comments.

Return a structured implementation brief with these sections:

1. Ticket identity
- Ticket key:
- Title:
- Relevant links inspected:

2. Source extraction
- All links and sources inspected:
- Which source appears authoritative, if multiple sources overlap:
- Relevant sections, comments, examples, notes, or linked issue details:
- Important statuses, flags, constraints, or implementation hints:

3. Requirement summary
- Current behavior:
- Desired behavior:
- User-visible/system behavior that must change:
- Acceptance criteria:
- Explicit non-goals:

4. Implementation constraints
- Compatibility/API/UI contract constraints:
- Permissions/security/privacy concerns:
- Data migration or existing-data behavior:
- Rollout/feature flag concerns:
- Performance or reliability concerns:

5. Ambiguities and decisions needed
- List anything unclear, conflicting, or inferred.
- Do not invent requirements. Mark uncertain items as questions.

6. Coding-agent prompt draft
- Write a self-contained coding-agent prompt.
- Include what to inspect in the repository.
- Include the smallest reasonable implementation scope.
- Include validation expectations.
- Include when the coding agent should stop and ask for clarification.
```

# Coding Agent Prompt Template

Use this after the source assistant returns the structured implementation brief. Remove sections that are irrelevant, but keep the prompt self-contained.

```markdown
You are implementing ticket <TICKET_KEY>: <TITLE>.

Ticket context:
- Link: <URL>
- Summary: <one-paragraph summary>
- Sources inspected: <ticket body, comments, attachments, linked issues, URLs, docs, or other linked sources>
- Current behavior: <what happens now>
- Desired behavior: <what should happen after this change>

Source extraction:
- Authoritative source: <source, if one is clearly authoritative>
- Relevant sections: <sections, comments, examples, notes, links, or issue details>
- Interpretation rules: <how statuses, flags, examples, and notes should be read>
- Ambiguities resolved before implementation: <grill-me decisions>

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
- Prefer the smallest coherent change that satisfies the acceptance criteria.
- Preserve existing patterns unless there is a clear reason to diverge.
- Do not introduce unrelated refactors.
- If the ticket is ambiguous or requires a product decision, stop and ask before changing direction.

Implementation notes:
- <known design decision from grill-me>
- <edge case handling>
- <linked docs or examples>

Validation:
- Run or discover the relevant tests/typecheck/lint for the touched area.
- If a command cannot be run, explain why and what risk remains.
- Add or update tests for the changed behavior when practical.

Final response:
- Summarize changed behavior.
- List files changed.
- List validation commands and results.
- Call out unresolved risks or follow-up needed.
```

## Follow-Up Repair Prompt Template

```markdown
Continue work on ticket <TICKET_KEY>: <TITLE>.

Context:
- Original objective: <short objective>
- Existing implementation is already in the working tree or branch.
- Inspect the current diff before editing.

Required fixes from review:
- [Blocker] <concrete issue and expected correction>
- [Blocker] <concrete issue and expected correction>
- [Cleanup] <optional or low-risk cleanup, if the user wants it>

Constraints:
- Do not redo unrelated parts of the implementation.
- Do not broaden the scope beyond the review findings.
- Preserve behavior that already satisfies the acceptance criteria.
- If a finding requires product clarification, stop and ask instead of guessing.

Validation:
- Rerun the relevant tests/typecheck/lint.
- Add or adjust tests if the fix changes behavior.

Final response:
- Explain each fix.
- List validation results.
- Note anything intentionally left unchanged.
```
