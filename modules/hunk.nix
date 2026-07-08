{ config, hunk, ... }:
{
  # Import the upstream Home Manager module, which provides the `programs.hunk`
  # option (package + ~/.config/hunk/config.toml generation).
  imports = [ hunk.homeManagerModules.default ];

  programs.hunk = {
    enable = true;

    # NOTE: We do NOT use the upstream `enableGitIntegration` option here.
    # It writes to `programs.git.settings.core.pager`, which only takes
    # effect when `programs.git.enable = true`. This repo manages git config
    # via activation scripts in modules/git.nix instead, so the git pager is
    # set there to stay consistent with the existing pattern.
    settings = {
      mode = "auto";
      line_numbers = true;
      wrap_lines = false;
    };
  };

  # Expose the hunk-review agent skill (bundled in the hunk package) to the
  # same two bases the repo uses for its skills (Codex + Copilot). Symlinking
  # the package's bundled copy keeps the skill in sync with the installed
  # hunk version automatically, unlike a static copy in the repo. The repo's
  # own skill symlinks (hosts/default.nix) point into the checkout, so we do
  # NOT add "hunk-review" to `skillNames` there to avoid a duplicate key.
  home.file = {
    ".codex/skills/hunk-review".source =
      "${config.programs.hunk.package}/skills/hunk-review";
    ".copilot/skills/hunk-review".source =
      "${config.programs.hunk.package}/skills/hunk-review";
  };
}
