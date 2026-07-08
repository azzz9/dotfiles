{ config, hunk, pkgs, lib, ... }:
let
  upstreamHunk = hunk.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # The upstream hunk package builds with `bun build --compile` and ships with
  # `dontFixup = true`, so the single-file binary has no DT_RUNPATH. Its
  # interpreter is Nix's ld-linux, but without a runpath it resolves libc from
  # the host (e.g. glibc 2.43 on Arch/WSL2), which mismatches Nix's glibc 2.42
  # ld-linux and segfaults on startup.
  #
  # patchelf can't fix this: it relocates ELF sections and corrupts Bun's
  # embedded archive. Instead we wrap the binary, prepending the matching Nix
  # glibc to LD_LIBRARY_PATH. This keeps process.execPath pointing at the real
  # binary (so the daemon self-reexec in `hunk session` and the bundled skill
  # path resolution still work) and only affects hunk's own libc load.
  hunkPackage =
    if pkgs.stdenv.isLinux then
      pkgs.runCommand "hunk-wrapped"
        { nativeBuildInputs = [ pkgs.makeWrapper ]; }
        ''
          mkdir -p $out
          cp -r ${upstreamHunk}/. $out/
          chmod -R u+w $out
          wrapProgram $out/bin/hunk --prefix LD_LIBRARY_PATH : ${lib.getLib pkgs.glibc}/lib
        ''
    else
      upstreamHunk;
in
{
  # Import the upstream Home Manager module, which provides the `programs.hunk`
  # option (package + ~/.config/hunk/config.toml generation).
  imports = [ hunk.homeManagerModules.default ];

  programs.hunk = {
    enable = true;
    package = hunkPackage;

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
