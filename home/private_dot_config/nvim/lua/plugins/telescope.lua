return {
  -- check out:
  --   https://github.com/HPRIOR/telescope-gpt
  --   https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#fuzzy-search-among-yaml-objects
  --   https://github.com/debugloop/telescope-undo.nvim
  --   https://github.com/davvid/telescope-git-grep.nvim
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
    event = { 'VeryLazy' },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    configure = function ()
      require('telescope').load_extension('terraform_doc')
    end
  },
  {
    'tsakirist/telescope-lazy.nvim',
    event = { 'VeryLazy' },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    configure = function ()
      require('telescope').load_extension('lazy')
    end
  },
  {
    'polirritmico/telescope-lazy-plugins.nvim',
    event = { 'VeryLazy' },
    opts = {
      lazy_config = vim.fn.stdpath("config") .. "/lua/config/lazy.lua",
    },
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    configure = function ()
      require('telescope').load_extension('lazy_plugins')
    end
  },
  {
    'stevearc/aerial.nvim',
    lazy = false, -- explicitly not lazy, needed for heirline's winbar
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    opts = {},
    config = true,
  }
}
