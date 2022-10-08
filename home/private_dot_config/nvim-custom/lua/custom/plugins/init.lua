return {
  -- auto close quotes/parens/etc. <- neovim uses nvim-autopairs but it doesn't support quotes
  ["spf13/vim-autoclose"] = {},
  -- ["m4xshen/autoclose.nvim"] = {},

  -- change, delete, add surroungings
  ["tpope/vim-surround"] = {},
  -- ["kylechui/nvim-surround"] = {},

  -- enable repeating supported plugin maps with '.'
  ["tpope/vim-repeat"] = {},

  -- auto-close if/for/etc.
  ["tpope/vim-endwise"] = {},

  -- <C-A> and <C-X> support for dates, roman numerals, ordinals (1st, 2nd, etc.), d<C-A> sets date under cusror to current date (d<C-A> for UTC)
  ["tpope/vim-speeddating"] = {},

  -- git magic
  ["tpope/vim-fugitive"] = {},

  -- like sublimetext multiselect
  ["terryma/vim-multiple-cursors"] = {},

  ["vim-scripts/bufexplorer.zip"] = {},

  ["sickill/vim-pasta"] = {},

  ["scrooloose/nerdcommenter"] = {},

  ["bronson/vim-trailing-whitespace"] = {},

  ["fatih/vim-go"] = {},

  ["dhruvasagar/vim-table-mode"] = {},

  ["mbbill/undotree"] = {},

  ["majutsushi/tagbar"] = {
    -- cond = function()
    --    -- determine if ctags is available
    -- end,
  },

  ["editorconfig/editorconfig-vim"] = {},

  -- TODO: test, is nested require correct?
  -- ["weilbith/nvim-code-action-menu"] = {
  --   cmd = 'CodeActionMenu',
  --   requires = {
  --    'kosayoda/nvim-lightbulb',
  --      config = {
  --        autocmd = {enabled = true}
  --      },
  --      requires = {'antoinemadec/FixCursorHold.nvim'},
  --   },
  -- },

  -- enable which-key
  ["folke/which-key.nvim"] = {
    disable = false,
  },

  -- fancy yaml
  -- TODO: doesn't work...
  ["someone-stole-my-name/yaml-companion.nvim"] = {
    requires = {
      { "neovim/nvim-lspconfig" },
      { "nvim-lua/plenary.nvim" },
      { "nvim-telescope/telescope.nvim" },
    },
    after = "telescope.nvim",
    config = function()
      require("telescope").load_extension("yaml_schema")
    end,
  },

  -- autocompletion
  ["f3fora/cmp-spell"] = {
    after = "nvim-cmp",
  },
  ["hrsh7th/nvim-cmp"] = {
    override_options = {
      sources = {
        { name = "luasnip" },
        { name = "nvim_lsp" },
        { name = "buffer" },
        { name = 'spell' }, -- cpm-spell
        { name = "nvim_lua" },
        { name = "path" },
      },
    },
  },

  ["williamboman/mason.nvim"] = {
    override_options = {
      ensure_installed = {
        "bash-language-server",
        "black",
        "cfn-lint",
        "debugpy",
        "dockerfile-language-server",
        "editorconfig-checker",
        "erb-lint",
        "eslint-lsp",
        "fixjson",
        "gitlint",
        "go-debug-adapter",
        "golangci-lint",
        "golangci-lint-langserver",
        "gopls",
        "graphql-language-service-cli",
        "groovy-language-server",
        "isort",
        "jq",
        "json-lsp",
        "kotlin-language-server",
        "lua-language-server",
        "markdownlint",
        "marksman",
        "prettier",
        "proselint",
        "pylint",
        "python-lsp-server",
        "shellcheck",
        "shfmt",
        "terraform-ls",
        "tflint",
        "typescript-language-server",
        "vim-language-server",
        "yaml-language-server",
      }
    }
  },

  ["NvChad/ui"] = {
    override_options = {
      tabufline = {
        lazyload = false, -- to show tabufline by default
      }
    }
  },

  ["lewis6991/gitsigns.nvim"] = {
    override_options = {
      numhl = true
    }
  },

  ["neovim/nvim-lspconfig"] = {
    config = function()
      require "plugins.configs.lspconfig" -- load defaults
      require "custom.plugins.lspconfig"  -- load customization
    end,
  },

  ["jose-elias-alvarez/null-ls.nvim"] = {
    after = "nvim-lspconfig",
    config = function()
      require("custom.plugins.null-ls").setup()
    end,
  },

  ["nvim-treesitter/nvim-treesitter"] = {
    override_options = {
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
        "yaml"
      }
    }
  }

  -- remove plugin example
  -- ["neovim/nvim-lspconfig"] = false
}
