{ lib, pkgs, llmAgents, machineNames, repoDir, ... }:
{
  # The CLI itself is dotfiles-cli.nix, because flake.nix exposes the same
  # script as a package for the CI audit. Its runtime inputs come from the plain
  # package set, which is what that package builds it against as well.
  home.packages = [
    (import ../dotfiles-cli.nix { inherit lib pkgs llmAgents machineNames; checkout = repoDir; })
  ];
}
