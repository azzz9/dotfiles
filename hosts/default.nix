{ skills, ... }:
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
  # Weekly GC, keeping 30 days of generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  manual = {
    html.enable = false;
    json.enable = false;
    manpages.enable = false;
  };

  # pi reads ~/.pi/agent/AGENTS.md as its global context file.
  home.file = {
    ".pi/agent/AGENTS.md".source = "${skills}/AGENTS.md";
    # Pi appends this one to the system prompt on every turn.
    ".pi/agent/APPEND_SYSTEM.md".source = "${skills}/APPEND_SYSTEM.md";
  };

  imports = [
    ./platform/darwin.nix
    ./platform/linux.nix
    ../modules/dotfiles.nix
    ../modules/pi.nix
    ../modules/gh.nix
    ../modules/gh-dash.nix
    ../modules/git.nix
    ../modules/hunk.nix
    ../modules/lazygit.nix
    ../modules/shell.nix
    ../modules/herdr.nix
    ../modules/tuios.nix
    ../modules/ghostty.nix
    ../modules/nvim.nix
    ../modules/packages.nix
  ];
}
