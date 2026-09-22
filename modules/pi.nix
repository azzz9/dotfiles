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
      "git:github.com/azzz9/pi-pstack@bac8e2a43fb92bb2f871c6cfda5a5e8f6fdc587f"
      # Tools the pstack playbooks call; the /btw overlay rides with them.
      (rpiv "todo")
      (rpiv "ask-user-question")
      (rpiv "btw")
      "npm:pi-subagents@0.70.1"
      # Provider packages stay out of this list: subscriptions, catalogs, and API
      # keys differ per host, and entries here become read-only. Install them per
      # machine into ~/.pi/agent/extensions/<name>/ (auto-discovered) or with a
      # local `pi install`.
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
  # Runs before linkGeneration so the first switch can still read the old store
  # symlink and carry the local keys into the regular file.
  home.activation.piSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run ${piSettingsMerge}
  '';
}
