{ config, lib, pkgs, llmAgents, ... }:
let
  configuredRepo = builtins.getEnv "DOTFILES_DIR";
  repo =
    if configuredRepo != ""
    then configuredRepo
    else "${config.home.homeDirectory}/src/github.com/azzz9/dotfiles";
  localSkillNames = [
    "archify"
    "conversation-to-memory"
    "conventional-commit"
    "domain-modeling"
    "dotfiles-context"
    "explain"
    "graphify"
    "grill-me"
    "grill-with-docs"
    "grilling"
    "herdr"
    "hunk-review"
    "nix-home-manager"
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
      bases = [ ".agents" ".codex" ".copilot" ];
    }
    {
      root = "${repo}/config/ai/pstack/skills";
      names = pstackSkillNames;
      # Copilot CLI currently rejects explicitly invoked skills that carry
      # disable-model-invocation. Keep the shared source and Codex copy intact.
      bases = [ ".codex" ".copilot" ];
      copilotCompat = true;
    }
  ];
  pstackSourceRoot = ../config/ai/pstack/skills;
  pstackSkillSource = name: builtins.path {
    path = "${pstackSourceRoot}/${name}";
    name = "pstack-${name}";
  };
  # Temporary workaround for github/copilot-cli#4438 and #4451. Copy the
  # complete skill tree so playbooks and scripts remain available to Copilot.
  copilotPstackSkillSources = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = pkgs.runCommand "copilot-pstack-${name}" {} ''
        cp -R ${pstackSkillSource name} "$out"
        chmod -R u+w "$out"
        sed -i '/^disable-model-invocation: true$/d' "$out/SKILL.md"
      '';
    }) pstackSkillNames
  );
  # Build runtime-specific skill links.
  skillLinks = builtins.listToAttrs (
    lib.concatMap ({ root, names, bases, copilotCompat ? false }:
      lib.concatMap (base: map (name: {
        name = "${base}/skills/${name}";
        value.source =
          if copilotCompat && base == ".copilot"
          then builtins.getAttr name copilotPstackSkillSources
          else config.lib.file.mkOutOfStoreSymlink "${root}/${name}";
      }) names) bases
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
  programs.pi-coding-agent = {
    enable = true;
    package = llmAgents.packages.${pkgs.system}.pi;
    extraPackages = with pkgs; [
      nodejs
      bun
    ];
    settings = {
      packages = [
        "npm:pi-mcp-adapter"
        "npm:pi-web-access"
        # Harness-neutral pstack mirror, kept separate from config/ai/pstack.
        # Pinned so a Home Manager generation always reconciles to this ref.
        "git:github.com/backnotprop/pstack@157aae39a733135e93d8b5b19ff62c6a84b0ad56"
        "npm:pi-subagents@0.70.1"
        # Ollama Cloud account surface: model discovery, web tools, quota
        # bars, and per-model spend. Registers provider id "ollama-cloud";
        # do not add pi-ollama-cloud or pi-free alongside it (same id).
        "npm:pi-ollama-cloud-link@1.1.0"
      ];
    };
  };
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

  # Local Codex / OMP / Copilot skills use out-of-store symlinks so edits in
  # this repo are immediately reflected at the target path. Pstack skills use
  # runtime-specific roots because Copilot needs a sanitized copy.
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
    # Shared pstack policy is runtime-neutral. Keep its contract in the
    # common .agents root so Codex and Copilot can read the same file.
    ".agents/pstack/runtime.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/pstack/runtime.md";
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
