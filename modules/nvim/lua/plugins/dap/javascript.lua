      -- JavaScript / TypeScript debugging via vscode-js-debug (js-debug).
      -- vim.g.js_debug_path points to the js-debug DAP server binary,
      -- set in modules/nvim.nix from pkgs.vscode-js-debug.
      -- The same server backs both the Node ("pwa-node") and browser
      -- ("pwa-chrome") adapters.
      -- pick_args comes from dap/init.lua (same prompt as C/C++).
      -- Note: vscode-js-debug does not support DAP stdio redirection,
      -- so stdin is not available here (use Node's process.stdin in the
      -- program, or pipe input in the integrated terminal).
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
