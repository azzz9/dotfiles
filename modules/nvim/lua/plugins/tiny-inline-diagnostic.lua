      -- Inline diagnostic rendering: overlapping diagnostics on one line,
      -- multi-line messages, and width overflow. nvim's built-in virtual_text
      -- is off in ui.lua, so this is the only inline renderer.
      require("tiny-inline-diagnostic").setup({
        -- classic draws "● message" without the powerline caps of "modern",
        -- and transparent_bg drops the chip background that would otherwise
        -- fight the transparent Normal highlight set in ui.lua.
        preset = "classic",
        transparent_bg = true,
        options = {
          -- Attach on display rather than on LspAttach alone: javascript,
          -- json and css buffers are linted by eslint_d/biome with no LSP
          -- client attached, and would show nothing inline.
          overwrite_events = { "BufWinEnter", "LspAttach" },
          -- always_show keeps messages on every line. Without it the plugin
          -- only draws the cursor line, which is quieter but loses the
          -- per-line messages nvim's virtual_text used to show.
          multilines = { enabled = true, always_show = true },
          -- Name the source only when several report in one buffer, so a
          -- lua_ls plus selene buffer is not ambiguous but the common
          -- single-source case stays clean.
          show_source = { enabled = true, if_many = true },
        },
      })
