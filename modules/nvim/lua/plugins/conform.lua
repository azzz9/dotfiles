      local prettier_plugin_solidity = vim.fn.expand("~/.nix-profile/lib/node_modules/prettier-plugin-solidity/dist/index.js")
      local function prettier_args(_, ctx)
        if vim.bo[ctx.buf].filetype == "solidity" then
          return { "--plugin", prettier_plugin_solidity }
        end
        return {}
      end

      require("conform").setup({
        formatters_by_ft = {
          javascript = { "prettierd", "prettier" },
          javascriptreact = { "prettierd", "prettier" },
          typescript = { "prettierd", "prettier" },
          typescriptreact = { "prettierd", "prettier" },
          json = { "prettierd", "prettier" },
          css = { "prettierd", "prettier" },
          html = { "prettierd", "prettier" },
          markdown = { "prettierd", "prettier" },
          lua = { "stylua" },
          python = { "ruff_format" },
          solidity = { "prettierd", "prettier" },
        },
        formatters = {
          prettierd = { prepend_args = prettier_args },
          prettier = { prepend_args = prettier_args },
        },
        format_on_save = function()
          return { async = false, lsp_fallback = true, quiet = true }
        end,
      })
