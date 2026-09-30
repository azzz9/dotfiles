{ lib, pkgs, ... }:
let
  pinned = import ./pinned-packages.nix { inherit pkgs; };
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
  # The explorer refuses to open on a clean tree, which kills a parked review
  # view. Keep it open so the watcher can fill in edits as they land.
  # Delete this and set explorer.open_on_empty once upstream PR 520 lands.
  codediffNvim = pkgs.vimPlugins.codediff-nvim.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace lua/codediff/commands/handlers/explorer.lua \
        --replace-fail 'if #status_result.unstaged == 0 and #status_result.staged == 0 and not has_conflicts then' 'if false then'
      substituteInPlace lua/codediff/commands/handlers/explorer_staged.lua \
        --replace-fail 'if #status_result.staged == 0 then' 'if false then'
    '';
  });
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
    "plugins/tiny-inline-diagnostic.lua"
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
        vim.g.prettier_plugin_solidity_path = "${pinned.prettierPluginSolidity}/lib/node_modules/prettier-plugin-solidity/dist/index.js"
        vim.g.tsserver_path = "${pkgs.typescript}/lib/node_modules/typescript/lib/tsserver.js"
        vim.g.debugpy_python = "${pinned.debugpyPython}/bin/python"
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
  home.sessionVariables.CODEDIFF_WATCHER_PATH = "${pinned.codediffWatcher}/bin/codediff-watcher";

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
    extraPackages = [ pinned.codediffWatcher ];
    extraPlugins =
      with pkgs.vimPlugins;
      [
        kanagawa-nvim
        flash-nvim
        lualine-nvim
        nvim-web-devicons
        blink-cmp
        telescope-nvim
        codediffNvim
        fff-nvim
        plenary-nvim
        telescope-ui-select-nvim
        nvim-lspconfig
        nvim-autopairs
        trouble-nvim
        tiny-inline-diagnostic-nvim
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
