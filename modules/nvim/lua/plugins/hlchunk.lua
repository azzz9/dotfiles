      require("hlchunk").setup({
        chunk = {
          enable = true,
          chars = {
            horizontal_line = "─",
            vertical_line = "│",
            left_top = "╭",
            left_bottom = "╰",
            right_top = "─",
            right_bottom = "─",
          },
        },
        indent = {
          enable = true,
          chars = { "▏" },
        },
        line_num = {
          enable = true,
        },
        blank = {
          enable = false,
        },
      })
