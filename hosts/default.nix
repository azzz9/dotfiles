{ config, lib, pkgs, ... }:
let
  repo = "${config.home.homeDirectory}/src/github.com/azzz9/dotfiles";
  localSkillNames = [
    "archify"
    "conversation-to-memory"
    "conventional-commit"
    "domain-modeling"
    "explain"
    "graphify"
    "grill-me"
    "grill-with-docs"
    "grilling"
    "herdr"
    "hunk-review"
    "show-me"
  ];
  # Vendored from cursor/plugins pstack at c1c0a32802223f4be824112dd83d33ad29a8b26c.
  pstackSkillNames = [
    "architect"
    "arena"
    "automate-me"
    "blast-radius"
    "bro"
    "create-verification-skill"
    "figure-it-out"
    "how"
    "interrogate"
    "maintain-verification-skill"
    "make-bot-ui"
    "no-comments"
    "poteto-mode"
    "principle-attack-the-premise"
    "principle-boundary-discipline"
    "principle-build-the-lever"
    "principle-encode-lessons-in-structure"
    "principle-exhaust-the-design-space"
    "principle-experience-first"
    "principle-fix-root-causes"
    "principle-foundational-thinking"
    "principle-guard-the-context-window"
    "principle-laziness-protocol"
    "principle-make-operations-idempotent"
    "principle-migrate-callers-then-delete-legacy-apis"
    "principle-minimize-reader-load"
    "principle-model-the-domain"
    "principle-never-block-on-the-human"
    "principle-outcome-oriented-execution"
    "principle-prove-it-works"
    "principle-redesign-from-first-principles"
    "principle-separate-before-serializing-shared-state"
    "principle-sequence-verifiable-units"
    "principle-subtract-before-you-add"
    "principle-test-behavior-not-implementation"
    "principle-type-system-discipline"
    "recall"
    "reflect"
    "setup-pstack"
    "show-me-your-work"
    "swarm"
    "tdd"
    "teach"
    "technical-writing"
    "typescript-best-practices"
    "unslop"
    "why"
  ];
  skillSources = [
    {
      root = "${repo}/config/ai/skills";
      names = localSkillNames;
    }
    {
      root = "${repo}/config/ai/pstack/skills";
      names = pstackSkillNames;
    }
  ];
  skillBases = [ ".agents" ".codex" ".copilot" ];
  # Build out-of-store symlinks for every skill x runtime combination.
  skillLinks = builtins.listToAttrs (
    lib.concatMap ({ root, names }:
      lib.concatMap (base: map (name: {
        name = "${base}/skills/${name}";
        value.source =
          config.lib.file.mkOutOfStoreSymlink "${root}/${name}";
      }) names) skillBases
    ) skillSources
  );
in
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";
  home.sessionPath =
    [ "${config.home.homeDirectory}/.local/bin" ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "${config.home.homeDirectory}/.nix-profile/bin"
      "/nix/var/nix/profiles/default/bin"
    ];

  programs.home-manager.enable = true;
  # Periodically reclaim unreferenced store paths while retaining recent generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # Home Manager's nix.gc.options is a string and launchd receives it as one
  # ProgramArguments element. Split the Darwin arguments at the launchd layer.
  launchd.agents.nix-gc.config.ProgramArguments = lib.mkIf pkgs.stdenv.isDarwin (
    lib.mkForce [
      "${pkgs.nix}/bin/nix-collect-garbage"
      "--delete-older-than"
      "30d"
    ]
  );
  manual = {
    html.enable = false;
    json.enable = false;
    manpages.enable = false;
  };

  # Codex / OMP / Copilot shared AI skills (out-of-store symlinks
  # so edits in this repo are immediately reflected at the target path).
  home.file = skillLinks // {
    ".codex/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
    ".codex/rules/default.rules" = {
      source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/codex/rules/default.rules";
      force = true;
    };
    # Codex profile: repo-owned static settings layered on top of the
    # runtime-mutated ~/.codex/config.toml via `codex -p dotfiles`.
    # config.toml itself is intentionally NOT Nix-managed because Codex
    # writes per-project trust_level and other runtime state into it.
    ".codex/dotfiles.config.toml" = {
      source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/codex/config.base.toml";
      force = true;
    };
    ".copilot/copilot-instructions.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
  };

  imports = [
    ../modules/dotfiles.nix
    ../modules/gh.nix
    ../modules/git.nix
    ../modules/hunk.nix
    ../modules/lazygit.nix
    ../modules/shell.nix
    ../modules/herdr.nix
    ../modules/ghostty.nix
    ../modules/nvim.nix
    ../modules/packages.nix
  ];
}
