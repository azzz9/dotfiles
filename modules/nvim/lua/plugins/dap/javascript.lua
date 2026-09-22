      -- JavaScript / TypeScript debugging via vscode-js-debug, whose binary
      -- path modules/nvim.nix sets in vim.g.js_debug_path. One server backs both
      -- the Node ("pwa-node") and browser ("pwa-chrome") adapters, and pick_args
      -- comes from dap/init.lua.
      -- js-debug does not support DAP stdio redirection, so stdin is only
      -- available through Node's process.stdin or the integrated terminal.
      local js_debug = vim.g.js_debug_path
      local js_adapter = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = js_debug,
          args = { "${port}" },
        },
      }
      dap.adapters["pwa-node"] = js_adapter
      dap.adapters["pwa-chrome"] = js_adapter

      for _, lang in ipairs({
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
      }) do
        dap.configurations[lang] = {
          {
            name = "Launch file (node)",
            type = "pwa-node",
            request = "launch",
            program = "${file}",
            cwd = "${workspaceFolder}",
            args = pick_args,
            -- runtimeExecutable defaults to "node" from PATH.
          },
          {
            name = "Attach to node process",
            type = "pwa-node",
            request = "attach",
            processId = function()
              return require("dap.utils").pick_process()
            end,
            cwd = "${workspaceFolder}",
          },
          {
            name = "Attach to Chrome dev server",
            type = "pwa-chrome",
            request = "attach",
            url = function()
              return vim.fn.input("URL: ", "http://localhost:3000")
            end,
            webRoot = "${workspaceFolder}",
            skipFiles = { "<node_internals>/**" },
          },
          {
            name = "Launch Chrome (open URL)",
            type = "pwa-chrome",
            request = "launch",
            url = function()
              return vim.fn.input("URL: ", "http://localhost:3000")
            end,
            webRoot = "${workspaceFolder}",
          },
        }
      end
