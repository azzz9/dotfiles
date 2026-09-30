{ lib, pkgs, llmAgents, piGitSources, ... }:
let
  rpivVersion = "2.11.0";
  rpiv = name: "npm:@juicesharp/rpiv-${name}@${rpivVersion}";

  # One row per package pi installs. `spec` is pi's source, `input` names the
  # locked flake input a git row's revision comes from, and `filter` is the
  # optional resource narrowing pi accepts on the object form. No row carries a
  # sha, so a pin cannot disagree with what Nix fetched.
  #
  # Provider packages stay out of this list: subscriptions, catalogs, and API
  # keys differ per host. Install them per machine as files under
  # ~/.pi/agent/extensions/<name>/ (auto-discovered); a local `pi install`
  # would be dropped again, because the merge below replaces the `packages`
  # array on every activation.
  rows = [
    { spec = "npm:pi-mcp-adapter"; }
    { spec = "npm:pi-web-access"; }
    { input = "pi-pstack"; }
    # The skill is vendored in config/ai/skills, so load the extension only.
    { input = "i-have-adhd"; filter = { skills = [ ]; }; }
    { spec = rpiv "todo"; }
    { spec = rpiv "ask-user-question"; }
    { spec = rpiv "btw"; }
    { spec = "npm:pi-subagents@0.70.1"; }
    # Blocks destructive shell commands and secret-file access before the
    # bash tool call runs. Pinned: the rule set is the point, so the pin moves
    # only on a deliberate bump.
    { spec = "npm:cc-safety-net@2.4.6"; }
  ];

  # Exactly what settings.json records for a row.
  declare = row:
    let
      source = if row ? input
        then "git:${piGitSources.${row.input}.spec}@${piGitSources.${row.input}.rev}"
        else row.spec;
    in
    if row ? filter then { inherit source; } // row.filter else source;

  # What scripts/pi-reconcile.sh reads: one <spec> <rev> line per git row.
  # `spec` is also the path pi keys the checkout by under the agent directory.
  pins = lib.concatMapStrings
    (row: "${piGitSources.${row.input}.spec} ${piGitSources.${row.input}.rev}\n")
    (builtins.filter (row: row ? input) rows);

  # pi writes its startup model and `pi install` packages into
  # ~/.pi/agent/settings.json, which cannot be a read-only store symlink, so the
  # keys below are merged into the local file on every activation.
  piManagedSettings = {
    packages = map declare rows;
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
  # The reconcile step reads this. A store symlink, so nothing writes to it.
  home.file.".pi/agent/.dotfiles-pi-pins".text = pins;
  # Runs before linkGeneration so the first switch can still read the old store
  # symlink and carry the local keys into the regular file.
  home.activation.piSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run ${piSettingsMerge}
  '';
}
