-- Base: https://astronvim.github.io/
-- Places to take inspiration:
--   - https://github.com/s1n7ax/dotnvim/tree/main
--   - https://github.com/ray-x/nvim
local function smart_quit(write)
  write = write or false
  if write then
    vim.cmd("write")
  end
  local bufs = vim.tbl_filter(astronvim.is_valid_buffer, vim.api.nvim_list_bufs())
  if #bufs > 1 then
    vim.api.nvim_command("bdelete")
  else
    vim.api.nvim_command("quit")
  end
end

local config = {
  -- astronvim defaults -> ~/.config/nvim/lua/core/options.lua
  options = {
    opt = {
      -- autochdir = true,
      background = "light",
      confirm = true,                               -- confirm :q with changes
      nrformats = "octal,hex,alpha",                -- let Ctrl-A/X work on all formats
      relativenumber = false,
      rtp = vim.opt.rtp + "~/.config/astronvim/after", -- Add custom `after` to to runtime path
      scrolloff = 4,                                -- Number of lines to keep above and below the cursor
      secure = true,                                -- shell and write commands are not allowed in ".nvimrc" and ".exrc" in the current directory and map commands are displayed.
      shiftround = true,                            -- < and > will hit indentation levels
      spellfile = "~/.vim/spell-en.utf-8.add",
    },
    g = {
      mapleader = ";",
      autoformat_enabled = false,
      -- how to get zip working in astronvim?
      -- the following are inversed from astro's
      -- zipPlugin = true,
      -- loaded_gzip = false,
      -- loaded_tar = false,
      -- loaded_tarPlugin = false,
      -- loaded_zip = false,
      -- loaded_zipPlugin = false,
    },
  },
  mappings = {
    n = {
      ["<Space>"] = { "@=(foldlevel('.')?'za':\"\\<Space>\")<CR>", desc = "Fold toggle" },
      ["Y"] = { "y$", desc = "Let Y behave analogously to D rather than to dd" },
      ["<esc>"] = { "<cmd>noh<cr>", desc = "no highlight" },
      ["<leader>T"] = { "<cmd>Telescope<cr>", desc = "Open Telescope" },
      ["<leader>F"] = { "<cmd>StripWhitespace<cr>", desc = "Strip Whitespace" },
      ["<leader>q"] = {
        function()
          smart_quit()
        end,
        desc = "SmartQuit",
      },
      ["<leader>wq"] = {
        function()
          smart_quit(true)
        end,
        desc = "Write and SmartQuit",
      },
      ["j"] = { "gj", desc = "move through wrapped lines" },
      ["k"] = { "gk", desc = "move through wrapped lines" },
      ["<leader>ys"] = {
        function()
          local schema = require("yaml-companion").get_buf_schema(0)
          if schema then
            astronvim.notify(string.format("Schema: %s", schema.result[1].name))
          else
            astronvim.notify("Schema not detected!")
          end
        end,
        desc = "Show the detected YAML Schema",
      },
      ["<leader>yS"] = { "<cmd>Telescope yaml_schema<cr>", desc = "Set YAML Schem" },
      ["<leader>pr"] = {
        function()
          astronvim.updater.reload(false)
          astronvim.notify("Starting Packer Sync...")
          vim.api.nvim_command("PackerSync")
        end,
        desc = "Reload and sync Packer",
      },
    },
    v = {
      ["<Space>"] = { "zf", desc = "Visual fold" },
    },
    i = {},
  },
  colorscheme = "onelight",
  --colorscheme = "dayfox",

  plugins = {
    init = {
      -- disable defaults like so:
      ["Darazaki/indent-o-matic"] = { disable = true },
      ["famiu/bufdelete.nvim"] = { disable = true },
      -- theme
      ["olimorris/onedarkpro.nvim"] = { -- has companion config for kitty (could be converted)
        config = function()
          require("onedarkpro").setup({
            options = {
              cursorline = true,
            },
          })
        end,
      },
      --["EdenEast/nightfox.nvim"] = {}, -- has some companion configs (tmux, iterm2, etc.)

      ["ethanholz/nvim-lastplace"] = {
        config = function()
          require("nvim-lastplace").setup()
        end,
      },
      -- change, delete, add surroungings
      ["tpope/vim-surround"] = {
        keys = { "ds", "cs", "cS", "ys", "yS", "yss", "ySs", "ySS", "S", "gS" },
      },
      -- enable repeating supported plugin maps with '.'
      ["tpope/vim-repeat"] = {
        keys = { "." },
      },
      -- smart indentation with editorconfig support
      ["tpope/vim-sleuth"] = {},
      -- auto-close if/for/etc.
      --["tpope/vim-endwise"] = {},
      ["RRethy/nvim-treesitter-endwise"] = {},
      -- <C-A> and <C-X> support for dates, roman numerals, ordinals (1st, 2nd, etc.), d<C-A> sets date under cusror to current date (d<C-A> for UTC)
      ["tpope/vim-speeddating"] = {
        -- keys = { "<C-X>", "<C-A>" }, -- C-X loads the plugin, C-A doesn't ?
        -- test blocks
        -- "Mon, 27 Dec 1999 00:00:03 +0000",
        -- "Sat, 01 Jan 2000 00:00:03 +0000",
      },
      -- git magic
      ["tpope/vim-fugitive"] = {
        cmd = { "G", "Git" },
      },
      ["sickill/vim-pasta"] = {
        keys = { "P", "p" },
      },
      ["scrooloose/nerdcommenter"] = {},
      ["ntpeters/vim-better-whitespace"] = {},
      ["dhruvasagar/vim-table-mode"] = {
        cmd = { "TableModeEnable", "TableModeToggle", "Tableize", "TableSort" },
      },
      ["editorconfig/editorconfig-vim"] = {},
      ["nvim-treesitter/nvim-treesitter-context"] = {},
      ["ray-x/lsp_signature.nvim"] = {
        config = function()
          require("lsp_signature").setup()
        end,
      },
      -- nvim lua helpers
      -- ["tjdevries/nlua.nvim"] = {},
      -- ["euclidianAce/BetterLua.vim"] = {},
      ["folke/neodev.nvim"] = {
        ft = { "lua" },
      },
      -- csv filetype
      ["chrisbra/csv.vim"] = {
        ft = { "csv" },
      },
      -- markdown popup preview using glow
      ["ellisonleao/glow.nvim"] = {
        cmd = { "Glow" },
      },
      -- golang
      ["ray-x/go.nvim"] = {
        ft = { "go" },
        config = function()
          require("go").setup()
          vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*.go",
            callback = function()
              require("go.format").goimport()
            end,
            --group = format_sync_grp,
          })
        end,
      },
      ["tmux-plugins/vim-tmux"] = {
        -- TODO: figure out conditional loading
        -- cond = function()
        --   -- local f = vim.split(vim.api.nvim_buf_get_name(0), "/")
        --   -- if f[#f] == ".tmux.conf" then
        --   --   return true
        --   -- end
        --   return vim.fn.bufname(".tmux.conf$") ~= ""
        -- end
      },
      ["rhysd/conflict-marker.vim"] = {},
      ["someone-stole-my-name/yaml-companion.nvim"] = {
        requires = {
          { "neovim/nvim-lspconfig" },
          { "nvim-lua/plenary.nvim" },
          { "nvim-telescope/telescope.nvim" },
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
            lspconfig = {
              settings = {
                yaml = {
                  format = {
                    enable = true,
                  },
                  hover = true,
                  schemaDownload = {
                    enable = true,
                  },
                  schemaStore = {
                    enable = true,
                    url = "https://www.schemastore.org/api/json/catalog.json",
                  },
                  schemas = {},
                  validate = true,
                },
              },
            },
          })
          require("lspconfig")["yamlls"].setup(cfg)
        end,
      },
      ["kosayoda/nvim-lightbulb"] = {
        config = function()
          require("nvim-lightbulb").setup({
            autocmd = {
              enabled = true,
            },
            sign = {
              priority = 100,
            },
          })
        end,
      },
      -- consider:
      -- https://github.com/ray-x/cmp-treesitter
      -- https://github.com/ray-x/sad.nvim
      -- https://github.com/ray-x/navigator.lua
      -- https://github.com/lukas-reineke/cmp-under-comparator
      -- https://github.com/hkupty/iron.nvim -- repl
    },
    -- astronvim plugin overrides below
    gitsigns = {
      numhl = true,
    },
    ["null-ls"] = function(config)
      local b = require("null-ls").builtins
      config.sources = {
        -- Lua
        b.formatting.stylua,
        -- b.diagnostics.luacheck.with({ extra_args = { "--global vim" } }), -- depends on luarocks

        b.formatting.shfmt,
        b.diagnostics.shellcheck.with({ diagnostics_format = "#{m} [#{c}]" }),
        b.code_actions.shellcheck,

        -- Python
        -- b.diagnostics.pylint, -- doesn't autodetect rcfile (due to `--from-stdin` flag?). Flake8 better?
        b.formatting.black,
        -- b.code_actions.refactoring, -- multiple languages .. https://github.com/ThePrimeagen/refactoring.nvim

        -- Misc.
        b.diagnostics.editorconfig_checker,
        b.formatting.jq,        -- JSON
        b.formatting.terraform_fmt, -- Terraform
        -- b.completion.spell, -- spelling completions (conflict with cmp-spell?)
        -- b.diagnostics.proselint, -- https://github.com/amperser/proselint
        -- b.code_actions.proselint, -- https://github.com/amperser/proselint
        b.diagnostics.actionlint, -- GH Actions https://github.com/rhysd/actionlint
        -- b.diagnostics.commitlint, -- commit messages https://commitlint.js.org/
      }
      return config
    end,
    ["mason-lspconfig"] = {
      -- https://github.com/williamboman/mason-lspconfig.nvim/tree/main#available-lsp-servers
      automatic_installation = true,
      ensure_installed = {
        "bashls",
        "dockerls",
        "eslint",
        -- "golangci_lint_ls",
        "gopls",
        "graphql",
        "groovyls",
        "jsonls",
        "kotlin_language_server",
        "marksman",
        -- "pyright",
        "pylsp",
        "sumneko_lua",
        "terraformls",
        "tflint",
        "tsserver",
        "vimls",
        "yamlls",
      },
    },
    ["mason-nvim-dap"] = {
      ensure_installed = {
        "go-debug-adapter",
        "js-debug-adapter",
        "python",
      },
    },
    treesitter = {
      -- Tip: `:TSInstall! all` <-- requires the treesitter cli to be installed
      auto_install = true,
      endwise = { enable = true },
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
      },
    },
  },
  lsp = {
    ["server-settings"] = {
      yamlls = {
        settings = {
          yaml = {
            schemas = {
              -- ["../../../../../schema.json"] = "clusters/*/*/*/*/config.yaml",
            },
          },
        },
      },
      pyright = {
        settings = {
          pyright = {
            analysis = {
              diagnosticMode = "workspace",
            },
          },
        },
      },
      pylsp = {
        -- https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
        -- https://github.com/python-lsp/python-lsp-server#3rd-party-plugins
        settings = {
          pylsp = {
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
              -- -- https://github.com/python-lsp/python-lsp-black
              -- black = {
              --   -- ? Does this work with or conflict with null-ls?
              --   enabled = true,
              -- },
              -- -- https://github.com/python-lsp/pylsp-mypy
              -- ["pyslsp-mypy"] = {
              --   enabled = true,
              -- }
            },
          },
        },
      },
    },
  },
  -- This function is run last and is a good place to configuring
  -- augroups/autocommands and custom filetypes also this just pure lua so
  -- anything that doesn't fit in the normal config locations above can go here
  polish = function()
    -- restore old hlsearch configuration (see: https://github.com/AstroNvim/AstroNvim/discussions/1428)
    vim.on_key(nil, vim.api.nvim_get_namespaces()["auto_hlsearch"])

    -- auto-reload init config
    -- vim.api.nvim_create_augroup("packer_conf", { clear = true })
    -- vim.api.nvim_create_autocmd("BufWritePost", {
    --   desc = "Sync packer after modifying init.lua",
    --   group = "packer_conf",
    --   pattern = "init.lua",
    --   command = "source <afile> | PackerSync",
    -- })
  end,
}

return config
