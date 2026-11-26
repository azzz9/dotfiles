{ lib, pkgs, ... }:
let
  # Generate SKILL.md from the installed tuios binary so the skill always
  # matches the running tuios version without a separate upstream pin.
  tuiosSkill = pkgs.runCommand "tuios-skill" { } ''
    mkdir -p "$out"
    ${pkgs.tuios}/bin/tuios --skill > "$out/SKILL.md"
  '';
  localConfigHeader = pkgs.writeText "tuios-local-config.toml" ''
    # Local tuios overrides saved by the TUI.
    # Declarative defaults live in ~/.config/tuios/config.d/00-dotfiles.toml.
  '';
in
{
  # tuios terminal multiplexer, https://github.com/Gaurav-Gosain/tuios
  # Linux and macOS both read ~/.config/tuios/config.toml (XDG).
  # Declarative defaults go in config.d/00-dotfiles.toml so ~/.config/tuios/config.toml
  # stays a writable regular file for TUI settings persistence (tuios merges
  # config.d/*.toml before config.toml, and saves changes to config.toml).
  xdg.configFile = {
    "tuios/config.d/00-dotfiles.toml" = {
      source = ./tuios/config.toml;
      force = true;
    };
    "tuios/themes/kanagawa-dark.json" = {
      source = ./tuios/themes/kanagawa-dark.json;
      force = true;
    };
    "tuios/harnesses/pi.toml" = {
      source = ./tuios/harnesses/pi.toml;
      force = true;
    };
    "tuios/harnesses/antigravity.toml" = {
      source = ./tuios/harnesses/antigravity.toml;
      force = true;
    };
  };

  # Mirror modules/skills.nix's shared layout so pi, codex, orca, and agy all
  # discover the built-in tuios skill without duplicating it in pi-skills/.
  home.file = {
    ".agents/skills/tuios".source = tuiosSkill;
    ".gemini/config/skills/tuios".source = tuiosSkill;
  };

  # Ensure ~/.config/tuios/config.toml is a writable regular file rather than a
  # Nix store symlink, while preserving any existing user edits made in the TUI.
  home.activation.tuiosLocalConfig = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/tuios/config.toml"
    if [ -L "$cfg" ]; then
      run rm "$cfg"
    fi
    if [ ! -e "$cfg" ]; then
      run ${pkgs.coreutils}/bin/install -D -m 600 ${localConfigHeader} "$cfg"
    fi
  '';

  # Reinstall pi's and agy's integrations on every activation: idempotent,
  # preserves other hooks (Orca), and passes --no-skill because
  # ~/.agents/skills/tuios is managed declaratively above.
  home.activation.tuiosIntegrations = lib.hm.dag.entryAfter [ "writeBoundary" "installPackages" ] ''
    run mkdir -p "$HOME/.pi/agent/extensions" "$HOME/.gemini/config"
    run ${pkgs.tuios}/bin/tuios integration install pi --no-skill >/dev/null
    run ${pkgs.tuios}/bin/tuios integration install antigravity --no-skill >/dev/null
  '';
}
