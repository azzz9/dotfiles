      require("atlas").setup({
        ui = {
          -- The default replaces lualine on Atlas views; keep the configured one.
          statusline = { atlas = false, diff = false },
          -- Atlas ships pickers for snacks and fzf-lua only. "default" is its
          -- own implementation, so telescope needs no adapter here.
          picker = "default",
        },
        providers = {
          -- A provider without an entry here counts as unconfigured.
          github = {},
        },
        keymaps = {
          pulls = {
            review = {
              -- Keep CodeDiff's default ]c, [c and - bindings on the diff.
              next_comment = "]a",
              prev_comment = "[a",
              toggle_file_reviewed = "<leader>gv",
              -- Atlas defaults shadow fff and Trouble on the review buffers.
              explorer = { find_file = false },
              atlas = { focus_explorer = false },
            },
          },
        },
      })

      vim.keymap.set("n", "<leader>gp", "<cmd>Atlas pulls<cr>", { desc = "Atlas pull requests" })
      vim.keymap.set("n", "<leader>gi", "<cmd>Atlas issues<cr>", { desc = "Atlas issues" })
      vim.keymap.set("n", "<leader>gr", "<cmd>Atlas review<cr>", { desc = "Atlas review pull request" })
      vim.keymap.set("n", "<leader>ga", "<cmd>Atlas browse .<cr>", { desc = "Atlas browse repository" })
