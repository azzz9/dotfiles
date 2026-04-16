      local function recording_register()
        local register = vim.fn.reg_recording()
        if register == "" then
          return ""
        end
        return "REC @" .. register
      end

      require("lualine").setup({
        options = {
          component_separators = {},
          section_separators = {},
        },
        sections = {
          lualine_a = { recording_register, "filename" },
          lualine_b = { "branch" },
          lualine_c = {
            "'%='",
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
              separator = "  |  ",
            },
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
            },
          },
          lualine_x = { "encoding", "fileformat" },
          lualine_y = { "filetype", "searchcount" },
          lualine_z = {},
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
      })

      vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
        callback = function()
          require("lualine").refresh()
        end,
      })
