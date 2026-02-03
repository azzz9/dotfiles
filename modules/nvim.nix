{ pkgs, ... }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
  treesitterWithGrammars = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
  smoothcursorPlugin = pkgs.vimUtils.buildVimPlugin {
    name = "smoothcursor-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "gen740";
      repo = "SmoothCursor.nvim";
      rev = "12518b284e1e3f7c6c703b346815968e1620bee2";
      hash = "sha256-P0jGm5ODEVbtmqPGgDFBPDeuOF49CFq5x1PzubEJgaM=";
    };
  };
in
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    colorschemes.gruvbox-material = {
      enable = true;
      settings = {
        background = "medium";
        enable_italic = true;
        diagnostic_text_highlight = true;
        diagnostic_line_highlight = true;
        diagnostic_virtual_text = "colored";
      };
    };
    globals = {
      mapleader = " ";
      maplocalleader = "\\";
    };
    opts = {
      clipboard = "unnamedplus";
      number = true;
      relativenumber = true;
      showmatch = true;
      mouse = "a";
      autoread = true;
      updatetime = 1000;
      cursorline = true;
      cursorlineopt = "both";
      tabstop = 2;
      shiftwidth = 2;
      softtabstop = 2;
      expandtab = true;
    };
    extraPlugins =
      with pkgs.vimPlugins;
      [
        noice-nvim
        nui-nvim
        nvim-notify
        flash-nvim
        lualine-nvim
        nvim-web-devicons
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path
        cmp-cmdline
        luasnip
        telescope-nvim
        plenary-nvim
        telescope-ui-select-nvim
        nvim-lspconfig
        nvim-autopairs
        trouble-nvim
        conform-nvim
        nvim-lint
        nvim-surround
        todo-comments-nvim
        lazygit-nvim
        copilot-lua
        copilot-cmp
        CopilotChat-nvim
        gitsigns-nvim
        oil-nvim
        mini-nvim
        bufferline-nvim
        nvim-dap
        nvim-dap-ui
        nvim-dap-virtual-text
        nvim-dap-python
        nvim-nio
        nvim-treesitter-textobjects
        indent-blankline-nvim
        rainbow-delimiters-nvim
        which-key-nvim
        neoscroll-nvim
        smoothcursorPlugin
      ]
      ++ [ treesitterWithGrammars ];
    extraConfigLua = ''
      vim.g.start_time = vim.loop.hrtime()

      vim.keymap.set("n", "<C-v>", "<C-v>", { noremap = true })
      vim.keymap.set("i", "<C-v>", "<C-v>", { noremap = true })

      vim.api.nvim_create_autocmd(
        { "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermClose", "TermLeave" },
        { command = "checktime" }
      )

      vim.api.nvim_create_autocmd("FileChangedShellPost", {
        callback = function()
          vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.WARN)
        end,
      })

      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function(args)
          if vim.bo[args.buf].buftype ~= "" or not vim.bo[args.buf].modifiable then
            return
          end
          local view = vim.fn.winsaveview()
          vim.cmd("silent! keepjumps normal! gg=G")
          vim.fn.winrestview(view)
        end,
      })

      vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", { silent = true })
      vim.keymap.set("n", "Y", "y$", { desc = "Yank to end of line" })
      vim.keymap.set("i", "jj", "<Esc>", { noremap = true })
      vim.keymap.set("i", "jk", "<Esc>", { noremap = true })
      vim.keymap.set("n", "<leader>sv", ":vsplit<CR>", { desc = "Vertical split" })
      vim.keymap.set("n", "<leader>sh", ":split<CR>", { desc = "Horizontal split" })
      vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "LSP rename" })
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      vim.keymap.set("n", "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Search buffer" })
      vim.keymap.set("n", "<leader>sg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
      vim.keymap.set("n", "<leader>sd", "<cmd>Telescope diagnostics<cr>", { desc = "Diagnostics search" })
      vim.keymap.set({ "n", "x", "o" }, "s", function()
        require("flash").jump()
      end, { desc = "Flash jump" })
      vim.keymap.set({ "n", "x", "o" }, "S", function()
        require("flash").treesitter()
      end, { desc = "Flash treesitter" })
      vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
      vim.keymap.set("n", "<C-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
      vim.keymap.set("n", "<C-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
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
        require("dapui").toggle()
      end, { desc = "DAP UI toggle" })

      require("telescope").setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            width = 0.95,
            height = 0.85,
          },
        },
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({}),
          },
        },
      })
      require("telescope").load_extension("ui-select")
      vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find Files" })
      vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live Grep" })
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find Buffers" })
      vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help Tags" })

      require("lualine").setup({
        options = {
          component_separators = {},
          section_separators = {},
        },
        sections = {
          lualine_a = { "filename" },
          lualine_b = { "branch" },
          lualine_c = {
            "'%='",
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
              separator = "  |  ",
            },
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
            },
          },
          lualine_x = { "encoding", "fileformat" },
          lualine_y = { "filetype", "searchcount" },
          lualine_z = {},
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
      })

      local parser_install_dir = vim.fn.stdpath("data") .. "/treesitter"
      vim.fn.mkdir(parser_install_dir, "p")
      vim.opt.runtimepath:append(parser_install_dir)
      require("nvim-treesitter.configs").setup({
        highlight = { enable = true },
        indent = { enable = true },
        rainbow = { enable = true, extended_mode = true },
        auto_install = false,
        parser_install_dir = parser_install_dir,
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["aa"] = "@parameter.outer",
              ["ia"] = "@parameter.inner",
            },
          },
        },
      })
      require("ibl").setup({})

      require("gitsigns").setup({
        signs = {
          add = { text = "▎" },
          change = { text = "▎" },
          delete = { text = "" },
          topdelete = { text = "" },
          changedelete = { text = "▎" },
        },
        preview_config = {
          border = "rounded",
        },
      })

      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          separator_style = "slant",
          show_buffer_close_icons = false,
          show_close_icon = false,
        },
      })

      require("mini.icons").setup({})
      require("mini.comment").setup({})
      require("mini.starter").setup({
        query_updaters = "",
        silent = true,
        footer = function()
          local ms = (vim.loop.hrtime() - vim.g.start_time) / 1e6
          return string.format("Startup: %.1f ms", ms)
        end,
      })
      require("oil").setup({})

      require("nvim-autopairs").setup({})
      require("nvim-surround").setup({})

      require("flash").setup({})

      require("which-key").setup({})

      local im_select = "/mnt/c/im-select.exe"
      vim.api.nvim_create_autocmd("InsertLeave", {
        callback = function()
          vim.system({ im_select, "1033" })
        end,
      })

      require("neoscroll").setup({
        duration_multiplier = 0.5,
      })

      require("smoothcursor").setup({
        autostart = true,
        interval = 25,
        speed = 40,
        threshold = 2,
      })

      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
      })

      require("trouble").setup()
      require("todo-comments").setup({})
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
        filetypes = { ["*"] = true },
      })
      require("copilot_cmp").setup({})
      require("CopilotChat").setup({
        chat_autocomplete = true,
        prompts = {
          Explain = {
            prompt = "選択したコードの説明を日本語で書いてください",
            mapping = "<leader>ce",
          },
          Review = {
            prompt = "コードを日本語でレビューしてください",
            mapping = "<leader>cr",
          },
          Fix = {
            prompt = "このコードには問題があります。バグを修正したコードを表示してください。説明は日本語でお願いします",
            mapping = "<leader>cf",
          },
          Optimize = {
            prompt = "選択したコードを最適化し、パフォーマンスと可読性を向上させてください。説明は日本語でお願いします",
            mapping = "<leader>co",
          },
          Docs = {
            prompt = "選択したコードに関するドキュメントコメントを日本語で生成してください",
            mapping = "<leader>cd",
          },
          Tests = {
            prompt = "選択したコードの詳細なユニットテストを書いてください。説明は日本語でお願いします",
            mapping = "<leader>ct",
          },
          Commit = {
            prompt = require("CopilotChat.config.prompts").Commit.prompt,
            mapping = "<leader>cco",
            selection = require("CopilotChat.select").gitdiff,
          },
        },
      })
      vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
        pattern = "copilot-chat",
        callback = function(args)
          local completion = require("CopilotChat.completion")
          completion.enable(args.buf, true)
          vim.bo[args.buf].completeopt = "menu,menuone,noselect,popup"
          vim.bo[args.buf].omnifunc = [[v:lua.require'CopilotChat.completion'.omnifunc]]
          local function pick_file()
            local buf = args.buf
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
            local needs_prefix = not line:sub(1, col):match("#file:%s*$")
            local prefix = needs_prefix and "#file: " or ""

            require("telescope.builtin").find_files({
              attach_mappings = function(prompt_bufnr, _)
                local actions = require("telescope.actions")
                local state = require("telescope.actions.state")
                actions.select_default:replace(function()
                  local entry = state.get_selected_entry()
                  actions.close(prompt_bufnr)
                  if not entry or not entry.path then
                    return
                  end
                  vim.api.nvim_buf_set_text(buf, row - 1, col, row - 1, col, { prefix .. entry.path })
                  vim.api.nvim_win_set_cursor(0, { row, col + #prefix + #entry.path })
                end)
                return true
              end,
            })
          end

          vim.keymap.set("i", "<C-f>", pick_file, { buffer = buf, desc = "CopilotChat file picker" })
          vim.keymap.set("i", "<C-x><C-f>", pick_file, { buffer = buf, desc = "CopilotChat file picker" })

          if vim.b[args.buf].copilotchat_picker_autocmd then
            return
          end
          vim.b[args.buf].copilotchat_picker_autocmd = true
          vim.api.nvim_create_autocmd("TextChangedI", {
            buffer = args.buf,
            callback = function()
              if vim.b[args.buf].copilotchat_picker_open then
                return
              end
              local row, col = unpack(vim.api.nvim_win_get_cursor(0))
              local line = vim.api.nvim_buf_get_lines(args.buf, row - 1, row, false)[1] or ""
              if line:sub(1, col):match("#file:%s*$") then
                vim.b[args.buf].copilotchat_picker_open = true
                vim.schedule(function()
                  if vim.api.nvim_buf_is_valid(args.buf) then
                    pick_file()
                  end
                  vim.b[args.buf].copilotchat_picker_open = false
                end)
              end
            end,
          })
        end,
      })
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(args)
          local name = vim.api.nvim_buf_get_name(args.buf)
          if name ~= "copilot-overlay" then
            return
          end
          vim.keymap.set("n", "<C-y>", function()
            local chat = require("CopilotChat").chat
            if not chat:visible() then
              return
            end
            local source = { winnr = vim.api.nvim_get_current_win(), bufnr = args.buf }
            local prev_win = source.winnr
            vim.api.nvim_set_current_win(chat.winnr)
            require("CopilotChat.config").mappings.accept_diff.callback(source)
            if vim.api.nvim_win_is_valid(prev_win) then
              vim.api.nvim_set_current_win(prev_win)
            end
          end, { buffer = args.buf, desc = "CopilotChat accept diff" })
        end,
      })
      vim.keymap.set("n", "<leader>cc", function()
        require("CopilotChat").toggle()
      end, { desc = "CopilotChat toggle" })
      vim.keymap.set("n", "<leader>cw", function()
        require("CopilotChat").toggle()
      end, { desc = "CopilotChat toggle (switch)" })
      vim.keymap.set("n", "<leader>cch", "<cmd>CopilotChatOpen<cr>", { desc = "CopilotChat open" })
      vim.keymap.set("n", "<leader>ccp", "<cmd>CopilotChatPrompts<cr>", { desc = "CopilotChat prompts" })
      vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
      vim.keymap.set("n", "<leader>xw", "<cmd>Trouble workspace_diagnostics toggle<cr>", {
        desc = "Workspace Diagnostics",
      })
      vim.keymap.set("n", "<leader>e", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics list" })

      require("conform").setup({
        formatters_by_ft = {
          javascript = { "prettierd", "prettier" },
          javascriptreact = { "prettierd", "prettier" },
          typescript = { "prettierd", "prettier" },
          typescriptreact = { "prettierd", "prettier" },
          json = { "prettierd", "prettier" },
          css = { "prettierd", "prettier" },
          html = { "prettierd", "prettier" },
          markdown = { "prettierd", "prettier" },
          lua = { "stylua" },
          python = { "ruff_format" },
        },
        format_on_save = function()
          return { async = false, lsp_fallback = true, quiet = true }
        end,
      })

      local lint = require("lint")
      lint.linters_by_ft = {
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        lua = { "selene" },
        python = { "ruff" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        callback = function()
          lint.try_lint()
        end,
      })

      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
          vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
          vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
          vim.api.nvim_set_hl(0, "FoldColumn", { bg = "none" })
          vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
          vim.api.nvim_set_hl(0, "DiagnosticErrorLine", { bg = "#3b1113" })
          vim.api.nvim_set_hl(0, "DiagnosticWarnLine", { bg = "#3b2a11" })
          vim.api.nvim_set_hl(0, "DiagnosticInfoLine", { bg = "#112f3b" })
          vim.api.nvim_set_hl(0, "DiagnosticHintLine", { bg = "#113b1b" })
          vim.api.nvim_set_hl(0, "DiagnosticErrorNr", { bg = "#3b1113", bold = true })
          vim.api.nvim_set_hl(0, "DiagnosticWarnNr", { bg = "#3b2a11", bold = true })
          vim.api.nvim_set_hl(0, "DiagnosticInfoNr", { bg = "#112f3b", bold = true })
          vim.api.nvim_set_hl(0, "DiagnosticHintNr", { bg = "#113b1b", bold = true })
          vim.api.nvim_set_hl(0, "LineNr", { fg = "#7c6f64" })
          vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#7c6f64" })
          vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#7c6f64" })
          vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#fabd2f", bold = true })
          vim.api.nvim_set_hl(0, "CursorLine", { bg = "#3c3836", ctermbg = 237 })
        end,
      })
      vim.cmd("doautocmd ColorScheme")

      vim.diagnostic.config({
        virtual_text = {
          spacing = 2,
          format = function(d)
            return d.message
          end,
        },
        virtual_lines = false,
        underline = false,
        update_in_insert = false,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.HINT] = "",
          },
          linehl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticErrorLine",
            [vim.diagnostic.severity.WARN] = "DiagnosticWarnLine",
            [vim.diagnostic.severity.INFO] = "DiagnosticInfoLine",
            [vim.diagnostic.severity.HINT] = "DiagnosticHintLine",
          },
          numhl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticErrorNr",
            [vim.diagnostic.severity.WARN] = "DiagnosticWarnNr",
            [vim.diagnostic.severity.INFO] = "DiagnosticInfoNr",
            [vim.diagnostic.severity.HINT] = "DiagnosticHintNr",
          },
        },
      })

      vim.lsp.config["lua_ls"] = {
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
      vim.lsp.enable({ "lua_ls", "ts_ls", "pyright" })

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
            if inline and inline.enable and inline.get then
              inline.enable(true, { bufnr = buf })
              vim.keymap.set("i", "<Tab>", function()
                if not inline.get() then
                  return "<Tab>"
                end
                if vim.fn.pumvisible() == 1 then
                  return "<C-e>"
                end
              end, {
                expr = true,
                buffer = buf,
                desc = "Accept the current inline completion",
              })
            end
          end
        end,
      })

      local cmp = require("cmp")
      vim.o.completeopt = "menu,menuone,noselect,popup"
      cmp.setup({
        preselect = cmp.PreselectMode.None,
        completion = { completeopt = "menu,menuone,noselect,popup" },
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = {
          { name = "copilot" },
          { name = "nvim_lsp" },
        },
        experimental = { ghost_text = false },
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline" },
        }),
      })
      cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })

      local dap = require("dap")
      local dapui = require("dapui")
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
      require("nvim-dap-virtual-text").setup()
      require("dap-python").setup("${debugpyPython}/bin/python")
    '';
  };
}
