# pstack runtime contract

pstack policy is shared between runtimes. Runtime operations are not. This
file is the boundary for delegation, model selection, history, recurring work,
skill authoring, and installation paths.

## Resolve this file

- In this repository, read `config/ai/pstack/runtime.md`.
- After Home Manager activation, read `~/.agents/pstack/runtime.md` from any
  Codex or GitHub Copilot CLI session.
- If neither path exists, use the current runtime's documented defaults and
  report that the shared contract was unavailable.

## Runtime profiles

| Concern | Codex | GitHub Copilot CLI |
| --- | --- | --- |
| Personal skill roots | `~/.codex/skills`, `~/.agents/skills` | `~/.copilot/skills`, `~/.agents/skills` |
| Project skill roots | Repository configuration and the roots exposed by the current session | `.agents/skills` or `.github/skills` |
| Explicit skill invocation | Use the invocation exposed by the current session | `/skill-name` |
| One delegated worker | Use the native delegation operation exposed by the current session | Use native `task` when available |
| Parallel workers | Use the native parallel delegation operation exposed by the current session | Use `/fleet` or the native parallel operation when available |
| Model selection | Use model IDs accepted by the current session | Use `/model`, a supported custom agent, or the parent model |
| Session history | Resolve the active path from the current runtime | Resolve the active session under `~/.copilot/session-state/`; current records use `events.jsonl` |
| Recurring work | Use the current runtime's recurring-work mechanism | Use a supported CLI recurring-work mechanism |
| Skill authoring | Use the current Codex skill-authoring workflow | Write `SKILL.md` in a supported skill root, then reload and inspect it with the CLI when available |

The profile is a capability map, not a promise that every installation has
every operation. The current runtime remains authoritative.

## Logical operations

Shared skills may name these operations and their inputs. They must not encode
another runtime's tool fields, agent names, command syntax, model IDs, or
storage paths.

| Operation | Required logical inputs | Runtime boundary |
| --- | --- | --- |
| `delegate` | role, objective, scope, access, output, done predicate | Map only fields accepted by the current worker operation |
| `parallel-delegate` | worker count, independent briefs, isolated outputs, aggregation rule | Use native parallelism; otherwise run serially and report the fallback |
| `select-model` | logical role, available model IDs, effort budget | Reject unknown IDs and use `inherit-parent` when selection is unavailable |
| `read-history` | active workspace, session identity, time window | Resolve metadata first; never guess a filename or record schema |
| `write-skill` | name, description, supported frontmatter, validation command | Use the current runtime's skill root and authoring workflow |
| `repeat-until` | interval, wake condition, stop predicate, status report | Use the current runtime's recurring-work mechanism |

For a missing operation, use the smallest parent-session or serial fallback.
State the reduced capability in the result. Do not emulate a runtime-specific
operation by inventing fields or paths.

Shell helpers that inspect history accept an already-resolved root through
`PSTACK_HISTORY_ROOT` or an explicit command argument. An unset root disables
the history scan. Helpers must not infer a runtime's directory layout.

## Portable model preferences

`setup-pstack` stores preferences at
`${XDG_CONFIG_HOME:-$HOME/.config}/pstack/models.toml`. Role names such as
`feature`, `bug-fix`, `how explorer`, and `swarm workers` are logical labels.
They are not arguments to a worker command. A runtime may apply them natively,
translate them to a custom agent, or keep the parent model.
Role and panel names are exact keys. The shared configuration does not define
comma-separated aliases or implicit name expansion.

The aliases `inherit-parent` and `auto` are always valid. A real model ID is
valid only after the current runtime exposes it. A panel list requests that
many workers, but the runtime's worker limit wins.

A role or panel entry may be written as a table with `model` (or `models`)
and an optional `effort` override. Valid override levels are `min`, `low`,
`medium`, `high`, and `max`. An omitted `effort` follows the top-level
`budget` label. A runtime adapter that cannot apply a per-worker effort
override falls back to the top-level budget and reports the reduced
capability.

An optional `[runtime.<name>]` section overrides the defaults for one
runtime. It may set `budget`, `effort`, `[runtime.<name>.roles]`, and
`[runtime.<name>.panels]`. A missing entry falls back to the top-level
value. Use runtime sections when two runtimes expose different model IDs
for the same logical role.

## Copilot CLI verification

When the Copilot CLI is available, use its own inspection commands to confirm
the live installation after activation or reload:

```text
/env
/instructions
/skills list
/skills info poteto-mode
```

These checks confirm the active environment, instructions, and skill metadata.
They do not prove that a delegated worker or model override is available.
