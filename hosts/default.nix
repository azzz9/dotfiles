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
    "poteto-mode"
    "show-me"
  ];
  # Local skills are linked into every runtime that reads them. The links point
  # out of store, so edits in this repo take effect without a rebuild.
  skillLinks = builtins.listToAttrs (
    lib.concatMap (base: map (name: {
      name = "${base}/skills/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/${name}";
    }) localSkillNames) [ ".agents" ".copilot" ]
  );

  # pi writes to ~/.pi/agent/settings.json: /model Ctrl+S persists the startup
  # model there, and `pi install` records packages. A Home Manager generated
  # settings.json is a read-only store symlink, so it cannot hold that state.
  # The `programs.pi-coding-agent.settings` option is therefore unused and this
  # package list is reconciled into the local file on every activation.
  piPackages = [
    "npm:pi-mcp-adapter"
    "npm:pi-web-access"
    # Pinned so a Home Manager generation always reconciles to this ref.
    # poteto-mode is vendored at config/ai/skills/poteto-mode with a valid
    # skill name; skip the package copy so only the repo copy registers.
    # make-bot-ui declares `name: Make Bot UI`, which pi rejects as an
    # invalid skill name at startup, and the skill drives Cursor-only tools.
    {
      source = "git:github.com/backnotprop/pstack@157aae39a733135e93d8b5b19ff62c6a84b0ad56";
      skills = [ "!poteto-mode" "!make-bot-ui" ];
    }
    "npm:pi-subagents@0.70.1"
    # Provider packages are machine-local and must not be listed here.
    # Subscriptions, model catalogs, quotas, and API keys differ per host.
    # Install them per machine instead: copy the package into
    # ~/.pi/agent/extensions/<name>/ (pi auto-discovers it, no settings.json
    # entry needed) or run a local `pi install`. Anything added to this
    # list becomes read-only and cannot be installed or updated locally.
  ];
  # Only `packages` is Nix-owned. Every other key (default model, theme, and
  # anything else set locally) is carried over untouched. The file is written
  # as a regular file, never as a store symlink, so pi can keep writing it.
  piPackagesJson = (pkgs.formats.json { }).generate "pi-packages.json" { packages = piPackages; };
  piSettingsMerge = pkgs.writeShellScript "pi-settings-packages" ''
    set -euo pipefail

    settings="''${HOME}/.pi/agent/settings.json"
    merged="''${settings}.hm-tmp"

    if [ -e "$settings" ] && ! ${pkgs.jq}/bin/jq -e . "$settings" >/dev/null 2>&1; then
      echo "pi-settings-packages: $settings is not valid JSON; leaving it untouched" >&2
      exit 0
    fi

    mkdir -p "$(dirname "$settings")"

    if [ -e "$settings" ]; then
      ${pkgs.jq}/bin/jq --slurpfile declared ${piPackagesJson} \
        '.packages = $declared[0].packages' "$settings" > "$merged"
    else
      cp ${piPackagesJson} "$merged"
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
  home.activation.piPackages = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
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
  # target path.
  home.file = skillLinks // {
    ".copilot/copilot-instructions.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
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
