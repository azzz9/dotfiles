{ lib, pkgs, config, repoDir, piFlake, piPackagePaths, machine, ... }:
let
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
    { input = "pi-subagents"; npmDepsHash = "sha256-zPo0Z3IjaSEA74YptOUComiwvQxSMhPw7N6SwtGkveE=";
      filter = { prompts = [ ]; skills = [ "!skills/council-mode" ]; };
    }
    { input = "pi-web-access"; npmDepsHash = "sha256-BvAI68JpqJKNcg8luJ3d250C/YISUf13EItMgrJVrV4="; }
    # The rules load from APPEND_SYSTEM.md every turn, so the menu lists only the
    # skills a person types.
    { input = "skills"; }
    # The rpiv workspace ships from a shared root that carries no pi manifest,
    # so this row stays an npm row.
    { spec = "npm:@juicesharp/rpiv-ask-user-question@2.12.0"; }
    # The /btw side conversation. The published tarball carries the TypeScript
    # pi loads, so the spec pin is the whole pin.
    { spec = "npm:pi-btw@0.8.0"; }
    # Blocks destructive shell commands and secret-file access before the bash
    # tool call runs. It stays an npm row because the repository builds its
    # extension in a prepare script, so only the published tarball carries the
    # dist.
    { spec = "npm:cc-safety-net@2.6.0"; }
    # Moves the running pi session to another directory or worktree, keeping the
    # conversation, and creates or removes the worktree through herdr. The
    # tarball carries the TypeScript pi loads, so the spec pin is the whole pin
    # and `dotfiles upgrade` bumps it with the other npm rows.
    { spec = "npm:pi-agent-teleport@0.2.5"; }
    # Compact, expandable TUI tool rows, with its own bundled theme.
    { input = "pi-compact-tools"; }
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    # pi_reconcile installs this row. The API key stays machine-local in
    # ~/.pi/agent/ollama_cloud.json.
    { spec = "npm:pi-ollama-cloud-link@1.2.0"; }
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
    # pi reads a list of only `+name` entries as a change to the inherited
    # selection, so a plain "codemode" here would replace read/bash/edit/write.
    defaultTools = [ "+codemode" ];
    markdown = { mermaid = "final"; };
    # The tier agents carry no model, so the host binds one per tier here. The
    # merge below adds this key to the local settings.json like any other.
    subagents = modelTiers.subagentsFor machine;
  };
  # Every other key is carried over untouched: objects are merged, scalars
  # replaced. The file stays a regular file so pi can keep writing it.
  piManagedSettingsJson = (pkgs.formats.json { }).generate "pi-managed-settings.json" piManagedSettings;
  # Compact-tools reads this at startup; only non-default keys belong here.
  compactToolsConfig = (pkgs.formats.json { }).generate "compact-tools.json" {
    style = "compact";
    mode = "silent";
  };
  # pi-subagents resolves an override by the agent's own name, so a row under a
  # misspelled name would be silently unused. Both agent packages own names here,
  # the skills package for the tiers and pi-subagents for the builtins.
  agentNamesIn = dir: map (lib.removeSuffix ".md") (builtins.attrNames (builtins.readDir dir));
  pinnedAgents = agentNamesIn "${piPackagePaths.skills}/agents" ++ agentNamesIn "${piPackagePaths.pi-subagents}/agents";
  modelTiers = import ./pi/model-tiers.nix { knownAgents = pinnedAgents; };
  assignmentProblems = modelTiers.problemsFor modelTiers.rows;
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
assert lib.assertMsg (assignmentProblems == [ ])
  "modules/pi.nix: delegation assignment: ${lib.concatStringsSep "; " assignmentProblems}";
{
  programs.pi-coding-agent = {
    enable = true;
    package = piFlake.packages.${pkgs.stdenv.hostPlatform.system}.pi;
    extraPackages = with pkgs; [
      nodejs
      bun
    ];
  };
  # The compact-tools extension reads this at startup. A store symlink, so the
  # style comes from the repo instead of a local edit.
  home.file.".pi/agent/compact-tools.json".source = compactToolsConfig;
  # The visible-model rules are hand-written for the providers the Linux
  # machines carry; the macOS row keeps its own provider set.
  home.file.".pi/agent/extensions/openai-model-visibility.ts" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/modules/pi/openai-model-visibility.ts";
    force = true;
  };
  # Runs before linkGeneration so the first switch can still read the old store
  # symlink and carry the local keys into the regular file.
  home.activation.piSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run ${piSettingsMerge}
  '';
}
