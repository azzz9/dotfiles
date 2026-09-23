{ lib, pkgs, llmAgents, ... }:
let
  rpivVersion = "2.11.0";
  rpiv = name: "npm:@juicesharp/rpiv-${name}@${rpivVersion}";

  # pi writes its startup model and `pi install` packages into
  # ~/.pi/agent/settings.json, which cannot be a read-only store symlink, so the
  # keys below are merged into the local file on every activation.
  piManagedSettings = {
    packages = [
      "npm:pi-mcp-adapter"
      "npm:pi-web-access"
      # pstack for pi (personal fork): the upstream port plus local harness
      # fixes. Pinned so a generation always reconciles to this version.
      "git:github.com/azzz9/pi-pstack@87251366b573e6064d88976233c153a83b2c5d63"
      # i-have-adhd supplies the session-wide ADHD output mode. The skill itself
      # is vendored in config/ai/skills, so load the extension only and skip the
      # package's duplicate copy of the same skill.
      {
        source = "git:github.com/ayghri/i-have-adhd@839872f9d1cd634fed642b4589ce7226199cc15f";
        skills = [ ];
      }
      # Tools the pstack playbooks call; the /btw overlay rides with them.
      (rpiv "todo")
      (rpiv "ask-user-question")
      (rpiv "btw")
      "npm:pi-subagents@0.70.1"
      # Blocks destructive shell commands and secret-file access before the
      # bash tool call runs. Pinned: the rule set is the point, so the pin moves
      # only on a deliberate bump.
      "npm:cc-safety-net@2.4.6"
      # Provider packages stay out of this list: subscriptions, catalogs, and API
      # keys differ per host. Install them per machine as files under
      # ~/.pi/agent/extensions/<name>/ (auto-discovered); a local `pi install`
      # would be dropped again, because this merge replaces the `packages` array
      # on every activation.
    ];
    # Hidden because the conclusion already appears in the answer.
    hideThinkingBlock = true;
  };
  # Every other key is carried over untouched: objects are merged, scalars
  # replaced. The file stays a regular file so pi can keep writing it.
  piManagedSettingsJson = (pkgs.formats.json { }).generate "pi-managed-settings.json" piManagedSettings;
  piSettingsMerge = pkgs.writeShellScript "pi-settings-managed" ''
    set -euo pipefail

    settings="''${HOME}/.pi/agent/settings.json"
    merged="''${settings}.hm-tmp"

    if [ -e "$settings" ] && ! ${pkgs.jq}/bin/jq -e . "$settings" >/dev/null 2>&1; then
      echo "pi-settings-managed: $settings is not valid JSON; leaving it untouched" >&2
      exit 0
    fi

    mkdir -p "$(dirname "$settings")"

    if [ -e "$settings" ]; then
      ${pkgs.jq}/bin/jq --slurpfile declared ${piManagedSettingsJson} \
        '. * $declared[0]' "$settings" > "$merged"
    else
      cp ${piManagedSettingsJson} "$merged"
    fi

    chmod 644 "$merged"
    mv -f "$merged" "$settings"
  '';
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = llmAgents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
    extraPackages = with pkgs; [
      nodejs
      bun
    ];
  };
  # The i-have-adhd extension turns the mode on at every new session when this
  # flag exists; a saved choice for the current session still wins, so an
  # explicit "stop adhd mode" survives.
  home.file.".pi/agent/.i-have-adhd-always".text = "";
  # Runs before linkGeneration so the first switch can still read the old store
  # symlink and carry the local keys into the regular file.
  home.activation.piSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run ${piSettingsMerge}
  '';
}
