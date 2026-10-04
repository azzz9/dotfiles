#!/usr/bin/env python3
"""Exercise bootstrap in isolated PATHs without touching the host system."""

import contextlib
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
                  clone_fail=False, conflicting_target=False,
                  dotfiles_dir=None, existing_target=False, nixos_machine=None,
                  machine_entry=True, machine_hardware=True, nixos_config=True,
                  scratch_dir=None, hm_host=None, test_arch=None):
        scratch_ctx = (tempfile.TemporaryDirectory(prefix="bootstrap-test-")
                       if scratch_dir is None else contextlib.nullcontext(scratch_dir))
        with scratch_ctx as scratch:
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
            repo = base / dotfiles_dir if dotfiles_dir else home / "src/github.com/azzz9/dotfiles"
            (base / "downloads").mkdir()
            script = base / "downloads/renamed-bootstrap.sh"
            execution_checkout = base / "existing-checkout"
            if checkout:
                (execution_checkout / ".git").mkdir(parents=True)
                (execution_checkout / ".git/HEAD").write_text("ref: refs/heads/main\n")
                (execution_checkout / "keep.txt").write_text("local changes")
                (execution_checkout / "scripts").mkdir()
                script = execution_checkout / "scripts/renamed-bootstrap.sh"
            if existing_target:
                (repo / ".git").mkdir(parents=True)
                (repo / ".git/HEAD").write_text("ref: refs/heads/main\n")
            if existing_target or conflicting_target:
                repo.mkdir(parents=True, exist_ok=True)
                (repo / "keep.txt").write_text("keep")
            # The machine tree lands in a checkout the caller already created,
            # because a repo path that exists without .git is a bootstrap error.
            if machine_entry and repo.is_dir():
                machine_dir = repo / "nixos/machines/desktop"
                machine_dir.mkdir(parents=True)
                (machine_dir / "default.nix").write_text("{ }\n")
                if machine_hardware:
                    (machine_dir / "hardware-configuration.nix").write_text("{ }\n")
            # Not fixtures/etc/nixos, because the rewrite check below rejects a
            # host path that survives as a substring of its own replacement.
            etc_nixos = fixtures / "system-etc"
            if nixos_config:
                etc_nixos.mkdir(parents=True)
                (etc_nixos / "configuration.nix").write_text("{ }\n")
            source = SETUP.read_text()
            # Host paths a test run must not follow, because the tools they point
            # at are not the fixtures. Homebrew especially, since a runner that
            # has it installed reaches the real brew and its read-only Cellar.
            host_paths = {
                "/etc/os-release": str(os_release),
                "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh": str(base / "no-profile"),
                "/opt/homebrew/bin/brew": str(base / "no-brew"),
                "/usr/local/bin/brew": str(base / "no-brew"),
                "/etc/nixos": str(etc_nixos),
            }
            for host_path, replacement in host_paths.items():
                source = source.replace(host_path, replacement)
            missed = [path for path in host_paths if path in source]
            if missed:
                raise AssertionError(f"fixture rewrite missed {missed}")
            source = source.replace('"$EUID"', '"$TEST_EUID"')
            source = source.replace('/bin/bash -c', f'{BASH} -c')
            script.write_text(source)
            if checkout:
                checkout_before = {
                    str(path.relative_to(execution_checkout)): path.read_bytes() if path.is_file() else None
                    for path in execution_checkout.rglob("*")
                }

            # Only OS base utilities are exposed. Git, curl, Nix, Homebrew,
            # and package managers are absent until a fixture provides them.
            for name in ("bash", "sh", "dirname", "mkdir", "ln", "cat", "grep", "basename",
                         "mv", "readlink"):
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
                DOTFILES_REPO_URL="https://github.com/azzz9/dotfiles.git",
                TEST_OS="Darwin" if distro == "macos" else "Linux",
                TEST_ARCH=test_arch or ("arm64" if distro == "macos" else "x86_64"),
                TEST_BIN=str(commands), TEST_FIXTURES=str(fixtures), TEST_LOG=str(log),
                TEST_EUID="0" if root else "1000", TEST_BUILD_FAIL=str(int(build_fail)),
                TEST_CLONE_FAIL=str(int(clone_fail)),
                NIXOS_MACHINE=nixos_machine or "",
            )
            for name in ("DOTFILES_DIR", "HM_HOST", "REBOOT", "BASH_ENV", "ENV"):
                env.pop(name, None)
            if dotfiles_dir is not None:
                env["DOTFILES_DIR"] = str(repo) if dotfiles_dir else ""
            if hm_host is not None:
                env["HM_HOST"] = hm_host
            result = subprocess.run(
                [BASH, "-s"] if stdin else [BASH, str(script)],
                input=source if stdin else None, env=env, text=True,
                capture_output=True, timeout=20,
            )
            calls = log.read_text() if log.exists() else ""
            if checkout:
                self.assertTrue(execution_checkout.is_dir())
                checkout_after = {
                    str(path.relative_to(execution_checkout)): path.read_bytes() if path.is_file() else None
                    for path in execution_checkout.rglob("*")
                }
                self.assertEqual(checkout_after, checkout_before)
            if existing_target or conflicting_target:
                self.assertEqual((repo / "keep.txt").read_text(), "keep")
            if existing_target:
                self.assertEqual((repo / ".git/HEAD").read_text(), "ref: refs/heads/main\n")
            if result.returncode == 0:
                self.assertTrue((repo / ".git").is_dir())
            return result, calls, str(repo)

    def assert_success(self, result, calls, repo):
        self.assertEqual(result.returncode, 0, result.stderr + "\n" + calls)
        self.assertIn(f"apply {repo}\n", calls)
        self.assertIn(f"-- switch --flake {repo}#", calls)
        self.assertIn("max-jobs = 2\nextra-experimental-features = nix-command flakes", calls)

    def test_nixos_missing_tools(self):
        for tools in (("nix",), ("nix", "git"), ("nix", "curl"), ("nix", "git", "curl")):
            with self.subTest(tools=tools):
                result, calls, repo = self.run_setup(tools=tools)
                self.assert_success(result, calls, repo)
                builds = [line for line in calls.splitlines() if line.startswith("nix ") and " build " in line]
                for name in ("git", "curl"):
                    self.assertEqual(any(f"nixpkgs#{name}" in line for line in builds), name not in tools)

    def test_outside_ghq_checkout_uses_default_target_without_moving_source(self):
        for tools in (("nix",), ("nix", "git", "curl")):
            with self.subTest(tools=tools):
                result, calls, repo = self.run_setup(checkout=True, tools=tools)
                self.assert_success(result, calls, repo)
                self.assertIn(f"git clone https://github.com/azzz9/dotfiles.git {repo}\n", calls)

    def test_explicit_override_outside_ghq(self):
        for existing_target in (False, True):
            with self.subTest(existing_target=existing_target):
                result, calls, repo = self.run_setup(
                    checkout=True, dotfiles_dir="custom dotfiles", existing_target=existing_target,
                )
                self.assert_success(result, calls, repo)
                if existing_target:
                    self.assertNotIn("git clone", calls)
                else:
                    self.assertIn(f"git clone https://github.com/azzz9/dotfiles.git {repo}\n", calls)

    def test_explicit_override_can_reuse_execution_checkout(self):
        result, calls, repo = self.run_setup(checkout=True, dotfiles_dir="existing-checkout")
        self.assert_success(result, calls, repo)
        self.assertNotIn("git clone", calls)

    def test_existing_default_target_is_reused(self):
        result, calls, repo = self.run_setup(checkout=True, existing_target=True)
        self.assert_success(result, calls, repo)
        self.assertNotIn("git clone", calls)

    def test_empty_override_uses_default_target(self):
        result, calls, repo = self.run_setup(checkout=True, dotfiles_dir="")
        self.assert_success(result, calls, repo)
        self.assertIn(f"git clone https://github.com/azzz9/dotfiles.git {repo}\n", calls)

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

    def test_intel_mac_fails_before_installing_packages(self):
        result, calls, _ = self.run_setup(distro="macos", tools=(), test_arch="x86_64")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not supported", result.stderr)
        self.assertNotIn("curl ", calls)

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

    def test_nixos_system_configuration_is_wired(self):
        with tempfile.TemporaryDirectory(prefix="bootstrap-wiring-") as scratch:
            result, calls, repo = self.run_setup(
                nixos_machine="desktop", existing_target=True, scratch_dir=scratch,
            )
            self.assert_success(result, calls, repo)
            target = Path(scratch) / "fixtures/system-etc/configuration.nix"
            entry = Path(repo) / "nixos/machines/desktop/default.nix"
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.with_name("configuration.nix.before-dotfiles").read_text(), "{ }\n")
            self.assertEqual(os.path.realpath(target), os.path.realpath(entry))
            self.assertIn(f"sudo mv {target} {target}.before-dotfiles\n", calls)
            self.assertIn(f"sudo ln -sfn {os.path.realpath(entry)} {target}\n", calls)

    def test_nixos_unknown_machine_lists_available(self):
        result, calls, _ = self.run_setup(nixos_machine="nope", existing_target=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Available machines: desktop", result.stderr)
        self.assertNotIn("ln -sfn", calls)
        self.assertNotIn("mv ", calls)

    def test_nixos_missing_hardware_configuration_is_reported(self):
        with tempfile.TemporaryDirectory(prefix="bootstrap-hardware-") as scratch:
            result, calls, repo = self.run_setup(
                nixos_machine="desktop", existing_target=True,
                machine_hardware=False, scratch_dir=scratch,
            )
            self.assertNotEqual(result.returncode, 0)
            target = Path(scratch) / "fixtures/system-etc/configuration.nix"
            hardware = Path(repo) / "nixos/machines/desktop/hardware-configuration.nix"
            self.assertIn("nixos-generate-config", result.stderr)
            self.assertIn(f"cp /tmp/hardware-configuration.nix {hardware}", result.stderr)
            self.assertFalse(target.is_symlink())
            self.assertFalse(target.with_name("configuration.nix.before-dotfiles").exists())

    def test_other_distributions_ignore_the_machine_name(self):
        result, calls, repo = self.run_setup(distro="ubuntu", nixos_machine="desktop")
        self.assert_success(result, calls, repo)
        self.assertIn(f"-- switch --flake {repo}#x86_64-linux", calls)
        self.assertNotIn("nixos/machines", calls)

    def test_nixos_machine_names_the_home_manager_attribute(self):
        result, calls, repo = self.run_setup(nixos_machine="desktop", existing_target=True)
        self.assert_success(result, calls, repo)
        self.assertIn(f"-- switch --flake {repo}#desktop", calls)

    def test_explicit_home_manager_host_wins_over_the_machine_name(self):
        result, calls, repo = self.run_setup(
            nixos_machine="desktop", existing_target=True, hm_host="x86_64-linux",
        )
        self.assert_success(result, calls, repo)
        self.assertIn(f"-- switch --flake {repo}#x86_64-linux", calls)


if __name__ == "__main__":
    unittest.main()
