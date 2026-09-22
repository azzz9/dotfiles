      vim.g.start_time = vim.uv.hrtime()
      vim.keymap.set("n", "<C-v>", "<C-v>", { noremap = true })
      vim.keymap.set("i", "<C-v>", "<C-v>", { noremap = true })

      vim.api.nvim_create_autocmd(
        { "FocusGained", "BufEnter", "TermClose", "TermLeave" },
        { command = "checktime" }
      )

      vim.api.nvim_create_autocmd("FileChangedShellPost", {
        callback = function()
          vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.WARN)
        end,
      })

      -- FocusGained never fires while nvim keeps the terminal's focus, so an
      -- edit from outside nvim (agent, script, another tool) produces no reload
      -- event. Poll for on-disk changes so those edits still appear without :edit.
      -- TODO(nvim-0.13): delete this timer once the nixpkgs pin is 0.13+. Its
      -- 'autoread' watches each buffer's file itself (nvim PR #37971), so the
      -- poll duplicates the built-in watcher.
      local disk_poll = vim.uv.new_timer()
      disk_poll:start(1000, 1000, vim.schedule_wrap(function()
        vim.cmd("silent! checktime")
      end))

      vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", { silent = true })
      vim.keymap.set("n", "Y", "y$", { desc = "Yank to end of line" })
      vim.keymap.set("i", "jj", "<Esc>", { noremap = true })
      vim.keymap.set("i", "jk", "<Esc>", { noremap = true })
      vim.keymap.set("n", "<leader>sv", ":vsplit<CR>", { desc = "Vertical split" })
      vim.keymap.set("n", "<leader>sh", ":split<CR>", { desc = "Horizontal split" })
      vim.keymap.set("x", "<leader>ar", function()
        local path = vim.api.nvim_buf_get_name(0)
        if path == "" then
          vim.notify("Save the buffer before copying an agent reference.", vim.log.levels.WARN)
          return
        end

        local start_line = vim.fn.line("v")
        local end_line = vim.fn.line(".")
        start_line, end_line = math.min(start_line, end_line), math.max(start_line, end_line)

        local reference = ("%s:%d-%d"):format(vim.fn.fnamemodify(path, ":p"), start_line, end_line)
        vim.fn.setreg("+", reference)
        vim.fn.setreg('"', reference)
        vim.notify("Copied agent reference: " .. reference)
      end, { desc = "Copy selected range for agent" })
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      vim.keymap.set("n", "<leader>k", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "<leader>j", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
