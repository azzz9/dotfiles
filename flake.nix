{
  description = "Home Manager config for azzz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nixvim, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
      {
			homeConfigurations = {
				arch-linux = home-manager.lib.homeManagerConfiguration {
					inherit pkgs;
					modules = [
						./hosts/arch-linux.nix
						nixvim.homeModules.nixvim
					];
				};
				ubuntu = home-manager.lib.homeManagerConfiguration {
					inherit pkgs;
					modules = [
						./hosts/ubuntu.nix
						nixvim.homeModules.nixvim
					];
				};
			};
    };
}
