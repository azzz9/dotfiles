#!/usr/bin/env python3
"""Exercise bootstrap in isolated PATHs without touching the host system."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SETUP = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).with_name("setup-system.sh")
BASH = shutil.which("bash")


class BootstrapTests(unittest.TestCase):
    def run_setup(self, distro="nixos", tools=("nix",), checkout=False,
                  stdin=False, root=False, sudo=True, build_fail=False,
                  clone_fail=False, conflicting_target=False):
        with tempfile.TemporaryDirectory(prefix="bootstrap-test-") as scratch:
            base = Path(scratch)
            home = base / "home"
            home.mkdir()
            commands = base / "bin"
            commands.mkdir()
            fixtures = base / "fixtures"
            fixtures.mkdir()
            log = base / "calls"
            os_release = base / "os-release"
            os_release.write_text(f"ID={distro}\nVERSION_CODENAME=test\n")
            repo = home / "src/github.com/azzz9/dotfiles"
            (base / "downloads").mkdir()
            script = base / "downloads/renamed-bootstrap.sh"
            if checkout:
                repo = base / "existing-checkout"
                (repo / ".git").mkdir(parents=True)
                (repo / "scripts").mkdir()
                script = repo / "scripts/renamed-bootstrap.sh"
            elif conflicting_target:
                repo.mkdir(parents=True)
                (repo / "keep.txt").write_text("keep")
            source = SETUP.read_text().replace("/etc/os-release", str(os_release))
            source = source.replace("/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh", str(base / "no-profile"))
            source = source.replace('"$EUID"', '"$TEST_EUID"')
            source = source.replace('/bin/bash -c', f'{BASH} -c')
            script.write_text(source)

            # Only OS base utilities are exposed. Git, curl, Nix, Homebrew,
            # and package managers are absent until a fixture provides them.
            for name in ("bash", "sh", "dirname", "mkdir", "ln", "cat", "grep", "basename"):
                (commands / name).symlink_to(shutil.which(name))
            preamble = (
                f"#!{BASH}\nset -euo pipefail\n"
                'printf "%s %s\\n" "${0##*/}" "$*" >> "$TEST_LOG"\n'
                'provide() { ln -sf "$TEST_FIXTURES/$1" "$TEST_BIN/$1"; }\n'
            )
            bodies = {
                "uname": 'if [[ "$1" == -s ]]; then echo "$TEST_OS"; else echo "$TEST_ARCH"; fi\n',
                "git": '''
if [[ "$1" == -C ]]; then
  if [[ -d "$2/.git" ]]; then (cd "$2" && pwd); else exit 1; fi
elif [[ "$1" == clone ]]; then
  [[ "$TEST_CLONE_FAIL" == 0 ]] || exit 1
  mkdir -p "${@: -1}/.git"
fi
''',
                "nix": '''
printf 'config %s\\n' "$NIX_CONFIG" >> "$TEST_LOG"
if [[ "$3" == build ]]; then
  [[ "$TEST_BUILD_FAIL" == 0 ]] || exit 1
  for arg in "$@"; do
    case "$arg" in nixpkgs#*) echo "$TEST_FIXTURES/packages/${arg#nixpkgs#}" ;; esac
  done
elif [[ "$3" == run ]]; then
  command -v git >/dev/null
  command -v curl >/dev/null
  [[ -d "$DOTFILES_DIR/.git" ]]
  printf 'apply %s\\n' "$DOTFILES_DIR" >> "$TEST_LOG"
fi
''',
                "curl": '''
case "$*" in
  *install.determinate.systems*) printf 'ln -sf "%s/nix" "%s/nix"\\n' "$TEST_FIXTURES" "$TEST_BIN" ;;
  *Homebrew/install*) printf 'ln -sf "%s/brew" "%s/brew"\\n' "$TEST_FIXTURES" "$TEST_BIN" ;;
  *) echo fixture ;;
esac
''',
                "sudo": '"$@"\n',
                "apt-get": '''
if [[ "$1" == install ]]; then
  for arg in "$@"; do
    case "$arg" in curl|zsh) provide "$arg" ;; gnupg) provide gpg ;; esac
  done
fi
''',
                "pacman": '''
for arg in "$@"; do
  case "$arg" in curl|zsh) provide "$arg" ;; esac
done
''',
                "brew": '''
if [[ "$1" == list ]]; then
  [[ "$2" == zsh ]] && command -v zsh >/dev/null
elif [[ "$1" == install && "$2" == zsh ]]; then
  provide zsh
fi
''',
                "dpkg": "echo amd64\n",
                "tee": "cat >/dev/null\n",
                "gpg": "cat >/dev/null\n",
            }
            for name in ("zsh", "install", "chmod", "systemctl", "usermod", "chsh"):
                bodies[name] = ":\n"
            for name, body in bodies.items():
                mock = fixtures / name
                mock.write_text(preamble + body)
                mock.chmod(0o755)
            for name in ("git", "curl"):
                package_bin = fixtures / "packages" / name / "bin"
                package_bin.mkdir(parents=True)
                (package_bin / name).symlink_to(fixtures / name)
            available = list(tools) + ["uname"]
            if distro == "ubuntu":
                available += ["apt-get", "dpkg", "install", "chmod", "tee", "systemctl", "usermod", "chsh"]
            elif distro == "arch":
                available += ["pacman", "systemctl", "usermod", "chsh"]
            elif distro == "macos":
                available += ["curl", "tee", "chsh"]  # macOS includes curl.
            if sudo:
                available += ["sudo"]
            for name in set(available):
                (commands / name).symlink_to(fixtures / name)
            env = os.environ.copy()
            env.update(
                PATH=str(commands), HOME=str(home), USER="test", SHELL="/bin/bash",
                NIX_CONFIG="max-jobs = 2", GIT_NAME="test", GIT_EMAIL="test@example.invalid",
                TEST_OS="Darwin" if distro == "macos" else "Linux",
                TEST_ARCH="arm64" if distro == "macos" else "x86_64",
                TEST_BIN=str(commands), TEST_FIXTURES=str(fixtures), TEST_LOG=str(log),
                TEST_EUID="0" if root else "1000", TEST_BUILD_FAIL=str(int(build_fail)),
                TEST_CLONE_FAIL=str(int(clone_fail)),
            )
            for name in ("DOTFILES_DIR", "HM_HOST", "REBOOT", "BASH_ENV", "ENV"):
                env.pop(name, None)
            result = subprocess.run(
                [BASH, "-s"] if stdin else [BASH, str(script)],
                input=source if stdin else None, env=env, text=True,
                capture_output=True, timeout=20,
            )
            calls = log.read_text() if log.exists() else ""
            if conflicting_target:
                self.assertEqual((repo / "keep.txt").read_text(), "keep")
            return result, calls, str(repo)

    def assert_success(self, result, calls, repo):
        self.assertEqual(result.returncode, 0, result.stderr + "\n" + calls)
        self.assertIn(f"apply {repo}\n", calls)
        self.assertIn("max-jobs = 2\nextra-experimental-features = nix-command flakes", calls)

    def test_nixos_missing_tools(self):
        for tools in (("nix",), ("nix", "git"), ("nix", "curl"), ("nix", "git", "curl")):
            with self.subTest(tools=tools):
                result, calls, repo = self.run_setup(tools=tools)
                self.assert_success(result, calls, repo)
                builds = [line for line in calls.splitlines() if line.startswith("nix ") and " build " in line]
                for name in ("git", "curl"):
                    self.assertEqual(any(f"nixpkgs#{name}" in line for line in builds), name not in tools)

    def test_existing_checkout_detected_after_git_bootstrap(self):
        result, calls, repo = self.run_setup(checkout=True)
        self.assert_success(result, calls, repo)
        self.assertNotIn("git clone", calls)

    def test_stdin_without_git_or_curl(self):
        result, calls, repo = self.run_setup(stdin=True)
        self.assert_success(result, calls, repo)

    def test_other_platforms_without_development_tools(self):
        for distro in ("ubuntu", "arch", "macos"):
            with self.subTest(distro=distro):
                result, calls, repo = self.run_setup(distro=distro, tools=())
                self.assert_success(result, calls, repo)
                self.assertLess(calls.index("curl "), calls.index("git config "))
                self.assertIn("nixpkgs#git", calls)

    def test_root_without_sudo(self):
        result, calls, repo = self.run_setup(distro="ubuntu", tools=(), root=True, sudo=False)
        self.assert_success(result, calls, repo)
        self.assertNotIn("sudo ", calls)

    def test_missing_administrator_access(self):
        result, calls, _ = self.run_setup(distro="ubuntu", tools=(), sudo=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("administrator access", result.stderr)
        self.assertNotIn("apt-get ", calls)

    def test_failed_bootstrap_stops_before_git_and_activation(self):
        result, calls, _ = self.run_setup(build_fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("git config", calls)
        self.assertNotIn("apply ", calls)

    def test_failed_clone_stops_before_activation(self):
        result, calls, _ = self.run_setup(clone_fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("apply ", calls)

    def test_existing_non_repository_is_preserved(self):
        result, calls, _ = self.run_setup(conflicting_target=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exists but is not a git repository", result.stderr)
        self.assertNotIn("git clone", calls)

    def test_unsupported_distribution_stops_early(self):
        result, calls, _ = self.run_setup(distro="fedora", tools=())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unsupported Linux distribution", result.stderr)
        self.assertNotIn("git ", calls)
        self.assertNotIn("nix ", calls)


if __name__ == "__main__":
    unittest.main()
