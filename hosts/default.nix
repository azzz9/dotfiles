{ config, lib, pkgs, llmAgents, ... }:
let
  configuredRepo = builtins.getEnv "DOTFILES_DIR";
  repo =
    if configuredRepo != ""
    then configuredRepo
    else "${config.home.homeDirectory}/src/github.com/azzz9/dotfiles";
  localSkillNames = [
    "archify"
    "conversation-to-memory"
    "conventional-commit"
    "domain-modeling"
    "dotfiles-context"
    "explain"
    "graphify"
    "grill-me"
    "grill-with-docs"
    "grilling"
    "herdr"
    "hunk-review"
    "nix-home-manager"
    "show-me"
  ];
  # Local skills are linked into every runtime that reads them. The links point
  # out of store, so edits in this repo take effect without a rebuild.
  skillLinks = builtins.listToAttrs (
    lib.concatMap (base: map (name: {
      name = "${base}/skills/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/${name}";
    }) localSkillNames) [ ".agents" ]
  );

  # pi writes to ~/.pi/agent/settings.json: /model Ctrl+S persists the startup
  # model there, and `pi install` records packages. A Home Manager generated
  # settings.json is a read-only store symlink, so it cannot hold that state.
  # The `programs.pi-coding-agent.settings` option is therefore unused and the
  # keys below are reconciled into the local file on every activation.
  piManagedSettings = {
    packages = [
      "npm:pi-mcp-adapter"
      "npm:pi-web-access"
      # Pinned so a Home Manager generation always reconciles to this version.
      # pstack for pi, from the personal fork. It carries the upstream port plus
      # the local harness fixes (pi session paths, subagent parameters, no cloud
      # agents, review-automation naming). See the fork's FORK.md.
      "git:github.com/azzz9/pi-pstack@ab2382bf1e5077406b972a3536043f670d9fa8f6"
      # Plugins the port expects: the `todo` tool that the playbooks open, and
      # the structured `ask_user_question` tool that poteto-mode asks through.
      "npm:@juicesharp/rpiv-todo@2.11.0"
      "npm:@juicesharp/rpiv-ask-user-question@2.11.0"
      "npm:pi-subagents@0.70.1"
      # Provider packages are machine-local and must not be listed here.
      # Subscriptions, model catalogs, quotas, and API keys differ per host.
      # Install them per machine instead: copy the package into
      # ~/.pi/agent/extensions/<name>/ (pi auto-discovers it, no settings.json
      # entry needed) or run a local `pi install`. Anything added to this
      # list becomes read-only and cannot be installed or updated locally.
    ];
    # Thinking blocks are noise in a transcript and the conclusion already
    # appears in the answer, so hide them. Nix-owned, unlike the startup model.
    hideThinkingBlock = true;
  };
  # Every other key (default model, theme, and anything else set locally) is
  # carried over untouched: arrays and scalars are replaced, nested objects are
  # merged. The file is written as a regular file, never as a store symlink, so
  # pi can keep writing it.
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
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";
  home.sessionPath =
    [ "${config.home.homeDirectory}/.local/bin" ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "${config.home.homeDirectory}/.nix-profile/bin"
      "/nix/var/nix/profiles/default/bin"
    ];

  programs.home-manager.enable = true;
  programs.pi-coding-agent = {
    enable = true;
    package = llmAgents.packages.${pkgs.system}.pi;
    extraPackages = with pkgs; [
      nodejs
      bun
    ];
  };
  # Runs before linkGeneration so the old read-only store symlink can still be
  # read: the first switch carries the local keys (model, provider) over into
  # the regular file. Afterwards HM leaves the path alone, because it is no
  # longer a link into a Home Manager generation.
  home.activation.piSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run ${piSettingsMerge}
  '';
  # Periodically reclaim unreferenced store paths while retaining recent generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # Home Manager's nix.gc.options is a string and launchd receives it as one
  # ProgramArguments element. Split the Darwin arguments at the launchd layer.
  launchd.agents.nix-gc.config.ProgramArguments = lib.mkIf pkgs.stdenv.isDarwin (
    lib.mkForce [
      "${pkgs.nix}/bin/nix-collect-garbage"
      "--delete-older-than"
      "30d"
    ]
  );
  manual = {
    html.enable = false;
    json.enable = false;
    manpages.enable = false;
  };

  # Out-of-store symlinks keep edits in this repo immediately visible at the
  # target path. pi reads ~/.pi/agent/AGENTS.md as its global context file.
  home.file = skillLinks // {
    ".pi/agent/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
  };

  imports = [
    ../modules/dotfiles.nix
    ../modules/gh.nix
    ../modules/git.nix
    ../modules/hunk.nix
    ../modules/lazygit.nix
    ../modules/shell.nix
    ../modules/herdr.nix
    ../modules/ghostty.nix
    ../modules/nvim.nix
    ../modules/packages.nix
  ];
}
