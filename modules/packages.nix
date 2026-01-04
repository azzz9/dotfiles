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
    fd
    ripgrep
    tree-sitter
    lua-language-server
    pyright
    stylua
    selene
    ruff
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.prettier
    prettierd
    nodePackages.eslint_d
  ];
}
