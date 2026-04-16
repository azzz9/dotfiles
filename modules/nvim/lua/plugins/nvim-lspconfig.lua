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
        local ok_cmp_lsp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
        if ok_cmp_lsp and type(cmp_lsp.default_capabilities) == "function" then
          local ok_caps, caps = pcall(cmp_lsp.default_capabilities)
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
        cmd = { "clangd", "--background-index", "--clang-tidy" },
      }
      vim.lsp.enable({ "lua_ls", "ts_ls", "pyright", "clangd" })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("my.lsp", {}),
        callback = function(args)
          local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
          local buf = args.buf

          if client:supports_method("textDocument/definition") then
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf, desc = "Go to definition" })
          end
          if client:supports_method("textDocument/declaration") then
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = buf, desc = "Go to declaration" })
          end
          if client:supports_method("textDocument/references") then
            vim.keymap.set("n", "gr", "<cmd>Telescope lsp_references<cr>", {
              buffer = buf,
              desc = "Go to references",
            })
          end
          if client:supports_method("textDocument/implementation") then
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { buffer = buf, desc = "Go to implementation" })
          end

          if client:supports_method("textDocument/hover") then
            vim.keymap.set("n", "<leader>k", function()
              vim.lsp.buf.hover({ border = "single" })
            end, { buffer = buf, desc = "Show hover documentation" })
          end

          if client:supports_method("textDocument/completion") then
            client.server_capabilities.completionProvider.triggerCharacters =
              vim.split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.", "")
            vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
          end

          if client:supports_method("textDocument/inlineCompletion") then
            local inline = vim.lsp.inline_completion
            if inline and inline.enable then
              inline.enable(true, { bufnr = buf })
            end
            if inline and inline.get then
              vim.keymap.set("i", "<C-l>", function()
                if not inline.get() then
                  return "<C-l>"
                end
              end, { buffer = buf, expr = true, desc = "Accept inline completion" })
            end
          end
        end,
      })
