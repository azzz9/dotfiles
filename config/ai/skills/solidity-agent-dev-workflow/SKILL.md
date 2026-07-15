---
name: solidity-agent-dev-workflow
description: Specialize the source-assistant to coding-agent workflow for Solidity smart contract and test-code development. Use when the user wants an upstream AI chat to read a ticket and all linked sources, produce a coding-agent prompt for Solidity contracts, Foundry/Hardhat-style tests, security-sensitive contract changes, or follow-up fixes from difit-review comments.
---

# Solidity Agent Dev Workflow

Inherit the overall flow from `agent-dev`, but specialize every prompt, grill question, and review pass for Solidity contract and test development.

Normal loop:

1. Create a source-assistant prompt that asks the upstream AI chat to read the ticket, comments, attachments, linked issues, and every pasted/linked source.
2. Convert source-assistant output into a Solidity-focused coding-agent prompt.
3. Use `grill-me` / `grilling` to close ambiguity before implementation.
4. Run the coding agent on contract and test changes.
5. Use `difit-review` on the diff.
6. Convert review findings into a Solidity-focused repair prompt.

## Scope

Assume the implementation target is Solidity contracts and tests unless the user says otherwise.

Prioritize:

- Contract behavior, invariants, access control, state transitions, events, errors, and external calls.
- Tests for happy paths, reverts, boundary values, role checks, fuzz/property cases, and regression coverage.
- Minimal changes to production contracts and test files.
- Security-sensitive reasoning over generic application development advice.

Avoid:

- Frontend, backend, infra, indexing, deployment, or UI changes unless the ticket explicitly requires them.
- Broad refactors that are not required to satisfy the ticket.
- Inventing protocol behavior that is not supported by the ticket or linked sources.

## Source-Assistant Stage

Use [prompt-template.md](./references/prompt-template.md) to ask the source assistant to produce a structured Solidity implementation brief.

The source-assistant prompt must ask the upstream AI chat to:

- Read all ticket text, comments, attachments, linked issues, and every pasted/linked source.
- Extract only facts relevant to Solidity contract behavior and test expectations.
- Identify affected contracts, interfaces, libraries, tests, roles, states, events, errors, assets, tokens, and external protocols when mentioned.
- Mark inferred or ambiguous requirements as questions.
- Produce a coding-agent prompt draft that is self-contained.

## Normalize Source-Assistant Output

Treat source-assistant output as a draft, not as ground truth.

Check for:

- Missing contract names or affected test suites.
- Unclear caller roles, permissions, ownership, pausing, upgradeability, or governance assumptions.
- Unclear asset/token decimal assumptions, rounding, precision, fees, slippage, or oracle behavior.
- Unclear revert conditions, custom errors, event expectations, and state-transition ordering.
- Missing security assumptions around reentrancy, callbacks, external calls, approvals, delegatecall, or upgrade storage layout.
- Missing validation command, test framework, fork requirements, or environment variables.

If source-assistant output is too generic, produce a tighter follow-up prompt for the source assistant rather than guessing.

## Produce the Coding-Agent Prompt

The final coding-agent prompt must include:

- Ticket key/title and sources the source assistant inspected.
- Solidity-specific objective.
- Files or areas to inspect first, if known.
- Contract behavior to implement or preserve.
- Invariants and security constraints.
- Test scenarios that must be added or updated.
- Validation commands to discover or run, such as `forge test`, `forge test --match-test`, `forge snapshot`, `npx hardhat test`, or project-specific equivalents.
- Non-goals and forbidden unrelated refactors.
- Stop conditions for product/protocol ambiguity.

Use exact contract, function, event, error, and test names from the source-assistant output when available. If names are unknown, instruct the coding agent to inspect the repository and derive them before editing.

## Grill Before Implementation

Use `grill-me` style questioning before handing the prompt to a coding agent. Ask one question at a time.

High-value Solidity questions:

- Which contract behavior is the authoritative source of truth if linked sources conflict?
- Which callers or roles are allowed to perform the action?
- What must revert, and with which custom error or message?
- What events must be emitted, and with which indexed/non-indexed values?
- What state must change, and what must remain unchanged on revert?
- Are there token decimals, rounding, fee, slippage, oracle, or timestamp assumptions?
- Are upgrades, storage layout, initialization, pausing, or governance involved?
- Does this require fuzz/property tests, fork tests, invariant tests, or only unit tests?
- What existing behavior must remain backward-compatible?

After each answer, update the coding-agent prompt. Do not keep stale assumptions.

## Review the Result

Use `difit-review` after the coding agent produces changes.

Review Solidity diffs for:

- Acceptance criteria coverage.
- Missing revert, event, role, boundary, or invariant tests.
- Behavior changes outside the ticket scope.
- Reentrancy, external-call ordering, unchecked return values, approvals, callbacks, and pull/push payment risks.
- Arithmetic, rounding, precision, underflow/overflow assumptions, and token decimal handling.
- Storage layout and initializer risks for upgradeable contracts.
- Gas-impacting changes when gas cost is relevant.
- Test brittleness, over-mocking, weak assertions, and tests that only cover implementation details.

Turn concrete findings into difit comments when possible.

## Follow-Up Repair Prompt

When difit-review finds issues, create a focused repair prompt:

- Reference the ticket key and original Solidity objective.
- Tell the coding agent to inspect the current diff before editing.
- List required fixes as blockers versus optional cleanup.
- Require focused contract/test changes only.
- Require rerunning the relevant Solidity test command.
- Tell the agent to stop if a finding requires a protocol/product decision.

Do not ask the coding agent to reimplement the whole ticket unless the diff is fundamentally wrong.
