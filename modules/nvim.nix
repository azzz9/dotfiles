{ lib, pkgs, ... }:
let
  solidity = import ./solidity.nix { inherit pkgs; };
  # Keep this release aligned with codediff.nvim's watcher VERSION.
  codediffWatcherVersion = "0.23.2";
  codediffWatcherTarget = {
    "x86_64-linux" = {
      os = "linux";
      arch = "x64";
      hash = "sha256-acXsKVZCUZ952p57kIkK0TLw/YDiiD9v9pZxBqAF27w=";
    };
    "aarch64-darwin" = {
      os = "macos";
      arch = "arm64";
      hash = "sha256-LOudhXiteUsNAYkwbwTQdf7GEdLAYfeL24q4SBri0t4=";
    };
  }.${pkgs.stdenv.hostPlatform.system};
  codediffWatcher = pkgs.stdenvNoCC.mkDerivation {
    pname = "codediff-watcher";
    version = codediffWatcherVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/esmuellert/codediff/releases/download/v${codediffWatcherVersion}/codediff-watcher-${codediffWatcherVersion}-${codediffWatcherTarget.os}-${codediffWatcherTarget.arch}.tar.gz";
      hash = codediffWatcherTarget.hash;
    };
    sourceRoot = ".";
    nativeBuildInputs = lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;
    buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.glibc
      pkgs.stdenv.cc.cc.lib
    ];
    installPhase = ''
      install -Dm755 codediff-watcher "$out/bin/codediff-watcher"
    '';
    meta = {
      description = "Native file watcher for codediff.nvim";
      homepage = "https://github.com/esmuellert/codediff";
      license = lib.licenses.mit;
      mainProgram = "codediff-watcher";
    };
  };
  treesitterWithGrammars = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
    p.tree-sitter-bash
    p.tree-sitter-c
    p.tree-sitter-nix
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
  luaConfigDir = ./nvim/lua;
  luaFiles = [
    "core.lua"
    "plugins/kanagawa.lua"
    "plugins/telescope.lua"
    "plugins/fff.lua"
    "plugins/flash.lua"
    "plugins/lazygit.lua"
    "plugins/barbar.lua"
    "plugins/lualine.lua"
    "plugins/nvim-treesitter.lua"
    "plugins/hlchunk.lua"
    "plugins/smear-cursor.lua"
    "plugins/gitsigns.lua"
    "plugins/gitblame.lua"
    "plugins/codediff.lua"
    "plugins/mini.lua"
    "plugins/oil.lua"
    "plugins/nvim-autopairs.lua"
    "plugins/nvim-surround.lua"
    "plugins/which-key.lua"
    "plugins/trouble.lua"
    "plugins/todo-comments.lua"
    "languages.lua"
    "plugins/conform.lua"
    "plugins/nvim-lint.lua"
    "ui.lua"
    "plugins/nvim-lspconfig.lua"
    "plugins/blink-cmp.lua"
    "plugins/dap/init.lua"
    "plugins/dap/c.lua"
    "plugins/dap/python.lua"
    "plugins/dap/javascript.lua"
  ];
  readLua = file: builtins.readFile (luaConfigDir + "/${file}");

  # Order matters (dap/init.lua defines the helpers the adapters use), so
  # luaFiles stays a list. This listing keeps it in sync with the directory.
  listLuaFiles = prefix: dir:
    lib.concatLists (lib.mapAttrsToList
      (name: type:
        let rel = if prefix == "" then name else "${prefix}/${name}";
        in
        if type == "directory" then listLuaFiles rel (dir + "/${name}")
        else lib.optional (lib.hasSuffix ".lua" name) rel)
      (builtins.readDir dir));
  luaFilesOnDisk = listLuaFiles "" luaConfigDir;
  luaFilesUnlisted = lib.subtractLists luaFiles luaFilesOnDisk;
  luaFilesAbsent = lib.subtractLists luaFilesOnDisk luaFiles;

  # core.lua loads unconditionally; every other file sits inside the
  # `if not is_vscode` wrapper so Neovim-only plugins are skipped in VSCode.
  extraConfigLua = lib.concatStringsSep "\n\n" (
    [
      ''
        vim.g.codelldb_path = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb"
        vim.g.prettier_plugin_solidity_path = "${solidity.prettierPluginSolidity}/lib/node_modules/prettier-plugin-solidity/dist/index.js"
        vim.g.tsserver_path = "${pkgs.typescript}/lib/node_modules/typescript/lib/tsserver.js"
        vim.g.debugpy_python = "${solidity.debugpyPython}/bin/python"
        vim.g.js_debug_path = "${pkgs.vscode-js-debug}/bin/js-debug"
        local is_vscode = vim.g.vscode ~= nil
      ''
      (readLua "core.lua")
      "if not is_vscode then"
    ]
    ++ (map readLua (builtins.filter (file: file != "core.lua") luaFiles))
    ++ [
      ''
        end
      ''
    ]
  );
in
assert lib.assertMsg (luaFilesUnlisted == [ ] && luaFilesAbsent == [ ])
  "modules/nvim.nix: luaFiles is out of sync with modules/nvim/lua/ (not listed: ${toString luaFilesUnlisted}; listed but absent: ${toString luaFilesAbsent})";
{
  home.sessionVariables.CODEDIFF_WATCHER_PATH = "${codediffWatcher}/bin/codediff-watcher";

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
    extraPackages = [ codediffWatcher ];
    extraPlugins =
      with pkgs.vimPlugins;
      [
        kanagawa-nvim
        flash-nvim
        lualine-nvim
        nvim-web-devicons
        blink-cmp
        telescope-nvim
        codediff-nvim
        fff-nvim
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
        smear-cursor-nvim
        which-key-nvim
      ]
      ++ [ treesitterWithGrammars ];
    inherit extraConfigLua;
  };
}
