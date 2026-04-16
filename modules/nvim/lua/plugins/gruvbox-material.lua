      local function read_file(path)
        local fd = vim.uv.fs_open(path, "r", 438)
        if not fd then
          return nil
        end
        local stat = vim.uv.fs_fstat(fd)
        if not stat then
          vim.uv.fs_close(fd)
          return nil
        end
        local data = vim.uv.fs_read(fd, stat.size, 0)
        vim.uv.fs_close(fd)
        return data
      end

      local function detect_terminal_theme()
        local profile_id = vim.env.WT_PROFILE_ID
        if not profile_id or profile_id == "" then
          return "dark"
        end

        local wt_paths = vim.fn.glob(
          "/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
          false,
          true
        )
        if #wt_paths == 0 then
          return "dark"
        end

        local raw = read_file(wt_paths[1])
        if not raw or raw == "" then
          return "dark"
        end

        local ok, wt = pcall(vim.json.decode, raw)
        if not ok or type(wt) ~= "table" then
          return "dark"
        end

        local mode = wt.theme == "light" and "light" or "dark"
        local profiles = wt.profiles or {}
        local defaults = profiles.defaults or {}
        local list = profiles.list or {}
        local current = nil

        for _, profile in ipairs(list) do
          if profile.guid == profile_id then
            current = profile
            break
          end
        end

        local scheme = (current and current.colorScheme) or defaults.colorScheme
        if type(scheme) == "string" then
          local lower = scheme:lower()
          if lower:find("light", 1, true) then
            mode = "light"
          elseif lower:find("dark", 1, true) then
            mode = "dark"
          end
        end

        return mode
      end

      local is_light_theme = detect_terminal_theme() == "light"
      vim.o.background = is_light_theme and "light" or "dark"
      vim.g.gruvbox_material_background = is_light_theme and "soft" or "medium"
      vim.g.gruvbox_material_enable_italic = true
      vim.g.gruvbox_material_diagnostic_text_highlight = true
      vim.g.gruvbox_material_diagnostic_line_highlight = true
      vim.g.gruvbox_material_diagnostic_virtual_text = "colored"
      pcall(vim.cmd.colorscheme, "gruvbox-material")
