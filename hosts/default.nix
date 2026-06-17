{ config, ... }:
let
  repo = "${config.home.homeDirectory}/dotfiles";
in
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  programs.home-manager.enable = true;
  manual = {
    html.enable = false;
    json.enable = false;
    manpages.enable = false;
  };

  home.file.".codex/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/AGENTS.md";
  home.file.".codex/config.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/config.toml";
    force = true;
  };
  home.file.".codex/rules/default.rules" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/rules/default.rules";
    force = true;
  };
  home.file.".codex/skills/conventional-commit".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/skills/conventional-commit";
  home.file.".codex/skills/difit-review".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/skills/difit-review";
  home.file.".codex/skills/grill-me".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/skills/grill-me";
  home.file.".copilot/skills/conventional-commit".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/skills/conventional-commit";
  home.file.".copilot/skills/difit-review".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/skills/difit-review";
  home.file.".copilot/skills/grill-me".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/skills/grill-me";

  imports = [
    ../modules/dotfiles-sync.nix
    ../modules/gh.nix
    ../modules/lazygit.nix
    ../modules/shell.nix
    ../modules/tmux.nix
    ../modules/nvim.nix
    ../modules/packages.nix
  ];
}
