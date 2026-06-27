{ lib, pkgs, ... }:
let
  solidity = import ./solidity.nix { inherit pkgs; };
  treesitterWithGrammars = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
    p.tree-sitter-bash
    p.tree-sitter-c
    p.tree-sitter-cpp
    p.tree-sitter-css
    p.tree-sitter-html
    p.tree-sitter-javascript
    p.tree-sitter-json
    p.tree-sitter-lua
    p.tree-sitter-markdown
    p.tree-sitter-python
    p.tree-sitter-regex
    p.tree-sitter-solidity
    p.tree-sitter-toml
    p.tree-sitter-typescript
    p.tree-sitter-vim
    p.tree-sitter-yaml
  ]);
  smoothcursorPlugin = pkgs.vimUtils.buildVimPlugin {
    pname = "smoothcursor-nvim";
    version = "2024-04-22";
    src = pkgs.fetchFromGitHub {
      owner = "gen740";
      repo = "SmoothCursor.nvim";
      rev = "12518b284e1e3f7c6c703b346815968e1620bee2";
      hash = "sha256-P0jGm5ODEVbtmqPGgDFBPDeuOF49CFq5x1PzubEJgaM=";
    };
  };
  luaConfigDir = ./nvim/lua;
  luaFiles = [
    "core.lua"
    "plugins/kanagawa.lua"
    "plugins/telescope.lua"
    "plugins/flash.lua"
    "plugins/lazygit.lua"
    "plugins/barbar.lua"
    "plugins/lualine.lua"
    "plugins/nvim-treesitter.lua"
    "plugins/hlchunk.lua"
    "plugins/gitsigns.lua"
    "plugins/gitblame.lua"
    "plugins/diffview.lua"
    "plugins/mini.lua"
    "plugins/oil.lua"
    "plugins/nvim-autopairs.lua"
    "plugins/nvim-surround.lua"
    "plugins/which-key.lua"
    "plugins/neoscroll.lua"
    "plugins/smoothcursor.lua"
    "plugins/noice.lua"
    "plugins/trouble.lua"
    "plugins/todo-comments.lua"
    "languages.lua"
    "plugins/conform.lua"
    "plugins/nvim-lint.lua"
    "ui.lua"
    "plugins/nvim-lspconfig.lua"
    "plugins/blink-cmp.lua"
    "plugins/nvim-dap.lua"
  ];
  readLua = file: builtins.readFile (luaConfigDir + "/${file}");
  # core.lua is always loaded (even inside VSCode). All other files are
  # wrapped in `if not is_vscode then ... end` so Neovim-only plugins
  # are skipped when Neovim runs as a VSCode extension.
  extraConfigLua = lib.concatStringsSep "\n\n" (
    [
      ''
        vim.g.codelldb_path = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb"
        vim.g.prettier_plugin_solidity_path = "${solidity.prettierPluginSolidity}/lib/node_modules/prettier-plugin-solidity/dist/index.js"
        vim.g.tsserver_path = "${pkgs.typescript}/lib/node_modules/typescript/bin/tsserver"
        local is_vscode = vim.g.vscode ~= nil
      ''
      (readLua "core.lua")
      "if not is_vscode then"
    ]
    ++ (map readLua (builtins.filter (file: file != "core.lua") luaFiles))
    ++ [
      ''
        require("dap-python").setup("${solidity.debugpyPython}/bin/python")
        end
      ''
    ]
  );
in
{
  programs.nixvim = {
    enable = true;
    enableMan = false;
    nixpkgs.source = pkgs.path;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    globals = {
      mapleader = " ";
      maplocalleader = "\\";
    };
    opts = {
      clipboard = "unnamedplus";
      number = true;
      relativenumber = false;
      showmatch = true;
      mouse = "a";
      autoread = true;
      updatetime = 1000;
      cursorline = true;
      cursorlineopt = "number";
      tabstop = 2;
      shiftwidth = 2;
      softtabstop = 2;
      expandtab = true;
      autoindent = true;
      smartindent = true;
      copyindent = true;
      preserveindent = true;
      breakindent = true;
    };
    extraPlugins =
      with pkgs.vimPlugins;
      [
        kanagawa-nvim
        noice-nvim
        nui-nvim
        nvim-notify
        flash-nvim
        lualine-nvim
        nvim-web-devicons
        blink-cmp
        telescope-nvim
        plenary-nvim
        telescope-ui-select-nvim
        nvim-lspconfig
        nvim-autopairs
        trouble-nvim
        conform-nvim
        nvim-lint
        nvim-surround
        todo-comments-nvim
        lazygit-nvim
        gitsigns-nvim
        git-blame-nvim
        diffview-nvim
        oil-nvim
        mini-nvim
        barbar-nvim
        nvim-dap
        nvim-dap-ui
        nvim-dap-virtual-text
        nvim-dap-python
        nvim-nio
        nvim-treesitter-textobjects
        hlchunk-nvim
        rainbow-delimiters-nvim
        which-key-nvim
        neoscroll-nvim
        smoothcursorPlugin
      ]
      ++ [ treesitterWithGrammars ];
    inherit extraConfigLua;
  };
}
