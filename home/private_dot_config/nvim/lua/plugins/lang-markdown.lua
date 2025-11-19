return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },            -- if you use the mini.nvim suite
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" }, -- if you use standalone mini plugins
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
  },
  {
    "mason-org/mason-lspconfig.nvim",
    optional = true,
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      -- TODO: Produces the following error:
      --   msg_show [mason-lspconfig.nvim] Server "rumdl" is not a valid entry in ensure_installed. Make sure to only provide lspconfig server names.
      ensure_installed = {
        -- "rumdl",
        "marksman",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = {
      servers = {
        marksman = {}, -- for TOC generation
        rumdl = { -- for linting and formatting
          -- For testing
          -- cmd = { "/Users/matt.klich/code/github/rumdl/target/release/rumdl", "server", "--verbose" },
          -- cmd = { "/Users/matt.klich/code/github/rumdl/target/release/rumdl", "server" },
          cmd = { "rumdl", "server" },
          filetypes = { "markdown", "markdown.mdx" },
          root_markers = { "rumdl.toml", ".rumdl.toml", ".markdownlint.yaml", ".git" },
        },
      },
    },
  },
  -- {
  --   "stevearc/conform.nvim",
  --   optional = true,
  --   opts = {
  --     formatters_by_ft = {
  --       ["markdown"] = { "prettier", "rumdl"},
  --       ["markdown.mdx"] = { "prettier", "rumdl"},
  --     },
  --   },
  -- },
}
