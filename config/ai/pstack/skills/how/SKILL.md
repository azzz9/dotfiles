---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
disable-model-invocation: true
---

# How

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

## Step 1. Assess Complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. One explainer explores and explains in a single pass. Go to Step 2b.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): spawn parallel explorers first, then hand off to the explainer. Go to Step 2a.

When in doubt, take the simple path.

## Step 2a. Explore (complex questions only)

Decompose the question into 2 to 4 exploration angles, each a distinct slice
of the subsystem. Use the current runtime's native delegation operation from
the pstack runtime contract. Give each explorer a separate read-only scope
when the runtime supports it. Otherwise run the same scopes serially and keep
the read-only rule in the prompt.
If no delegation operation is available, perform the same angle-separated
exploration in the parent session.

Each explorer gets the prompt in `references/explorer-prompt.md` with its angle
filled in. Then go to Step 3.

## Step 2b. Direct Explain (simple questions)

Use one native worker that explores and explains in one pass. Read
the pstack runtime contract for the delegation and model mapping. Give the
worker a read-only scope when the runtime supports it. Otherwise state the
read-only constraint in its prompt and inspect its artifact before using it.
If no worker is available, perform the pass in the parent session.

Build its prompt from `references/explainer-prompt.md` without the
explorer-findings section. Go to Step 4.

## Step 3. Synthesize (complex questions only)

Once all explorers have returned, use one native worker to synthesize their
findings into one explanation. Use the runtime's model mapping and preserve
the read-only scope. Build its prompt from `references/explainer-prompt.md`
with every explorer's findings filled in.
If no worker is available, synthesize the findings in the parent session.

## Step 4. Present

Present the explainer's output to the user. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

## Output Format

The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
