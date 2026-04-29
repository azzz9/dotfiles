{
  description = "Home Manager config for azzz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-codex.url = "github:NixOS/nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-codex, home-manager, nixvim, ... }:
    let
      system = "x86_64-linux";
      overlays = [
        (final: prev: {
          # Track codex faster than nixos-unstable by sourcing only this package
          # from nixpkgs master.
          codex = nixpkgs-codex.legacyPackages.${system}.codex;
        })
      ];
      pkgs = import nixpkgs {
        inherit system overlays;
      };
    in
      {
        homeConfigurations = {
          default = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              ./hosts/default.nix
              nixvim.homeModules.nixvim
            ];
          };
        };
      };
}
