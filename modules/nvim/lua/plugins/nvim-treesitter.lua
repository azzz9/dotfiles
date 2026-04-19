      local parser_install_dir = vim.fn.stdpath("data") .. "/treesitter"
      vim.fn.mkdir(parser_install_dir, "p")
      vim.opt.runtimepath:append(parser_install_dir)
      require("nvim-treesitter").setup({
        install_dir = parser_install_dir,
      })
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          if vim.bo[args.buf].buftype ~= "" then
            return
          end
          local has_parser = pcall(vim.treesitter.get_parser, args.buf)
          if has_parser then
            pcall(vim.treesitter.start, args.buf)
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
      require("nvim-treesitter-textobjects").setup({
        select = {
          lookahead = true,
          keymaps = {
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
          },
        },
      })
