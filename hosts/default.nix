{ config, ... }:
let
  repo = "${config.home.homeDirectory}/dotfiles";
in
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
  manual = {
    html.enable = false;
    json.enable = false;
    manpages.enable = false;
  };

  home.file.".codex/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/AGENTS.md";
  home.file.".codex/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/config.toml";
  home.file.".codex/rules/default.rules".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/codex/rules/default.rules";
  home.file.".copilot/skills/grill-me".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.codex/skills/grill-me";
  home.file."AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/AGENTS.md";

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
