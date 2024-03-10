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
    event = { "BufEnter" },
    config = function()
      require('hlargs').setup()
    end,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    }
  },
  {
    'HiPhish/rainbow-delimiters.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
    },
    event = 'VeryLazy',
    main = "rainbow-delimiters.setup",
  },
  {
    -- show code/scope context at top of window
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter" },
    },
    event = { "VeryLazy" },
  },
  {
    'JoosepAlviste/nvim-ts-context-commentstring',
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      'echasnovski/mini.nvim',
    },
    event = { "VeryLazy" },
    config = function()
      -- skip backwards compatibility routines and speed up loading
      vim.g.skip_ts_context_commentstring_module = true

      ---@diagnostic disable-next-line: missing-fields
      require('ts_context_commentstring').setup {
        -- disabling autocomand so that mini.comment can trigger comment string discovery
        enable_autocmd = false,
      }
    end
  }
}
