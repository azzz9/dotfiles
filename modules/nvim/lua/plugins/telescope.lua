      vim.keymap.set("n", "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Search buffer" })
      vim.keymap.set("n", "<leader>sg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
      vim.keymap.set("n", "<leader>sd", "<cmd>Telescope diagnostics<cr>", { desc = "Diagnostics search" })
      local builtin = require("telescope.builtin")
      local show_hidden = false

      local function live_grep_args()
        if not show_hidden then
          return nil
        end
        return { "--hidden", "--glob", "!.git/*" }
      end

      require("telescope").setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            width = 0.95,
            height = 0.85,
          },
        },
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({}),
          },
        },
      })
      require("telescope").load_extension("ui-select")
      vim.keymap.set("n", "<leader>f.", function()
        show_hidden = not show_hidden
        vim.notify("Telescope hidden files: " .. (show_hidden and "on" or "off"))
      end, { desc = "Toggle hidden files" })
      vim.keymap.set("n", "<leader>ff", function()
        builtin.find_files({
          hidden = show_hidden,
          no_ignore = false,
        })
      end, { desc = "Find Files" })
      vim.keymap.set("n", "<leader>fg", function()
        builtin.live_grep({
          additional_args = live_grep_args,
        })
      end, { desc = "Live Grep" })
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find Buffers" })
      vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help Tags" })
