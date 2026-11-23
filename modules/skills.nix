{ config, lib, pkgs, piPackagePaths, ... }:
let
  cfg = config.dotfiles.skills;
  inherit (piPackagePaths pkgs) skills;

  mkSharedSkillLinks = name: {
    # Canonical Agent Skills directory (~/.agents/skills/), discovered natively
    # by pi, codex, and `orca skills installed`.
    ".agents/skills/${name}".source = "${skills}/skills/${name}";
    # Global Antigravity (agy) skills directory, matching Orca's link layout.
    ".gemini/config/skills/${name}".source = "${skills}/skills/${name}";
  };
in
{
  options.dotfiles.skills.shared = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ "yomiyasu" ];
    description = ''
      Agent-agnostic skills built in pi-skills/ to deploy through ~/.agents/skills/
      and link to each global agent skills directory. Excluded from pi's package
      loader and agy's dotfiles plugin so nothing loads twice.
    '';
  };

  config = {
    home.file = lib.mkMerge (map mkSharedSkillLinks cfg.shared);
  };
}
