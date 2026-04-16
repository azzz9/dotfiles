      vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
      require("oil").setup({
        keymaps = {
          ["g."] = "actions.toggle_hidden",
        },
      })
