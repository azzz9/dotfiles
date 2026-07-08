{
  description = "Home Manager config for azzz";

  # Numtide binary cache for llm-agents.nix packages (e.g. codex).
  # Nix rejects a top-level `let ... in { ... }` in flake.nix
  # ("must be an attribute set"), so these values are inlined here
  # instead of imported from config/numtide-cache.nix. The same URL/key
  # also live in config/numtide-cache.nix (used by modules/dotfiles.nix);
  # keep both in sync.
  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Temporary: nixos-unstable does not yet have herdr 0.7.3 (PR #539412
    # merged 2026-07-08, channel propagation pending). Pull herdr from
    # master via an overlay until nixos-unstable catches up, then remove
    # this input and the overlay below.
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    llm-agents.url = "github:numtide/llm-agents.nix";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-master, llm-agents, home-manager, nixvim, hunk, ... }:
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
            # llm-agents.nix is packages-only (no overlay/HM module).
            # Guard with `or null` so unsupported systems (e.g. aarch64-darwin
            # if not yet packaged) do not break the build; packages.nix
            # skips null entries.
            codexPackage = (llm-agents.packages.${system} or { }).codex or null;
            copilotPackage = (llm-agents.packages.${system} or { })."copilot-cli" or null;
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
