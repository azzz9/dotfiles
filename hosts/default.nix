{ config, lib, ... }:
let
  repo = "${config.home.homeDirectory}/src/github.com/azzz9/dotfiles";
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

  home.file.".codex/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
  home.file.".codex/rules/default.rules" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/codex/rules/default.rules";
    force = true;
  };
  home.file.".codex/skills/conventional-commit".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/conventional-commit";
  home.file.".codex/skills/difit-review".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/difit-review";
  home.file.".codex/skills/domain-modeling".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/domain-modeling";
  home.file.".codex/skills/grill-me".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/grill-me";
  home.file.".codex/skills/grill-with-docs".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/grill-with-docs";
  home.file.".codex/skills/grilling".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/grilling";
  home.file.".codex/skills/agent-dev-workflow".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/agent-dev-workflow";
  home.file.".codex/skills/solidity-agent-dev-workflow".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/solidity-agent-dev-workflow";
  home.file.".copilot/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/AGENTS.md";
  home.file.".copilot/skills/conventional-commit".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/conventional-commit";
  home.file.".copilot/skills/difit-review".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/difit-review";
  home.file.".copilot/skills/domain-modeling".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/domain-modeling";
  home.file.".copilot/skills/grill-me".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/grill-me";
  home.file.".copilot/skills/grill-with-docs".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/grill-with-docs";
  home.file.".copilot/skills/grilling".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/grilling";
  home.file.".copilot/skills/agent-dev-workflow".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/agent-dev-workflow";
  home.file.".copilot/skills/solidity-agent-dev-workflow".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config/ai/skills/solidity-agent-dev-workflow";

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
