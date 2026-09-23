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
            vim.api.nvim_set_hl(0, "LineNr", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#928374" })
            vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#af3a03", bold = true })
            vim.api.nvim_set_hl(0, "CursorLine", { bg = "none", ctermbg = "none" })
            vim.api.nvim_set_hl(0, "Visual", { bg = "#e5d5b5", fg = "#3c3836", nocombine = true })
            vim.api.nvim_set_hl(0, "VisualNOS", { bg = "#e5d5b5", fg = "#3c3836", nocombine = true })
          else
            vim.api.nvim_set_hl(0, "IblIndent", { fg = "#4a443e", nocombine = true })
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
        -- Inline text is rendered by plugins/tiny-inline-diagnostic.lua.
        virtual_text = false,
        virtual_lines = false,
        underline = false,
        update_in_insert = false,
        float = { border = "rounded", source = true },
        -- Blanks keep the sign column empty, since nvim falls back to a "U"
        -- glyph for any severity with no entry here. No linehl or numhl: the
        -- line and its number stay uncolored and the inline text carries the
        -- severity on its own.
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.HINT] = "",
          },
        },
      })
