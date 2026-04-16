{ lib, pkgs, ... }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
in
{
  home.packages =
    (with pkgs; [
      lazygit
      nodejs_24
      debugpyPython
      codex
      yazi
      fd
      ripgrep
      jq
      poppler-utils
      ffmpegthumbnailer
      unar
      p7zip
      imagemagick
      resvg
      tree-sitter
      lua-language-server
      pyright
      stylua
      selene
      ruff
      typescript
      typescript-language-server
      prettier
      prettierd
      eslint_d
      clang-tools
    ])
    ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
      xclip
      wl-clipboard
    ]);
}
