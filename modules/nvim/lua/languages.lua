      -- Single source of truth for language tool mappings.
      -- Used by conform.lua, nvim-lint.lua, and nvim-lspconfig.lua.
      --
      -- Adding a new language:
      --   1. Add entry here (lsp / formatters / linters)
      --   2. Add the corresponding packages to modules/packages.nix
      --   3. Add LSP-specific config to nvim-lspconfig.lua if needed
      --      (custom cmd, root_dir, settings, etc.)
      local _langs = {
        lua = {
          lsp = "lua_ls",
          formatters = { "stylua" },
          linters = { "selene" },
        },
        python = {
          lsp = "pyright",
          formatters = { "ruff_format" },
          linters = { "ruff" },
        },
        typescript = {
          lsp = "ts_ls",
          formatters = { "prettierd", "prettier" },
          linters = { "eslint_d" },
        },
        javascript = {
          formatters = { "prettierd", "prettier" },
          linters = { "eslint_d" },
        },
        javascriptreact = {
          formatters = { "prettierd", "prettier" },
          linters = { "eslint_d" },
        },
        typescriptreact = {
          formatters = { "prettierd", "prettier" },
          linters = { "eslint_d" },
        },
        json = {
          formatters = { "prettierd", "prettier" },
        },
        css = {
          formatters = { "prettierd", "prettier" },
        },
        html = {
          formatters = { "prettierd", "prettier" },
        },
        markdown = {
          formatters = { "prettierd", "prettier" },
        },
        solidity = {
          lsp = "solidity_ls_nomicfoundation",
          formatters = { "prettierd", "prettier" },
          linters = { "solhint" },
        },
        c = {
          lsp = "clangd",
        },
        cpp = {
          lsp = "clangd",
        },
        nix = {
          lsp = "nil_ls",
          formatters = { "nixpkgs_fmt" },
          linters = { "statix", "deadnix" },
        },
      }
