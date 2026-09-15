{
  description = "Home Manager config for azzz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Temporary: nixos-unstable does not yet have herdr 0.7.3 (PR #539412
    # merged 2026-07-08, channel propagation pending). Pull herdr from
    # master via an overlay until nixos-unstable catches up, then remove
    # this input and the overlay below.
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hunk = {
      url = "github:modem-dev/hunk";
      # bun2nix (hunk's input) uses flake-parts + treefmt-nix, which
      # evaluates `flake.formatter` for every system in its `systems`
      # list (github:nix-systems/default = all systems), including
      # x86_64-darwin. nixpkgs unstable (26.11+) dropped x86_64-darwin
      # support, so that transitive evaluation throws -- even when
      # building for x86_64-linux -- and breaks `dotfiles upgrade`.
      # Do NOT follow our unstable nixpkgs here; pin hunk/bun2nix's
      # nixpkgs to the 26.05 stable branch (the last to support
      # x86_64-darwin) so the transitive eval only warns, not errors.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    };
  };

  outputs = { nixpkgs, nixpkgs-master, home-manager, nixvim, hunk, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      mkHomeConfiguration = system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
              "barbar.nvim"
            ];
            overlays = [
              # Temporary: override herdr with 0.7.3 from nixpkgs master.
              # Remove this overlay (and the nixpkgs-master input) once
              # nixos-unstable includes herdr >= 0.7.3.
              (final: prev: {
                herdr = (import nixpkgs-master {
                  inherit system;
                  config.allowUnfreePredicate = prev.config.allowUnfreePredicate;
                }).herdr;
              })
            ];
          };
          extraSpecialArgs = {
            hunk = hunk;
          };
          modules = [
            ./hosts/default.nix
            nixvim.homeModules.nixvim
          ];
        };
    in
    {
      homeConfigurations = forAllSystems mkHomeConfiguration;
    };
}
