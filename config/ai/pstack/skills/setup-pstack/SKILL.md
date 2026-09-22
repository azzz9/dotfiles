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

## OMP adapter

When the `omp` CLI is present, `pstack-omp-adapter.py` (next to this skill's
repository checkout, under `config/ai/pstack/scripts/`) translates the
`[runtime.omp]` section into OMP configuration. It validates every model ID
against `omp models --kind chat`, maps `min` effort to OMP `low` (other
levels 1:1), clamps an effort to the model's ladder when the model does not
support it, and writes:

1. `~/.config/pstack/omp-modelRoles.yml`: a `modelRoles` overlay. Panel
   entries emit one key per member at its original list position
   (`pstack-<panel>-1..N`), so OMP can fan a panel across distinct models.
2. One OMP task agent per workflow role in `~/.omp/agent/agents/psx-*.md`,
   each with `model: ["@<modelRoles-key>"]`, a role-appropriate `tools`
   set (read-only for review/exploration roles, full for implementers),
   and `spawns: ""`. Panel members generate one agent per list entry at
   the member's original position: `psx-<panel>-1..N`. An
   `inherit-parent`/`auto` member generates an agent without a `model`
   field: OMP runs it on the parent model. Every generated file carries
   `metadata: generated-by: pstack-omp-adapter`; re-runs prune stale files
   by that marker only and never touch hand-written agents.
3. With `--install`: register the overlay for every future OMP launch by
   exporting `PI_CONFIG_FILES` in the shell init (`--shell-init` path;
   the adapter refuses Home Manager / nix-store-managed inits, which
   `dotfiles apply` would overwrite). The export preserves an existing
   `PI_CONFIG_FILES` as a path list and appends the overlay. OMP loads
   `PI_CONFIG_FILES` overlays ahead of `--config`;
   `~/.omp/agent/config.yml` is never modified. Idempotent: re-running
   replaces the export block.

- `python3 pstack-omp-adapter.py --check` validates and prints the resolved
  table without writing.
- Write mode refuses partial output when a model id does not resolve;
  `--allow-missing` writes the resolvable subset and reports the dropped
  entries.
- To route a delegated worker by role, dispatch the generated agent name
  (for example `psx-interrogate-reviewers-2` in a `tasks[]` batch). OMP
  resolves the agent's `@<modelRoles-key>` at spawn time; an undefined
  alias fails the spawn instead of falling back silently, so validate
  before use. If the parent session itself falls back to another model,
  an alias can resolve through the fallback chain: record the resolved
  model the child reports.
