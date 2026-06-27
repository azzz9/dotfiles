      require("gitsigns").setup({
        signs = {
          add = { text = "▎" },
          change = { text = "▎" },
          delete = { text = "" },
          topdelete = { text = "" },
          changedelete = { text = "▎" },
        },
        preview_config = {
          border = "rounded",
        },
      })

      local gs = require("gitsigns")
      vim.keymap.set("n", "]c", function() gs.nav_hunk("next") end, { desc = "Next git hunk" })
      vim.keymap.set("n", "[c", function() gs.nav_hunk("prev") end, { desc = "Prev git hunk" })
