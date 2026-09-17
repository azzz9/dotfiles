---
name: setup-pstack
description: Configure pstack role models and reasoning budget in a runtime-neutral user configuration. Use for /setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
disable-model-invocation: true
---

# Setup pstack

Read the pstack runtime contract from `config/ai/pstack/runtime.md` in this
repository or `~/.agents/pstack/runtime.md` after installation. Write the
portable pstack model configuration at
`${XDG_CONFIG_HOME:-$HOME/.config}/pstack/models.toml`.
Do not write editor-specific rules.

## 1. Detect capabilities

Inspect the current runtime for the model IDs and reasoning levels that it
actually accepts for delegated work. Use the current agent's exposed model
list or delegation interface. Do not copy model IDs from another runtime.
The aliases `inherit-parent` and `auto` are always valid. They mean that the
role uses the parent session model.

If the runtime cannot select a different model for a delegated role, record
`inherit-parent` for that role and report the limitation.

## 2. Load current state

Read the portable configuration if it exists. Keep existing role choices that
remain valid. Drop entries for unavailable models and report them as needing a
choice.

The configuration has one default budget value, optional per-role effort
overrides, scalar role choices, and list-valued panel choices. A panel list
controls the requested number of independent reviewers only when the runtime
can provide that many workers.

A scalar role entry is either a model alias or a table with `model` and
optional `effort`. A panel entry is either a list of model aliases or a table
with `models` and optional `effort`.

```toml
budget = "unlimited"

[roles]
feature = "inherit-parent"
refactoring = "inherit-parent"
"bug-fix" = "inherit-parent"
"perf-issue" = "inherit-parent"
hillclimb = "inherit-parent"
"judgment and prose" = "inherit-parent"
"how explorer" = "inherit-parent"
"how explainer" = "inherit-parent"
"why investigators" = "inherit-parent"
"why synthesizer" = "inherit-parent"
"reflect tooling" = "inherit-parent"
"reflect judgment" = "inherit-parent"
"reflect divergent" = "inherit-parent"
"reflect synthesizer" = "inherit-parent"
"swarm workers" = "inherit-parent"

# Per-role effort override: hardest tasks use max effort while other roles
# follow the default budget label.
[roles."hardest tasks"]
model = "inherit-parent"
effort = "max"

[panels]
"arena runners" = ["inherit-parent"]
"arena cross-judge pool" = ["inherit-parent"]
"interrogate reviewers" = ["inherit-parent"]

# Panel effort override: apply the same effort to every worker in the panel.
[panels."architect runners"]
models = ["inherit-parent", "inherit-parent"]
effort = "high"
```

Valid effort levels are `min`, `low`, `medium`, `high`, and `max`.
The default `budget` keeps its existing labels and meaning.

An optional `[runtime.<name>]` section overrides the defaults for one
runtime. `<name>` is the runtime adapter name (for example `codex` or
`copilot`). It may set `budget`, `effort`, `[runtime.<name>.roles]`, and
`[runtime.<name>.panels]`. Entries inside a runtime section use the same
scalar-or-table shape as the top-level `[roles]` and `[panels]` sections.
A missing role or panel inside a runtime section falls back to the
top-level entry. Use this when two runtimes expose different model IDs
for the same logical role.

```toml
[runtime.codex]
budget = "unlimited"

[runtime.codex.roles]
feature = { model = "inherit-parent", effort = "max" }

[runtime.copilot.roles]
feature = { model = "inherit-parent", effort = "medium" }
```

## 3. Choose the budget

Offer these labels and preserve the current value when one exists.

- `unlimited` keeps the runtime's maximum available effort.
- `large` requests the highest available effort.
- `medium` requests high effort when available.
- `small` requests medium effort when available.

Do not invent a lower-effort model ID. Select the closest detected model in
the same family, or use `inherit-parent` when no valid choice exists.

## 4. Confirm and validate

Show every scalar role and every panel entry. Ask the user to accept the
table or change named entries. Validate every real model ID against the list
detected in step 1. `inherit-parent` and `auto` always pass. Validate every
`effort` value against the list `min`, `low`, `medium`, `high`, `max`.

## 5. Write idempotently

Write the complete TOML document to a temporary file in the same directory,
then replace the target atomically. Re-running this skill must converge on the
same file for the same choices. Do not modify a runtime's own configuration
from this skill.

## 6. Report runtime limits

Tell the user the path written, the default budget, the per-role and panel
effort overrides, and which choices the current runtime can or cannot apply
natively. The pstack skills read this file as preferences. A runtime-specific
adapter remains the authority for the actual delegation call.
