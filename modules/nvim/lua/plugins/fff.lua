      require("fff").setup({
        layout = {
          width = 0.95,
          height = 0.85,
          preview_position = "right",
        },
        keymaps = {
          move_up = { "<Up>", "<C-p>", "<C-k>" },
          move_down = { "<Down>", "<C-n>", "<C-j>" },
        },
      })

      vim.keymap.set("n", "<leader>ff", function()
        require("fff").find_files()
      end, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", function()
        require("fff").live_grep()
      end, { desc = "Live grep" })
      vim.keymap.set({ "n", "x" }, "<leader>fw", function()
        require("fff").live_grep_under_cursor()
      end, { desc = "Search word or selection" })
      vim.keymap.set("n", "<leader>fr", function()
        require("fff").resume()
      end, { desc = "Resume previous search" })
