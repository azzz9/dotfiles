      vim.keymap.set("n", "<leader>dc", function()
        require("dap").continue()
      end, { desc = "DAP continue" })
      vim.keymap.set("n", "<leader>do", function()
        require("dap").step_over()
      end, { desc = "DAP step over" })
      vim.keymap.set("n", "<leader>di", function()
        require("dap").step_into()
      end, { desc = "DAP step into" })
      vim.keymap.set("n", "<leader>dO", function()
        require("dap").step_out()
      end, { desc = "DAP step out" })
      vim.keymap.set("n", "<leader>db", function()
        require("dap").toggle_breakpoint()
      end, { desc = "DAP toggle breakpoint" })
      vim.keymap.set("n", "<leader>dr", function()
        require("dap").repl.open()
      end, { desc = "DAP REPL" })
      vim.keymap.set("n", "<leader>dl", function()
        require("dap").run_last()
      end, { desc = "DAP run last" })
      vim.keymap.set("n", "<leader>du", function()
        local ok, dapui = pcall(require, "dapui")
        if ok then
          dapui.toggle()
        else
          vim.notify("dapui is unavailable", vim.log.levels.WARN)
        end
      end, { desc = "DAP UI toggle" })
      local dap = require("dap")
      local dapui_ok, dapui = pcall(require, "dapui")

      local function dedupe_and_sort(paths)
        local seen = {}
        local out = {}
        for _, path in ipairs(paths) do
          if path ~= "" and not seen[path] then
            seen[path] = true
            table.insert(out, path)
          end
        end
        table.sort(out)
        return out
      end

      local function collect_executable_candidates(cwd)
        local candidates = {}
        local stem = vim.fn.expand("%:t:r")
        if stem ~= "" then
          local stem_out = cwd .. "/" .. stem .. ".out"
          if vim.fn.filereadable(stem_out) == 1 then
            table.insert(candidates, stem_out)
          end
        end
        for _, path in ipairs({ cwd .. "/main.out", cwd .. "/a.out" }) do
          if vim.fn.filereadable(path) == 1 then
            table.insert(candidates, path)
          end
        end

        for _, path in ipairs(vim.fn.globpath(cwd, "*", false, true)) do
          if vim.fn.filereadable(path) == 1 and vim.fn.executable(path) == 1 then
            table.insert(candidates, path)
          end
        end
        return dedupe_and_sort(candidates)
      end

      local function collect_stdin_candidates(cwd)
        local candidates = {}
        local patterns = {
          "test/**/*.in",
          "test/*.in",
          "*.in",
          "input.txt",
          "stdin.txt",
        }
        for _, pattern in ipairs(patterns) do
          for _, path in ipairs(vim.fn.globpath(cwd, pattern, false, true)) do
            if vim.fn.filereadable(path) == 1 then
              table.insert(candidates, path)
            end
          end
        end
        return dedupe_and_sort(candidates)
      end

      local function pick_path_from_candidates(prompt, candidates, default_path, allow_empty)
        if #candidates == 0 then
          local typed = vim.fn.input(prompt, default_path, "file")
          if typed == "" and allow_empty then
            return nil
          end
          return typed
        end

        local lines = { prompt }
        local choices = {}
        local i = 1

        if allow_empty then
          lines[#lines + 1] = i .. ". (none)"
          choices[i] = nil
          i = i + 1
        end

        for _, path in ipairs(candidates) do
          lines[#lines + 1] = i .. ". " .. vim.fn.fnamemodify(path, ":~:.")
          choices[i] = path
          i = i + 1
        end

        lines[#lines + 1] = i .. ". Enter path manually"
        local manual_index = i

        local selected = vim.fn.inputlist(lines)
        if selected == manual_index then
          local typed = vim.fn.input(prompt, default_path, "file")
          if typed == "" and allow_empty then
            return nil
          end
          return typed
        end

        if allow_empty and selected == 1 then
          return nil
        end

        if choices[selected] ~= nil then
          return choices[selected]
        end

        local typed = vim.fn.input(prompt, default_path, "file")
        if typed == "" and allow_empty then
          return nil
        end
        return typed
      end

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
            cwd = vim.fn.getcwd(),
            stopOnEntry = false,
          },
        }
      end

      if dapui_ok then
        dapui.setup()
        dap.listeners.after.event_initialized["dapui_config"] = function()
          dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
          dapui.close()
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
          dapui.close()
        end
      end
      require("nvim-dap-virtual-text").setup()
