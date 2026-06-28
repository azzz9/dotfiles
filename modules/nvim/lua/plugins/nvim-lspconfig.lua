      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "LSP rename" })
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
      -- Keep a stable LSP status command regardless of plugin command registration timing.
      local function _open_lsp_health()
        vim.cmd("checkhealth vim.lsp")
      end
      if vim.fn.exists(":LspInfo") == 0 then
        vim.api.nvim_create_user_command("LspInfo", _open_lsp_health, { desc = "Alias to :checkhealth vim.lsp" })
      end

      local lsp_capabilities = nil
      do
        local ok_blink, blink = pcall(require, "blink.cmp")
        if ok_blink and type(blink.get_lsp_capabilities) == "function" then
          local ok_caps, caps = pcall(blink.get_lsp_capabilities)
          if ok_caps and type(caps) == "table" then
            lsp_capabilities = caps
            pcall(vim.lsp.config, "*", { capabilities = caps })
          end
        end
      end

      vim.lsp.config["lua_ls"] = {
        capabilities = lsp_capabilities,
        settings = {
          Lua = {
            format = { enable = false },
            diagnostics = { globals = { "vim" } },
            workspace = {
              checkThirdParty = false,
              library = { vim.env.VIMRUNTIME .. "/lua" },
            },
            telemetry = { enable = false },
          },
        },
      }
      vim.lsp.config["clangd"] = {
        capabilities = lsp_capabilities,
        cmd = { "clangd", "--background-index", "--clang-tidy", "--function-arg-placeholders=false" },
      }
      vim.lsp.config["ts_ls"] = {
        capabilities = lsp_capabilities,
        cmd = {
          "typescript-language-server",
          "--tsserver-path",
          vim.g.tsserver_path,
          "--stdio",
        },
      }
      local solidity_project_markers = {
        "hardhat.config.js",
        "hardhat.config.ts",
        "foundry.toml",
        "remappings.txt",
        "truffle.js",
        "truffle-config.js",
        "ape-config.yaml",
      }
      local solidity_fallback_markers = { ".git", "package.json" }
      vim.lsp.config["solidity_ls_nomicfoundation"] = {
        capabilities = lsp_capabilities,
        cmd = { "nomicfoundation-solidity-language-server", "--stdio" },
        filetypes = { "solidity" },
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          -- Search upward for project markers, but skip markers inside
          -- lib/ (Foundry dependencies) or node_modules/ (Hardhat dependencies)
          -- to avoid starting separate LSP instances for dependency files.
          --
          -- Without this, opening a .sol file in lib/dependency/src/ would
          -- find the dependency's own foundry.toml and use that as the workspace
          -- root, resulting in a separate LSP server that doesn't know about
          -- the main project's files. Cross-file definition jumps between
          -- src/ and lib/ would then silently fail.
          local root = nil
          local dir = vim.fs.dirname(fname)
          while dir and dir ~= "" and dir ~= "/" do
            for _, marker in ipairs(solidity_project_markers) do
              if vim.fn.filereadable(dir .. "/" .. marker) == 1 then
                local parent_name = vim.fn.fnamemodify(vim.fs.dirname(dir), ":t")
                if parent_name ~= "lib" and parent_name ~= "node_modules" then
                  root = dir
                  break
                end
              end
            end
            if root then
              break
            end
            dir = vim.fs.dirname(dir)
          end
          if not root then
            root = vim.fs.root(fname, solidity_fallback_markers)
          end
          on_dir(root or vim.fs.dirname(fname))
        end,
      }
      -- Enable LSP servers from the language table.
      local _lsp_names = {}
      local _seen = {}
      for _, _conf in pairs(_langs) do
        if _conf.lsp and not _seen[_conf.lsp] then
          _seen[_conf.lsp] = true
          table.insert(_lsp_names, _conf.lsp)
        end
      end
      vim.lsp.enable(_lsp_names)

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("my.lsp", {}),
        callback = function(args)
          local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
          local buf = args.buf

          if client:supports_method("textDocument/definition") then
            vim.keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<cr>", {
              buffer = buf,
              desc = "Go to definition",
            })
          end
          if client:supports_method("textDocument/declaration") then
            vim.keymap.set("n", "gD", "<cmd>Telescope lsp_declarations<cr>", {
              buffer = buf,
              desc = "Go to declaration",
            })
          end
          if client:supports_method("textDocument/references") then
            vim.keymap.set("n", "gr", "<cmd>Telescope lsp_references<cr>", {
              buffer = buf,
              desc = "Go to references",
            })
          end
          if client:supports_method("textDocument/implementation") then
            vim.keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<cr>", {
              buffer = buf,
              desc = "Go to implementation",
            })
          end

          if client:supports_method("textDocument/hover") then
            vim.keymap.set("n", "K", function()
              vim.lsp.buf.hover({ border = "single" })
            end, { buffer = buf, desc = "Show hover documentation" })
          end

        end,
      })
