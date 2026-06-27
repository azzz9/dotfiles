      vim.g.gitblame_enabled = 0
      vim.g.gitblame_message_template = "  <author> - <summary>"
      vim.g.gitblame_highlight_group = "Comment"

      vim.keymap.set("n", "<leader>gb", "<cmd>GitBlameToggle<cr>", { desc = "Toggle git blame" })
