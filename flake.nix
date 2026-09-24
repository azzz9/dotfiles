{
  description = "Home Manager config for azzz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Temporary: nixos-unstable lacks herdr 0.7.3 (PR #539412). Pull it from
    # master through the overlay below; drop both once the channel catches up.
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
      # bun2nix (hunk's input) evaluates flake.formatter for every system in
      # github:nix-systems/default, including x86_64-darwin, which unstable
      # nixpkgs (26.11+) dropped. That transitive eval throws even when building
      # for x86_64-linux and breaks `dotfiles upgrade`, so pin hunk to 26.05 (the
      # last branch with x86_64-darwin) instead of following our nixpkgs.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    };
    # Pi is packaged by numtide/llm-agents.nix. Keep its nixpkgs pin separate
    # so its binary cache stays usable.
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    { self, nixpkgs, nixpkgs-master, home-manager, nixvim, hunk, llm-agents, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      # Resolved once. hosts/default.nix and modules/dotfiles.nix both need the
      # checkout path, and HOME matches the home.homeDirectory those modules set.
      repoDir =
        let configured = builtins.getEnv "DOTFILES_DIR";
        in
        if configured != "" then configured else "${builtins.getEnv "HOME"}/src/github.com/azzz9/dotfiles";
      mkHomeConfiguration = system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
              "barbar.nvim"
            ];
            overlays = [
              # Temporary herdr 0.7.3 override; drop with the nixpkgs-master input.
              (_final: prev: {
                herdr = (import nixpkgs-master {
                  inherit system;
                  config.allowUnfreePredicate = prev.config.allowUnfreePredicate;
                }).herdr;
              })
            ];
          };
          extraSpecialArgs = {
            inherit repoDir supportedSystems;
            hunk = hunk;
            llmAgents = llm-agents;
          };
          modules = [
            ./hosts/default.nix
            nixvim.homeModules.nixvim
          ];
        };
      # The verification layer. scripts/check.sh, the pre-push hook, and CI all
      # run these, so a check cannot drift between them. Registry-vs-disk
      # equality is enforced by asserts in modules/nvim.nix and hosts/default.nix.
      mkChecks = system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          deadnix = pkgs.runCommand "deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            deadnix --fail ${self}
            touch $out
          '';
          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            shellcheck ${self}/scripts/*.sh ${self}/.githooks/pre-push
            bash -n ${self}/scripts/*.sh ${self}/.githooks/pre-push
            touch $out
          '';
          actionlint = pkgs.runCommand "actionlint" { nativeBuildInputs = [ pkgs.actionlint ]; } ''
            actionlint ${self}/.github/workflows/*.yml
            touch $out
          '';
          # The generated files are only text until a tool parses them, so parse
          # every config this flake emits.
          generated-configs = pkgs.runCommand "generated-configs" {
            nativeBuildInputs = [ pkgs.python3 pkgs.yq-go pkgs.zsh pkgs.lua5_1 ];
          } ''
            files=${self.homeConfigurations.${system}.activationPackage}/home-files
            for f in .config/herdr/config.toml .config/hunk/config.toml; do
              python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$files/$f"
            done
            for f in .config/lazygit/config.yml .config/gh/config.yml; do
              yq -e '.' "$files/$f" > /dev/null
            done
            zsh -n "$files/.zshrc"
            lua -e "assert(loadfile('$files/.config/nvim/init.lua'))"
            touch $out
          '';
        };
    in
    {
      homeConfigurations = forAllSystems mkHomeConfiguration;
      checks = forAllSystems mkChecks;
    };
}
