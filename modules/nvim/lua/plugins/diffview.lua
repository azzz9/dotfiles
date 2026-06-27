      require("diffview").setup({
        enhanced_diff_hl = true,
        view = {
          default = { layout = "diff2_horizontal" },
          merge_tool = { layout = "diff3_horizontal" },
          file_history = { layout = "diff2_horizontal" },
        },
      })

      vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Open git diff" })
      vim.keymap.set("n", "<leader>gD", "<cmd>DiffviewOpen HEAD~1<cr>", { desc = "Open last commit diff" })
      vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Current file history" })
      vim.keymap.set("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>", { desc = "Repository file history" })
      vim.keymap.set("n", "<leader>gq", "<cmd>DiffviewClose<cr>", { desc = "Close git diff" })

      -- Jump to the new (right) diff window inside diffview.
      vim.keymap.set("n", "<leader>b", "<C-w>l", { desc = "Move to new buffer (diffview)" })
