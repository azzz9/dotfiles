{ config, lib, ... }:
let
  repo = "${config.home.homeDirectory}/src/github.com/azzz9/dotfiles";
  skillNames = [
    "conventional-commit"
    "difit-review"
    "domain-modeling"
    "grill-me"
    "grill-with-docs"
    "grilling"
    "agent-dev-workflow"
    "solidity-agent-dev-workflow"
    "tmux"
    "ascii-art-diagrams"
    "dotfiles-context"
    "nix-home-manager"
  ];
  skillBases = [ ".codex" ".copilot" ];
  # Build a flat attrset of out-of-store symlinks for every skill x base
  # combination, e.g. ".codex/skills/tmux" -> symlink to repo.
  skillLinks = builtins.listToAttrs (
    lib.concatMap (base: map (name: {
      name = "${base}/skills/${name}";
      value.source =
        config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/${name}";
    }) skillNames) skillBases
  );
  # On-demand rule files split from AGENTS.md. Symlinked alongside the
  # main instructions file so agents can read them via relative path
  # `rules/<name>.md` when the situation applies.
  ruleNames = [
    "file-change-reporting"
    "git-commit-push"
    "diagrams"
  ];
  ruleLinks = builtins.listToAttrs (
    lib.concatMap (base: map (name: {
      name = "${base}/rules/${name}.md";
      value.source =
        config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/rules/${name}.md";
    }) ruleNames) skillBases
  );
in
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  programs.home-manager.enable = true;
  manual = {
    html.enable = false;
    json.enable = false;
    manpages.enable = false;
  };

  # Codex / Copilot shared AI context and skills (out-of-store symlinks
  # so edits in this repo are immediately reflected at the target path).
  home.file = skillLinks // ruleLinks // {
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
    ../modules/tmux.nix
    ../modules/nvim.nix
    ../modules/packages.nix
  ];
}
