{ lib, pkgs, llmAgents, repoDir, supportedSystems, ... }:
let
  supportedHosts = lib.concatStringsSep " " supportedSystems;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "dotfiles";
      # writeShellApplication runs shellcheck during the build, so the CLI is
      # linted by the build itself and not only by CI.
      runtimeInputs = with pkgs; [ nix git coreutils gnugrep gnused bash nix-update ]
        ++ [ llmAgents.packages.${pkgs.stdenv.hostPlatform.system}.pi ];
      text = ''
        # Values come from flake.nix; scripts/dotfiles.sh reads them.
        DOTFILES_DIR=${lib.escapeShellArg repoDir}
        DOTFILES_SUPPORTED_HOSTS=${lib.escapeShellArg supportedHosts}
      ''
      # scripts/pi-reconcile.sh is a leaf the CLI calls, not a second command.
      + builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (builtins.readFile ../scripts/pi-reconcile.sh)
      + builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (builtins.readFile ../scripts/dotfiles.sh);
    })
  ];
}
