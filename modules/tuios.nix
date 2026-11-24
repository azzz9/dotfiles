{ lib, pkgs, ... }:
let
  # Generate SKILL.md from the installed tuios binary so the skill always
  # matches the running tuios version without a separate upstream pin.
  tuiosSkill = pkgs.runCommand "tuios-skill" { } ''
    mkdir -p "$out"
    ${pkgs.tuios}/bin/tuios --skill > "$out/SKILL.md"
  '';
in
{
  # tuios terminal multiplexer, https://github.com/Gaurav-Gosain/tuios
  # Linux and macOS both read ~/.config/tuios/config.toml (XDG).
  xdg.configFile."tuios/config.toml" = {
    source = ./tuios/config.toml;
    force = true;
  };

  # Mirror modules/skills.nix's shared layout so pi, codex, orca, and agy all
  # discover the built-in tuios skill without duplicating it in pi-skills/.
  home.file = {
    ".agents/skills/tuios".source = tuiosSkill;
    ".gemini/config/skills/tuios".source = tuiosSkill;
  };

  # Reinstall pi's and agy's integrations on every activation: idempotent,
  # preserves other hooks (Orca, Herdr), and passes --no-skill because
  # ~/.agents/skills/tuios is managed declaratively above.
  home.activation.tuiosIntegrations = lib.hm.dag.entryAfter [ "writeBoundary" "installPackages" ] ''
    run mkdir -p "$HOME/.pi/agent/extensions" "$HOME/.gemini/config"
    run ${pkgs.tuios}/bin/tuios integration install pi --no-skill >/dev/null
    run ${pkgs.tuios}/bin/tuios integration install antigravity --no-skill >/dev/null
  '';
}
