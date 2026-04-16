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
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      mkPkgs = system:
        import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              # Track codex faster than nixos-unstable by sourcing only this package
              # from nixpkgs master.
              codex = nixpkgs-codex.legacyPackages.${system}.codex;
            })
          ];
        };
      mkHomeConfiguration = system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          modules = [
            ./hosts/default.nix
            nixvim.homeModules.nixvim
          ];
        };
    in
      {
        homeConfigurations =
          (forAllSystems mkHomeConfiguration)
          // {
            default = mkHomeConfiguration "x86_64-linux";
          };
      };
}
