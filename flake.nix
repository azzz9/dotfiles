{
  description = "Home Manager config for azzz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Temporary: nixos-unstable lags master for the packages the overlay below
    # takes from it (tuios 0.8.1 there, 0.8.5 here). Drop both once the channel
    # catches up; herdr already matches unstable at 0.9.3.
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
    # Pi installs these as git packages. Nix locks their revisions, so
    # `nix flake update <name>` is what moves a pin and flake.lock is what
    # records it. Nothing reads the input trees, so none of these builds.
    pi-pstack = { url = "github:azzz9/pi-pstack"; flake = false; };
    i-have-adhd = { url = "github:ayghri/i-have-adhd"; flake = false; };
    pi-subagents = { url = "github:nicobailon/pi-subagents"; flake = false; };
    pi-web-access = { url = "github:nicobailon/pi-web-access"; flake = false; };
    # `cc-safety-net` stays an npm row (see modules/pi.nix): its repository runs
    # `lefthook install` from a prepare script, which a pi git install cannot
    # satisfy, so it is deliberately not an input here.
    pi-compact-tools = { url = "github:nedleeds/pi-compact-tools"; flake = false; };
    herdr-auto-title = { url = "github:kryptamine/herdr-auto-title"; flake = false; };
  };

  outputs =
    { self, nixpkgs, nixpkgs-master, home-manager, nixvim, hunk, llm-agents
    , pi-pstack, pi-subagents, pi-web-access, pi-compact-tools, i-have-adhd, ...
    }:
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
      lockedSources = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes;
      lockedSource = name:
        let node = lockedSources.${name}.locked;
        in {
          inherit (node) owner repo rev;
          spec = "github.com/${node.owner}/${node.repo}";
        };
      # The git packages pi installs, by flake input name. Nix hands pi each
      # input's store path, so pi loads the exact source flake.lock locked and
      # nothing has to move that checkout afterwards.
      piPackagePaths = {
        inherit pi-pstack i-have-adhd pi-subagents pi-web-access pi-compact-tools;
      };
      herdrAutoTitleSource = lockedSource "herdr-auto-title";
      # One table for every machine, and one name for both layers. The key is
      # the homeConfigurations attribute, and with it the nixosConfigurations
      # attribute for a row that carries a nixos path. The hostname on each
      # machine is the key, so the CLI and the bootstrap need no
      # platform-to-attribute mapping. The NixOS platform directory holds that
      # machine's own system files next to the shared modules it imports.
      machines = {
        desktop = { system = "x86_64-linux"; nixos = ./hosts/platform/nixos/machines/desktop; };
        mac = { system = "aarch64-darwin"; };
        # headless = { system = "x86_64-linux"; nixos = ./hosts/platform/nixos/machines/headless; }; # add once it has its hardware-configuration.nix
      };
      # The names the `dotfiles` CLI and its completion offer.
      machineNames = nixpkgs.lib.attrNames machines;
      mkHomeConfiguration = _: { system, home ? [ ], ... }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
              "barbar.nvim"
            ];
            overlays = [
              # nixpkgs-master fills what nixos-unstable has not caught up with.
              # herdr is a no-op here now (unstable has 0.9.3 too); tuios is the
              # live one, because unstable's 0.8.1 predates the herdr socket API.
              (_final: prev: {
                inherit (import nixpkgs-master {
                  inherit system;
                  config.allowUnfreePredicate = prev.config.allowUnfreePredicate;
                }) herdr tuios;
              })
            ];
          };
          extraSpecialArgs = {
            inherit repoDir machineNames piPackagePaths herdrAutoTitleSource;
            hunk = hunk;
            llmAgents = llm-agents;
          };
          modules = [
            ./hosts/default.nix
            nixvim.homeModules.nixvim
          ] ++ home;
        };
      # The NixOS system layer. Each machine directory imports the shared
      # modules and its own hardware-configuration.nix, so the flake owns the
      # system configuration the same way it owns the user profiles.
      mkNixosSystem = _: { system, nixos, ... }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ nixos ];
        };
      # The pinned derivations in modules/pinned-packages.nix, exposed as
      # flake packages so `nix-update --flake <name>` (the bump `dotfiles
      # upgrade` runs) can find and rewrite them. Build pkgs the same way
      # mkChecks does: these derivations need neither the unfree allowlist nor
      # the temporary herdr overlay.
      mkPackages = system:
        let
          pkgs = import nixpkgs { inherit system; };
          pinned = import ./modules/pinned-packages.nix { inherit pkgs; };
        in
        {
          solhint = pinned.solhint;
          "prettier-plugin-solidity" = pinned.prettierPluginSolidity;
          "prettier-plugin-solidity-dist" = pinned.prettierPluginSolidityDist;
          roots = pinned.roots;
          codediff-watcher = pinned.codediffWatcher;
          herdr-nvim = pinned.herdrNvim;
        };
      # The verification layer, one file per check. scripts/check.sh, the
      # pre-push hook, and CI all run these.
      mkChecks = system:
        let
          pkgs = import nixpkgs { inherit system; };
          # `generated-configs` parses the config the machines on this platform
          # emit, so it needs their names, not the platform name.
          platformMachines = nixpkgs.lib.filterAttrs (_: machine: machine.system == system) machines;
        in
        import ./checks {
          inherit self pkgs platformMachines;
        };
      homeConfigurations = nixpkgs.lib.mapAttrs mkHomeConfiguration machines;
      # Only the rows that carry a nixos path have a system configuration.
      nixosConfigurations = nixpkgs.lib.mapAttrs mkNixosSystem (nixpkgs.lib.filterAttrs (_: m: m ? nixos) machines);
    in
    {
      inherit homeConfigurations nixosConfigurations;
      packages = forAllSystems mkPackages;
      checks = forAllSystems mkChecks;
    };
}
