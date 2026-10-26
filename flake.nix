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
    # Pi's own flake builds the CLI from source. It tracks main rather than the
    # ref upstream offers consumers (`stable`): that branch advances only after
    # a release tag's flake builds on every system, so it lags main whenever the
    # newest tag does not build.
    pi.url = "github:earendil-works/pi";
    # Pi loads these from the store paths Nix fetches for them. flake.lock
    # records the revision, so `nix flake update <name>` is what moves a pin.
    skills = { url = "github:azzz9/skills"; flake = false; };
    pstack = { url = "github:michael-denyer/pstack-claude"; flake = false; };
    pi-web-access = { url = "github:nicobailon/pi-web-access"; flake = false; };
    # `cc-safety-net` stays an npm row (see modules/pi.nix), so it is not an
    # input here.
    pi-compact-tools = { url = "github:nedleeds/pi-compact-tools"; flake = false; };
    # The Hermes Agent CLI, its Home Manager module, and its package. Its own
    # nixpkgs pin stays separate, like pi's does: the package is a
    # uv2nix venv plus npm frontends resolved against the nixpkgs revision
    # upstream tests against, so following ours would risk that resolution.
    hermes-agent = { url = "github:NousResearch/hermes-agent"; };
  };

  outputs =
    { self, nixpkgs, home-manager, nixvim, pi
    , skills, pstack, pi-web-access, pi-compact-tools
    , hermes-agent, ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      defaultCheckout = "${builtins.getEnv "HOME"}/src/github.com/azzz9/dotfiles";
      # The pi packages, by flake input name. A row hands pi that input's store
      # path, so pi loads the source flake.lock locked.
      piPackagePaths = {
        inherit skills pstack pi-web-access pi-compact-tools;
      };
      # One table for every machine. The key names homeConfigurations.<name>
      # and is the machine's hostname, so the CLI and the bootstrap resolve a
      # machine with no mapping table of their own. The OS side of each machine
      # lives in its own repository.
      machines = {
        nix-desktop = {
          system = "x86_64-linux";
          home = [ ./hosts/linux.nix ./modules/niri.nix ./modules/fcitx5.nix ];
        };
        macbook = {
          system = "aarch64-darwin";
          home = [ ./hosts/darwin.nix ];
        };
        # The gateway is a systemd user service, so only this machine asks for
        # the module.
        nix-server = {
          system = "x86_64-linux";
          home = [ ./hosts/linux.nix ./modules/hermes.nix ];
        };
      };
      # The names the `dotfiles` CLI and its completion offer.
      machineNames = nixpkgs.lib.attrNames machines;
      # Everything the common layer needs that is not a per-machine fact. A
      # machine repository spreads this into extraSpecialArgs, so the flake
      # inputs stay owned here.
      homeArgs = { machine, machineNames, repoDir, worktreeRoot ? "worktrees" }: {
        inherit machine machineNames repoDir worktreeRoot skills piPackagePaths;
        piFlake = pi;
        hermesAgent = hermes-agent;
      };
      mkHomeConfiguration = name: { system, home ? [ ], checkout ? defaultCheckout, ... }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
              "barbar.nvim"
            ];
          };
          extraSpecialArgs = homeArgs { inherit machineNames; machine = name; repoDir = checkout; };
          modules = [
            ./hosts/default.nix
            nixvim.homeModules.nixvim
          ] ++ home;
        };
      # The pinned derivations in modules/pinned-packages.nix, exposed as
      # flake packages so `nix-update --flake <name>` (the pin bump) can find
      # and rewrite them. Build pkgs the same way
      # mkChecks does: these derivations need neither the unfree allowlist nor
      # the home configuration's package set.
      mkPackages = system:
        let
          pkgs = import nixpkgs { inherit system; };
          pinned = import ./modules/pinned-packages.nix { inherit pkgs; };
        in
        {
          # The CI audit runs the CLI from here, so it is the script the
          # machines install. Its runtime inputs come from the plain package
          # set, not the home configuration's pkgs.
          dotfiles = import ./dotfiles-cli.nix {
            inherit (nixpkgs) lib;
            inherit pkgs machineNames;
            checkout = defaultCheckout;
            piFlake = pi;
          };
          solhint = pinned.solhint;
          "prettier-plugin-solidity" = pinned.prettierPluginSolidity;
          "prettier-plugin-solidity-dist" = pinned.prettierPluginSolidityDist;
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
    in
    {
      inherit homeConfigurations;
      # The common layer on its own, for a machine repository that builds its own
      # home configuration: spread `homeArgs` into extraSpecialArgs and add this
      # module to the module list.
      homeManagerModules.default = {
        imports = [ ./hosts/default.nix nixvim.homeModules.nixvim ];
      };
      lib.homeArgs = homeArgs;
      packages = forAllSystems mkPackages;
      checks = forAllSystems mkChecks;
    };
}
