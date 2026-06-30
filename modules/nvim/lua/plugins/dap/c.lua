      -- C / C++ debugging via codelldb (vscode-lldb).
      -- Helpers (collect_executable_candidates, collect_stdin_candidates,
      -- pick_path_from_candidates, adapter_settings) come from dap/init.lua.
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.g.codelldb_path,
          args = { "--port", "${port}" },
        },
      }

      for _, lang in ipairs({ "c", "cpp" }) do
        dap.configurations[lang] = {
          {
            name = "Launch executable",
            type = "codelldb",
            request = "launch",
            program = function()
              local cwd = vim.fn.getcwd()
              local program = pick_path_from_candidates(
                "Executable: ",
                collect_executable_candidates(cwd),
                cwd .. "/",
                false
              )
              if program == nil or program == "" then
                return dap.ABORT
              end
              return program
            end,
            stdio = function()
              local cwd = vim.fn.getcwd()
              local stdin_file = pick_path_from_candidates(
                "stdin file (empty: none): ",
                collect_stdin_candidates(cwd),
                cwd .. "/",
                true
              )
              if stdin_file == nil or stdin_file == "" then
                return nil
              end
              return { stdin_file, nil, nil }
            end,
            args = pick_args,
            cwd = vim.fn.getcwd(),
            stopOnEntry = false,
            _adapterSettings = adapter_settings,
          },
        }
      end
