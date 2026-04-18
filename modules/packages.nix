{ pkgs, ... }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
in
{
  home.packages = with pkgs; [
    lazygit
    nodejs_24
    debugpyPython
    codex
    xclip
    wl-clipboard
    fd
    ripgrep
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
  ];
}
