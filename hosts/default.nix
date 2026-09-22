{ config, lib, pkgs, repoDir, ... }:
let
  # Every directory under config/ai/skills is a global skill, so the list is
  # derived. Skills that only make sense in this repo live in .agents/skills.
  skillsDir = ../config/ai/skills;
  localSkillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir)
  );
  skillsWithoutSkillFile = lib.filter (name: !builtins.pathExists (skillsDir + "/${name}/SKILL.md")) localSkillNames;

  # Out-of-store links, so edits here take effect without a rebuild.
  skillLinks = builtins.listToAttrs (
    lib.concatMap (base: map (name: {
      name = "${base}/skills/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/ai/skills/${name}";
    }) localSkillNames) [ ".agents" ]
  );
in
assert lib.assertMsg (skillsWithoutSkillFile == [ ])
  "hosts/default.nix: config/ai/skills entries without SKILL.md: ${toString skillsWithoutSkillFile}";
{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";
  home.sessionPath =
    [ "${config.home.homeDirectory}/.local/bin" ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      "${config.home.homeDirectory}/.nix-profile/bin"
      "/nix/var/nix/profiles/default/bin"
    ];

  programs.home-manager.enable = true;
  # Weekly GC, keeping 30 days of generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # nix.gc.options is one string and launchd takes one argument per element, so
  # split the Darwin arguments at the launchd layer.
  launchd.agents.nix-gc.config.ProgramArguments = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
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

  # pi reads ~/.pi/agent/AGENTS.md as its global context file. Out-of-store links
  # keep edits in this repo immediately visible at the target path.
  home.file = skillLinks // {
    ".pi/agent/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/ai/AGENTS.md";
  };

  imports = [
    ../modules/dotfiles.nix
    ../modules/pi.nix
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
