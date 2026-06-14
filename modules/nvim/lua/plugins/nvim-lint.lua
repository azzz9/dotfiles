      local lint = require("lint")
      lint.linters_by_ft = {
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        lua = { "selene" },
        python = { "ruff" },
        solidity = { "solhint", "eslint_d" },
      }
      lint.linters.solhint.args = { "stdin", "--disc" }

      local has_clangd = vim.fn.executable("clangd") == 1
      if vim.fn.executable("clang-tidy") == 1 and not has_clangd then
        lint.linters_by_ft.c = { "clangtidy" }
        lint.linters_by_ft.cpp = { "clangtidy" }
        lint.linters_by_ft.objc = { "clangtidy" }
        lint.linters_by_ft.objcpp = { "clangtidy" }
      end

      local function has_config(names)
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname == "" then
          return false
        end
        return vim.fs.find(names, {
          path = bufname,
          upward = true,
        })[1] ~= nil
      end

      local function has_solhint_config()
        return has_config({ ".solhint.json", ".solhint.yaml", ".solhint.yml" })
      end

      local function has_eslint_config()
        return has_config({
          "eslint.config.js",
          "eslint.config.mjs",
          "eslint.config.cjs",
          "eslint.config.ts",
          "eslint.config.mts",
          "eslint.config.cts",
          ".eslintrc",
          ".eslintrc.js",
          ".eslintrc.cjs",
          ".eslintrc.json",
          ".eslintrc.yaml",
          ".eslintrc.yml",
        })
      end

      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        callback = function()
          if vim.bo.filetype == "solidity" then
            local linters = {}
            if has_solhint_config() then
              table.insert(linters, "solhint")
            end
            if has_eslint_config() then
              table.insert(linters, "eslint_d")
            end
            if #linters > 0 then
              lint.try_lint(linters)
            end
            return
          end
          lint.try_lint()
        end,
      })
