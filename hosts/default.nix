{ config, lib, pkgs, ... }:
let
  repo = "${config.home.homeDirectory}/src/github.com/azzz9/dotfiles";
  skillNames = [
    "archify"
    "conversation-to-memory"
    "conventional-commit"
    "domain-modeling"
    "explain"
    "graphify"
    "grill-me"
    "grill-with-docs"
    "grilling"
    "herdr"
    "hunk-review"
    "show-me"
  ];
  skillBases = [ ".codex" ".copilot" ];
  # Build a flat attrset of out-of-store symlinks for every skill x base
  # combination, e.g. ".codex/skills/show-me" -> symlink to repo.
  skillLinks = builtins.listToAttrs (
    lib.concatMap (base: map (name: {
      name = "${base}/skills/${name}";
      value.source =
        config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/${name}";
    }) skillNames) skillBases
  );
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

  # Codex / Copilot shared AI context and skills (out-of-store symlinks
  # so edits in this repo are immediately reflected at the target path).
  home.file = skillLinks // {
    ".codex/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
    ".codex/rules/default.rules" = {
      source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/codex/rules/default.rules";
      force = true;
    };
    # Codex profile: repo-owned static settings layered on top of the
    # runtime-mutated ~/.codex/config.toml via `codex -p dotfiles`.
    # config.toml itself is intentionally NOT Nix-managed because Codex
    # writes per-project trust_level and other runtime state into it.
    ".codex/dotfiles.config.toml" = {
      source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/codex/config.base.toml";
      force = true;
    };
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
