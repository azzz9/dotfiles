      -- barbar.nvim: configured via vim.g (no setup() call needed)

      vim.keymap.set("n", "<C-h>", "<cmd>BufferPrevious<cr>", { desc = "Previous buffer" })
      vim.keymap.set("n", "<C-l>", "<cmd>BufferNext<cr>", { desc = "Next buffer" })
      vim.keymap.set("n", "<leader>q", "<cmd>BufferClose<cr>", { desc = "Close buffer" })
      vim.keymap.set("n", "<leader>bo", "<cmd>BufferCloseAllButCurrent<cr>", { desc = "Close other buffers" })
