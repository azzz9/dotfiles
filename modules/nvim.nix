{ lib, pkgs, ... }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
  treesitterWithGrammars = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
  smoothcursorPlugin = pkgs.vimUtils.buildVimPlugin {
    name = "smoothcursor-nvim";
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
    "plugins/gruvbox-material.lua"
    "plugins/telescope.lua"
    "plugins/flash.lua"
    "plugins/lazygit.lua"
    "plugins/bufferline.lua"
    "plugins/lualine.lua"
    "plugins/nvim-treesitter.lua"
    "plugins/indent-blankline.lua"
    "plugins/gitsigns.lua"
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
    "plugins/copilot.lua"
    "plugins/copilot-chat.lua"
    "plugins/conform.lua"
    "plugins/nvim-lint.lua"
    "ui.lua"
    "plugins/nvim-lspconfig.lua"
    "plugins/nvim-cmp.lua"
    "plugins/nvim-dap.lua"
  ];
  readLua = file: builtins.readFile (luaConfigDir + "/${file}");
in
{
  programs.nixvim = {
    enable = true;
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
      relativenumber = true;
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
    };
    extraPlugins =
      with pkgs.vimPlugins;
      [
        gruvbox-material
        noice-nvim
        nui-nvim
        nvim-notify
        flash-nvim
        lualine-nvim
        nvim-web-devicons
        nvim-cmp
        cmp-nvim-lsp
        cmp_luasnip
        cmp-buffer
        cmp-path
        cmp-cmdline
        luasnip
        friendly-snippets
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
        copilot-lua
        CopilotChat-nvim
        gitsigns-nvim
        oil-nvim
        mini-nvim
        bufferline-nvim
        nvim-dap
        nvim-dap-ui
        nvim-dap-virtual-text
        nvim-dap-python
        nvim-nio
        nvim-treesitter-textobjects
        indent-blankline-nvim
        rainbow-delimiters-nvim
        which-key-nvim
        neoscroll-nvim
        smoothcursorPlugin
      ]
      ++ [ treesitterWithGrammars ];
    extraConfigLua =
      lib.concatMapStringsSep "\n\n" readLua luaFiles
      + "\n\n"
      + ''
        require("dap-python").setup("${debugpyPython}/bin/python")
      '';
  };
}
