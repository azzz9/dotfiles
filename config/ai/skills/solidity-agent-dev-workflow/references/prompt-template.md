# Source-Assistant Prompt Template

Use this in an upstream AI chat to create a Solidity-focused implementation brief from a ticket.

```markdown
I need to create an implementation prompt for a coding agent that will work primarily on Solidity smart contracts and tests.

Please inspect this ticket thoroughly: ticket body, comments, attachments, linked issues, and every URL or linked source pasted in the ticket or comments.

Return a structured Solidity implementation brief with these sections:

1. Ticket identity
- Ticket key:
- Title:
- Relevant links inspected:

2. Source extraction
- All links and sources inspected:
- Which source appears authoritative, if multiple sources overlap:
- Relevant sections, examples, notes, or linked issue details:
- Any inferred items that are not explicitly stated:

3. Solidity requirement summary
- Current contract behavior:
- Desired contract behavior:
- Affected contracts/interfaces/libraries, if identifiable:
- Affected functions/modifiers/events/errors, if identifiable:
- Caller roles, permissions, ownership, governance, or pausing assumptions:
- Assets/tokens/protocols/oracles involved:
- Acceptance criteria:
- Explicit non-goals:

4. Contract constraints and risks
- Revert conditions and expected errors/messages:
- Events that must be emitted:
- State changes and invariants:
- External calls, callbacks, approvals, or reentrancy concerns:
- Rounding, precision, token decimal, fee, slippage, timestamp, or oracle assumptions:
- Upgradeability, storage layout, initializer, or migration concerns:
- Backward compatibility requirements:

5. Test expectations
- Existing test files or suites likely relevant:
- Required happy-path tests:
- Required revert/permission tests:
- Required boundary/fuzz/property/invariant/fork tests:
- Regression cases from the ticket or linked sources:
- Validation command if known:

6. Ambiguities and decisions needed
- List anything unclear, conflicting, or inferred.
- Do not invent requirements. Mark uncertain items as questions.

7. Coding-agent prompt draft
- Write a self-contained prompt for a coding agent.
- Tell the agent to inspect the relevant contracts and tests before editing.
- Include the smallest reasonable contract/test implementation scope.
- Include Solidity-specific security and invariant constraints.
- Include concrete test expectations.
- Include validation commands or instructions to discover them.
- Include when the coding agent should stop and ask for clarification.
```

# Coding Agent Prompt Template

Use this after the source assistant returns the structured implementation brief. Remove irrelevant sections, but keep the prompt self-contained.

```markdown
You are implementing ticket <TICKET_KEY>: <TITLE>.

Task type:
- Solidity smart contract and test-code change.

Ticket context:
- Link: <URL>
- Summary: <one-paragraph summary>
- Sources inspected by source assistant: <ticket body, comments, attachments, linked issues, URLs, docs, or other linked sources>
- Current contract behavior: <what happens now>
- Desired contract behavior: <what should happen after this change>

Solidity scope:
- Affected contracts/interfaces/libraries: <names or "inspect repository first">
- Affected functions/modifiers/events/errors: <names or "inspect repository first">
- In scope: <specific contract/test behavior>
- Out of scope: <explicit non-goals>

Contract requirements:
- Caller roles and permission rules: <rules>
- State changes and invariants: <rules>
- Revert conditions and errors/messages: <rules>
- Event expectations: <events and values>
- External call / token / oracle / callback assumptions: <assumptions>
- Rounding, precision, decimals, fee, slippage, or timestamp rules: <rules>
- Upgradeability, storage layout, initializer, or migration constraints: <constraints>

Implementation instructions:
- First inspect the relevant contracts, interfaces, libraries, and tests before editing.
- Prefer the smallest coherent contract/test change that satisfies the acceptance criteria.
- Preserve existing contract patterns and security assumptions unless the ticket explicitly changes them.
- Do not introduce unrelated refactors.
- Do not broaden scope into frontend, backend, deployment, or infrastructure unless explicitly required.
- If protocol behavior, permissions, accounting, or security assumptions are ambiguous, stop and ask before editing.

Test requirements:
- Add or update tests for the changed behavior.
- Cover happy path, revert cases, permissions, boundary values, events, and state invariants as applicable.
- Add fuzz/property/invariant/fork tests only when they fit the existing project style or the risk requires them.
- Avoid weak assertions that only prove the implementation ran.

Validation:
- Discover and run the relevant Solidity test command, for example `forge test`, `forge test --match-test <name>`, `forge snapshot`, `npx hardhat test`, or the project-specific equivalent.
- If a validation command cannot be run, explain why and what risk remains.

Final response:
- Summarize contract behavior changed.
- List contract and test files changed.
- List validation commands and results.
- Call out unresolved protocol/security risks or follow-up needed.
```

## Follow-Up Repair Prompt Template

```markdown
Continue work on ticket <TICKET_KEY>: <TITLE>.

Context:
- Original Solidity objective: <short objective>
- Existing implementation is already in the working tree or branch.
- Inspect the current diff before editing.

Required fixes from review:
- [Blocker] <concrete contract/test issue and expected correction>
- [Blocker] <concrete contract/test issue and expected correction>
- [Cleanup] <optional or low-risk cleanup, if the user wants it>

Constraints:
- Do not reimplement unrelated parts of the ticket.
- Do not broaden the scope beyond the review findings.
- Preserve behavior that already satisfies the acceptance criteria.
- Do not introduce unrelated contract refactors.
- If a finding requires protocol/product clarification, stop and ask instead of guessing.

Validation:
- Rerun the relevant Solidity tests.
- Add or adjust tests when the fix changes behavior or covers a missing edge case.

Final response:
- Explain each contract/test fix.
- List validation results.
- Note anything intentionally left unchanged.
```
