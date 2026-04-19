      vim.g.start_time = vim.loop.hrtime()
      vim.keymap.set("n", "<C-v>", "<C-v>", { noremap = true })
      vim.keymap.set("i", "<C-v>", "<C-v>", { noremap = true })

      vim.api.nvim_create_autocmd(
        { "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermClose", "TermLeave" },
        { command = "checktime" }
      )

      vim.api.nvim_create_autocmd("FileChangedShellPost", {
        callback = function()
          vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.WARN)
        end,
      })

      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function(args)
          if vim.bo[args.buf].buftype ~= "" or not vim.bo[args.buf].modifiable then
            return
          end
          local view = vim.fn.winsaveview()
          vim.cmd("silent! keepjumps normal! gg=G")
          vim.fn.winrestview(view)
        end,
      })

      vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", { silent = true })
      vim.keymap.set("n", "Y", "y$", { desc = "Yank to end of line" })
      vim.keymap.set("i", "jj", "<Esc>", { noremap = true })
      vim.keymap.set("i", "jk", "<Esc>", { noremap = true })
      vim.keymap.set("n", "<leader>sv", ":vsplit<CR>", { desc = "Vertical split" })
      vim.keymap.set("n", "<leader>sh", ":split<CR>", { desc = "Horizontal split" })
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      local im_select = "/mnt/c/im-select.exe"
      if vim.fn.has("wsl") == 1 and vim.fn.executable(im_select) == 1 then
        vim.api.nvim_create_autocmd("InsertLeave", {
          callback = function()
            vim.system({ im_select, "1033" })
          end,
        })
      end
