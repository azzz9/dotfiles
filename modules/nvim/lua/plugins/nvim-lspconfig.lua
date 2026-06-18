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
        cmd = { "clangd", "--background-index", "--clang-tidy" },
      }
      vim.lsp.config["solidity_ls_nomicfoundation"] = {
        capabilities = vim.empty_dict(),
        cmd = { "nomicfoundation-solidity-language-server", "--stdio" },
        filetypes = { "solidity" },
        root_markers = {
          "hardhat.config.js",
          "hardhat.config.ts",
          "foundry.toml",
          "remappings.txt",
          "truffle.js",
          "truffle-config.js",
          "ape-config.yaml",
          ".git",
          "package.json",
        },
      }
      vim.lsp.enable({ "lua_ls", "ts_ls", "pyright", "clangd", "solidity_ls_nomicfoundation" })

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
