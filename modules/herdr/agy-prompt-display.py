#!/usr/bin/env python3
"""Antigravity CLI hook that mirrors modules/herdr/prompt-display.ts.

Reports the latest user prompt and current git branch to Herdr's sidebar when
running inside a Herdr pane (HERDR_ENV=1 and HERDR_PANE_ID set). Outside Herdr
it emits `{}` and exits immediately, so it is a no-op under Orca or plain shells.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time

SOURCE = "dotfiles:agy-prompt"
MAX_PROMPT_CHARS = 80
CONTROL_CHARS = re.compile(r"[\u0000-\u001f\u007f-\u009f]")
WHITESPACE = re.compile(r"\s+")


def normalize_prompt(text: object) -> str | None:
    if not isinstance(text, str):
        return None
    cleaned = WHITESPACE.sub(" ", CONTROL_CHARS.sub(" ", text)).strip()
    if not cleaned:
        return None
    return cleaned[:MAX_PROMPT_CHARS]


def extract_cwd(payload: dict[str, object]) -> str | None:
    cwd = payload.get("cwd")
    if isinstance(cwd, str) and cwd:
        return cwd
    workspaces = payload.get("workspacePaths")
    if isinstance(workspaces, list) and workspaces:
        first = workspaces[0]
        if isinstance(first, str) and first:
            return first
    return None


def current_branch(cwd: str | None, git_bin: str) -> str | None:
    if not cwd:
        return None
    try:
        result = subprocess.run(
            [git_bin, "-C", cwd, "symbolic-ref", "--quiet", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    name = result.stdout.strip()
    return name or None


def build_herdr_args(
    pane_id: str,
    prompt: str | None,
    git_branch: str | None,
    seq: int,
) -> list[str]:
    args = [
        "pane",
        "report-metadata",
        pane_id,
        "--source",
        SOURCE,
        "--seq",
        str(seq),
    ]
    for key, value in (("prompt", prompt), ("git_branch", git_branch)):
        if value:
            args.extend(["--token", f"{key}={value}"])
        else:
            args.extend(["--clear-token", key])
    return args


def main() -> int:
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except Exception:
        payload = {}
    if not isinstance(payload, dict):
        payload = {}

    pane_id = os.environ.get("HERDR_PANE_ID", "")
    if os.environ.get("HERDR_ENV") == "1" and pane_id:
        git_bin = os.environ.get("GIT_BIN") or "git"
        herdr_bin = os.environ.get("HERDR_BIN") or "herdr"
        prompt = normalize_prompt(payload.get("lastUserInput"))
        branch = current_branch(extract_cwd(payload), git_bin)
        args = build_herdr_args(pane_id, prompt, branch, time.time_ns())
        try:
            subprocess.run(
                [herdr_bin, *args],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3,
                check=False,
            )
        except (OSError, subprocess.SubprocessError):
            pass

    sys.stdout.write("{}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
