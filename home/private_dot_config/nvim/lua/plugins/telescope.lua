return {
  -- check out:
  --   https://github.com/HPRIOR/telescope-gpt
  --   https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#fuzzy-search-among-yaml-objects
  --   https://github.com/debugloop/telescope-undo.nvim
  --   custom dot_files extension: https://github.com/ray-x/nvim/blob/7e200b0949f919e805cd404ac4eac682dfe7140e/lua/utils/telescope.lua#L279

  {
    "nvim-telescope/telescope.nvim",
    cmd = { "Telescope" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "folke/which-key.nvim",
      "nvim-treesitter/nvim-treesitter",
      'nvim-telescope/telescope-fzf-native.nvim',
      -- 'desdic/telescope-rooter.nvim',
    },
    config = function()
      require('telescope').load_extension('fzf')
      -- require "telescope".load_extension("rooter")
    end,
  },
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',
  },
  {
    'ANGkeith/telescope-terraform-doc.nvim',
    keys = { "<leader>tT" },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    'tsakirist/telescope-lazy.nvim',
    keys = { "<leader>tl" },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    'polirritmico/telescope-lazy-plugins.nvim',
    keys = { "<leader>tL" },
    opts = {
      lazy_config = vim.fn.stdpath("config") .. "/lua/config/lazy.lua",
    },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    'stevearc/aerial.nvim',
    lazy = false, -- explicitly not lazy, needed for heirline's winbar
    -- keys = { "<leader>ts" }, --
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    opts = {},
    config = true,
  }
}
