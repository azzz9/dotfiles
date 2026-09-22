      vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
      require("oil").setup({
        watch_for_changes = true,
        keymaps = {
          ["g."] = "actions.toggle_hidden",
        },
      })
