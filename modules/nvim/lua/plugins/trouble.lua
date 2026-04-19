      require("trouble").setup()
      vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
      vim.keymap.set("n", "<leader>xw", "<cmd>Trouble workspace_diagnostics toggle<cr>", {
        desc = "Workspace Diagnostics",
      })
      vim.keymap.set("n", "<leader>e", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics list" })
