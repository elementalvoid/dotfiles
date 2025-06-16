return {
  {
    "benomahony/uv.nvim",
    opts = {
      picker_integration = true,
      keymaps = {
        prefix = "<leader>p", -- Change prefix to <leader>u
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Format is <server-name> = { settings ... }. Manuualy nesting the settings
        -- block is not required.

        -- pylsp = {
        --   -- https://github.com/python-lsp/python-lsp-server
        --   configurationSources = { "flake8" },
        --   plugins = {
        --     pycodestyle = { enabled = false },
        --     mccabe = { enabled = false },
        --     pyflakes = { enabled = false },
        --     flake8 = {
        --       enabled = true,
        --       ignore = {
        --         -- https://flake8.pycqa.org/en/latest/user/error-codes.html
        --         "E501", -- disable line length, let 'black' formatter handle this
        --       },
        --     },
        --     -- rope_autoimport = {
        --     --   enabled = true,
        --     -- },
        --     -- -- depends on: https://github.com/python-lsp/python-lsp-black
        --     -- black = {
        --     -- enabled = true,
        --     -- },
        --     -- -- https://github.com/python-lsp/pylsp-mypy
        --     -- ["pyslsp-mypy"] = {
        --     --   enabled = true,
        --     -- }
        --   },
        -- },
        -- pyright = {
        --   analysis = {
        --     diagnosticMode = "workspace",
        --   },
        -- },
      },
    },
  },
}
