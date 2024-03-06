return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPre", "BufNewFile" },
    cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
    config = function()
      local configs = require("nvim-treesitter.configs")

      ---@diagnostic disable-next-line: missing-fields
      configs.setup({
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true
        },
        ensure_installed = {
          "bash",
          "comment",
          "dockerfile",
          "gitattributes",
          "gitignore",
          "go",
          "gomod",
          "hcl",
          "html",
          "http",
          "java",
          "javascript",
          "json",
          "json5",
          "kotlin",
          "lua",
          "make",
          "markdown",
          "markdown_inline",
          "proto",
          "python",
          "regex",
          "ruby",
          "rust",
          "sql",
          "toml",
          "typescript",
          "vim",
          "yaml",
        }
      })
    end
  },
  {
    -- hilight function args using treesitter
    'm-demare/hlargs.nvim',
    event = { "VeryLazy" },
    -- config = function()
    --   require('hlargs').setup()
    -- end,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    }
  },
  {
    'HiPhish/rainbow-delimiters.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter'
    },
    event = 'VeryLazy',
    main = 'rainbow-delimiters.setup',
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter" },
    },
    event = { "VeryLazy" },
  },
}
