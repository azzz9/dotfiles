      vim.o.background = "dark"

      require("kanagawa").setup({
        theme = "dragon",
        background = {
          dark = "dragon",
          light = "lotus",
        },
        compile = false,
        undercurl = true,
        commentStyle = { italic = true },
        keywordStyle = { italic = true },
        statementStyle = { bold = true },
        transparent = false,
        dimInactive = false,
        terminalColors = true,
        -- Kanagawa leaves nvim's Diagnostic* groups without a background, so
        -- the severity tints used by the signs.linehl/numhl mapping in ui.lua
        -- are built here from the active palette instead of ui.lua hex codes.
        overrides = function(colors)
          local Color = require("kanagawa.lib.color")
          local ui, diag = colors.theme.ui, colors.theme.diag
          local light = vim.o.background == "light"
          -- Blend out from the theme's paper color. Light themes start at
          -- white: kanagawa's lotus paper (#f2ecbc) is cream, and no blend of
          -- cream and a severity color reaches a pastel error pink.
          local paper = (light and Color(ui.bg):brighten(1) or Color(ui.bg)):to_hex()
          -- Ratios for kanagawa's sqrt-space blend, fitted against the values
          -- ui.lua used to hardcode: #3b1818 / #3a2a14 / #1a2a33 / #182a22
          -- for dragon, #f4d8d8 / #f5e2c6 / #d7e5ea / #d8e8e0 for lotus.
          local ratio = light and 0.30 or 0.055
          local specs = {
            { "DiagnosticErrorLine", "DiagnosticErrorNr", diag.error },
            { "DiagnosticWarnLine", "DiagnosticWarnNr", diag.warning },
            { "DiagnosticInfoLine", "DiagnosticInfoNr", diag.info },
            { "DiagnosticHintLine", "DiagnosticHintNr", diag.hint },
          }
          local hl = {}
          for _, spec in ipairs(specs) do
            local bg = Color(paper):blend(spec[3], ratio):to_hex()
            hl[spec[1]] = { bg = bg }
            hl[spec[2]] = { bg = bg, bold = true }
          end
          return hl
        end,
      })

      pcall(vim.cmd.colorscheme, "kanagawa-dragon")
