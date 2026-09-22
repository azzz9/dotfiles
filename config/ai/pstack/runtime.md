# pstack runtime contract

pstack policy is shared between runtimes. Runtime operations are not. This
file is the boundary for delegation, model selection, history, recurring work,
skill authoring, and installation paths.

## Resolve this file

- In this repository, read `config/ai/pstack/runtime.md`.
- After Home Manager activation, read `~/.agents/pstack/runtime.md` from any
  Codex, Oh My Pi, or GitHub Copilot CLI session.
- If neither path exists, use the current runtime's documented defaults and
  report that the shared contract was unavailable.

## Runtime profiles

| Concern | Codex | GitHub Copilot CLI | Oh My Pi (omp) |
| --- | --- | --- | --- |
| Personal skill roots | `~/.codex/skills`, `~/.agents/skills` | `~/.copilot/skills`, `~/.agents/skills` | `~/.omp/agent/skills`, `~/.agents/skills` |
| Project skill roots | Repository configuration and the roots exposed by the current session | `.agents/skills` or `.github/skills` | `.omp/skills/` (native), `.agents/skills`, `.github/skills`, or `skills.customDirectories` |
| Explicit skill invocation | Use the invocation exposed by the current session | `/skill-name` | `/skill:<name>` |
| One delegated worker | Use the native delegation operation exposed by the current session | Use native `task` when available | Native `task` tool (or `eval agent()`) |
| Parallel workers | Use the native parallel delegation operation exposed by the current session | Use `/fleet` or the native parallel operation when available | Native `task` batch (`tasks[]`) or `eval workpool()` |
| Model selection | Use model IDs accepted by the current session | Use `/model`, a supported custom agent, or the parent model | `modelRoles` in `~/.omp/agent/config.yml` (e.g. `default`, `smol`, `slow`, `plan`, `advisor`); per-agent via agent frontmatter `model` or `task.agentModelOverrides` |
| Session history | Resolve the active path from the current runtime | Resolve the active session under `~/.copilot/session-state/`; current records use `events.jsonl` | Session JSONL under `~/.omp/agent/sessions/<encoded-cwd>/` (append-only tree; read metadata, do not guess schemas) |
| Recurring work | Use the current runtime's recurring-work mechanism | Use a supported CLI recurring-work mechanism | Use the current runtime's recurring-work mechanism (no native recurring-work operation; fall back to serial loops and report it) |
| Skill authoring | Use the current Codex skill-authoring workflow | Write `SKILL.md` in a supported skill root, then reload and inspect it with the CLI when available | Write `<skills-root>/<name>/SKILL.md` (one level under the skills root); OMP discovers at startup |
| Effort override | Runtime-specific | Runtime-specific | Thinking levels `minimal`…`max` via `defaultThinkingLevel`, `:level` model suffixes, or agent `thinkingLevel` frontmatter |

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
| `select-model` | logical role, available model IDs, effort budget | Reject unknown IDs and use `inherit-parent` when selection is unavailable. On OMP, `pstack-omp-adapter.py` validates `[runtime.omp]` against `omp models` and writes a modelRoles overlay plus one task agent per role (`psx-*.md`, ownership-marked); panels emit one agent and one modelRoles key per member at the member's original list position, enabling multi-model fan-out through a `tasks[]` batch. An `inherit-parent` member gets an agent without a `model` field: OMP runs it on the parent model. Dispatch the generated agent name; an unresolved alias fails the spawn instead of silently reusing the parent model. If the parent session falls back to another model, an alias can resolve through the fallback chain: record the resolved model reported by the child. With `--install` the adapter exports `PI_CONFIG_FILES` from the shell init so every new OMP session loads the overlay; `~/.omp/agent/config.yml` is never modified. |
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
runtime. `<name>` is the runtime adapter name (for example `codex`,
`copilot`, or `omp`). It may set `budget`, `effort`, `[runtime.<name>.roles]`,
and `[runtime.<name>.panels]`. A missing entry falls back to the top-level
value. Use runtime sections when two runtimes expose different model IDs
for the same logical role.

## Oh My Pi verification

When the `omp` CLI is available, confirm the live installation after
activation. From a shell, `omp config path` prints the agent directory,
`omp config get skills.customDirectories` prints configured extra roots, and
`python3 config/ai/pstack/scripts/pstack-omp-adapter.py --check` validates
the `[runtime.omp]` section against the live model catalog without writing.
After running the adapter, `ls ~/.omp/agent/agents/psx-*.md` lists the
generated per-role agents. In an interactive session, `/skill:<name> [args]`
invokes a discovered skill, and the `read` tool resolves
`skill://<name>/<path>` inside the skill directory. These checks confirm
discovery; they do not prove that a delegated worker or model override is
available.

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
