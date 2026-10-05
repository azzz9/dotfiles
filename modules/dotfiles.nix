{ lib, pkgs, llmAgents, repoDir, machineNames, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "dotfiles";
      # writeShellApplication runs shellcheck during the build, so the CLI is
      # linted by the build itself and not only by CI.
      runtimeInputs = with pkgs; [ nix git coreutils gnugrep gnused bash nix-update jq curl hostname ]
        ++ [ llmAgents.packages.${pkgs.stdenv.hostPlatform.system}.pi ];
      text = ''
        # Values come from flake.nix; scripts/dotfiles.sh reads them.
        # Exported because flake.nix's repoDir reads it back via builtins.getEnv during evaluation.
        export DOTFILES_DIR=${lib.escapeShellArg repoDir}
        DOTFILES_MACHINES=${lib.escapeShellArg (lib.concatStringsSep " " machineNames)}
      ''
      # scripts/pi-reconcile.sh is a leaf the CLI calls, not a second command.
      # Join with a newline so a body without a trailing newline cannot merge
      # its last line into the next file's first line.
      + builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (builtins.readFile ../scripts/pi-reconcile.sh)
      + "\n"
      + builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (builtins.readFile ../scripts/dotfiles.sh);
    })
  ];
}
