      -- DAP core: keymaps, shared helpers, UI, virtual-text.
      -- Per-language adapters/configurations live in sibling files
      -- (c.lua, python.lua, javascript.lua) and reuse the locals
      -- declared here because all DAP files are concatenated into one
      -- Lua chunk by modules/nvim.nix.
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

      -- Interactive args prompt shared by all language configs.
      -- Mirrors the C/C++ behavior: prompt for a space-separated arg
      -- string, split on whitespace, return nil when left empty so the
      -- adapter receives no args.
      local function pick_args(prompt, default)
        local input = vim.fn.input(prompt or "Args: ", default or "")
        if input == nil or input == "" then
          return nil
        end
        local args = {}
        for word in input:gmatch("%S+") do
          table.insert(args, word)
        end
        return args
      end

      local adapter_settings = {
        showDisassembly = "never",
        suppressMissingSourceFiles = true,
      }

      -- Export helpers for external config overrides (e.g. atcoder contest mode)
      package.loaded["dap.codelldb_helpers"] = {
        collect_stdin_candidates = collect_stdin_candidates,
        pick_path_from_candidates = pick_path_from_candidates,
        pick_args = pick_args,
        adapter_settings = adapter_settings,
      }

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
