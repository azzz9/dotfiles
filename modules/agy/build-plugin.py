#!/usr/bin/env python3
"""Builds the Antigravity (agy) dotfiles plugin tree from the pi-skills package.

Reuses pi-skills/AGENTS.md, the Output rules of pi-skills/APPEND_SYSTEM.md, and
the five built skills (herdr, imozuru, retro, workspace, yomiyasu) so rules and
upstream-tracked skills stay in one place. Fails loudly if an expected anchor in
pi-skills disappears so adaptations never drift silently.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
from pathlib import Path

AGY_GATES_AND_TOOLS = """## Gates

- Before editing or adding files, state the plan in one to three lines: what changes, which files,
  how you will verify it, and what you will not touch. Then proceed unless the user redirects.
- Work that edits files starts in a linked worktree, and read-only work stays put. If you are
  already in a linked worktree (for example, an Orca workspace), work there and do not create
  another. Under Herdr (`HERDR_ENV=1`), use the `workspace` skill to create one, dispatch an
  independent task, or close a branch.

## Tools

Search file contents with `rg` and find files with `rg --files` or `fd` via `run_command`.
"""


def replace_exact(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"agy-plugin: expected text not found in {path}: {old!r}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def build_rules(pi_skills: Path, out: Path) -> None:
    agents = (pi_skills / "AGENTS.md").read_text(encoding="utf-8").rstrip()
    append = (pi_skills / "APPEND_SYSTEM.md").read_text(encoding="utf-8")
    anchor = "## Output\n"
    idx = append.find(anchor)
    if idx == -1:
        raise SystemExit("agy-plugin: '## Output' heading not found in APPEND_SYSTEM.md")
    output_rules = append[idx:].rstrip()

    rules_dir = out / "rules"
    rules_dir.mkdir(parents=True, exist_ok=True)
    combined = f"{agents}\n\n{AGY_GATES_AND_TOOLS.rstrip()}\n\n{output_rules}\n"
    (rules_dir / "AGENTS.md").write_text(combined, encoding="utf-8")


def copy_writable(src: Path, dst: Path) -> None:
    shutil.copytree(src, dst)
    for root, dirs, files in os.walk(dst):
        root_path = Path(root)
        root_path.chmod(root_path.stat().st_mode | stat.S_IWUSR)
        for name in dirs + files:
            entry = root_path / name
            if not entry.is_symlink():
                entry.chmod(entry.stat().st_mode | stat.S_IWUSR)


def adapt_skills(pi_skills: Path, out: Path, exclude_skills: set[str]) -> None:
    skills_dst = out / "skills"
    copy_writable(pi_skills / "skills", skills_dst)
    for name in exclude_skills:
        excluded = skills_dst / name
        if excluded.exists():
            shutil.rmtree(excluded)

    # imozuru: drop pi-specific slash command and runtime name.
    imozuru = skills_dst / "imozuru" / "SKILL.md"
    replace_exact(imozuru, "/skill:imozuru", "imozuru")
    replace_exact(imozuru, "pi 自身", "エージェント自身")
    replace_exact(imozuru, "同じ pi", "同じエージェント")

    # retro: point at AGENTS.md (where Output rules live on agy) and skill name.
    retro = skills_dst / "retro" / "SKILL.md"
    replace_exact(
        retro,
        "Follow the Output rules in `APPEND_SYSTEM.md`. When writing in Japanese, read `/skill:yomiyasu`.",
        "Follow the Output rules in global `AGENTS.md`. When writing in Japanese, read the `yomiyasu` skill.",
    )
    replace_exact(retro, "for Japanese, use `/skill:yomiyasu`.", "for Japanese, use the `yomiyasu` skill.")

    # workspace: adapt branch prefix, Herdr kind, and existing-worktree rule for Orca/Herdr.
    workspace = skills_dst / "workspace" / "SKILL.md"
    replace_exact(
        workspace,
        "- Work that edits files starts in a linked worktree. Do not edit in the main repo. Herdr is required. Check `HERDR_ENV=1` and run `herdr worktree create --cwd <repo root> --branch pi/<slug>`. Stop if you are outside Herdr. Read-only work stays put.",
        "- Work that edits files starts in a linked worktree. Do not edit in the main repo. If you are already in a linked worktree (for example, an Orca workspace), work there and do not create another. Creating or dispatching a new worktree requires Herdr (`HERDR_ENV=1`): run `herdr worktree create --cwd <repo root> --branch agy/<slug>`, or stop if outside Herdr. Read-only work stays put.",
    )
    replace_exact(workspace, "separate pi session", "separate agy session")
    replace_exact(workspace, "(no subagent; Herdr + child pi)", "(no subagent; Herdr + child agy)")
    replace_exact(workspace, "wt-clean pi/<slug>", "wt-clean agy/<slug>")

    herdr_ref = skills_dst / "workspace" / "references" / "herdr-workspace.md"
    replace_exact(herdr_ref, "pi/<slug>", "agy/<slug>")
    replace_exact(herdr_ref, "--kind pi", "--kind agy")
    replace_exact(herdr_ref, "its pi process", "its agy process")
    replace_exact(herdr_ref, "`pi --continue`", "`agy --continue`")
    replace_exact(herdr_ref, "a child pi", "a child agy")

    # worktree-audit.sh: check both agy and pi transcript directories.
    audit_sh = skills_dst / "workspace" / "scripts" / "worktree-audit.sh"
    replace_exact(
        audit_sh,
        '# Transcripts dir: ~/.pi/agent/sessions (JSONL, one file per session).\ntranscripts="$HOME/.pi/agent/sessions"',
        '# Transcript dirs: agy brain logs and pi sessions (whichever exist).\ntranscript_dirs=()\n[ -d "$HOME/.gemini/antigravity-cli/brain" ] && transcript_dirs+=("$HOME/.gemini/antigravity-cli/brain")\n[ -d "$HOME/.pi/agent/sessions" ] && transcript_dirs+=("$HOME/.pi/agent/sessions")',
    )
    replace_exact(
        audit_sh,
        '\tif [ -d "$transcripts" ]; then\n\t\tf=$(rg -l -e "${wt}/" -e "${wt}\\"" "$transcripts" 2>/dev/null \\',
        '\tif ((${#transcript_dirs[@]} > 0)); then\n\t\tf=$(rg -l -e "${wt}/" -e "${wt}\\"" "${transcript_dirs[@]}" 2>/dev/null \\',
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pi-skills", required=True)
    parser.add_argument("--hooks-json", required=True)
    parser.add_argument("--exclude-skill", action="append", default=[])
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    pi_skills = Path(args.pi_skills)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    (out / "plugin.json").write_text(
        json.dumps({"name": "dotfiles"}, indent=2) + "\n",
        encoding="utf-8",
    )
    shutil.copyfile(args.hooks_json, out / "hooks.json")

    build_rules(pi_skills, out)
    adapt_skills(pi_skills, out, set(args.exclude_skill))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
