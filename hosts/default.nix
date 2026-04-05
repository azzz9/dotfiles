{ ... }:
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  imports = [
    ../modules/dotfiles-sync.nix
    ../modules/gh.nix
    ../modules/shell.nix
    ../modules/tmux.nix
    ../modules/nvim.nix
    ../modules/packages.nix
  ];
}
