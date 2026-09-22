#!/usr/bin/env python3
"""Generate OMP modelRoles overlay and per-role task agents from pstack models.toml.

Reads ${XDG_CONFIG_HOME:-$HOME/.config}/pstack/models.toml, resolves the
[runtime.omp] section over the top-level [roles]/[panels] defaults, validates
every concrete model ID against `omp models --kind chat`, and writes:

  1. A YAML overlay with `modelRoles` for `omp --config <overlay>`
     (default: ~/.config/pstack/omp-modelRoles.yml).
  2. One OMP task agent per workflow role in ~/.omp/agent/agents/psx-<role>.md,
     with `model: ["@<modelRoles-key>"]`, a role-appropriate tool set, and
     `spawns: ""` (children never spawn children). Panel entries generate one
     agent per list member at its original list position:
     psx-<panel>-<position>, each pinned to `@pstack-<panel>-<position>`,
     enabling multi-model fan-out. An `inherit-parent` member generates an
     agent without a `model` field: OMP then runs it on the parent model.
     Every generated file carries a `metadata: generated-by:
     pstack-omp-adapter` marker; re-runs prune stale files by that marker and
     never touch hand-written agents.
  3. With --install: register the overlay for every future OMP launch by
     writing `PI_CONFIG_FILES` into the shell init. OMP loads overlay files
     ahead of `--config` overlays; config.yml is never modified. Idempotent:
     re-running replaces the export line.

Usage:
  pstack-omp-adapter.py [--check] [--out PATH] [--agents-dir PATH]
                        [--install] [--allow-missing]

  --check        validate only; print the resolved table, write nothing
  --out PATH     overlay path (default: ~/.config/pstack/omp-modelRoles.yml)
  --agents-dir   agent output dir (default: ~/.omp/agent/agents)
  --shell-init   shell init to register PI_CONFIG_FILES in
                 (default: ~/.config/zsh/.zshrc when present, else ~/.zshrc)
  --install      also export PI_CONFIG_FILES from the shell init so every
                 new OMP session loads the overlay
  --allow-missing  write partial output even when some entries are
                   unresolvable (missing entries are dropped and reported)

Role keys become OMP modelRoles keys `pstack-<normalized-name>`. Per-key
merge: an entry inside [runtime.omp] overrides the top-level default for
that role/panel; missing keys fall back to the top-level tables.
Panel member keys and agent names are pinned to the member's original list
index, so the skill's list order always maps to the generated agents.
`effort` maps pstack min -> OMP low, others 1:1; the `:level` suffix is
appended only when the model ladder supports it, clamped down otherwise.
Unresolvable model ids are fatal: check mode reports them and exits 1,
write mode refuses to produce partial output unless --allow-missing is
given. Clamp/effort warnings are non-fatal and applied.
Exit codes: 0 ok, 1 validation error, 2 usage/environment error.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import tomllib

RANKED = ["low", "medium", "high", "xhigh", "max"]
EFFORT_MAP = {"min": "low", "low": "low", "medium": "medium", "high": "high", "max": "max"}


def models_toml_path() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return Path(base) / "pstack" / "models.toml"


def omp_catalog():
    result = subprocess.run(
        ["omp", "models", "--kind", "chat", "--json"],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f"omp models failed: {result.stderr.strip()}")
    data = json.loads(result.stdout)
    models = data if isinstance(data, list) else data.get("models", [])
    ids = {}
    for m in models:
        selector = (m.get("selector") or "").strip()
        if not selector and (m.get("provider") or "").strip() and (m.get("id") or "").strip():
            selector = f"{m['provider'].strip()}/{m['id'].strip()}"
        ladder = [str(x).lower() for x in (m.get("thinking") or m.get("thinkingLevels") or [])]
        if selector:
            ids[selector] = ladder
    return ids


def role_slug(key: str) -> str:
    slug = key.strip().lower().replace(" ", "-").replace(",", "")
    while "--" in slug:
        slug = slug.replace("--", "-")
    return "pstack-" + slug


def clamp(effort: str, ladder: list[str], label: str, warnings: list[str]) -> str | None:
    if not effort:
        return None
    eff = EFFORT_MAP.get(effort)
    if not eff:
        warnings.append(f"unknown effort {effort!r} ignored for {label}")
        return None
    if not ladder:
        return eff  # model metadata lacks a ladder; pass through
    if eff in ladder:
        return eff
    # clamp down to the closest supported level below or equal
    idx = RANKED.index(eff) if eff in RANKED else len(RANKED) - 1
    for lv in reversed(RANKED[: idx + 1]):
        if lv in ladder:
            if lv != eff:
                warnings.append(f"clamped {eff} -> {lv} for {label}")
            return lv
    return ladder[0]


def resolve(entry, catalog, warnings, label):
    if isinstance(entry, str):
        alias = entry.strip()
        if alias in ("inherit-parent", "auto"):
            return None, None
        if alias in catalog:
            return alias, None
        bare = alias.split("/", 1)[1] if "/" in alias else alias
        matches = [s for s in catalog if s.split("/", 1)[1] == bare]
        if len(matches) == 1:
            return matches[0], None
        warnings.append(f"{label}: unresolvable model id {alias!r}")
        return None, None
    if isinstance(entry, dict):
        model = entry.get("model")
        if not isinstance(model, str) or not model.strip():
            warnings.append(f"{label}: table entry without scalar model")
            return None, None
        model = model.strip()
        if model in ("inherit-parent", "auto"):
            return None, None
        if model in catalog:
            return model, entry.get("effort")
        bare = model.split("/", 1)[1] if "/" in model else model
        matches = [s for s in catalog if s.split("/", 1)[1] == bare]
        if not matches:
            warnings.append(f"{label}: unresolvable model id {model!r}")
            return None, None
        if len(matches) > 1:
            warnings.append(f"{label}: ambiguous model id {model!r}: {sorted(matches)}")
            return None, None
        return matches[0], entry.get("effort")
    warnings.append(f"{label}: unsupported entry shape {type(entry).__name__}")
    return None, None


# Tool sets by work shape. Read-only roles and review panels must not write;
# implementer roles get the full editing surface. Override per role with a
# [runtime.omp.tools] section keyed by the same role/panel name.
READ_ONLY = ["read", "grep", "glob"]
FULL = None  # no tools key: full default access

TOOL_SHAPES = {
    # role name -> shape
    "feature, refactoring": FULL,
    "bug-fix": FULL,
    "perf-issue": FULL,
    "hillclimb": FULL,
    "hardest tasks": FULL,
    "reflect tooling": FULL,
    "how explorer": READ_ONLY,
    "why investigators": READ_ONLY,
    "why synthesizer": READ_ONLY,
    "how explainer": READ_ONLY,
    "judgment and prose": READ_ONLY,
    "reflect judgment, divergent, synthesizer": READ_ONLY,
    # panels
    "arena runners": FULL,
    "arena cross-judge pool": READ_ONLY,
    "swarm workers": FULL,
    "architect runners": READ_ONLY,
    "interrogate reviewers": READ_ONLY,
}

ROLE_BLURB = {
    "feature, refactoring": "Bounded implementation with explicit write ownership.",
    "bug-fix": "Bounded defect fix with write ownership.",
    "perf-issue": "Measured perf fix with write ownership.",
    "hillclimb": "Iterative metric improvement with write ownership.",
    "hardest tasks": "Deep reasoning work on the hardest unit.",
    "reflect tooling": "Tooling-oriented research and review.",
    "how explorer": "Read-only repository reconnaissance.",
    "why investigators": "Source-verified investigation; read-only.",
    "why synthesizer": "Synthesize frozen reports; read-only.",
    "how explainer": "Explain and document; read-only.",
    "judgment and prose": "Independent judgment and review; read-only.",
    "reflect judgment, divergent, synthesizer": "Reflective judgment; read-only.",
    "arena runners": "Arena candidate: produce one complete artifact.",
    "arena cross-judge pool": "Cross-judge candidates against the rubric; read-only.",
    "swarm workers": "Swarm worker: one independent slice.",
    "architect runners": "Design candidate: read-only analysis output.",
    "interrogate reviewers": "Independent adversarial review; read-only.",
}


def agent_name_for(slug: str, index: int | None) -> str:
    base = slug.removeprefix("pstack-")
    return f"psx-{base}" if index is None else f"psx-{base}-{index}"


def agent_markdown(name: str, description: str, role_key: str | None, tools, blurb: str) -> str:
    lines = [
        "---",
        f"name: {name}",
        f'description: "{description}"',
        "metadata:",
        "  generated-by: pstack-omp-adapter",
    ]
    if role_key is not None:
        lines += ["model:", f'  - "@{role_key}"']
    if tools is not None:
        lines.append("tools:")
        lines += [f"  - {t}" for t in tools]
    lines += [
        'spawns: ""',
        "---",
        "",
        f"pstack role: {name}. {blurb}",
        "Never call task and never start children.",
        "Report PASS | ISSUES | BLOCKED with the executed verification evidence.",
        "",
    ]
    return "\n".join(lines)


def yaml_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


INSTALL_BEGIN = "# >>> pstack-omp-adapter >>>"
INSTALL_END = "# <<< pstack-omp-adapter <<<"


def hm_managed(path: Path) -> bool:
    """True when the path is a Home Manager / nix store symlink."""
    try:
        return path.is_symlink() and "nix/store" in os.path.realpath(path)
    except OSError:
        return False


def register_pi_config_files(shell_init: Path, overlay_path: Path) -> str:
    """Add or replace a PI_CONFIG_FILES export block in a user-owned shell
    init. Returns "rewritten" | "unchanged" | "refused"."""
    if hm_managed(shell_init):
        print(f"error: refusing to edit HM-managed {shell_init} (dotfiles apply would discard the block); pass --shell-init with a user-owned file", file=sys.stderr)
        return "refused"
    try:
        text = shell_init.read_text()
    except FileNotFoundError:
        text = ""
    block = (
        f"{INSTALL_BEGIN}\n"
        "# Registered by pstack-omp-adapter.py; re-run it after changing\n"
        "# pstack preferences. OMP loads overlay files ahead of --config.\n"
        f'export PI_CONFIG_FILES="{overlay_path}${{PI_CONFIG_FILES:+:${{PI_CONFIG_FILES}}}}"\n'
        f"{INSTALL_END}"
    )
    pattern = re.compile(
        re.escape(INSTALL_BEGIN) + r"\n.*?\n" + re.escape(INSTALL_END) + r"\n?",
        re.S,
    )
    if pattern.search(text):
        new_text = pattern.sub(block + "\n", text)
    else:
        new_text = text.rstrip("\n") + ("\n" if text else "") + block + "\n"
    if new_text == text:
        return "unchanged"
    tmp = shell_init.with_suffix(shell_init.suffix + ".tmp")
    tmp.write_text(new_text)
    tmp.replace(shell_init)
    return "rewritten"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate an OMP modelRoles overlay and per-role task agents from pstack models.toml")
    parser.add_argument("--check", action="store_true", help="validate and print the overlay, write nothing")
    parser.add_argument("--out", default=None, help="overlay output path")
    parser.add_argument("--agents-dir", default=None, help="agent output dir (default: ~/.omp/agent/agents)")
    parser.add_argument("--shell-init", default=None,
                        help="shell init to register PI_CONFIG_FILES in (default: ~/.config/zsh/.zshrc when present, else ~/.zshrc)")
    parser.add_argument("--install", action="store_true",
                        help="also export PI_CONFIG_FILES from the shell init so every new OMP session loads the overlay")
    parser.add_argument("--allow-missing", action="store_true",
                        help="write partial output even when some entries are unresolvable (missing entries are dropped)")
    args = parser.parse_args()

    path = models_toml_path()
    if not path.exists():
        print(f"error: {path} not found", file=sys.stderr)
        return 2

    config = tomllib.loads(path.read_text())
    omp = config.get("runtime", {}).get("omp")
    if not omp:
        print("error: no [runtime.omp] section in models.toml", file=sys.stderr)
        return 2

    warnings: list[str] = []  # non-fatal: clamps, unknown efforts, inherit-parent notes
    errors: list[str] = []    # fatal: unresolvable model ids, malformed entries
    catalog = omp_catalog()
    if not catalog:
        print("error: omp model catalog is empty", file=sys.stderr)
        return 1

    budget = (omp.get("budget") or config.get("budget") or "").strip()
    default_effort = EFFORT_MAP.get(budget) if budget not in ("", "unlimited") else None

    # Per-key merge per the setup-pstack contract: an entry inside
    # [runtime.omp] overrides the top-level default for that role/panel;
    # missing keys fall back to the top-level table.
    merged_roles = {**(config.get("roles") or {}), **(omp.get("roles") or {})}
    merged_panels = {**(config.get("panels") or {}), **(omp.get("panels") or {})}
    tool_overrides = omp.get("tools") or {}

    roles_out: dict[str, str] = {}
    inherit_agents: list[tuple[str, str]] = []  # (agent display, role/panel label)
    for role, entry in merged_roles.items():
        label = f"role {role!r}"
        selector, effort = resolve(entry, catalog, errors, label)
        if not selector:
            alias = entry if isinstance(entry, str) else (entry.get("model") if isinstance(entry, dict) else None)
            if alias in ("inherit-parent", "auto"):
                inherit_agents.append((role, label))
            continue
        eff_in = effort or default_effort
        eff = clamp(eff_in if isinstance(eff_in, str) else "", catalog[selector], selector, warnings)
        roles_out[role_slug(role)] = f"{selector}:{eff}" if eff else selector

    # Panel entries get one modelRoles key per member, pinned to the member's
    # original list position, so the skill's list order always maps to the
    # generated agents: pstack-<panel>-<position>.
    panel_members: dict[str, list[tuple[str, str]]] = {}  # slug -> [(agent_name, modelRoles_key)]
    for panel, entry in merged_panels.items():
        label = f"panel {panel!r}"
        entries = entry if isinstance(entry, list) else [entry]
        slug = role_slug(panel)
        for i, item in enumerate(entries):
            position = i + 1
            selector, effort = resolve(item, catalog, errors, f"{label}[{i}]")
            if not selector:
                alias = item if isinstance(item, str) else (item.get("model") if isinstance(item, dict) else None)
                if alias in ("inherit-parent", "auto"):
                    inherit_agents.append((agent_name_for(slug, position), f"{label}[{i}]"))
                continue
            eff_in = effort or default_effort
            eff = clamp(eff_in if isinstance(eff_in, str) else "", catalog[selector], selector, warnings)
            key = f"{slug}-{position}"
            roles_out[key] = f"{selector}:{eff}" if eff else selector
            panel_members.setdefault(slug, []).append((agent_name_for(slug, position), key))

    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    for e in errors:
        print(f"error: {e}", file=sys.stderr)

    lines = [
        "# Generated by pstack-omp-adapter.py from ~/.config/pstack/models.toml [runtime.omp].",
        "# Do not edit by hand; re-run the adapter after changing pstack preferences.",
        "modelRoles:",
    ]
    lines += [f'  {k}: "{v}"' for k, v in sorted(roles_out.items())]

    text = "\n".join(lines) + "\n"
    if args.check:
        print(text, end="")
        for slug, members in sorted(panel_members.items()):
            print(f"# panel {slug}: " + ", ".join(f"{a} -> @{k}" for a, k in members))
        return 1 if errors else 0

    if errors and not args.allow_missing:
        print("error: refusing to write partial output; fix models.toml or pass --allow-missing", file=sys.stderr)
        return 1

    # 1. modelRoles overlay (atomic)
    out = Path(args.out) if args.out else models_toml_path().with_name("omp-modelRoles.yml")
    tmp = out.with_suffix(out.suffix + ".tmp")
    tmp.write_text(text)
    tmp.replace(out)

    # 2. per-role/panel-member task agents, ownership-marked; prune only
    # files carrying the generated marker so hand-written agents survive.
    agents_dir = Path(args.agents_dir) if args.agents_dir else Path.home() / ".omp" / "agent" / "agents"
    agents_dir.mkdir(parents=True, exist_ok=True)
    expected_agents: dict[str, str] = {}  # name -> markdown
    inherit_agent_names: list[str] = []

    def plan_agent(name: str, role_key: str | None, display: str, member_label: str | None, blurb: str, shape) -> None:
        tools = tool_overrides.get(display, shape)
        if role_key is None:
            desc = f"pstack {display} (inherit-parent: runs on the parent model)"
            if member_label:
                desc = f"pstack panel {display} ({member_label}, inherit-parent: parent model)"
        else:
            desc = f"pstack {display} -> @{role_key}"
            if member_label:
                desc = f"pstack panel {display} ({member_label}) -> @{role_key}"
        expected_agents[name] = agent_markdown(name, desc, role_key, tools, blurb)

    for role, entry in merged_roles.items():
        selector, _effort = resolve(entry, catalog, [], "x")
        slug = role_slug(role)
        shape = tool_overrides.get(role, TOOL_SHAPES.get(role, FULL))
        blurb = ROLE_BLURB.get(role, f"pstack role {role}.")
        if not selector:
            alias = entry if isinstance(entry, str) else (entry.get("model") if isinstance(entry, dict) else None)
            if alias in ("inherit-parent", "auto"):
                plan_agent(agent_name_for(slug, None), None, role, None, blurb, shape)
                inherit_agent_names.append(agent_name_for(slug, None))
            continue  # validation-error entry: no agent, only --allow-missing reaches here
        plan_agent(agent_name_for(slug, None), slug, role, None, blurb, shape)
    for panel, entry in merged_panels.items():
        entries = entry if isinstance(entry, list) else [entry]
        slug = role_slug(panel)
        shape = tool_overrides.get(panel, TOOL_SHAPES.get(panel, READ_ONLY))
        for i, item in enumerate(entries):
            position = i + 1
            selector, _effort = resolve(item, catalog, [], "x")
            name = agent_name_for(slug, position)
            blurb = ROLE_BLURB.get(panel, f"pstack panel {panel} member {position}.")
            if not selector:
                alias = item if isinstance(item, str) else (item.get("model") if isinstance(item, dict) else None)
                if alias in ("inherit-parent", "auto"):
                    plan_agent(name, None, panel, f"entry {position}", blurb, shape)
                    inherit_agent_names.append(name)
                continue  # validation-error entry: no agent
            plan_agent(name, f"{slug}-{position}", panel, f"entry {position}", blurb, shape)

    # Prune stale generated agents: only files whose frontmatter carries the
    # exact generated-by marker, so hand-written agents survive.
    marker_line = "  generated-by: pstack-omp-adapter"
    for old in agents_dir.glob("psx-*.md"):
        try:
            head = old.read_text()[:600]
        except OSError:
            continue
        if not head.startswith("---\n"):
            continue
        closing = head.find("\n---", 4)
        if closing == -1:
            continue
        if marker_line in head[:closing]:
            old.unlink()

    for name, md in expected_agents.items():
        p = agents_dir / f"{name}.md"
        tmpf = p.with_suffix(".md.tmp")
        tmpf.write_text(md)
        tmpf.replace(p)

    # 3. optional install: register overlay for every new OMP session via
    # PI_CONFIG_FILES (overlay layer sits above project/global settings).
    if args.install:
        default_init = Path.home() / ".config" / "zsh" / ".zshrc"
        shell_init = Path(args.shell_init) if args.shell_init else (default_init if default_init.exists() else Path.home() / ".zshrc")
        status = register_pi_config_files(shell_init, out)
        if status == "rewritten":
            print(f"registered PI_CONFIG_FILES={out} in {shell_init}")
        elif status == "unchanged":
            print(f"PI_CONFIG_FILES already registered in {shell_init}")
        else:
            print("warning: install not completed; load the overlay per session with PI_CONFIG_FILES=... or omp --config", file=sys.stderr)

    inherit_note = f", {len(inherit_agents)} inherit-parent agents (parent-model fallback)" if inherit_agent_names else ""
    print(f"wrote {out} ({len(roles_out)} modelRoles keys incl. {sum(len(v) for v in panel_members.values())} panel members{inherit_note})")
    print(f"wrote {len(expected_agents)} agents to {agents_dir}: {', '.join(sorted(expected_agents))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
