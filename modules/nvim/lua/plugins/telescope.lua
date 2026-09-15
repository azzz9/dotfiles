      local actions = require("telescope.actions")

      vim.keymap.set("n", "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Search buffer" })
      vim.keymap.set("n", "<leader>sd", "<cmd>Telescope diagnostics<cr>", { desc = "Diagnostics search" })

      require("telescope").setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            width = 0.95,
            height = 0.85,
          },
          mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
            },
            n = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
            },
          },
        },
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({}),
          },
        },
      })
      require("telescope").load_extension("ui-select")
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find Buffers" })
      vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help Tags" })
