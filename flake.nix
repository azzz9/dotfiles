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
      # The git packages pi installs. flake.lock records owner, repo, and
      # revision for every locked input, so one node carries both the identity
      # pi keys a package and its checkout by (spec) and the revision the pin
      # sits at. A row in modules/pi.nix names only the input; spec and rev
      # both come from here, so no module holds a sha or a second spec string.
      piGitLock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes;
      piGitSource = name:
        let node = piGitLock.${name}.locked;
        in {
          inherit (node) owner repo rev;
          spec = "github.com/${node.owner}/${node.repo}";
        };
      piGitSources = {
        pi-pstack = piGitSource "pi-pstack";
        i-have-adhd = piGitSource "i-have-adhd";
        pi-subagents = piGitSource "pi-subagents";
        pi-web-access = piGitSource "pi-web-access";
        pi-compact-tools = piGitSource "pi-compact-tools";
      };
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
            inherit repoDir supportedSystems piGitSources;
            hunk = hunk;
            llmAgents = llm-agents;
          };
          modules = [
            ./hosts/default.nix
            nixvim.homeModules.nixvim
          ];
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
            # The reconcile step's manifest: one "<host/owner/repo> <40-hex
            # rev>" line per git package, and a short sha is the failure this
            # manifest exists to prevent.
            pins="$files/.pi/agent/.dotfiles-pi-pins"
            entries=$(grep -c . "$pins" || true)
            pinned=$(grep -Ec '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+){2} [0-9a-f]{40}$' "$pins" || true)
            test "$entries" -gt 0
            test "$entries" -eq "$pinned"
            touch $out
          '';
          pi-reconcile = pkgs.runCommand "pi-reconcile" {
            nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.jq pkgs.git ];
          } ''
            export HOME=$TMPDIR/home GIT_CONFIG_NOSYSTEM=1
            export PATH=$TMPDIR/bin:$PATH
            mkdir -p "$HOME/.pi/agent/git/github.com/example" "$HOME/.pi/agent/npm/node_modules" "$TMPDIR/bin"

            # Keep the heredoc body at this indentation; nix strips the common
            # indent from the whole string, which is what puts the shebang at
            # column zero in the stub.
            cat > "$TMPDIR/bin/pi" <<'STUB'
            #!/bin/sh
            printf '%s\n' "$*" >> "$HOME/pi-calls"
            STUB
            chmod +x "$TMPDIR/bin/pi"

            checkout=$HOME/.pi/agent/git/github.com/example/pkg
            git init -q "$checkout"
            git -C "$checkout" -c user.email=check@invalid -c user.name=check \
              commit -q --allow-empty -m pinned
            pinned=$(git -C "$checkout" rev-parse HEAD)
            pinnedRepo=github.com/example/pkg
            pinnedSpec=git:github.com/example/pkg
            npmName='@example/rpiv-todo'
            npmSource="npm:$npmName@2.12.0"
            pins=$HOME/.pi/agent/.dotfiles-pi-pins
            settings=$HOME/.pi/agent/settings.json
            source ${self}/scripts/pi-reconcile.sh

            npm_dir=$HOME/.pi/agent/npm/node_modules/$npmName
            mkdir -p "$npm_dir"
            printf '{"version":"2.12.0"}\n' > "$npm_dir/package.json"
            printf '{"packages":["%s","%s"]}\n' "$pinnedSpec" "$npmSource" > "$settings"

            # Off the pinned revision, one scoped update with no @ref. The npm
            # spec is installed at its version, so it asks pi nothing.
            printf '%s %040d\n' "$pinnedRepo" 0 > "$pins"
            pi_reconcile
            test "$(cat "$HOME/pi-calls")" = "update $pinnedSpec"

            # On the pinned revision, the next apply asks pi nothing.
            printf '%s %s\n' "$pinnedRepo" "$pinned" > "$pins"
            pi_reconcile
            test "$(wc -l < "$HOME/pi-calls")" = 1

            # An npm package whose installed version differs is installed once.
            printf '{"version":"2.11.0"}\n' > "$npm_dir/package.json"
            pi_reconcile
            test "$(sed -n 2p "$HOME/pi-calls")" = "install $npmSource"
            test "$(wc -l < "$HOME/pi-calls")" = 2

            # On the pinned version, the next apply asks pi nothing.
            printf '{"version":"2.12.0"}\n' > "$npm_dir/package.json"
            pi_reconcile
            test "$(wc -l < "$HOME/pi-calls")" = 2

            # A package.json that is not there needs the install too.
            rm -rf "$npm_dir"
            pi_reconcile
            test "$(wc -l < "$HOME/pi-calls")" = 3

            # With npm converged again, a missing checkout is the only drift.
            mkdir -p "$npm_dir"
            printf '{"version":"2.12.0"}\n' > "$npm_dir/package.json"
            rm -rf "$checkout"
            pi_reconcile
            test "$(wc -l < "$HOME/pi-calls")" = 4

            # No manifest, nothing to converge, and the apply still succeeds.
            rm -f "$pins"
            pi_reconcile
            test "$(wc -l < "$HOME/pi-calls")" = 4

            # A pi that cannot move the checkout fails the apply.
            printf '%s %040d\n' "$pinnedRepo" 0 > "$pins"
            printf '#!/bin/sh\nexit 1\n' > "$TMPDIR/bin/pi"
            chmod +x "$TMPDIR/bin/pi"
            if pi_reconcile 2>/dev/null; then
              echo "pi_reconcile passed while pi failed" >&2
              exit 1
            fi
            touch $out
          '';
        };
    in
    {
      homeConfigurations = forAllSystems mkHomeConfiguration;
      packages = forAllSystems mkPackages;
      checks = forAllSystems mkChecks;
    };
}
