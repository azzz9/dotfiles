{
  description = "Home Manager config for azzz";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Temporary: nixos-unstable lags master for the package the overlay below
    # takes from it (tuios 0.8.1 there, 0.8.5 here). The overlay reads this
    # input's package set directly, so it costs one nixpkgs evaluation rather
    # than an import of a second one. Drop the input once the channel catches
    # up.
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
    # Pi's own flake builds the CLI from source. It tracks main rather than the
    # ref upstream offers consumers (`stable`): that branch advances only after
    # a release tag's flake builds on every system, so it lags main whenever the
    # newest tag does not build.
    pi.url = "github:earendil-works/pi";
    # Serein, the Wayland-native Discord client, is not in nixpkgs. It keeps its
    # own locked nixpkgs: a `follows` here would change the derivation.
    serein.url = "github:ViceVerse-cz/Serein";
    # Pi loads these from the store paths Nix fetches for them. flake.lock
    # records the revision, so `nix flake update <name>` is what moves a pin.
    skills = {
      url = "github:azzz9/skills";
      flake = false;
    };
    pi-subagents = {
      url = "github:nicobailon/pi-subagents";
      flake = false;
    };
    pi-web-access = {
      url = "github:nicobailon/pi-web-access";
      flake = false;
    };
    # `cc-safety-net` stays an npm row (see modules/pi.nix), so it is not an
    # input here.
    pi-compact-tools = {
      url = "github:nedleeds/pi-compact-tools";
      flake = false;
    };
    # The Hermes Agent CLI, its Home Manager module, and its package. Its own
    # nixpkgs pin stays separate, like pi's does: the package is a
    # uv2nix venv plus npm frontends resolved against the nixpkgs revision
    # upstream tests against, so following ours would risk that resolution.
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-master,
      home-manager,
      nixvim,
      hunk,
      pi,
      serein,
      skills,
      pi-subagents,
      pi-web-access,
      pi-compact-tools,
      hermes-agent,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
      # One account owns every machine, so the account and the paths under its
      # home are facts this file states instead of environment variables it
      # reads. Pure evaluation is what keeps `nix flake check`, `nix flake
      # metadata`, and every command in scripts/ free of `--impure`. A machine
      # row overrides any of them with `username`, `homeDirectory`, `checkout`,
      # or `skillsCheckout`.
      user = "azzz";
      homeDirectoryFor =
        system: if lib.hasSuffix "-darwin" system then "/Users/${user}" else "/home/${user}";
      defaultCheckout = homeDirectory: "${homeDirectory}/src/github.com/azzz9/dotfiles";
      # The skills repository owns the rules, and ~/.pi/agent/AGENTS.md links
      # to its checkout. Like `checkout`, the path is a machine fact, so it
      # never follows the checkout that ran the switch.
      defaultSkillsCheckout = homeDirectory: "${homeDirectory}/src/github.com/azzz9/skills";
      # The pi packages, by flake input name. A row hands pi that input's store
      # path, so pi loads the source flake.lock locked.
      piPackagePaths = {
        inherit
          skills
          pi-subagents
          pi-web-access
          pi-compact-tools
          ;
      };
      # One table for every machine. The key names homeConfigurations.<name>,
      # and nixosConfigurations.<name> for a row that carries a nixos path. The
      # key is the machine's hostname, so the CLI and the bootstrap resolve a
      # machine with no mapping table of their own.
      machines = {
        nix-desktop = {
          system = "x86_64-linux";
          nixos = ./hosts/platform/nixos/machines/nix-desktop;
          home = [
            ./modules/niri.nix
            ./modules/ime.nix
          ];
        };
        macbook = {
          system = "aarch64-darwin";
        };
        # The gateway is a systemd user service, so only this machine asks for
        # the module.
        nix-server = {
          system = "x86_64-linux";
          nixos = ./hosts/platform/nixos/machines/nix-server;
          home = [ ./modules/hermes.nix ];
        };
      };
      # The names the `dotfiles` CLI and its completion offer.
      machineNames = nixpkgs.lib.attrNames machines;
      mkHomeConfiguration =
        name:
        {
          system,
          home ? [ ],
          username ? user,
          homeDirectory ? homeDirectoryFor system,
          checkout ? defaultCheckout homeDirectory,
          skillsCheckout ? defaultSkillsCheckout homeDirectory,
          ...
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "barbar.nvim"
              ];
            overlays = [
              # nixpkgs-master fills what nixos-unstable has not caught up with.
              # tuios is the live one: unstable's 0.8.1 predates the herdr socket
              # API. `legacyPackages` reads that input's package set directly, so
              # this evaluates one nixpkgs rather than importing a second one.
              (_final: prev: {
                inherit (nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system}) tuios;
              })
            ];
          };
          extraSpecialArgs = {
            repoDir = checkout;
            worktreeRoot = "worktrees";
            inherit skillsCheckout machineNames piPackagePaths;
            inherit username homeDirectory;
            machine = name;
            inherit hunk;
            piFlake = pi;
            # modules/hermes.nix imports this input's Home Manager module.
            hermesAgent = hermes-agent;
          };
          modules = [
            ./hosts/default.nix
            nixvim.homeModules.nixvim
          ]
          ++ home;
        };
      # The NixOS system layer. Each machine directory imports the shared
      # modules and its own hardware-configuration.nix.
      mkNixosSystem =
        _:
        { system, nixos, ... }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            serein = serein.packages.${system}.serein;
          };
          modules = [ nixos ];
        };
      # One package set per system, so the packages, the checks, the formatter,
      # and the dev shell share one evaluation.
      pkgsFor = system: import nixpkgs { inherit system; };
      # The pinned derivations in modules/pinned-packages.nix, exposed as
      # flake packages so `nix-update --flake <name>` (the bump `dotfiles
      # upgrade` runs) can find and rewrite them. Build pkgs the same way
      # mkChecks does: these derivations need neither the unfree allowlist nor
      # the tuios overlay.
      mkPackages =
        system:
        let
          pkgs = pkgsFor system;
          pinned = import ./modules/pinned-packages.nix { inherit pkgs; };
        in
        {
          # The CI audit runs the CLI from here, so it is the script the
          # machines install. Its runtime inputs come from the plain package
          # set, not the home configuration's overlay, which carries only tuios.
          dotfiles = import ./dotfiles-cli.nix {
            inherit (nixpkgs) lib;
            inherit pkgs machineNames;
            checkout = defaultCheckout (homeDirectoryFor system);
            piFlake = pi;
          };
          inherit (pinned) solhint;
          "prettier-plugin-solidity" = pinned.prettierPluginSolidity;
          "prettier-plugin-solidity-dist" = pinned.prettierPluginSolidityDist;
          inherit (pinned) roots;
          codediff-watcher = pinned.codediffWatcher;
          herdr-nvim = pinned.herdrNvim;
        };
      # The verification layer, one file per check. scripts/check.sh, the
      # pre-push hook, and CI all run these.
      mkChecks =
        system:
        let
          pkgs = pkgsFor system;
          # `generated-configs` parses the config the machines on this platform
          # emit, so it needs their names, not the platform name.
          platformMachines = nixpkgs.lib.filterAttrs (_: machine: machine.system == system) machines;
        in
        import ./checks {
          inherit
            self
            pkgs
            platformMachines
            machines
            ;
        };
      homeConfigurations = nixpkgs.lib.mapAttrs mkHomeConfiguration machines;
      # Only the rows that carry a nixos path have a system configuration.
      nixosConfigurations = nixpkgs.lib.mapAttrs mkNixosSystem (
        nixpkgs.lib.filterAttrs (_: m: m ? nixos) machines
      );
      # `nix fmt` and `nix develop` are the two entry points a contributor has
      # before any check runs. The formatter matches what Neovim's conform.nvim
      # calls, so an editor save and `nix fmt` cannot disagree. nixfmt itself
      # reads stdin with no argument and does not recurse, so the wrapper
      # expands a directory (`.` by default) and leaves flags alone.
      mkFormatter =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.writeShellApplication {
          name = "nixfmt";
          runtimeInputs = [
            pkgs.nixfmt
            pkgs.findutils
          ];
          text = ''
            flags=()
            targets=()
            for argument in "$@"; do
              case "$argument" in
                -*) flags+=("$argument") ;;
                *) targets+=("$argument") ;;
              esac
            done
            if [ "''${#targets[@]}" -eq 0 ]; then
              targets=(.)
            fi
            files=()
            for target in "''${targets[@]}"; do
              if [ -d "$target" ]; then
                while IFS= read -r file; do
                  files+=("$file")
                done < <(find "$target" -type f -name '*.nix')
              else
                files+=("$target")
              fi
            done
            nixfmt "''${flags[@]}" "''${files[@]}"
          '';
        };
      mkDevShell =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            deadnix
            statix
            stylua
            shellcheck
            actionlint
            git
          ];
        };
    in
    {
      inherit homeConfigurations nixosConfigurations;
      packages = forAllSystems mkPackages;
      checks = forAllSystems mkChecks;
      formatter = forAllSystems mkFormatter;
      devShells = forAllSystems (system: {
        default = mkDevShell system;
      });
    };
}
