return {
  -- lsp-zero: https://lsp-zero.netlify.app
  -- All servers: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
  -- Check out:
  --   https://github.com/stevearc/conform.nvim (replaces null-ls/none-ls)
  --   https://github.com/mfussenegger/nvim-dap
  --   https://github.com/rcarriga/nvim-dap-ui
  --   https://github.com/jay-babu/mason-nvim-dap.nvim
  --
  -- Telescope builtins to consider:
  --   lsp_definitions = <function 27>,
  --   lsp_document_symbols = <function 28>,
  --   lsp_dynamic_workspace_symbols = <function 29>,
  --   lsp_implementations = <function 30>,
  --   lsp_incoming_calls = <function 31>,
  --   lsp_outgoing_calls = <function 32>,
  --   lsp_references = <function 33>,
  --   lsp_type_definitions = <function 34>,
  --   lsp_workspace_symbols = <function 35>,

  {
    'aznhe21/actions-preview.nvim',
    event = "VeryLazy",
    opts = {
      telescope = {
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
          width = 0.8,
          height = 0.9,
          prompt_position = "top",
          preview_cutoff = 20,
          preview_height = function(_, _, max_lines)
            return max_lines - 15
          end,
        },
      },
    },
  },
  {
    "folke/lazydev.nvim",
    ft = "lua", -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    -- optional `vim.uv` typings
    "Bilal2453/luvit-meta",
    lazy = true
  },
  {
    -- completion source for require statements and module annotations
    "hrsh7th/nvim-cmp",
    -- ---@param opts cmp.ConfigSchema
    -- opts = function(_, opts)
    --   opts.sources = opts.sources or {}
    --   table.insert(opts.sources, {
    --     name = "lazydev",
    --     group_index = 0, -- set group index to 0 to skip loading LuaLS completions
    --   })
    -- end,
  },
  {
    -- JSON/YAML schema
    'b0o/schemastore.nvim',
  },
  {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v3.x',
    dependencies = {
      'folke/neodev.nvim',
    },
    init = function()
      local lsp_zero = require('lsp-zero')
      local lspkind = require('lspkind')
      local cmp = require('cmp')
      local cmp_action = require('lsp-zero').cmp_action()

      lsp_zero.extend_lspconfig()

      ---@diagnostic disable-next-line: unused-local
      lsp_zero.on_attach(function(client, bufnr)
        -- see :help lsp-zero-keybindings
        -- to learn the available actions
        lsp_zero.default_keymaps({ buffer = bufnr })

        -- add borders to lsp_signature
        require "lsp_signature".on_attach({
          bind = true, -- This is mandatory, otherwise border config won't get registered.
          handler_opts = {
            border = "rounded"
          }
        }, bufnr)
      end)

      lsp_zero.set_sign_icons({
        error = '✘',
        warn = '▲',
        hint = '⚑',
        info = '»'
      })

      cmp.setup({
        sources = {
          { name = 'copilot' },
          { name = 'nvim_lsp' },
          { name = 'treesitter' },
          { name = 'nvim_lua' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        },
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<Tab>'] = cmp_action.luasnip_supertab(),
          ['<S-Tab>'] = cmp_action.luasnip_shift_supertab(),
          ['<CR>'] = cmp.mapping.confirm({ select = false }),
          ['<C-Space>'] = cmp.mapping.complete(),
        }),
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        completion = {
          -- Uncomment to auto-select the first entry
          -- completeopt = "menu,menuone,noinsert"
        },
        ---@diagnostic disable-next-line: missing-fields
        formatting = {
          fields = { 'abbr', 'kind', 'menu' },
          format = lspkind.cmp_format({
            mode = 'symbol_text',     -- show only symbol annotations
            maxwidth = 50,            -- prevent the popup from showing more than provided characters
            ellipsis_char = '...',    -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead
            show_labelDetails = true, -- show labelDetails in menu. Disabled by default
            -- symbol_map is copied from astronvim
            symbol_map = {
              Array = "󰅪",
              Boolean = "⊨",
              Class = "󰌗",
              Copilot = "",
              Constructor = "",
              Key = "󰌆",
              Namespace = "󰅪",
              Null = "NULL",
              Number = "#",
              Object = "󰀚",
              Package = "󰏗",
              Property = "",
              Reference = "",
              Snippet = "",
              String = "󰀬",
              TypeParameter = "󰊄",
              Unit = "",
            },
          }),
          sorting = {
            -- The prioritize comparitor causes copilot entries to appear higher in the cmp menu. It is recommended
            -- keeping priority weight at 2, or placing the exact comparitor above copilot so that better lsp
            -- matches are not stuck below poor copilot matches.
            priority_weight = 2,
            comparators = {
              require("copilot_cmp.comparators").prioritize,

              -- Below is the default comparitor list and order for nvim-cmp
              cmp.config.compare.offset,
              -- cmp.config.compare.scopes, --this is commented in nvim-cmp too
              cmp.config.compare.exact,
              cmp.config.compare.score,
              cmp.config.compare.recently_used,
              cmp.config.compare.locality,
              cmp.config.compare.kind,
              cmp.config.compare.sort_text,
              cmp.config.compare.length,
              cmp.config.compare.order,
            },
          },
        },
      })

      -- to learn how to use mason.nvim with lsp-zero
      -- read this: https://github.com/VonHeikemen/lsp-zero.nvim/blob/v3.x/doc/md/guide/integrate-with-mason-nvim.md
      require('mason').setup({})
      require('mason-lspconfig').setup({
        automatic_installation = true,
        ensure_installed = {
          'bashls',
          'dockerls',
          'gopls',
          'jsonls',
          'lua_ls',
          'marksman',
          'pylsp',
          'ruff_lsp',
          'terraformls',
          'tflint',
          'vimls',
          'yamlls',
        },
        handlers = {
          lsp_zero.default_setup,

          -- example to disable auomatic setup
          -- example_server = lsp_zero.noop,

          lua_ls = function()
            local lua_opts = lsp_zero.nvim_lua_ls()
            require('lspconfig').lua_ls.setup(lua_opts)
          end,
          terraformls = function()
            require('lspconfig').terraformls.setup {
              -- make terraformls shutup: https://github.com/hashicorp/terraform-ls/issues/1271
              cmd = { 'terraform-ls', 'serve', '-log-file', '/dev/null' }
            }
          end,
          pylsp = function()
            -- https://github.com/python-lsp/python-lsp-server
            require('lspconfig').pylsp.setup {
              configurationSources = { "flake8" },
              plugins = {
                pycodestyle = { enabled = false },
                mccabe = { enabled = false },
                pyflakes = { enabled = false },
                flake8 = {
                  enabled = true,
                  ignore = {
                    -- https://flake8.pycqa.org/en/latest/user/error-codes.html
                    "E501", -- disable line length, let 'black' formatter handle this
                  },
                },
                -- rope_autoimport = {
                --   enabled = true,
                -- },
                -- -- depends on: https://github.com/python-lsp/python-lsp-black
                -- black = {
                -- enabled = true,
                -- },
                -- -- https://github.com/python-lsp/pylsp-mypy
                -- ["pyslsp-mypy"] = {
                --   enabled = true,
                -- }
              },
            }
          end,
          jsonls = function()
            require('lspconfig').jsonls.setup {
              settings = {
                json = {
                  schemas = require('schemastore').json.schemas(),
                  validate = { enable = true },
                },
              },
            }
          end,
          yamlls = function()
            require('lspconfig').yamlls.setup {
              settings = {
                yaml = {
                  schemaStore = {
                    -- You must disable built-in schemaStore support if you want to use
                    -- this plugin and its advanced options like `ignore`.
                    enable = false,
                    -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
                    url = "",
                  },
                  schemas = require('schemastore').yaml.schemas(),
                },
              },
            }
          end
          -- pyright = {
          --   settings = {
          --     pyright = {
          --       analysis = {
          --         diagnosticMode = "workspace",
          --       },
          --     },
          --   },
          -- },
        },
      })
    end,
  },
  { 'williamboman/mason.nvim' },
  { 'williamboman/mason-lspconfig.nvim' },
  { 'neovim/nvim-lspconfig' },
  {
    'hrsh7th/nvim-cmp',
    event = { 'VeryLazy' },
  },
  {
    'hrsh7th/cmp-nvim-lsp',
    event = { 'VeryLazy' },
  },
  {
    'hrsh7th/cmp-buffer',
    event = { 'VeryLazy' },
  },
  {
    'hrsh7th/cmp-path',
    event = { 'VeryLazy' },
  },
  {
    'hrsh7th/cmp-nvim-lua',
    event = { 'VeryLazy' },
  },
  {
    'L3MON4D3/LuaSnip',
    event = { 'VeryLazy' },
  },
  {
    'rafamadriz/friendly-snippets',
    event = { 'VeryLazy' },
    config = function()
      require("luasnip").config.set_config({ history = true, updateevents = "TextChanged,TextChangedI" })
      -- load the extra snippets from rafamadriz/friendly-snippets
      require('luasnip.loaders.from_vscode').lazy_load()
    end,
  },
  {
    'saadparwaiz1/cmp_luasnip',
    event = { 'VeryLazy' },
  },
  {
    'onsails/lspkind.nvim',
    event = { 'VeryLazy' },
  },
  {
    'ray-x/cmp-treesitter',
    event = { 'VeryLazy' },
  },
  {
    "ray-x/lsp_signature.nvim",
    event = { 'VeryLazy' },
    opts = {},
    config = function(_, opts)
      require 'lsp_signature'.setup(opts)
    end
  },
  {
    'kosayoda/nvim-lightbulb',
    event = { 'VeryLazy' },
    config = function()
      require('nvim-lightbulb').setup({
        autocmd = {
          enabled = true,
        },
        sign = {
          priority = 100,
        },
      })
    end,
  },
  {
    --   -- YAML support for JSON Schemas
    "someone-stole-my-name/yaml-companion.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    ft = { "yaml" },
    config = function()
      require("telescope").load_extension("yaml_schema")
      local cfg = require("yaml-companion").setup({
        builtin_matchers = {
          kubernetes = {
            enabled = true,
          },
        },
        -- disabled due to config in lsz-zero section to use 'b0o/schemastore.nvim'
        -- lspconfig = {
        --   settings = {
        --     yaml = {
        --       format = {
        --         enable = true,
        --       },
        --       hover = true,
        --       schemaDownload = {
        --         enable = true,
        --       },
        --       schemaStore = {
        --         enable = true,
        --         url = "https://www.schemastore.org/api/json/catalog.json",
        --       },
        --       schemas = {},
        --       validate = true,
        --     },
        --   },
        -- },
      })
      require("lspconfig")["yamlls"].setup(cfg)
    end,
  },
}
