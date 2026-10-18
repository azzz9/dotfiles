{ config, lib, pkgs, skillsCheckout, ... }:
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

  # pi reads ~/.pi/agent/AGENTS.md as its global context file. The file belongs to
  # the skills repository, which owns the rules, and the out-of-store link to it
  # keeps an edit there immediately visible at the target path.
  #
  # dsh-agent-instructions@0.2.0-rc.2 reads the user-global file at
  # $DSH_HOME/AGENTS.md. The dsh layer is Linux-only, so the link follows it.
  home.file = {
    ".pi/agent/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${skillsCheckout}/AGENTS.md";
    # Pi appends this one to the system prompt on every turn. The rules live there.
    ".pi/agent/APPEND_SYSTEM.md".source = config.lib.file.mkOutOfStoreSymlink "${skillsCheckout}/APPEND_SYSTEM.md";
  } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    ".dsh/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${skillsCheckout}/AGENTS.md";
  };

  imports = [
    ./platform/darwin.nix
    ./platform/linux.nix
    ../modules/dotfiles.nix
    ../modules/pi.nix
    ../modules/dsh.nix
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
