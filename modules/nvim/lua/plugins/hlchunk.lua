      require("hlchunk").setup({
        chunk = {
          enable = false,
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
          enable = false,
        },
        blank = {
          enable = false,
        },
      })
