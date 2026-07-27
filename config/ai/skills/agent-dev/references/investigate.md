# Step 3: Delegate Investigation and Interview

Delegate repository investigation to a fresh Copilot agent to complement the source-assistant output (or to work without it when no ticket exists). The source assistant covers the ticket's outside (body, comments, links); the investigation agent covers the repository's inside (code, docs, tests, past plans).

Run the investigation agent non-interactively with a self-contained prompt and Claude Opus 4.8:

```bash
copilot -p "<investigation prompt>" -s --no-ask-user --model claude-opus-4.8
```

The prompt must include the ticket summary or brief, repository root, investigation categories below, baseline commands to discover and run, required response structure, and these constraints:

- Read and run diagnostics only; do not edit project files or apply fixes.
- Distinguish observed repository facts from inference.
- Cite file paths, symbols, and command results for every material conclusion.
- Surface contradictions and ambiguity; do not choose product or implementation policy.
- Return the complete Material Ambiguity Checklist and baseline results.

Save the complete response to `.agent-dev/<key>_investigation.md`. The main agent must verify material citations and command results before relying on them. Save the verified baseline separately to `.agent-dev/<key>_baseline.md`. Do not reuse this agent for implementation.

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

This baseline is used in Step 7 to distinguish pre-existing issues from regressions caused by the implementation. Save it to `.agent-dev/<key>_baseline.md` (see Working Files above).

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

**Prohibition on guessing**: When the ticket and linked sources do not provide enough information to determine an implementation detail, do not fill the gap with assumptions. Surface the gap as a Material Ambiguity question to the user instead. The same applies when the source-assistant brief contradicts repository reality -- the contradiction must be resolved by the user, not silently resolved by the agent.

The investigation agent completes the Material Ambiguity Checklist after investigating each category:

```text
Material Ambiguity Checklist:
- [ ] Implementation direction: <"found (Q<n>)" or "clear: <1-line reason>">
- [ ] Verification approach: <"found (Q<n>)" or "clear: <1-line reason>">
- [ ] Rollout strategy: <"found (Q<n>)" or "clear: <1-line reason>">
- [ ] Data handling: <"found (Q<n>)" or "clear: <1-line reason>">
- [ ] Permissions/security: <"found (Q<n>)" or "clear: <1-line reason>">
- [ ] User-visible behavior: <"found (Q<n>)" or "clear: <1-line reason>">

Interview status: <N> questions asked.
  or
Interview status: 0 ambiguities found (checklist verified).
```

After verifying the investigation response, the main agent returns ambiguities to the user one at a time in this format:

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
- When the checklist shows 0 ambiguities, each "clear" entry must include a 1-line reason explaining what was checked and why no ambiguity remains. Bare "clear" without a reason is not acceptable.

The checklist and interview status are a hard gate: Step 4 must not begin until the checklist is printed and all questions (if any) are answered by the user.

If no ticket exists and no source assistant was used, start directly from this step.
