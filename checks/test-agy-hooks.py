#!/usr/bin/env python3
"""Verification tests for the Antigravity (agy) harness built by modules/agy.nix."""

from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOME_FILES = Path(os.environ["AGY_HOME_FILES"])
DOTFILES_PLUGIN = Path(os.environ["AGY_DOTFILES_PLUGIN"])
PSTACK_PLUGIN = Path(os.environ["AGY_PSTACK_PLUGIN"])
PROMPT_DISPLAY = Path(os.environ["AGY_PROMPT_DISPLAY"])


class AgyPluginStructureTest(unittest.TestCase):
    def test_rules_and_skills_adapted(self) -> None:
        rules = (DOTFILES_PLUGIN / "rules" / "AGENTS.md").read_text(encoding="utf-8")
        self.assertIn("## Turn Gate", rules)
        self.assertIn("## Output", rules)
        self.assertIn("Orca workspace", rules)
        self.assertNotIn("ffgrep", rules)
        self.assertNotIn("/skill:", rules)

        for name in ("herdr", "imozuru", "retro", "workspace"):
            skill_md = DOTFILES_PLUGIN / "skills" / name / "SKILL.md"
            self.assertTrue(skill_md.is_file(), f"missing skill {name}")
            content = skill_md.read_text(encoding="utf-8")
            self.assertNotIn("/skill:", content, f"stray /skill: in {name}")

        self.assertFalse(
            (DOTFILES_PLUGIN / "skills" / "yomiyasu").exists(),
            "shared skill yomiyasu should not be duplicated inside dotfiles plugin",
        )
        for rel in (
            ".agents/skills/yomiyasu/SKILL.md",
            ".gemini/config/skills/yomiyasu/SKILL.md",
        ):
            self.assertTrue((HOME_FILES / rel).is_file(), f"missing shared skill link {rel}")

        herdr_ref = (
            DOTFILES_PLUGIN / "skills" / "workspace" / "references" / "herdr-workspace.md"
        ).read_text(encoding="utf-8")
        self.assertIn("--kind agy", herdr_ref)
        self.assertIn("agy/<slug>", herdr_ref)
        self.assertNotIn("--kind pi", herdr_ref)

        audit_sh = DOTFILES_PLUGIN / "skills" / "workspace" / "scripts" / "worktree-audit.sh"
        res = subprocess.run(["bash", "-n", str(audit_sh)], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stderr)


class CcSafetyNetHookTest(unittest.TestCase):
    def _run_hook(self, payload: dict[str, object]) -> subprocess.CompletedProcess[str]:
        hooks = json.loads((DOTFILES_PLUGIN / "hooks.json").read_text(encoding="utf-8"))
        cmd = hooks["cc-safety-net"]["PreToolUse"][0]["hooks"][0]["command"]
        return subprocess.run(
            ["/bin/sh", "-c", cmd],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            cwd=str(DOTFILES_PLUGIN),
            check=False,
        )

    def test_allows_safe_command(self) -> None:
        res = self._run_hook(
            {
                "toolCall": {
                    "id": "t1",
                    "name": "run_command",
                    "args": {"CommandLine": "git status"},
                },
                "cwd": "/tmp",
                "hookEventName": "PreToolUse",
            }
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(res.stdout.strip(), "")

    def test_blocks_destructive_command(self) -> None:
        res = self._run_hook(
            {
                "toolCall": {
                    "id": "t2",
                    "name": "run_command",
                    "args": {"CommandLine": "git reset --hard"},
                },
                "cwd": "/tmp",
                "hookEventName": "PreToolUse",
            }
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        decision = json.loads(res.stdout)
        self.assertEqual(decision.get("decision"), "deny")

    def test_blocks_secret_file_read(self) -> None:
        res = self._run_hook(
            {
                "toolCall": {
                    "id": "t3",
                    "name": "read_file",
                    "args": {"Path": "/tmp/.env"},
                },
                "cwd": "/tmp",
                "hookEventName": "PreToolUse",
            }
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        decision = json.loads(res.stdout)
        self.assertEqual(decision.get("decision"), "deny")


class PstackSessionStartHookTest(unittest.TestCase):
    def test_pstack_session_start_emits_routing_json(self) -> None:
        hooks = json.loads((PSTACK_PLUGIN / "hooks.json").read_text(encoding="utf-8"))
        cmd = hooks["pstack-routing"]["SessionStart"][0]["command"]
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, HOME=tmp)
            res = subprocess.run(
                ["/bin/sh", "-c", cmd],
                input=json.dumps({"hookEventName": "SessionStart"}),
                capture_output=True,
                text=True,
                cwd=str(PSTACK_PLUGIN),
                env=env,
                check=False,
            )
        self.assertEqual(res.returncode, 0, res.stderr)
        data = json.loads(res.stdout)
        msg = data["injectSteps"][0]["systemMessage"]["systemMessage"]
        self.assertIn("poteto-mode", msg)


class HerdrPromptDisplayHookTest(unittest.TestCase):
    def test_noop_outside_herdr(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            marker = Path(tmp) / "called"
            fake_herdr = Path(tmp) / "herdr"
            fake_herdr.write_text(f"#!/bin/sh\ntouch {marker}\n", encoding="utf-8")
            fake_herdr.chmod(fake_herdr.stat().st_mode | stat.S_IXUSR)
            env = {
                k: v
                for k, v in os.environ.items()
                if k not in ("HERDR_ENV", "HERDR_PANE_ID")
            }
            env["HERDR_BIN"] = str(fake_herdr)
            res = subprocess.run(
                [sys.executable, str(PROMPT_DISPLAY)],
                input=json.dumps({"lastUserInput": "hello", "cwd": tmp}),
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertEqual(json.loads(res.stdout), {})
            self.assertFalse(marker.exists())

    def test_reports_normalized_prompt_and_branch_inside_herdr(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            repo.mkdir()
            subprocess.run(["git", "init", "-b", "feat/agy-test", str(repo)], check=True, capture_output=True)

            log = Path(tmp) / "args.json"
            fake_herdr = Path(tmp) / "herdr"
            fake_herdr.write_text(
                f"#!{sys.executable}\n"
                "import json, sys\n"
                f"open({str(log)!r}, 'w').write(json.dumps(sys.argv[1:]))\n",
                encoding="utf-8",
            )
            fake_herdr.chmod(fake_herdr.stat().st_mode | stat.S_IXUSR)

            long_japanese = "あ" * 95
            env = dict(
                os.environ,
                HERDR_ENV="1",
                HERDR_PANE_ID="pane-42",
                HERDR_BIN=str(fake_herdr),
            )
            res = subprocess.run(
                [sys.executable, str(PROMPT_DISPLAY)],
                input=json.dumps({"lastUserInput": f"  {long_japanese}\n\t  ", "cwd": str(repo)}),
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertEqual(json.loads(res.stdout), {})

            recorded = json.loads(log.read_text(encoding="utf-8"))
            self.assertEqual(recorded[:5], ["pane", "report-metadata", "pane-42", "--source", "dotfiles:agy-prompt"])
            self.assertIn(f"prompt={'あ' * 80}", recorded)
            self.assertIn("git_branch=feat/agy-test", recorded)

    def test_clears_prompt_on_session_start(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "args.json"
            fake_herdr = Path(tmp) / "herdr"
            fake_herdr.write_text(
                f"#!{sys.executable}\n"
                "import json, sys\n"
                f"open({str(log)!r}, 'w').write(json.dumps(sys.argv[1:]))\n",
                encoding="utf-8",
            )
            fake_herdr.chmod(fake_herdr.stat().st_mode | stat.S_IXUSR)

            env = dict(
                os.environ,
                HERDR_ENV="1",
                HERDR_PANE_ID="pane-7",
                HERDR_BIN=str(fake_herdr),
            )
            res = subprocess.run(
                [sys.executable, str(PROMPT_DISPLAY)],
                input=json.dumps({"cwd": tmp}),
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertEqual(json.loads(res.stdout), {})
            recorded = json.loads(log.read_text(encoding="utf-8"))
            self.assertIn("--clear-token", recorded)
            self.assertIn("prompt", recorded)
            self.assertIn("git_branch", recorded)


if __name__ == "__main__":
    unittest.main()
