{ lib, pkgs, config, repoDir, piFlake, piPackagePaths, machine, ... }:
let
  # One row per package pi installs. `input` names the flake input whose store
  # path the row loads; `tarball` names a published npm tarball Nix unpacks into
  # the store; `spec` is an exact npm source pi installs itself; `npmDepsHash`
  # marks an input whose extension imports runtime dependencies, which pi never
  # installs for a local package (docs/packages.md, "Local packages are not
  # installed or modified"); `filter` is the optional resource narrowing pi
  # accepts on the object form.
  #
  # Provider packages stay out of this list: subscriptions, catalogs, and API
  # keys differ per host. Install them per machine as files under
  # ~/.pi/agent/extensions/<name>/ (auto-discovered); a local `pi install`
  # would be dropped again, because the merge below replaces the `packages`
  # array on every activation.
  #
  # The rows every machine gets. The Linux-only row is appended below, because
  # the filter assert must not force pkgs while config is computed.
  baseRows = [
    { input = "pi-subagents"; npmDepsHash = "sha256-862hXsUJ7CSVSntkV1Iv4z5E2On8v5BJSbM9iIYe+GY=";
      filter = { prompts = [ ]; skills = [ "!skills/council-mode" ]; };
    }
    { input = "pi-web-access"; npmDepsHash = "sha256-BvAI68JpqJKNcg8luJ3d250C/YISUf13EItMgrJVrV4="; }
    # The rules load from APPEND_SYSTEM.md every turn, so the menu lists only the
    # skills a person types.
    { input = "skills"; }
    # The rpiv workspace ships from a shared root that carries no pi manifest, so
    # the published tarball is the source. Its one runtime dependency is vendored
    # under node_modules, which is what `pi install` would have produced.
    { tarball = {
        name = "@juicesharp/rpiv-ask-user-question";
        version = "2.12.0";
        url = "https://registry.npmjs.org/@juicesharp/rpiv-ask-user-question/-/rpiv-ask-user-question-2.12.0.tgz";
        hash = "sha256-9AeJNjjxiTo3MERPRntO3Bkkzy0gauWE91JeHoroYPY=";
        deps = [{
          name = "@juicesharp/rpiv-config";
          version = "2.12.0";
          url = "https://registry.npmjs.org/@juicesharp/rpiv-config/-/rpiv-config-2.12.0.tgz";
          hash = "sha256-5ZKpbqxsSPTx7n+pHvh/UOqCVeiH/wSuvHkEpL7Q8dQ=";
        }];
      };
    }
    # The /btw side conversation. The published tarball carries the TypeScript
    # pi loads and has no runtime dependencies, so Nix unpacks it and pi loads it
    # from the store. `pi_reconcile` never sees this row, and the version and
    # hash move by hand until a tarball bump joins `dotfiles upgrade`.
    { tarball = {
        name = "pi-btw";
        version = "0.8.0";
        url = "https://registry.npmjs.org/pi-btw/-/pi-btw-0.8.0.tgz";
        hash = "sha256-kZMFybKqs1YX5wvUdc0tmibF9PlPbHHQGtK01IXXWvc=";
      };
    }
    # Blocks destructive shell commands and secret-file access before the bash
    # tool call runs. The repository builds its extension in a prepare script, so
    # only the published tarball carries the dist.
    { tarball = {
        name = "cc-safety-net";
        version = "2.6.0";
        url = "https://registry.npmjs.org/cc-safety-net/-/cc-safety-net-2.6.0.tgz";
        hash = "sha256-hzfkiFdMYRxfm+BtEw9Mwx+/CWLkNqe5teAICi/JqIQ=";
      };
    }
    # Moves the running pi session to another directory or worktree, keeping the
    # conversation, and creates or removes the worktree through herdr.
    { tarball = {
        name = "pi-agent-teleport";
        version = "0.2.5";
        url = "https://registry.npmjs.org/pi-agent-teleport/-/pi-agent-teleport-0.2.5.tgz";
        hash = "sha256-5iaLcgw3JjvrM//2brll+FOckXJsijvA4cFEe4O0wLI=";
      };
    }
    # Compact, expandable TUI tool rows, with its own bundled theme.
    { input = "pi-compact-tools"; }
  ];
  rows = baseRows ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    # The API key stays machine-local in ~/.pi/agent/ollama_cloud.json.
    { tarball = {
        name = "pi-ollama-cloud-link";
        version = "1.2.0";
        url = "https://registry.npmjs.org/pi-ollama-cloud-link/-/pi-ollama-cloud-link-1.2.0.tgz";
        hash = "sha256-Y+rc+ku3qJBzx0gEFmTrpRdeITAkQyq/sh1YWrGEpMY=";
      };
    }
  ];

  # A published npm tarball unpacked into the store, ready for pi to load. A
  # runtime dependency is vendored under node_modules, because pi loads a local
  # package without installing anything (docs/packages.md, "Local packages are
  # not installed or modified"). The recursion covers a dependency of a
  # dependency.
  unpackTarball = entry:
    pkgs.stdenvNoCC.mkDerivation {
      pname = entry.name;
      version = entry.version;
      src = pkgs.fetchurl { inherit (entry) url hash; };
      # An npm tarball unpacks to package/.
      sourceRoot = "package";
      dontBuild = true;
      installPhase = ''
        mkdir -p $out
        cp -r . $out/
        ${lib.concatMapStrings (dep: ''
          mkdir -p "$out/node_modules/$(dirname "${dep.name}")"
          cp -r ${unpackTarball dep} "$out/node_modules/${dep.name}"
        '') (entry.deps or [ ])}
      '';
    };

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
        else if row ? tarball then unpackTarball row.tarball
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
  # A filter path is relative to the pinned package and may carry a + or !
  # prefix. An upstream rename would silently stop narrowing, so every path is
  # checked against the store path the row actually loads.
  filterProblems = lib.concatMap
    (row:
      lib.concatMap
        (kind:
          map
            (entry: "${row.input} filter.${kind} names a path the pinned package does not carry: ${entry}")
            (builtins.filter
              (entry:
                !(builtins.pathExists
                  "${piPackagePaths.${row.input}}/${lib.removePrefix "!" (lib.removePrefix "+" entry)}"))
              (row.filter.${kind} or [ ])))
        (builtins.attrNames (row.filter or { })))
    (builtins.filter (row: row ? filter) baseRows);
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
assert lib.assertMsg (assignmentProblems == [ ] && filterProblems == [ ])
  "modules/pi.nix: ${lib.concatStringsSep "; " (assignmentProblems ++ filterProblems)}";
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
