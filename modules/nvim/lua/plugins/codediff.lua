      local function select_branch_diff()
        local branches = vim.fn.systemlist({
          "git",
          "for-each-ref",
          "--format=%(refname:short)",
          "refs/heads",
          "refs/remotes",
        })

        local seen = {}
        branches = vim.tbl_filter(function(branch)
          if branch == "" or branch:match("/HEAD$") or seen[branch] then
            return false
          end
          seen[branch] = true
          return true
        end, branches)
        table.sort(branches)

        if #branches == 0 then
          vim.notify("No local or remote branches found", vim.log.levels.WARN)
          return
        end

        vim.ui.select(branches, { prompt = "Compare from branch (merge-base): " }, function(branch)
          if branch then
            vim.cmd("CodeDiff " .. vim.fn.fnameescape(branch .. "..."))
          end
        end)
      end

      require("codediff").setup({
        diff = {
          layout = "inline",
          gutter_signs = true,
          jump_to_first_change = true,
        },
        explorer = {
          position = "left",
        },
        history = {
          position = "bottom",
        },
      })

      vim.keymap.set("n", "<leader>gc", "<cmd>CodeDiff<cr>", { desc = "Open git diff" })
      vim.keymap.set("n", "<leader>gC", select_branch_diff, { desc = "Compare branch diff" })
      vim.keymap.set("n", "<leader>gs", "<cmd>CodeDiff --staged<cr>", { desc = "Open staged diff" })
      vim.keymap.set("n", "<leader>gf", "<cmd>CodeDiff file HEAD<cr>", { desc = "Compare file with HEAD" })
      vim.keymap.set("n", "<leader>gl", "<cmd>CodeDiff history %<cr>", { desc = "Current file history" })
      vim.keymap.set("n", "<leader>gL", "<cmd>CodeDiff history<cr>", { desc = "Repository file history" })
