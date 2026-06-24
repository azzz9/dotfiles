      vim.keymap.set("n", "<C-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
      vim.keymap.set("n", "<C-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          separator_style = "slant",
          show_buffer_close_icons = false,
          show_close_icon = false,
        },
      })
      vim.keymap.set("n", "<leader>q", "<cmd>BufferLineCloseCurrent<cr>", { desc = "Close buffer" })
      vim.keymap.set("n", "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
