if vim.env.TUIOS_ENV == "1" then
  require("tuios-nvim-navigator").setup({
    keymaps = {
      left = "<A-h>",
      down = "<A-j>",
      up = "<A-k>",
      right = "<A-l>",
    },
  })
end
