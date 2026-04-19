      local lint = require("lint")
      lint.linters_by_ft = {
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        lua = { "selene" },
        python = { "ruff" },
      }
      local has_clangd = vim.fn.executable("clangd") == 1
      if vim.fn.executable("clang-tidy") == 1 and not has_clangd then
        lint.linters_by_ft.c = { "clangtidy" }
        lint.linters_by_ft.cpp = { "clangtidy" }
        lint.linters_by_ft.objc = { "clangtidy" }
        lint.linters_by_ft.objcpp = { "clangtidy" }
      end
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        callback = function()
          lint.try_lint()
        end,
      })
