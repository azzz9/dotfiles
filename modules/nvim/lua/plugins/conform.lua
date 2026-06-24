      local formatters_by_ft = {}
      for ft, conf in pairs(_langs) do
        if conf.formatters then
          formatters_by_ft[ft] = conf.formatters
        end
      end

      local prettier_plugin_solidity = vim.g.prettier_plugin_solidity_path
      local function prettier_args(_, ctx)
        if vim.bo[ctx.buf].filetype == "solidity" then
          return { "--plugin", prettier_plugin_solidity }
        end
        return {}
      end

      require("conform").setup({
        formatters_by_ft = formatters_by_ft,
        formatters = {
          prettierd = { prepend_args = prettier_args },
          prettier = { prepend_args = prettier_args },
        },
        format_on_save = function()
          return { async = false, lsp_fallback = true, quiet = true }
        end,
      })
