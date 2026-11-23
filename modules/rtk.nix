{ lib, pkgs, ... }:
let
  rtkConfigToml = (pkgs.formats.toml { }).generate "rtk-config.toml" {
    tracking = {
      enabled = true;
      history_days = 90;
    };
    display = {
      colors = true;
      emoji = true;
      max_width = 120;
    };
    filters = {
      ignore_dirs = [
        ".git"
        "node_modules"
        "target"
        "__pycache__"
        ".venv"
        "vendor"
      ];
      ignore_files = [
        "*.lock"
        "*.min.js"
        "*.min.css"
      ];
    };
    retriever = {
      mode = "sqlite";
      max_entry_bytes = 10485760;
      max_entries = 200;
      retention_days = 30;
      compression = true;
      tee_max_files = 20;
      tee_max_file_size = 1048576;
      tee_on_success = false;
    };
    telemetry = {
      enabled = false;
    };
    hooks = {
      exclude_commands = [ ];
      transparent_prefixes = [ ];
      suppress_hook_warning = false;
      wrap_fish_scripts = false;
    };
    limits = {
      grep_max_results = 200;
      grep_max_per_file = 25;
      status_max_files = 15;
      status_max_untracked = 10;
      passthrough_max_chars = 2000;
    };
    awareness = {
      level = "default";
    };
  };

  rtkPiExtension = pkgs.runCommand "rtk-pi-extension.ts" { } ''
    export HOME="$TMPDIR"
    ${pkgs.rtk}/bin/rtk init -g --agent pi >/dev/null
    cp "$HOME/.pi/agent/extensions/rtk.ts" "$out"
  '';

  # Generate the Antigravity plugin from rtk itself and pin the hook binary to
  # the Nix store path so agy does not depend on shell PATH resolution.
  rtkAgyPlugin = pkgs.runCommand "agy-rtk-plugin"
    {
      nativeBuildInputs = [ pkgs.python3 ];
    }
    ''
      export HOME="$TMPDIR"
      ${pkgs.rtk}/bin/rtk init -g --agent antigravity --auto-patch >/dev/null
      cp -r "$HOME/.gemini/config/plugins/rtk" "$out"
      chmod -R u+w "$out"
      python3 - "$out/hooks.json" "${pkgs.rtk}/bin/rtk" <<'PY'
      import json
      import sys
      from pathlib import Path

      hooks_path = Path(sys.argv[1])
      rtk_bin = sys.argv[2]
      data = json.loads(hooks_path.read_text(encoding="utf-8"))
      for entry in data["rtk-rewrite"]["PreToolUse"]:
          for hook in entry["hooks"]:
              if hook.get("command") == "rtk hook antigravity":
                  hook["command"] = f"{rtk_bin} hook antigravity"
      hooks_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
      PY
    '';
in
{
  options.dotfiles.rtk.configSource = lib.mkOption {
    type = lib.types.path;
    internal = true;
    readOnly = true;
    default = rtkConfigToml;
    description = "Generated rtk config.toml path shared between hosts/linux.nix and hosts/darwin.nix.";
  };

  config = {
    home.packages = [ pkgs.rtk ];

    home.file.".pi/agent/extensions/rtk.ts".source = rtkPiExtension;
    home.file.".gemini/config/plugins/rtk".source = rtkAgyPlugin;
  };
}
