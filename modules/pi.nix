{ lib, pkgs, llmAgents, piGitSources, ... }:
let
  rpivVersion = "2.12.0";
  rpiv = name: "npm:@juicesharp/rpiv-${name}@${rpivVersion}";

  # One row per package pi installs. `spec` is an exact npm source; `input`
  # names the locked flake input whose revision a git row carries; `filter`
  # is the optional resource narrowing pi accepts on the object form. No row
  # carries a sha, so a pin cannot disagree with what Nix fetched.
  #
  # Provider packages stay out of this list: subscriptions, catalogs, and API
  # keys differ per host. Install them per machine as files under
  # ~/.pi/agent/extensions/<name>/ (auto-discovered); a local `pi install`
  # would be dropped again, because the merge below replaces the `packages`
  # array on every activation.
  rows = [
    { input = "pi-subagents"; }
    { input = "pi-web-access"; }
    { input = "pi-mcp-adapter"; }
    { input = "pi-pstack"; }
    # The skill is vendored in config/ai/skills, so load the extension only.
    { input = "i-have-adhd"; filter = { skills = [ ]; }; }
    # The rpiv packages ship from a 15-package workspace whose root carries no
    # pi manifest, so they cannot be git sources and stay npm rows.
    { spec = rpiv "todo"; }
    { spec = rpiv "ask-user-question"; }
    { spec = rpiv "btw"; }
    # Blocks destructive shell commands and secret-file access before the bash
    # tool call runs. The rule set is the point, so it stays an npm row: its
    # repository runs `lefthook install` from a prepare script, which a pi git
    # install cannot satisfy. The published tarball carries the built dist with
    # no runtime dependencies.
    { spec = "npm:cc-safety-net@2.4.14"; }
    # Persistent memory, session search, and a background learning loop. npm is
    # the publisher's install path, and its better-sqlite3 dependency arrives
    # prebuilt, so pi install runs no compiler.
    { spec = "npm:pi-hermes-memory@0.9.9"; }
    # Compact, expandable TUI tool rows, with its own bundled theme.
    { input = "pi-compact-tools"; }
  ];

  # Exactly what settings.json records for a row.
  declare = row:
    let
      source = if row ? input
        then "git:${piGitSources.${row.input}.spec}@${piGitSources.${row.input}.rev}"
        else row.spec;
    in
    if row ? filter then { inherit source; } // row.filter else source;

  # What scripts/pi-reconcile.sh reads: one "<spec> <rev>" line per git row.
  # `spec` is also the path pi keys the checkout by under the agent directory.
  # The two-field shape is deliberately unchanged from before the npm pins
  # existed: the CLI running the first apply after an upgrade is the previously
  # installed one, and it parses this file with the same two fields.
  #
  # npm rows are absent on purpose. Their pinned version already sits in the
  # spec that settings.json records, so the reconcile reads it there instead of
  # holding a second copy that could disagree.
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
    defaultThinkingLevel = "xhigh";
  };
  # Every other key is carried over untouched: objects are merged, scalars
  # replaced. The file stays a regular file so pi can keep writing it.
  piManagedSettingsJson = (pkgs.formats.json { }).generate "pi-managed-settings.json" piManagedSettings;
  # Compact-tools reads this at startup; only non-default keys belong here.
  compactToolsConfig = (pkgs.formats.json { }).generate "compact-tools.json" { style = "compact"; };
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
  # The compact-tools extension reads this at startup. A store symlink, so the
  # style comes from the repo instead of a local edit.
  home.file.".pi/agent/compact-tools.json".source = compactToolsConfig;
  # Runs before linkGeneration so the first switch can still read the old store
  # symlink and carry the local keys into the regular file.
  home.activation.piSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run ${piSettingsMerge}
  '';
}
