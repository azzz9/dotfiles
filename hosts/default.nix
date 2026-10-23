{ config, lib, skills, ... }:
let
  cfg = config.dotfiles;
in
{
  imports = [
    ../modules/dotfiles.nix
    ../modules/pi.nix
    ../modules/gh.nix
    ../modules/git.nix
    ../modules/lazygit.nix
    ../modules/shell.nix
    ../modules/herdr.nix
    ../modules/nvim.nix
    ../modules/packages.nix
  ];

  # A machine names its platform by importing hosts/linux.nix or hosts/darwin.nix.
  # The assertion turns a forgotten import into an evaluation failure instead of
  # a home without its PATH and platform settings.
  options.dotfiles.platform = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "linux" "darwin" ]);
    default = null;
  };

  config = {
    assertions = [
      {
        assertion = cfg.platform != null;
        message = "This machine imports no platform module; add hosts/linux.nix or hosts/darwin.nix to its home modules.";
      }
    ];

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
  };
}
