      require("mini.icons").setup({})
      require("mini.comment").setup({})
      require("mini.starter").setup({
        query_updaters = "",
        silent = true,
        footer = function()
          local ms = (vim.loop.hrtime() - vim.g.start_time) / 1e6
          return string.format("Startup: %.1f ms", ms)
        end,
      })
