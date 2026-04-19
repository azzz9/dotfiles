      require("lualine").setup({
        options = {
          component_separators = {},
          section_separators = {},
        },
        sections = {
          lualine_a = { "filename" },
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
