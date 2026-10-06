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
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      vim.keymap.set("n", "<leader>k", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "<leader>j", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      -- nvim auto-selects OSC 52 only when 'clipboard' is empty, and this
      -- config sets unnamedplus, so a host with no clipboard of its own needs
      -- the provider set explicitly. g:clipboard outranks every detected tool,
      -- so this mirrors nvim's own gates loosely and errs toward leaving
      -- working hosts alone.
      local has_local_backend = vim.fn.has("mac") == 1
        or vim.env.WAYLAND_DISPLAY ~= nil
        or vim.env.DISPLAY ~= nil
        or vim.fn.executable("win32yank.exe") == 1
        or vim.fn.executable("lemonade") == 1
        or vim.fn.executable("doitclient") == 1
        or (vim.fn.executable("clip") == 1 and vim.fn.executable("powershell") == 1)

      if not has_local_backend and vim.env.TMUX == nil then
        local osc52 = require("vim.ui.clipboard.osc52")
        vim.g.clipboard = {
          name = "osc52-copy",
          copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
          -- Windows Terminal cannot answer the OSC 52 read query, so paste is
          -- empty instead of hanging for ten seconds.
          paste = { ["+"] = function() return {} end, ["*"] = function() return {} end },
        }
      end
