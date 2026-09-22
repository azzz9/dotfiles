{ lib, pkgs, repoDir, supportedSystems, ... }:
let
  supportedHosts = lib.concatStringsSep " " supportedSystems;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "dotfiles";
      # writeShellApplication runs shellcheck during the build, so the CLI is
      # linted by the build itself and not only by CI.
      runtimeInputs = with pkgs; [ nix git coreutils gnugrep gnused bash ];
      text = ''
        # Values come from flake.nix; scripts/dotfiles.sh reads them.
        DOTFILES_DIR=${lib.escapeShellArg repoDir}
        DOTFILES_SUPPORTED_HOSTS=${lib.escapeShellArg supportedHosts}
      '' + builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (builtins.readFile ../scripts/dotfiles.sh);
    })
  ];
}
