      -- Renders Markdown in the buffer itself (headings, code blocks, tables,
      -- checkboxes); the cursor line falls back to raw text while editing.
      require("render-markdown").setup({
        completions = { blink = { enabled = true } },
      })
      vim.keymap.set("n", "<leader>mm", "<cmd>RenderMarkdown buf_toggle<cr>", { desc = "Markdown: toggle render" })
      vim.keymap.set("n", "<leader>mp", "<cmd>RenderMarkdown preview<cr>", { desc = "Markdown: side preview" })
