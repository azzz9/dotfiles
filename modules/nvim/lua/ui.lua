      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
          vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
          vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
          vim.api.nvim_set_hl(0, "FoldColumn", { bg = "none" })
          vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
          if vim.o.background == "light" then
            vim.api.nvim_set_hl(0, "IblIndent", { fg = "#d5c4a1", nocombine = true })
            vim.api.nvim_set_hl(0, "DiagnosticErrorLine", { bg = "#fbe3e4" })
            vim.api.nvim_set_hl(0, "DiagnosticWarnLine", { bg = "#faedcd" })
            vim.api.nvim_set_hl(0, "DiagnosticInfoLine", { bg = "#ddebf4" })
            vim.api.nvim_set_hl(0, "DiagnosticHintLine", { bg = "#e4f3e1" })
            vim.api.nvim_set_hl(0, "DiagnosticErrorNr", { bg = "#fbe3e4", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticWarnNr", { bg = "#faedcd", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticInfoNr", { bg = "#ddebf4", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticHintNr", { bg = "#e4f3e1", bold = true })
            vim.api.nvim_set_hl(0, "LineNr", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#af3a03", bold = true })
            vim.api.nvim_set_hl(0, "CursorLine", { bg = "none", ctermbg = "none" })
            vim.api.nvim_set_hl(0, "Visual", { bg = "#e5d5b5", fg = "#3c3836", nocombine = true })
            vim.api.nvim_set_hl(0, "VisualNOS", { bg = "#e5d5b5", fg = "#3c3836", nocombine = true })
          else
            vim.api.nvim_set_hl(0, "IblIndent", { fg = "#4a443e", nocombine = true })
            vim.api.nvim_set_hl(0, "DiagnosticErrorLine", { bg = "#3b1113" })
            vim.api.nvim_set_hl(0, "DiagnosticWarnLine", { bg = "#3b2a11" })
            vim.api.nvim_set_hl(0, "DiagnosticInfoLine", { bg = "#112f3b" })
            vim.api.nvim_set_hl(0, "DiagnosticHintLine", { bg = "#113b1b" })
            vim.api.nvim_set_hl(0, "DiagnosticErrorNr", { bg = "#3b1113", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticWarnNr", { bg = "#3b2a11", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticInfoNr", { bg = "#112f3b", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticHintNr", { bg = "#113b1b", bold = true })
            vim.api.nvim_set_hl(0, "LineNr", { fg = "#7c6f64" })
            vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#7c6f64" })
            vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#7c6f64" })
            vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#fabd2f", bold = true })
            vim.api.nvim_set_hl(0, "CursorLine", { bg = "none", ctermbg = "none" })
            vim.api.nvim_set_hl(0, "Visual", { bg = "#4f453c", fg = "#ebdbb2", nocombine = true })
            vim.api.nvim_set_hl(0, "VisualNOS", { bg = "#4f453c", fg = "#ebdbb2", nocombine = true })
          end
        end,
      })
      vim.cmd("doautocmd ColorScheme")

      vim.diagnostic.config({
        virtual_text = {
          spacing = 2,
          format = function(d)
            return d.message
          end,
        },
        virtual_lines = false,
        underline = false,
        update_in_insert = true,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.HINT] = "",
          },
          linehl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticErrorLine",
            [vim.diagnostic.severity.WARN] = "DiagnosticWarnLine",
            [vim.diagnostic.severity.INFO] = "DiagnosticInfoLine",
            [vim.diagnostic.severity.HINT] = "DiagnosticHintLine",
          },
          numhl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticErrorNr",
            [vim.diagnostic.severity.WARN] = "DiagnosticWarnNr",
            [vim.diagnostic.severity.INFO] = "DiagnosticInfoNr",
            [vim.diagnostic.severity.HINT] = "DiagnosticHintNr",
          },
        },
      })
