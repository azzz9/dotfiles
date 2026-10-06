{ lib, pkgs, llmAgents, piPackagePaths, ... }:
let
  rpivVersion = "2.12.0";
  rpiv = name: "npm:@juicesharp/rpiv-${name}@${rpivVersion}";

  # One row per package pi installs. `input` names the flake input whose store
  # path the row loads; `spec` is an exact npm source; `npmDepsHash` marks an
  # input whose extension imports runtime dependencies, which pi never installs
  # for a local package (docs/packages.md, "Local packages are not installed or
  # modified"); `filter` is the optional resource narrowing pi accepts on the
  # object form.
  #
  # Provider packages stay out of this list: subscriptions, catalogs, and API
  # keys differ per host. Install them per machine as files under
  # ~/.pi/agent/extensions/<name>/ (auto-discovered); a local `pi install`
  # would be dropped again, because the merge below replaces the `packages`
  # array on every activation.
  rows = [
    { input = "pi-subagents"; npmDepsHash = "sha256-zPo0Z3IjaSEA74YptOUComiwvQxSMhPw7N6SwtGkveE="; }
    { input = "pi-web-access"; npmDepsHash = "sha256-BvAI68JpqJKNcg8luJ3d250C/YISUf13EItMgrJVrV4="; }
    # The 23 principle-* skills are poteto-mode's own vocabulary and the agent
    # reads them by path, so the menu lists only skills a person types.
    { input = "pi-pstack"; filter = { skills = [ "!skills/principle-*" ]; }; }
    # The skill is vendored in agents/skills, so load the extension only.
    { input = "i-have-adhd"; filter = { skills = [ ]; }; }
    # The rpiv packages ship from a 15-package workspace whose root carries no
    # pi manifest, so they stay npm rows.
    { spec = rpiv "ask-user-question"; }
    { spec = rpiv "btw"; }
    # Blocks destructive shell commands and secret-file access before the bash
    # tool call runs. It stays an npm row because the repository builds its
    # extension in a prepare script, so only the published tarball carries the
    # dist.
    { spec = "npm:cc-safety-net@2.6.0"; }
    # Persistent memory, session search, and a background learning loop. npm is
    # the publisher's install path, and its better-sqlite3 dependency arrives
    # prebuilt, so pi install runs no compiler.
    { spec = "npm:pi-hermes-memory@0.9.10"; }
    # Compact, expandable TUI tool rows, with its own bundled theme.
    { input = "pi-compact-tools"; }
  ];

  # Exactly what settings.json records for a row. A bare package row resolves to
  # the store path of its flake input, which pi loads in place. A row with
  # `npmDepsHash` loads a copy of that path carrying its node_modules. The
  # install phase copies the whole work tree because the pack step that
  # buildNpmPackage runs by default trims the sources pi loads from here.
  declare = row:
    let
      source =
        if row ? input then
          let
            src = piPackagePaths.${row.input};
            meta = builtins.fromJSON (builtins.readFile "${src}/package.json");
          in
          if row ? npmDepsHash then
            pkgs.buildNpmPackage {
              pname = meta.name;
              version = meta.version;
              inherit src;
              inherit (row) npmDepsHash;
              dontNpmBuild = true;
              # pi installs its npm packages with the same two flags: the
              # extensions need no dev tree and resolve pi's own packages from
              # the host.
              npmFlags = [ "--omit=dev" "--legacy-peer-deps" ];
              installPhase = "mkdir -p $out; cp -r . $out/";
            }
          else src
        else row.spec;
    in
    if row ? filter then { inherit source; } // row.filter else source;

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
  # The compact-tools extension reads this at startup. A store symlink, so the
  # style comes from the repo instead of a local edit.
  home.file.".pi/agent/compact-tools.json".source = compactToolsConfig;
  # Runs before linkGeneration so the first switch can still read the old store
  # symlink and carry the local keys into the regular file.
  home.activation.piSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run ${piSettingsMerge}
  '';
}
