      -- Python debugging via debugpy. modules/nvim.nix points
      -- vim.g.debugpy_python at an interpreter that ships it, and pick_args
      -- comes from dap/init.lua.
      -- debugpy does not support DAP stdio redirection, so stdin must come from
      -- the integrated terminal or from the program itself.
      require("dap-python").setup(vim.g.debugpy_python)

      dap.configurations.python = {
        {
          name = "Launch file",
          type = "python",
          request = "launch",
          program = "${file}",
          args = pick_args,
          console = "integratedTerminal",
          justMyCode = true,
        },
        {
          name = "Launch module",
          type = "python",
          request = "launch",
          module = function()
            local mod = vim.fn.input("Module: ")
            if mod == nil or mod == "" then
              return dap.ABORT
            end
            return mod
          end,
          args = pick_args,
          console = "integratedTerminal",
          justMyCode = true,
        },
        {
          name = "Launch pytest (current file)",
          type = "python",
          request = "launch",
          module = "pytest",
          args = function()
            local extra = pick_args("pytest args: ", "-v")
            local args = { "${file}" }
            if extra then
              for _, word in ipairs(extra) do
                table.insert(args, word)
              end
            end
            return args
          end,
          console = "integratedTerminal",
          justMyCode = false,
        },
        {
          name = "Attach to running process",
          type = "python",
          request = "attach",
          processId = function()
            return require("dap.utils").pick_process()
          end,
          justMyCode = true,
        },
      }
