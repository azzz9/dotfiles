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
  ];
  mkSkillSymlink = base: name: {
    "${base}/skills/${name}".source =
      config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/${name}";
  };
  skillLinks =
    builtins.foldl'
      (acc: base:
        acc // builtins.foldl' (a: name: a // mkSkillSymlink base name) {} skillNames)
      {}
      [ ".codex" ".copilot" ];
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
  home.file = skillLinks // {
    ".codex/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
    ".codex/rules/default.rules" = {
      source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/codex/rules/default.rules";
      force = true;
    };
    ".copilot/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
  };

  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.codex/config.toml"
    source="${repo}/config/ai/codex/config.base.toml"

    mkdir -p "$HOME/.codex"
    if [ ! -e "$target" ]; then
      cp "$source" "$target"
      chmod 600 "$target"
    fi
  '';

  imports = [
    ../modules/dotfiles-sync.nix
    ../modules/gh.nix
    ../modules/git.nix
    ../modules/lazygit.nix
    ../modules/shell.nix
    ../modules/tmux.nix
    ../modules/nvim.nix
    ../modules/packages.nix
  ];
}
