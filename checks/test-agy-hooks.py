#!/usr/bin/env python3
"""Verification tests for the Antigravity (agy) harness built by modules/agy.nix."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HOME_FILES = Path(os.environ["AGY_HOME_FILES"])
DOTFILES_PLUGIN = Path(os.environ["AGY_DOTFILES_PLUGIN"])
PSTACK_PLUGIN = Path(os.environ["AGY_PSTACK_PLUGIN"])
RTK_PLUGIN = Path(os.environ["AGY_RTK_PLUGIN"])


class AgyPluginStructureTest(unittest.TestCase):
    def test_rules_and_skills_adapted(self) -> None:
        rules = (DOTFILES_PLUGIN / "rules" / "AGENTS.md").read_text(encoding="utf-8")
        self.assertIn("## Turn Gate", rules)
        self.assertIn("## Output", rules)
        self.assertIn("Orca workspace", rules)
        self.assertNotIn("ffgrep", rules)
        self.assertNotIn("/skill:", rules)

        for name in ("imozuru", "retro", "workspace"):
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

        tuios_ref = (
            DOTFILES_PLUGIN / "skills" / "workspace" / "references" / "tuios-workspace.md"
        ).read_text(encoding="utf-8")
        self.assertIn("--agent agy", tuios_ref)
        self.assertIn("agy/<slug>", tuios_ref)
        self.assertNotIn("--agent pi", tuios_ref)

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

    def test_blocks_rtk_prefixed_destructive_command(self) -> None:
        res = self._run_hook(
            {
                "toolCall": {
                    "id": "t4",
                    "name": "run_command",
                    "args": {"CommandLine": "rtk git push --force"},
                },
                "cwd": "/tmp",
                "hookEventName": "PreToolUse",
            }
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        decision = json.loads(res.stdout)
        self.assertEqual(decision.get("decision"), "deny")


class RtkPluginHookTest(unittest.TestCase):
    def _run_hook(self, payload: dict[str, object]) -> subprocess.CompletedProcess[str]:
        hooks = json.loads((RTK_PLUGIN / "hooks.json").read_text(encoding="utf-8"))
        cmd = hooks["rtk-rewrite"]["PreToolUse"][0]["hooks"][0]["command"]
        self.assertTrue(cmd.startswith("/nix/store/"), f"expected store path in {cmd!r}")
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, HOME=tmp)
            return subprocess.run(
                ["/bin/sh", "-c", cmd],
                input=json.dumps(payload),
                capture_output=True,
                text=True,
                cwd=str(RTK_PLUGIN),
                env=env,
                check=False,
            )

    def test_plugin_files_present(self) -> None:
        self.assertTrue((RTK_PLUGIN / "plugin.json").is_file())
        self.assertTrue((RTK_PLUGIN / "hooks.json").is_file())
        self.assertTrue((RTK_PLUGIN / "rules" / "AGENTS.md").is_file())

    def test_rewrites_supported_command(self) -> None:
        res = self._run_hook(
            {
                "toolCall": {
                    "id": "r1",
                    "name": "run_command",
                    "args": {"CommandLine": "git status"},
                },
                "cwd": "/tmp",
                "hookEventName": "PreToolUse",
            }
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        decision = json.loads(res.stdout)
        self.assertEqual(decision.get("decision"), "allow")
        self.assertEqual(decision.get("overwrite"), {"CommandLine": "rtk git status"})

    def test_passes_through_unsupported_command(self) -> None:
        res = self._run_hook(
            {
                "toolCall": {
                    "id": "r2",
                    "name": "run_command",
                    "args": {"CommandLine": "echo hello"},
                },
                "cwd": "/tmp",
                "hookEventName": "PreToolUse",
            }
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        decision = json.loads(res.stdout)
        self.assertEqual(decision.get("decision"), "allow")
        self.assertNotIn("overwrite", decision)


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


if __name__ == "__main__":
    unittest.main()
