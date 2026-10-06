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

# The checkout the fixtures build. The adoption inserts the machine row between
# the `machines` line and the closing brace at the same indentation.
FLAKE = """{
  outputs =
    { ... }:
    let
      machines = {
        nix-server = { system = "x86_64-linux"; };
      };
    in
    {
      inherit machines;
    };
}
"""

# What the installer leaves in /etc/nixos on a machine that drives a GUI.
GUI_CONFIG = """{ config, pkgs, lib, ... }:

{
  networking.hostName = "installer-name"; # Define your hostname.
  services.displayManager.sddm.enable = true;
  users.users.azzz.shell = pkgs.zsh;
}
"""

ADOPTED_DEFAULT = """{ ... }:

{
  imports = [
    ../../modules/common.nix
    ../../modules/desktop.nix
    ./configuration.nix
  ];

  networking.hostName = "nix-desktop";
}
"""


class BootstrapTests(unittest.TestCase):
    def run_setup(self, distro="nixos", tools=("nix",), checkout=False,
                  stdin=False, root=False, sudo=True, build_fail=False,
                  clone_fail=False, conflicting_target=False,
                  dotfiles_dir=None, existing_target=False, machine="nix-desktop",
                  machine_entry=True, machine_hardware=True, nixos_config=True,
                  nixos_config_body="{ }\n", capability=None, repeat=False,
                  scratch_dir=None, hostname="nix-desktop", test_arch=None,
                  flake_machines="nix-desktop macbook nix-server", flake_fail=False):
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
            # The tree the fixtures build: the flake the adoption edits, and the
            # machine directory when this machine is already in the repository.
            # A path that exists without .git is a bootstrap error, so a caller
            # that already created the target gets the tree copied into it, and a
            # clone lands it through the git stub below.
            skeleton = base / "repo-skeleton"
            (skeleton / "hosts/platform/nixos/machines").mkdir(parents=True)
            (skeleton / "flake.nix").write_text(FLAKE)
            if machine_entry:
                machine_dir = skeleton / "hosts/platform/nixos/machines/nix-desktop"
                machine_dir.mkdir()
                (machine_dir / "default.nix").write_text("{ }\n")
                if machine_hardware:
                    (machine_dir / "hardware-configuration.nix").write_text("{ }\n")
            if repo.is_dir():
                shutil.copytree(skeleton, repo, dirs_exist_ok=True)
            # Not fixtures/etc/nixos, because the rewrite check below rejects a
            # host path that survives as a substring of its own replacement.
            # /etc/hosts sits beside it: the Linux paths rewrite its 127.0.1.1
            # line, and this file is what they rewrite.
            etc_nixos = fixtures / "system-etc"
            etc_hosts = etc_nixos / "hosts"
            etc_nixos.mkdir(parents=True)
            etc_hosts.write_text("127.0.0.1\tlocalhost\n127.0.1.1\tinstaller-name\n")
            if nixos_config:
                (etc_nixos / "configuration.nix").write_text(nixos_config_body)
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
                "/etc/hosts": str(etc_hosts),
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
                         "mv", "readlink", "cp", "rm", "env"):
                (commands / name).symlink_to(shutil.which(name))
            preamble = (
                f"#!{BASH}\nset -euo pipefail\n"
                'printf "%s %s\\n" "${0##*/}" "$*" >> "$TEST_LOG"\n'
                'provide() { ln -sf "$TEST_FIXTURES/$1" "$TEST_BIN/$1"; }\n'
            )
            bodies = {
                "uname": 'if [[ "$1" == -s ]]; then echo "$TEST_OS"; else echo "$TEST_ARCH"; fi\n',
                # A platform that changes the hostname writes the new name here,
                # so the script reads back what it set, as it would on the machine.
                "hostname": '''
if [[ -s "$TEST_HOSTNAME_FILE" ]]; then cat "$TEST_HOSTNAME_FILE"; else printf "%s\\n" "$TEST_HOSTNAME"; fi
''',
                "hostnamectl": '''
if [[ "$1" == set-hostname ]]; then printf "%s\\n" "$2" > "$TEST_HOSTNAME_FILE"; fi
''',
                "scutil": '''
if [[ "$1" == --set ]]; then printf "%s\\n" "$3" > "$TEST_HOSTNAME_FILE"; fi
''',
                "git": '''
if [[ "$1" == -C ]]; then
  if [[ -d "$2/.git" ]]; then (cd "$2" && pwd); else exit 1; fi
elif [[ "$1" == clone ]]; then
  [[ "$TEST_CLONE_FAIL" == 0 ]] || exit 1
  mkdir -p "${@: -1}/.git"
  cp -r "$TEST_REPO_SKELETON/." "${@: -1}/"
fi
''',
                "nix": '''
printf 'config %s\\n' "$NIX_CONFIG" >> "$TEST_LOG"
if [[ "$3" == build ]]; then
  [[ "$TEST_BUILD_FAIL" == 0 ]] || exit 1
  for arg in "$@"; do
    case "$arg" in nixpkgs#*) echo "$TEST_FIXTURES/packages/${arg#nixpkgs#}" ;; esac
  done
elif [[ "$3" == eval ]]; then
  # What nix reports for the homeConfigurations attr names the script asks for.
  [[ "$TEST_FLAKE_FAIL" == 0 ]] || exit 1
  printf '%s\\n' "$TEST_FLAKE_MACHINES"
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
                "nixos-generate-config": '''
cat <<GEN
# Do not modify this file!  It was generated by nixos-generate-config
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, modulesPath, pkgs, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = { device = "/dev/disk/by-uuid/test"; fsType = "ext4"; };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
GEN
''',
                "dpkg": "echo amd64\n",
                "tee": '''
append=0
if [[ "$1" == -a || "$1" == --append ]]; then append=1; shift; fi
target="$1"
case "$target" in
  # A path inside the scratch tree is a fixture a test wants written. A real
  # system path stays untouched, because this run is not that system's.
  "$TEST_FIXTURES"/*) if [[ "$append" == 1 ]]; then cat >> "$target"; else cat > "$target"; fi ;;
  *) cat > /dev/null ;;
esac
''',
                "gpg": "cat >/dev/null\n",
            }
            for name in ("zsh", "install", "chmod", "systemctl", "usermod", "chsh", "nixos-rebuild"):
                bodies[name] = ":\n"
            for name, body in bodies.items():
                mock = fixtures / name
                mock.write_text(preamble + body)
                mock.chmod(0o755)
            for name in ("git", "curl"):
                package_bin = fixtures / "packages" / name / "bin"
                package_bin.mkdir(parents=True)
                (package_bin / name).symlink_to(fixtures / name)
            available = list(tools) + ["uname", "hostname"]
            if distro == "ubuntu":
                available += ["apt-get", "dpkg", "install", "chmod", "tee", "systemctl",
                              "usermod", "chsh", "hostnamectl"]
            elif distro == "arch":
                available += ["pacman", "systemctl", "usermod", "chsh", "hostnamectl", "tee"]
            elif distro == "nixos":
                # No hostnamectl and no scutil here: the NixOS system switch sets
                # the hostname, so the bootstrap must not reach for either.
                available += ["nixos-generate-config", "nixos-rebuild"]
            elif distro == "macos":
                available += ["curl", "tee", "chsh", "scutil"]  # macOS includes curl.
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
                MACHINE=machine, MACHINE_CAPABILITY=capability or "",
                TEST_HOSTNAME=hostname, TEST_HOSTNAME_FILE=str(base / "synced-hostname"),
                TEST_FLAKE_MACHINES=flake_machines, TEST_FLAKE_FAIL=str(int(flake_fail)),
                TEST_REPO_SKELETON=str(skeleton),
            )
            for name in ("DOTFILES_DIR", "REBOOT", "BASH_ENV", "ENV"):
                env.pop(name, None)
            if dotfiles_dir is not None:
                env["DOTFILES_DIR"] = str(repo) if dotfiles_dir else ""
            def invoke():
                return subprocess.run(
                    [BASH, "-s"] if stdin else [BASH, str(script)],
                    input=source if stdin else None, env=env, text=True,
                    capture_output=True, timeout=20,
                )

            def repo_state():
                return {str(path.relative_to(repo)): path.read_bytes()
                        for path in repo.rglob("*") if path.is_file()}

            result = invoke()
            calls = log.read_text() if log.exists() else ""
            if repeat:
                # The second run finds the machine complete, so nothing changes.
                self.assertEqual(result.returncode, 0, result.stderr + "\n" + calls)
                first_state = repo_state()
                first_calls = calls
                result = invoke()
                self.assertEqual(repo_state(), first_state)
                calls = log.read_text()[len(first_calls):]
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

    def persistent_scratch(self):
        # The default scratch directory is removed when run_setup returns, so a
        # test that reads back the files the bootstrap wrote keeps its own.
        scratch = tempfile.mkdtemp(prefix="bootstrap-test-")
        self.addCleanup(shutil.rmtree, scratch, ignore_errors=True)
        return scratch

    def assert_success(self, result, calls, repo):
        self.assertEqual(result.returncode, 0, result.stderr + "\n" + calls)
        self.assertIn(f"apply {repo}\n", calls)
        self.assertIn(f"-- switch --flake {repo}#", calls)
        self.assertIn("max-jobs = 2\nextra-experimental-features = nix-command flakes", calls)

    def assert_nix_parses(self, path):
        # The bootstrap check sandbox carries python3, bash, coreutils, and grep,
        # so only an environment with Nix on PATH parses for real. The caller
        # pins the file's text either way.
        nix = shutil.which("nix-instantiate")
        if nix is None:
            return
        parsed = subprocess.run([nix, "--parse", str(path)],
                                capture_output=True, text=True, timeout=60)
        self.assertEqual(parsed.returncode, 0, parsed.stderr)

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

    def test_nixos_complete_machine_applies_the_system(self):
        result, calls, repo = self.run_setup(machine="nix-desktop", existing_target=True)
        self.assert_success(result, calls, repo)
        self.assertIn(
            f"sudo env NIX_CONFIG=extra-experimental-features = nix-command flakes "
            f"nixos-rebuild switch --flake {repo}#nix-desktop --impure\n", calls)
        self.assertNotIn("nixos-rebuild switch --flake", result.stdout)
        self.assertNotIn("nixos-generate-config", calls)
        self.assertNotIn(" add ", calls)
        self.assertNotIn("ln -sfn", calls)

    def test_nixos_missing_machine_is_adopted(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, nixos_config_body=GUI_CONFIG,
            scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        machine_dir = Path(repo) / "hosts/platform/nixos/machines/nix-desktop"
        default = machine_dir / "default.nix"
        self.assertEqual(default.read_text(), ADOPTED_DEFAULT)
        self.assertTrue((machine_dir / "configuration.nix").is_file())
        self.assertTrue((machine_dir / "hardware-configuration.nix").is_file())
        self.assert_nix_parses(default)
        # Every import names a file the repository actually carries.
        repo_root = SETUP.resolve().parent.parent
        for imported in ("common.nix", "desktop.nix"):
            self.assertTrue((repo_root / "hosts/platform/nixos/modules" / imported).is_file())
        flake = (Path(repo) / "flake.nix").read_text()
        self.assertIn("        nix-desktop = { system = \"x86_64-linux\"; "
                      "nixos = ./hosts/platform/nixos/machines/nix-desktop; };\n", flake)
        self.assertLess(flake.index("nixos = ./hosts/platform"), flake.index("      };"))
        # Nix sees tracked files only, and the switch evaluates the flake.
        self.assertLess(calls.index(f"git -C {repo} add --"),
                        calls.index("nixos-rebuild switch"))

    def test_nixos_gui_configuration_picks_the_desktop_module(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, nixos_config_body=GUI_CONFIG,
            scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        default = (Path(repo) / "hosts/platform/nixos/machines/nix-desktop"
                   / "default.nix").read_text()
        self.assertIn("../../modules/desktop.nix", default)
        self.assertIn("services.displayManager", result.stdout)

    def test_nixos_plain_configuration_picks_the_headless_module(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        default = (Path(repo) / "hosts/platform/nixos/machines/nix-desktop"
                   / "default.nix").read_text()
        self.assertIn("../../modules/headless.nix", default)
        self.assertIn("drives no GUI", result.stdout)

    def test_nixos_capability_override_wins(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, capability="desktop",
            scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        default = (Path(repo) / "hosts/platform/nixos/machines/nix-desktop"
                   / "default.nix").read_text()
        self.assertIn("../../modules/desktop.nix", default)
        self.assertIn("MACHINE_CAPABILITY=desktop", result.stdout)

    def test_nixos_generated_hardware_file_drops_header_and_unused_arguments(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        hardware = (Path(repo) / "hosts/platform/nixos/machines/nix-desktop"
                    / "hardware-configuration.nix").read_text()
        self.assertTrue(hardware.startswith("{ config, lib, modulesPath, ... }:\n"), hardware)
        self.assertNotIn("/etc/nixos", hardware)
        self.assertIn('nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";', hardware)
        self.assertIn("hardware.cpu.intel.updateMicrocode", hardware)

    def test_nixos_copied_configuration_keeps_everything_but_the_name(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, nixos_config_body=GUI_CONFIG,
            scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        copied = (Path(repo) / "hosts/platform/nixos/machines/nix-desktop"
                  / "configuration.nix").read_text()
        self.assertNotIn("networking.hostName", copied)
        self.assertIn("users.users.azzz.shell = pkgs.zsh;", copied)
        self.assertIn("services.displayManager.sddm.enable = true;", copied)

    def test_nixos_adoption_is_idempotent(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, repeat=True,
        )
        self.assert_success(result, calls, repo)
        self.assertIn("already has a system configuration", result.stdout)
        self.assertNotIn("nixos-generate-config", calls)
        self.assertNotIn(" add ", calls)

    def test_nixos_machine_without_a_hardware_file_is_completed(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_hardware=False, nixos_config_body=GUI_CONFIG,
            scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        machine_dir = Path(repo) / "hosts/platform/nixos/machines/nix-desktop"
        # A machine directory without its hardware file is incomplete, so the
        # adoption writes all three files, default.nix included.
        self.assertEqual((machine_dir / "default.nix").read_text(), ADOPTED_DEFAULT)
        self.assertTrue((machine_dir / "configuration.nix").is_file())
        self.assertTrue((machine_dir / "hardware-configuration.nix").is_file())

    def test_nixos_machine_with_its_own_row_is_left_alone(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, machine="nix-server",
            scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        self.assertIn("already carries the machines.nix-server row", result.stdout)
        self.assertEqual((Path(repo) / "flake.nix").read_text().count("nix-server = {"), 1)

    def test_nixos_without_a_system_configuration_stops_before_writing(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, nixos_config=False,
            scratch_dir=self.persistent_scratch(),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Cannot adopt this machine", result.stderr)
        self.assertFalse((Path(repo) / "hosts/platform/nixos/machines/nix-desktop").exists())
        self.assertNotIn(" apply ", calls)

    def test_other_distributions_use_the_machine_name(self):
        result, calls, repo = self.run_setup(distro="ubuntu", machine="nix-desktop")
        self.assert_success(result, calls, repo)
        self.assertIn(f"-- switch --flake {repo}#nix-desktop", calls)
        self.assertNotIn("hosts/platform/nixos", calls)

    def test_missing_machine_stops_before_installing_and_applying(self):
        # The hostname no longer supplies the machine, so an unset MACHINE is an
        # error on every platform, before a package manager runs.
        for distro in ("macos", "ubuntu"):
            with self.subTest(distro=distro):
                result, calls, _ = self.run_setup(distro=distro, tools=(), machine="")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Set MACHINE", result.stderr)
                self.assertNotIn("install.sh", calls)
                self.assertNotIn("apt-get ", calls)
                self.assertNotIn("home-manager", calls)

    def test_machine_the_repository_does_not_carry_is_fatal_off_nixos(self):
        for distro, system in (("macos", "aarch64-darwin"), ("ubuntu", "x86_64-linux")):
            with self.subTest(distro=distro):
                result, calls, _ = self.run_setup(distro=distro, tools=(), machine="newbox")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Machines in flake.nix: nix-desktop macbook nix-server",
                              result.stderr)
                self.assertIn(f'        newbox = {{ system = "{system}"; }};', result.stderr)
                self.assertNotIn("home-manager", calls)

    def test_nixos_adopts_a_machine_the_repository_does_not_carry_yet(self):
        result, calls, repo = self.run_setup(
            existing_target=True, machine_entry=False, machine="newbox", hostname="newbox",
            nixos_config_body=GUI_CONFIG, scratch_dir=self.persistent_scratch(),
        )
        self.assert_success(result, calls, repo)
        self.assertIn("does not carry 'newbox' yet", result.stdout)
        machine_dir = Path(repo) / "hosts/platform/nixos/machines/newbox"
        self.assertIn('networking.hostName = "newbox";',
                      (machine_dir / "default.nix").read_text())
        self.assertIn('        newbox = { system = "x86_64-linux"; '
                      'nixos = ./hosts/platform/nixos/machines/newbox; };',
                      (Path(repo) / "flake.nix").read_text())

    def test_macos_sets_the_hostname_from_the_machine(self):
        scratch = self.persistent_scratch()
        result, calls, repo = self.run_setup(
            distro="macos", machine="macbook", hostname="azzz-mac.local", scratch_dir=scratch,
        )
        self.assert_success(result, calls, repo)
        self.assertIn(f"-- switch --flake {repo}#macbook", calls)
        self.assertIn("scutil --set HostName macbook\n", calls)
        self.assertIn("scutil --set LocalHostName macbook\n", calls)
        # The run reads the hostname back, so it ends with the two names agreeing.
        self.assertEqual((Path(scratch) / "synced-hostname").read_text(), "macbook\n")
        self.assertIn("so 'dotfiles' needs no argument", result.stdout)

    def test_macos_hostname_with_the_mdns_suffix_is_already_the_machine(self):
        # macOS reports an mDNS name; the .local suffix is not part of the name,
        # so this Mac is named macbook and nothing needs setting.
        result, calls, repo = self.run_setup(distro="macos", machine="macbook",
                                            hostname="macbook.local")
        self.assert_success(result, calls, repo)
        self.assertNotIn("scutil", calls)
        self.assertIn("so 'dotfiles' needs no argument", result.stdout)

    def test_linux_sets_the_hostname_and_the_hosts_entry_from_the_machine(self):
        for distro in ("ubuntu", "arch"):
            with self.subTest(distro=distro):
                scratch = self.persistent_scratch()
                result, calls, repo = self.run_setup(
                    distro=distro, machine="nix-desktop", hostname="installer-name",
                    scratch_dir=scratch,
                )
                self.assert_success(result, calls, repo)
                self.assertIn("hostnamectl set-hostname nix-desktop\n", calls)
                self.assertEqual((Path(scratch) / "synced-hostname").read_text(),
                                 "nix-desktop\n")
                hosts = (Path(scratch) / "fixtures/system-etc/hosts").read_text()
                self.assertIn("127.0.1.1\tnix-desktop\n", hosts)
                self.assertNotIn("installer-name", hosts)
                self.assertIn("so 'dotfiles' needs no argument", result.stdout)

    def test_nixos_leaves_the_hostname_to_the_system_switch(self):
        result, calls, repo = self.run_setup(
            machine="nix-desktop", hostname="installer-name", existing_target=True,
        )
        self.assert_success(result, calls, repo)
        self.assertIn("nixos-rebuild switch", calls)
        self.assertNotIn("hostnamectl", calls)
        self.assertNotIn("scutil", calls)
        # The switch applies networking.hostName, so the script asks for no
        # hostname change and names the file that owns the name.
        self.assertIn("networking.hostName", result.stderr)

    def test_unreadable_machine_list_lets_home_manager_report_the_name(self):
        # A flake that cannot be evaluated leaves the name unchecked, and Home
        # Manager reports the machine in its own words.
        result, calls, repo = self.run_setup(distro="ubuntu", machine="nix-desktop",
                                            flake_fail=True)
        self.assert_success(result, calls, repo)
        self.assertIn("Could not read the machine list", result.stderr)


if __name__ == "__main__":
    unittest.main()
