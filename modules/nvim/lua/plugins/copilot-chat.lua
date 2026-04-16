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
          local buf = args.buf
          local completion = require("CopilotChat.completion")
          completion.enable(buf, true)
          vim.bo[buf].completeopt = "menu,menuone,noselect,popup"
          vim.bo[buf].omnifunc = [[v:lua.require'CopilotChat.completion'.omnifunc]]
          local function pick_file()
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

          if vim.b[buf].copilotchat_picker_autocmd then
            return
          end
          vim.b[buf].copilotchat_picker_autocmd = true
          vim.api.nvim_create_autocmd("TextChangedI", {
            buffer = buf,
            callback = function()
              if vim.b[buf].copilotchat_picker_open then
                return
              end
              local row, col = unpack(vim.api.nvim_win_get_cursor(0))
              local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
              if line:sub(1, col):match("#file:%s*$") then
                vim.b[buf].copilotchat_picker_open = true
                vim.schedule(function()
                  if vim.api.nvim_buf_is_valid(buf) then
                    pick_file()
                  end
                  vim.b[buf].copilotchat_picker_open = false
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
