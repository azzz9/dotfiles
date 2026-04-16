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
        },
        format_on_save = function()
          return { async = false, lsp_fallback = true, quiet = true }
        end,
      })
