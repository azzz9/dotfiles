{ config, lib, pkgs, piPackagePaths, ... }:
let
  packagePaths = piPackagePaths pkgs;
  inherit (packagePaths) pstack skills;
  ccSafetyNet = config.dotfiles.pi.ccSafetyNetPackage;
  excludeSkillFlags = lib.concatMapStringsSep " "
    (name: "--exclude-skill ${lib.escapeShellArg name}")
    config.dotfiles.skills.shared;

  # Plugin-scoped hooks merge with ~/.gemini/config/hooks.json at runtime, so
  # Orca's and tuios's managed entries in ~/.gemini/config/hooks.json stay untouched.
  hooksJson = (pkgs.formats.json { }).generate "agy-dotfiles-hooks.json" {
    "cc-safety-net" = {
      PreToolUse = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = "${pkgs.nodejs}/bin/node ${ccSafetyNet}/dist/bin/cc-safety-net.js hook --agy-cli";
              timeout = 30;
            }
          ];
        }
      ];
    };
  };

  dotfilesPlugin = pkgs.runCommand "agy-dotfiles-plugin"
    {
      nativeBuildInputs = [ pkgs.python3 ];
    }
    ''
      python3 ${./agy/build-plugin.py} \
        --pi-skills ${skills} \
        --hooks-json ${hooksJson} \
        ${excludeSkillFlags} \
        --out "$out"
    '';
in
{
  home.packages = [
    pkgs.antigravity-cli # Google Antigravity CLI (agy, unfree)
  ];

  # Native Antigravity plugins under ~/.gemini/config/plugins/:
  # - pstack ships its own .antigravity-plugin/plugin.json, hooks.json, agents, and skills.
  # - dotfiles ships the adapted global AGENTS.md rules, the four skills from pi-skills/,
  #   and the cc-safety-net PreToolUse guard.
  # pstack-models.md, config.json, hooks.json, and settings.json remain local/mutable.
  home.file = {
    ".gemini/config/plugins/pstack".source = "${pstack}/plugins/pstack";
    ".gemini/config/plugins/dotfiles".source = dotfilesPlugin;
  };
}
