{ lib, pkgs, ... }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
  prettierPluginSolidityDist = pkgs.fetchurl {
    url = "https://registry.npmjs.org/prettier-plugin-solidity/-/prettier-plugin-solidity-2.3.1.tgz";
    hash = "sha256-KQqnnYIFE37d+qa7AB4LECsEcoFeyRfwgCJE6OtLXwA=";
  };
  prettierPluginSolidity = pkgs.buildNpmPackage rec {
    pname = "prettier-plugin-solidity";
    version = "2.3.1";
    src = pkgs.fetchFromGitHub {
      owner = "prettier-solidity";
      repo = "prettier-plugin-solidity";
      rev = "v${version}";
      hash = "sha256-zo5kw8ObjCRubucNe2MKhcjd5uYv9clfolIHtiM6/rQ=";
    };
    npmDepsHash = "sha256-BEk3Sh9NDFVifzCfY6Iq1pesUau3qUi954KR7JPWbZc=";
    postInstall = ''
      rm -rf "$out/lib/node_modules/${pname}/dist"
      tar -xzf ${prettierPluginSolidityDist} -C "$out/lib/node_modules/${pname}" --strip-components=1 package/dist
      ln -s ${pkgs.prettier}/lib/node_modules/prettier "$out/lib/node_modules/${pname}/node_modules/prettier"
    '';
  };
  treesitterWithGrammars = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
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
    "plugins/bufferline.lua"
    "plugins/lualine.lua"
    "plugins/nvim-treesitter.lua"
    "plugins/indent-blankline.lua"
    "plugins/gitsigns.lua"
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
    "plugins/conform.lua"
    "plugins/nvim-lint.lua"
    "ui.lua"
    "plugins/nvim-lspconfig.lua"
    "plugins/blink-cmp.lua"
    "plugins/nvim-dap.lua"
  ];
  readLua = file: builtins.readFile (luaConfigDir + "/${file}");
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
        diffview-nvim
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
      ''
        vim.g.codelldb_path = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb"
        vim.g.prettier_plugin_solidity_path = "${prettierPluginSolidity}/lib/node_modules/prettier-plugin-solidity/dist/index.js"
        local is_vscode = vim.g.vscode ~= nil
      ''
      + "\n\n"
      + readLua "core.lua"
      + "\n\n"
      + ''
        if not is_vscode then
      ''
      + "\n\n"
      + lib.concatMapStringsSep "\n\n" readLua (builtins.filter (file: file != "core.lua") luaFiles)
      + "\n\n"
      + ''
        require("dap-python").setup("${debugpyPython}/bin/python")
        end
      '';
  };
}
