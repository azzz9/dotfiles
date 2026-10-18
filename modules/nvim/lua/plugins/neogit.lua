-- Parent lookup (parent_or_empty_tree) comes from codediff.lua.
require("neogit").setup({
  graph_style = "unicode",
  -- The pinned neogit still builds codediff's pre-4.0 session config, so its
  -- own integration errors as soon as a commit opens. The graph hands commits
  -- to the command instead, which is codediff's stable surface.
  integrations = { codediff = false },
})

-- The log action skips the log popup, so one key reaches the graph. `--graph`
-- and `--decorate` are read as internal flags rather than passed to git.
vim.keymap.set(
  "n",
  "<leader>gg",
  require("neogit").action("log", "log_current", { "--all", "--graph", "--decorate" }),
  { desc = "Git graph" }
)

vim.api.nvim_create_autocmd("FileType", {
  pattern = "NeogitLogView",
  callback = function(event)
    vim.keymap.set("n", "D", function()
      local log_view = require("neogit.buffers.log_view")
      local oid = log_view.instance and log_view.instance.buffer.ui:get_commit_under_cursor()
      local git_root = require("neogit.lib.git").repo.worktree_root
      if not oid then
        vim.notify("No commit under the cursor", vim.log.levels.WARN)
        return
      end
      if not git_root or git_root == "" then
        vim.notify("Neogit has no git root", vim.log.levels.WARN)
        return
      end
      vim.cmd(table.concat({
        "CodeDiff",
        "-C",
        vim.fn.fnameescape(git_root),
        vim.fn.fnameescape(parent_or_empty_tree(oid, git_root)),
        vim.fn.fnameescape(oid),
      }, " "))
    end, { buffer = event.buf, desc = "Open commit in codediff" })
  end,
})
