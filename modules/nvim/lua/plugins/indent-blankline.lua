      require("ibl").setup({
        indent = {
          char = "▏",
          tab_char = "▏",
          highlight = "IblIndent",
        },
        scope = {
          enabled = false,
        },
        exclude = {
          buftypes = { "terminal", "nofile", "quickfix", "prompt" },
          filetypes = {
            "help",
            "lazy",
            "mason",
            "notify",
            "Trouble",
            "oil",
            "copilot-chat",
          },
        },
      })
