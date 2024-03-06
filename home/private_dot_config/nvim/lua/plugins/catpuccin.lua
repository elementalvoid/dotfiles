return {
  {
    "catppuccin/nvim",
    lazy = false,    -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      -- load the colorscheme here
      vim.cmd([[colorscheme catppuccin-latte]])
    end,
    ---@type CatppuccinOptions
    opts = {
      integrations = {
        mason = true,
        -- neotree = true,
        noice = true,
        notify = true,
        rainbow_delimiters = true,
        symbols_outline = true,
        telescope = true,
        treesitter_context = true,
        ts_rainbow = false,
        which_key = true,
      }
    },
  }
}
