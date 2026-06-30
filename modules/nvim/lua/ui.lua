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
            -- kanagawa-lotus (bg: #f2ecbc). Severity tints derived from
            -- lotus diag colors: error #e82424, warn #e98a00,
            -- info #5a7785, hint #5e857a.
            vim.api.nvim_set_hl(0, "IblIndent", { fg = "#d5c4a1", nocombine = true })
            vim.api.nvim_set_hl(0, "DiagnosticErrorLine", { bg = "#f4d8d8" })
            vim.api.nvim_set_hl(0, "DiagnosticWarnLine", { bg = "#f5e2c6" })
            vim.api.nvim_set_hl(0, "DiagnosticInfoLine", { bg = "#d7e5ea" })
            vim.api.nvim_set_hl(0, "DiagnosticHintLine", { bg = "#d8e8e0" })
            vim.api.nvim_set_hl(0, "DiagnosticErrorNr", { bg = "#f4d8d8", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticWarnNr", { bg = "#f5e2c6", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticInfoNr", { bg = "#d7e5ea", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticHintNr", { bg = "#d8e8e0", bold = true })
            vim.api.nvim_set_hl(0, "LineNr", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#af3a03", bold = true })
            vim.api.nvim_set_hl(0, "CursorLine", { bg = "none", ctermbg = "none" })
            vim.api.nvim_set_hl(0, "Visual", { bg = "#e5d5b5", fg = "#3c3836", nocombine = true })
            vim.api.nvim_set_hl(0, "VisualNOS", { bg = "#e5d5b5", fg = "#3c3836", nocombine = true })
          else
            -- kanagawa-dragon (bg: #181616). Severity tints derived from
            -- dragon diag colors: error samuraiRed #e82424, warn roninYellow
            -- #ff9e3b, info dragonBlue #658594, hint waveAqua1 #6a9589.
            vim.api.nvim_set_hl(0, "IblIndent", { fg = "#4a443e", nocombine = true })
            vim.api.nvim_set_hl(0, "DiagnosticErrorLine", { bg = "#3b1818" })
            vim.api.nvim_set_hl(0, "DiagnosticWarnLine", { bg = "#3a2a14" })
            vim.api.nvim_set_hl(0, "DiagnosticInfoLine", { bg = "#1a2a33" })
            vim.api.nvim_set_hl(0, "DiagnosticHintLine", { bg = "#182a22" })
            vim.api.nvim_set_hl(0, "DiagnosticErrorNr", { bg = "#3b1818", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticWarnNr", { bg = "#3a2a14", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticInfoNr", { bg = "#1a2a33", bold = true })
            vim.api.nvim_set_hl(0, "DiagnosticHintNr", { bg = "#182a22", bold = true })
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
        update_in_insert = false,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.HINT] = "",
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
