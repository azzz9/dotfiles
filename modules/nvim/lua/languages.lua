      -- Single source of truth for language tool mappings.
      -- Used by conform.lua, nvim-lint.lua, and nvim-lspconfig.lua.
      --
      -- Adding a new language:
      --   1. Add entry here (lsp / formatters / linters)
      --   2. Add the corresponding packages to modules/packages.nix
      --   3. Add LSP-specific config to nvim-lspconfig.lua if needed
      --      (custom cmd, root_dir, settings, etc.)
      local biome_config_files = { "biome.json", "biome.jsonc" }
      local biome_filetypes = {
        javascript = true,
        javascriptreact = true,
        json = true,
        jsonc = true,
        typescript = true,
        typescriptreact = true,
      }

      local function has_project_config(bufnr, names)
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname == "" then
          return false
        end
        return vim.fs.find(names, {
          path = vim.fs.dirname(bufname),
          upward = true,
        })[1] ~= nil
      end

      local function uses_biome(bufnr)
        return biome_filetypes[vim.bo[bufnr].filetype] == true
          and has_project_config(bufnr, biome_config_files)
      end

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
          formatters = { "biome", "prettierd", "prettier", stop_after_first = true },
          linters = { "eslint_d" },
        },
        javascript = {
          lsp = "ts_ls",
          formatters = { "biome", "prettierd", "prettier", stop_after_first = true },
          linters = { "eslint_d" },
        },
        javascriptreact = {
          lsp = "ts_ls",
          formatters = { "biome", "prettierd", "prettier", stop_after_first = true },
          linters = { "eslint_d" },
        },
        typescriptreact = {
          lsp = "ts_ls",
          formatters = { "biome", "prettierd", "prettier", stop_after_first = true },
          linters = { "eslint_d" },
        },
        json = {
          lsp = "jsonls",
          formatters = { "biome", "prettierd", "prettier", stop_after_first = true },
        },
        jsonc = {
          lsp = "jsonls",
          formatters = { "biome", "prettierd", "prettier", stop_after_first = true },
        },
        css = {
          lsp = "cssls",
          formatters = { "prettierd", "prettier" },
          linters = { "stylelint" },
        },
        html = {
          lsp = "html",
          formatters = { "prettierd", "prettier" },
          linters = { "htmlhint" },
        },
        markdown = {
          formatters = { "prettierd", "prettier" },
          linters = { "markdownlint" },
        },
        solidity = {
          lsp = "solidity_ls_nomicfoundation",
          formatters = { "prettierd", "prettier" },
          linters = { "solhint" },
        },
        c = {
          lsp = "clangd",
          formatters = { "clang_format" },
        },
        cpp = {
          lsp = "clangd",
          formatters = { "clang_format" },
        },
        sh = {
          lsp = "bashls",
          formatters = { "shfmt" },
          linters = { "shellcheck" },
        },
        nix = {
          lsp = "nil_ls",
          formatters = { "nixpkgs_fmt" },
          linters = { "statix", "deadnix" },
        },
        yaml = {
          lsp = "yamlls",
          formatters = { "prettierd", "prettier" },
          linters = { "yamllint" },
        },
        toml = {
          lsp = "taplo",
          formatters = { "taplo" },
        },
      }
