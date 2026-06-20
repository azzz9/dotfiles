{
  description = "Home Manager config for azzz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, codex-cli-nix, home-manager, nixvim, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      mkHomeConfiguration = system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { inherit system; };
          extraSpecialArgs = {
            codexPackage = codex-cli-nix.packages.${system}.default;
          };
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
