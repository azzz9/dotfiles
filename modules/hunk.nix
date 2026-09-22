{ hunk, pkgs, lib, ... }:
let
  upstreamHunk = hunk.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Upstream hunk is a `bun build --compile` binary with no DT_RUNPATH: Nix's
  # ld-linux loads, but libc resolves from the host, which segfaults on startup.
  # patchelf corrupts Bun's embedded archive and LD_LIBRARY_PATH alone still
  # segfaults, so on Linux we launch the real binary through the matching
  # ld-linux. That makes process.execPath point at ld-linux, which breaks the
  # session daemon auto-spawn (`hunk session` relaunches itself) and the bundled
  # `hunk skill path` lookup; the wrapper restores both. Darwin has no ld-linux
  # and uses the upstream package directly.
  hunkPackage =
    if pkgs.stdenv.hostPlatform.isLinux then
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
  # Upstream HM module: provides the `programs.hunk` option.
  imports = [ hunk.homeManagerModules.default ];

  programs.hunk = {
    enable = true;
    package = hunkPackage;

    # enableGitIntegration is deliberately unused: it writes
    # programs.git.settings.core.pager, which only applies when
    # programs.git.enable = true. modules/git.nix sets the pager instead.
    settings = {
      mode = "auto";
      line_numbers = true;
      wrap_lines = false;
    };
  };
}
