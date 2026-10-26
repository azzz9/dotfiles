{ lib, pkgs, config, repoDir, piFlake, piPackagePaths, ... }:
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
  # The rows every machine gets. The Linux-only row is appended below.
  baseRows = [
    # The skills and the Pi extension the poteto-mode workflow calls. The
    # extension adds the agent and question tools Pi does not carry.
    { input = "pstack"; }
    { input = "pi-web-access"; npmDepsHash = "sha256-Emyw5LJdSEkb9Kg7Do6iobY6KslF3rkHxRI0EP6eEiY="; }
    # The rules load from APPEND_SYSTEM.md every turn, so the menu lists only the
    # skills a person types.
    { input = "skills"; }
    # The /btw side conversation. The published tarball carries the TypeScript
    # pi loads and has no runtime dependencies, so Nix unpacks it and pi loads it
    # from the store. `pi_reconcile` never sees this row; the tarball bump in
    # scripts/bump-pins.sh moves it.
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
        version = "2.6.19";
        url = "https://registry.npmjs.org/cc-safety-net/-/cc-safety-net-2.6.19.tgz";
        hash = "sha256-DBRAfiVBCmKKTSNBl/gC8bUJiNXWHl6xsumtXMU5jto=";
      };
    }
    # Moves the running pi session to another directory or worktree, keeping the
    # conversation, and creates or removes the worktree through herdr.
    { tarball = {
        name = "pi-agent-teleport";
        version = "0.2.7";
        url = "https://registry.npmjs.org/pi-agent-teleport/-/pi-agent-teleport-0.2.7.tgz";
        hash = "sha256-9yW+e8sZAxLbzluZ6CBJC+HeZW6+2SEmYiVOeaMmSEg=";
        postPatch = ''
          patch -p1 < ${./pi/teleport-agent-tab.patch}
        '';
      };
    }
    # Compact, expandable TUI tool rows, with its own bundled theme.
    { input = "pi-compact-tools"; }
  ];
  # fff-node calls a Rust cdylib through ffi-rs, so a system pins the two
  # prebuilt binaries npm would pick from the manifest's optionalDependencies.
  # They need glibc and, on ffi-rs, libgcc_s, with no rpath, and node maps both,
  # so the row needs no autoPatchelfHook.
  fffNative = {
    x86_64-linux = [
      { name = "@yuuang/ffi-rs-linux-x64-gnu"; version = "1.3.7";
        url = "https://registry.npmjs.org/@yuuang/ffi-rs-linux-x64-gnu/-/ffi-rs-linux-x64-gnu-1.3.7.tgz";
        hash = "sha256-BCBwMehwlllH0mf4Z4IDVXGbyTBlt3u0GPN3zjOvREM=";
      }
      { name = "@ff-labs/fff-bin-linux-x64-gnu"; version = "0.11.0";
        url = "https://registry.npmjs.org/@ff-labs/fff-bin-linux-x64-gnu/-/fff-bin-linux-x64-gnu-0.11.0.tgz";
        hash = "sha256-NsXwm34xXk4YcPwjEd+uOS0PbmGX88CwaX4V2Ng0Tr8=";
      }
    ];
    aarch64-darwin = [
      { name = "@yuuang/ffi-rs-darwin-arm64"; version = "1.3.7";
        url = "https://registry.npmjs.org/@yuuang/ffi-rs-darwin-arm64/-/ffi-rs-darwin-arm64-1.3.7.tgz";
        hash = "sha256-TM5t92ZAnva/NibUZkR4R9nH2X2oGewl8X20mdt672g=";
      }
      { name = "@ff-labs/fff-bin-darwin-arm64"; version = "0.11.0";
        url = "https://registry.npmjs.org/@ff-labs/fff-bin-darwin-arm64/-/fff-bin-darwin-arm64-0.11.0.tgz";
        hash = "sha256-BQR/OxUERaNerK0TWhU3y6ARuBWMteKP0y9XxZDv6vc=";
      }
    ];
  };
  # FFF adds fffind and fffgrep beside pi's own tools, and the mode that replaces
  # find and grep is opt-in. The SDK loads on first use, and this host is node,
  # so fff-node is vendored and fff-bun is not: the bun loader only runs as a
  # fallback the node loader has already answered.
  fffRow = {
    tarball = {
      name = "@ff-labs/pi-fff";
      version = "0.11.0";
      url = "https://registry.npmjs.org/@ff-labs/pi-fff/-/pi-fff-0.11.0.tgz";
      hash = "sha256-0lystSl0qMmb4ez4igulVEWUAqiFB5jMci4IsIjSHeM=";
      deps = [
        { name = "@ff-labs/fff-node"; version = "0.11.0";
          url = "https://registry.npmjs.org/@ff-labs/fff-node/-/fff-node-0.11.0.tgz";
          hash = "sha256-gS/LFf8Sb8xpQDZuXCqbkWQFWimARVuP0Vhv5+BZSPc=";
        }
        { name = "ffi-rs"; version = "1.3.7";
          url = "https://registry.npmjs.org/ffi-rs/-/ffi-rs-1.3.7.tgz";
          hash = "sha256-gcELutWG0iAJHEIp+CCk0FVlEQwLq2ZBvwIbbffrQ0w=";
        }
      ] ++ fffNative.${pkgs.stdenv.hostPlatform.system};
    };
  };
  rows = baseRows ++ [ fffRow ] ++ lib.optionals config.dotfiles.pi.linuxProviders [
    # The API key stays machine-local in ~/.pi/agent/ollama_cloud.json.
    { tarball = {
        name = "pi-ollama-cloud-link";
        version = "1.3.0";
        url = "https://registry.npmjs.org/pi-ollama-cloud-link/-/pi-ollama-cloud-link-1.3.0.tgz";
        hash = "sha256-sGsjHY+87bFAquBMa9hH0D8PQM0nN/KbWG9dB9yP4e8=";
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
      postPatch = entry.postPatch or "";
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
  };
  # Every other key is carried over untouched: objects are merged, scalars
  # replaced. The file stays a regular file so pi can keep writing it.
  piManagedSettingsJson = (pkgs.formats.json { }).generate "pi-managed-settings.json" piManagedSettings;
  # Compact-tools reads this at startup; only non-default keys belong here.
  compactToolsConfig = (pkgs.formats.json { }).generate "compact-tools.json" {
    style = "compact";
    mode = "silent";
  };
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
  # pstack resolves the Claude family names its skills name through this sheet.
  # Without it the extension falls back to Anthropic ids on any provider it has
  # no table for. Hard work runs on Claude Opus and everything else on Ollama's
  # deepseek, because Pi bills Claude used through a subscription per token as
  # extra usage. Both strongest roles point at Opus. The panel lines name full
  # ids so the panels keep four distinct models whatever the family defaults
  # are. `default effort` is opus's level; every other role line carries its
  # own. The macbook picks its own with setup-pstack.
  pstackModels = pkgs.writeText "pstack-models.md" ''
    pi models: opus=anthropic/claude-opus-5-5, fable=anthropic/claude-opus-5-5, sonnet=ollama-cloud/deepseek-v4.1-flash:1017, haiku=ollama-cloud/deepseek-v4.1-flash:1017
    default effort: medium
    strongest judgment: fable @high
    feature, refactoring: sonnet @xhigh
    arena runners: ollama-cloud/minimax-m3.1-flash @xhigh, anthropic/claude-opus-5-5 @high, ollama-cloud/deepseek-v4.1-flash:1017 @xhigh, ollama-cloud/glm-5.3 @xhigh
    arena cross-judge pool: ollama-cloud/minimax-m3.1-flash @xhigh, anthropic/claude-opus-5-5 @high, ollama-cloud/deepseek-v4.1-flash:1017 @xhigh, ollama-cloud/glm-5.3 @xhigh
    architect runners: ollama-cloud/minimax-m3.1-flash @xhigh, anthropic/claude-opus-5-5 @high, ollama-cloud/deepseek-v4.1-flash:1017 @xhigh, ollama-cloud/glm-5.3 @xhigh
    interrogate reviewers: ollama-cloud/minimax-m3.1-flash @xhigh, anthropic/claude-opus-5-5 @high, ollama-cloud/deepseek-v4.1-flash:1017 @xhigh, ollama-cloud/glm-5.3 @xhigh
  '';
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
        'del(.subagents) * $declared[0]' "$settings" > "$merged"
    else
      cp ${piManagedSettingsJson} "$merged"
    fi

    chmod 644 "$merged"
    mv -f "$merged" "$settings"
  '';
in
assert lib.assertMsg (filterProblems == [ ])
  "modules/pi.nix: ${lib.concatStringsSep "; " filterProblems}";
{
  options.dotfiles.pi.linuxProviders = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Add the ollama-cloud model link and the OpenAI model visibility extension, which describe the Linux machines' provider set.";
  };

  config = {
    programs.pi-coding-agent = {
      enable = true;
      package = piFlake.packages.${pkgs.stdenv.hostPlatform.system}.pi;
    };
    # The compact-tools extension reads this at startup. A store symlink, so the
    # style comes from the repo instead of a local edit.
    home.file.".pi/agent/compact-tools.json".source = compactToolsConfig;
    # pstack reads the sheet at every agent start, children included.
    home.file.".pi/agent/pstack-models.md" =
      lib.mkIf config.dotfiles.pi.linuxProviders {
        source = pstackModels;
      };
    # The visible-model rules are hand-written for the providers the Linux
    # machines carry; the macOS row keeps its own provider set.
    home.file.".pi/agent/extensions/openai-model-visibility.ts" =
      lib.mkIf config.dotfiles.pi.linuxProviders {
        source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/modules/pi/openai-model-visibility.ts";
        force = true;
      };
    # Runs before linkGeneration so the first switch can still read the old store
    # symlink and carry the local keys into the regular file.
    home.activation.piSettings =
      lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
        run ${piSettingsMerge}
      '';
  };
}
