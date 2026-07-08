{ config, hunk, pkgs, lib, ... }:
let
  upstreamHunk = hunk.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # The upstream hunk package builds with `bun build --compile` and ships with
  # `dontFixup = true`, so the single-file binary has no DT_RUNPATH. Its
  # interpreter is Nix's ld-linux but it resolves libc from the host (e.g.
  # glibc 2.43 on Arch/WSL2), mismatching Nix's glibc 2.42 ld-linux and
  # segfaulting on startup.
  #
  # We cannot fix this with patchelf (it relocates ELF sections and corrupts
  # Bun's embedded archive) nor with LD_LIBRARY_PATH alone: even with the
  # matching Nix glibc loaded, the kernel-mapped direct launch segfaults in a
  # BSS page (strace: SEGV_MAPERR @ 0x6510e40) because the kernel does not map
  # the binary's last BSS page the way ld-linux does. The binary runs correctly
  # only when ld-linux maps it explicitly.
  #
  # So on Linux we wrap `hunk` to launch the real binary through the matching
  # ld-linux with --library-path. Trade-off: process.execPath then points at
  # ld-linux, which breaks the TUI's auto-spawn of the session daemon
  # (`hunk session` uses process.execPath to relaunch itself) and the bundled
  # `hunk skill path` lookup. The wrapper below restores those two user-facing
  # behaviors without patching Hunk's compiled Bun archive:
  #
  # - review commands start the daemon first, so `hunk diff` registers a live
  #   session without a separate `hunk daemon serve` terminal;
  # - `hunk skill path` returns the bundled skill path from this package.
  # darwin is unaffected (no ld-linux) and uses the upstream package directly.
  hunkPackage =
    if pkgs.stdenv.isLinux then
      pkgs.runCommand "hunk-wrapped" { } ''
        mkdir -p $out
        cp -r ${upstreamHunk}/. $out/
        chmod -R u+w $out
        mv $out/bin/hunk $out/bin/.hunk-real
        cat > $out/bin/hunk <<EOF
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        real="$out/bin/.hunk-real"
        ld="${lib.getLib pkgs.glibc}/lib/ld-linux-x86-64.so.2"
        lib_path="${lib.getLib pkgs.glibc}/lib"
        curl="${pkgs.curl}/bin/curl"

        run_hunk() {
          exec "\$ld" --library-path "\$lib_path" "\$real" "\$@"
        }

        is_help_request() {
          for arg in "\$@"; do
            case "\$arg" in
              -h|--help)
                return 0
                ;;
            esac
          done

          return 1
        }

        daemon_health_url() {
          local host="\''${HUNK_MCP_HOST:-127.0.0.1}"
          local port="\''${HUNK_MCP_PORT:-47657}"
          printf 'http://%s:%s/health' "\$host" "\$port"
        }

        daemon_is_healthy() {
          "\$curl" --silent --fail --max-time 0.2 "\$(daemon_health_url)" >/dev/null 2>&1
        }

        ensure_daemon() {
          if daemon_is_healthy; then
            return 0
          fi

          "\$0" daemon serve >/dev/null 2>&1 &
          disown || true

          for _ in {1..40}; do
            if daemon_is_healthy; then
              return 0
            fi
            sleep 0.05
          done
        }

        if ! is_help_request "\$@"; then
          case "\''${1:-}" in
            diff|show|patch|pager|difftool)
              ensure_daemon
              ;;
            stash)
              if [[ "\''${2:-}" == "show" ]]; then
                ensure_daemon
              fi
              ;;
          esac
        fi

        if [[ "\''${1:-}" == "skill" && "\''${2:-}" == "path" ]]; then
          printf '%s\n' "$out/skills/hunk-review/SKILL.md"
          exit 0
        fi

        run_hunk "\$@"
        EOF
        chmod +x $out/bin/hunk
      ''
    else
      upstreamHunk;
in
{
  # Import the upstream Home Manager module, which provides the `programs.hunk`
  # option (package + ~/.config/hunk/config.toml generation).
  imports = [ hunk.homeManagerModules.default ];

  programs.hunk = {
    enable = true;
    package = hunkPackage;

    # NOTE: We do NOT use the upstream `enableGitIntegration` option here.
    # It writes to `programs.git.settings.core.pager`, which only takes
    # effect when `programs.git.enable = true`. This repo manages git config
    # via activation scripts in modules/git.nix instead, so the git pager is
    # set there to stay consistent with the existing pattern.
    settings = {
      mode = "auto";
      line_numbers = true;
      wrap_lines = false;
    };
  };

  # The repo owns the deployed hunk-review skill so local review policy can be
  # adjusted without patching Hunk's bundled copy.
}
