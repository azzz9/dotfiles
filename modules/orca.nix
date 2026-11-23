{ lib, ... }:
{
  # Refresh any already-installed Orca bundled skills (~/.agents/skills/ and
  # linked agent folders such as ~/.gemini/config/skills/) when an Orca host
  # binary is present. Never fall back to bare `orca` on Linux, which can
  # resolve to the GNOME Orca screen reader (/usr/bin/orca).
  home.activation.orcaSkills =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      orca_bin=""
      if [ -n "''${ORCA_CLI_COMMAND:-}" ] && [ -x "''${ORCA_CLI_COMMAND}" ]; then
        orca_bin="''${ORCA_CLI_COMMAND}"
      elif [ -x "$HOME/.config/orca/linux-orca-cli-shim/orca" ]; then
        orca_bin="$HOME/.config/orca/linux-orca-cli-shim/orca"
      elif command -v orca-ide >/dev/null 2>&1; then
        orca_bin="$(command -v orca-ide)"
      elif [ -x "/run/current-system/sw/bin/orca-ide" ]; then
        orca_bin="/run/current-system/sw/bin/orca-ide"
      elif [ -x "/Applications/Orca.app/Contents/Resources/bin/orca" ]; then
        orca_bin="/Applications/Orca.app/Contents/Resources/bin/orca"
      fi

      if [ -n "$orca_bin" ]; then
        if ! "$orca_bin" skills update --all >/dev/null 2>&1; then
          echo "orca-skills: warning: '$orca_bin skills update --all' did not complete cleanly" >&2
        fi
      fi
    '';
}
