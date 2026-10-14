      local function select_branch_diff()
        local branches = vim.fn.systemlist({
          "git",
          "for-each-ref",
          "--format=%(refname:short)",
          "refs/heads",
          "refs/remotes",
        })

        local seen = {}
        branches = vim.tbl_filter(function(branch)
          if branch == "" or branch:match("/HEAD$") or seen[branch] then
            return false
          end
          seen[branch] = true
          return true
        end, branches)
        table.sort(branches)

        if #branches == 0 then
          vim.notify("No local or remote branches found", vim.log.levels.WARN)
          return
        end

        vim.ui.select(branches, { prompt = "Compare from branch (merge-base): " }, function(branch)
          if branch then
            vim.cmd("CodeDiff " .. vim.fn.fnameescape(branch .. "..."))
          end
        end)
      end

      require("codediff").setup({
        diff = {
          layout = "inline",
          gutter_signs = true,
          jump_to_first_change = true,
        },
        explorer = {
          position = "left",
        },
        history = {
          position = "bottom",
          -- Take the whole tab: nvim clamps the height to what fits, and
          -- codediff re-pins the pane to this number whenever it rearranges.
          height = 1000,
        },
      })

      vim.keymap.set("n", "<leader>gc", "<cmd>CodeDiff<cr>", { desc = "Open git diff" })
      vim.keymap.set("n", "<leader>gC", select_branch_diff, { desc = "Compare branch diff" })
      vim.keymap.set("n", "<leader>gs", "<cmd>CodeDiff --staged<cr>", { desc = "Open staged diff" })
      vim.keymap.set("n", "<leader>gf", "<cmd>CodeDiff file HEAD<cr>", { desc = "Compare file with HEAD" })
      vim.keymap.set("n", "<leader>gl", "<cmd>CodeDiff history %<cr>", { desc = "Current file history" })
      vim.keymap.set("n", "<leader>gL", "<cmd>CodeDiff history<cr>", { desc = "Repository file history" })

      -- A history session always keeps a diff pane next to its list, and at one
      -- row that pane is a blank strip above the list. winminheight lets a
      -- window collapse to no rows, so the pane moves below the list and
      -- squashes. Focusing the pane hands its row back, hence the re-apply.
      vim.opt.winminheight = 0

      local function collapse_history_pane(tabpage)
        -- A float owns the focus it was given, so leave pickers and help alone.
        if vim.api.nvim_win_get_config(vim.api.nvim_get_current_win()).relative ~= "" then
          return
        end
        local session = require("codediff.ui.lifecycle").get_session(tabpage)
        local panel = session and session.panel
        if not (panel and panel.name == "history" and panel.view) then
          return
        end
        local panel_config = require("codediff.config").options.history
        if panel_config.position ~= "bottom" then
          return
        end
        local panel_win, diff_win = panel.view.winid, session.modified_win
        if not (panel_win and vim.api.nvim_win_is_valid(panel_win)) then
          return
        end
        if not (diff_win and vim.api.nvim_win_is_valid(diff_win)) then
          return
        end
        if vim.api.nvim_get_current_win() ~= panel_win then
          vim.api.nvim_set_current_win(panel_win)
        end
        if vim.api.nvim_win_get_position(diff_win)[1] < vim.api.nvim_win_get_position(panel_win)[1] then
          pcall(vim.api.nvim_win_set_config, diff_win, { split = "below", win = panel_win })
        end
        if vim.api.nvim_win_get_height(diff_win) > 0 then
          vim.api.nvim_win_set_height(panel_win, vim.o.lines)
        end
      end

      vim.api.nvim_create_autocmd("User", {
        pattern = "CodeDiffOpen",
        callback = function(event)
          if event.data.mode == "history" then
            vim.schedule(function()
              collapse_history_pane(event.data.tabpage)
            end)
          end
        end,
      })

      vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "TabEnter" }, {
        callback = function()
          vim.schedule(function()
            collapse_history_pane(vim.api.nvim_get_current_tabpage())
          end)
        end,
      })

      local GIT_EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904" -- git hash-object -t tree /dev/null

      local function history_entry()
        local tabpage = vim.api.nvim_get_current_tabpage()
        local view = require("codediff.ui.lifecycle").get_panel_view(tabpage)
        local node = view and view.tree and view.tree:get_node()
        local data = node and node.data
        if not data then
          return nil
        end
        local hash = data.type == "commit" and data.hash or data.commit_hash
        if not hash then
          return nil
        end
        return hash, data.git_root or (view.data and view.data.git_root)
      end

      -- A root commit has no parent. Git shows it against the empty tree, and
      -- codediff uses the same hash for an unborn HEAD.
      local function parent_or_empty_tree(hash, git_root)
        -- The raw commit object names its parents even when a shallow clone
        -- never fetched them, so this separates a root commit from a missing
        -- one. Reporting the missing parent beats diffing against the empty
        -- tree, which would show every file as added.
        for _, line in ipairs(vim.fn.systemlist({ "git", "-C", git_root, "cat-file", "-p", hash })) do
          if line == "" then
            break
          end
          local parent = line:match("^parent (%x+)")
          if parent then
            return parent
          end
        end
        return GIT_EMPTY_TREE
      end

      local function open_history_entry()
        local hash, git_root = history_entry()
        if not hash then
          vim.notify("No commit under the cursor", vim.log.levels.WARN)
          return
        end
        git_root = git_root or vim.fn.getcwd()
        local command = {
          "CodeDiff",
          "-C",
          vim.fn.fnameescape(git_root),
          vim.fn.fnameescape(parent_or_empty_tree(hash, git_root)),
          vim.fn.fnameescape(hash),
        }
        -- A file history reads one file: keep the explorer on that file.
        local view = require("codediff.ui.lifecycle").get_panel_view(vim.api.nvim_get_current_tabpage())
        local file = view and view.is_single_file_mode and view.data and view.data.file_path
        if file and file ~= "" then
          vim.list_extend(command, { "--", vim.fn.fnameescape(file) })
        end
        vim.cmd(table.concat(command, " "))
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "codediff-history",
        callback = function(event)
          vim.keymap.set("n", "o", open_history_entry, { buffer = event.buf, desc = "Open commit diff in explorer" })
        end,
      })

      -- Reading a commit must not write to the repository. An explorer session
      -- of two revisions still maps the staging keys, and they run git add, git
      -- reset and git restore against the working tree and index. Wrapping the
      -- actions behind them, rather than their keys, covers every key that
      -- reaches them and leaves --staged and rev-versus-worktree sessions alone.
      local STAGING_ACTIONS = {
        { module = "codediff.ui.view.actions.stage", name = "toggle_stage", label = "- (stage/unstage)" },
        { module = "codediff.ui.explorer.actions", name = "stage_all", label = "S (stage all)" },
        { module = "codediff.ui.explorer.actions", name = "unstage_all", label = "U (unstage all)" },
        { module = "codediff.ui.explorer.actions", name = "restore_entry", label = "X (restore file)" },
      }

      -- The explorer's comparison, not the file under the cursor, decides
      -- whether staging applies: only the working tree and the index are sides
      -- it can act on, and a selected deletion or conflict stage rewrites the
      -- session revision.
      local function is_read_only_tabpage(tabpage)
        local session = require("codediff.ui.lifecycle").get_session(tabpage)
        local panel = session and session.panel
        if not (panel and panel.name == "explorer") then
          return false
        end
        local refs = panel.data and panel.data.source_revisions
        local modified = refs and refs.modified
        return modified ~= nil and modified ~= "WORKING" and modified ~= ":0"
      end

      for _, action in ipairs(STAGING_ACTIONS) do
        local original = require(action.module)[action.name]
        if type(original) ~= "function" then
          vim.notify_once("[codediff] cannot guard " .. action.name .. ": no such action", vim.log.levels.WARN)
        else
          require(action.module)[action.name] = function(first, ...)
            local tabpage = type(first) == "table" and first.tabpage or vim.api.nvim_get_current_tabpage()
            if is_read_only_tabpage(tabpage) then
              vim.notify(action.label .. " would change the working tree or index; this comparison is read-only", vim.log.levels.WARN)
              return
            end
            return original(first, ...)
          end
        end
      end

      -- Everything above reads codediff internals. Re-verify the history keys
      -- and the staging guard when the plugin moves; this is the version the
      -- internals were read against.
      local CODEDIFF_VERIFIED = "4.0.6"
      local codediff_version = require("codediff.version").VERSION
      if codediff_version and codediff_version ~= CODEDIFF_VERIFIED then
        vim.notify_once(
          "codediff " .. codediff_version .. " differs from the verified " .. CODEDIFF_VERIFIED .. ": re-check the history keys and the staging guard",
          vim.log.levels.WARN
        )
      end
