{ config, hunk, pkgs, lib, ... }:
let
  upstreamHunk = hunk.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # The upstream hunk package builds with `bun build --compile` and ships with
  # `dontFixup = true`, so the single-file binary has no DT_RUNPATH. Its
  # interpreter is Nix's ld-linux but it resolves libc from the host (e.g.
  # glibc 2.43 on Arch/WSL2), mismatching Nix's glibc 2.42 ld-linux and
  # segfaulting on startup.
  #
  # We cannot fix this with patchelf (it relocates ELF sections and corrupts
  # Bun's embedded archive) nor with LD_LIBRARY_PATH alone: even with the
  # matching Nix glibc loaded, the kernel-mapped direct launch segfaults in a
  # BSS page (strace: SEGV_MAPERR @ 0x6510e40) because the kernel does not map
  # the binary's last BSS page the way ld-linux does. The binary runs correctly
  # only when ld-linux maps it explicitly.
  #
  # So on Linux we wrap `hunk` to launch the real binary through the matching
  # ld-linux with --library-path. Trade-off: process.execPath then points at
  # ld-linux, which breaks the TUI's auto-spawn of the session daemon
  # (`hunk session` uses process.execPath to relaunch itself) and the bundled
  # `hunk skill path` lookup. The session daemon can still be started manually
  # with `hunk daemon serve`, and the review skill is deployed separately to
  # ~/.codex/skills/hunk-review and ~/.copilot/skills/hunk-review below.
  # darwin is unaffected (no ld-linux) and uses the upstream package directly.
  hunkPackage =
    if pkgs.stdenv.isLinux then
      pkgs.runCommand "hunk-wrapped" { } ''
        mkdir -p $out
        cp -r ${upstreamHunk}/. $out/
        chmod -R u+w $out
        mv $out/bin/hunk $out/bin/.hunk-real
        cat > $out/bin/hunk <<EOF
        #!${pkgs.bash}/bin/bash
        exec ${lib.getLib pkgs.glibc}/lib/ld-linux-x86-64.so.2 --library-path ${lib.getLib pkgs.glibc}/lib $out/bin/.hunk-real "\$@"
        EOF
        chmod +x $out/bin/hunk
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
  # This also works around the wrapper breaking `hunk skill path`: agents can
  # read the skill directly from these deployed paths.
  home.file = {
    ".codex/skills/hunk-review".source =
      "${config.programs.hunk.package}/skills/hunk-review";
    ".copilot/skills/hunk-review".source =
      "${config.programs.hunk.package}/skills/hunk-review";
  };
}
