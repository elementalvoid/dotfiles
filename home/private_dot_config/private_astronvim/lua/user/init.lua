-- Base: https://astronvim.github.io/
-- Places to take inspiration:
--   - https://github.com/s1n7ax/dotnvim/tree/main
--   - https://github.com/ray-x/nvim
local function smart_quit(write)
  write = write or false
  if write then
    vim.cmd("write")
  end
  local bufs = vim.tbl_filter(require("astronvim.utils.buffer").is_valid, vim.api.nvim_list_bufs())
  if #bufs > 1 then
    vim.api.nvim_command("bdelete")
  else
    vim.api.nvim_command("quit")
  end
end

local config = {
  -- astronvim defaults -> ~/.config/nvim/lua/astronvim/options.lua
  options = {
    opt = {
      -- autochdir = true,
      background = "light",
      confirm = true,                                  -- confirm :q with changes
      nrformats = "octal,hex,alpha",                   -- let Ctrl-A/X work on all formats
      relativenumber = false,
      rtp = vim.opt.rtp + "~/.config/astronvim/after", -- Add custom `after` to to runtime path
      scrolloff = 4,                                   -- Number of lines to keep above and below the cursor
      secure = true,                                   -- shell and write commands are not allowed in ".nvimrc" and ".exrc" in the current directory and map commands are displayed.
      shiftround = true,                               -- < and > will hit indentation levels
      spellfile = "~/.vim/spell-en.utf-8.add",
    },
    g = {
      mapleader = ";",
      autoformat_enabled = false,
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
      -- apparently no longer needed?
      -- ["j"] = { "gj", desc = "move through wrapped lines" },
      -- ["k"] = { "gk", desc = "move through wrapped lines" },
      ["<leader>ys"] = {
        function()
          local schema = require("yaml-companion").get_buf_schema(0)
          if schema then
            require("astronvim.utils").notify(string.format("Schema: %s", schema.result[1].name))
          else
            require("astronvim.utils").notify("Schema not detected!")
          end
        end,
        desc = "Show the detected YAML Schema",
      },
      ["<leader>yS"] = { "<cmd>Telescope yaml_schema<cr>", desc = "Set YAML Schem" },
      ["<leader>pr"] = {
        function()
          require("astronvim.utils").reload(false)
          require("astronvim.utils").notify("Starting Packer Sync...")
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

  lazy = {
    performance = {
      rtp = {
        -- default disabled_plugins = { "gzip", "matchit", "matchparen", "netrwPlugin", "tarPlugin", "tohtml", "tutor", "zipPlugin", },
        disabled_plugins = { "matchit", "matchparen", "tohtml", "tutor" },
      },
    },
  },

  plugins = {
    -- disable defaults like so:
    { "Darazaki/indent-o-matic",   enabled = false },
    { "NMAC427/guess-indent.nvim", enabled = false },
    { "famiu/bufdelete.nvim",      enabled = false },
    { "goolord/alpha-nvim",        enabled = false },

    {
      -- theme
      "olimorris/onedarkpro.nvim", -- has companion config for kitty (could be converted)
      config = function()
        require("onedarkpro").setup({
          options = {
            cursorline = true,
          },
        })
      end,
    },
    -- {
    --   -- theme
    --   -- has some companion configs (tmux, iterm2, etc.)
    --   "EdenEast/nightfox.nvim"
    -- },
    {
      -- Community plugins/config
      "AstroNvim/astrocommunity",

      -- Cutlass overrides the delete operations to actually just delete and not affect the current yank.
      -- TODO: breaks in-file cut/paste
      --{ import = "astrocommunity.editing-support.cutlass-nvim" },

      { import = "astrocommunity.editing-support.nvim-ts-rainbow2" },
      { import = "astrocommunity.editing-support.todo-comments-nvim" },
      { import = "astrocommunity.syntax.hlargs-nvim" },
      { import = "astrocommunity.bars-and-lines.scope-nvim" },
    },
    {
      "ethanholz/nvim-lastplace",
      lazy = false,
      config = function()
        require("nvim-lastplace").setup()
      end,
    },
    {
      -- change, delete, add surroungings
      "tpope/vim-surround",
      keys = { "ds", "cs", "cS", "ys", "yS", "yss", "ySs", "ySS", "S", "gS" },
    },
    {
      -- enable repeating supported plugin maps with '.'
      "tpope/vim-repeat",
      keys = { "." },
    },
    {
      -- smart indentation with editorconfig support
      "tpope/vim-sleuth",
      event = { "VeryLazy" },
    },
    {
      -- auto-close if/for/etc;
      -- alternative: {"tpope/vim-endwise"},
      "RRethy/nvim-treesitter-endwise",
      dependencies = {
        { "nvim-treesitter/nvim-treesitter" },
      },
      ft = { "rb", "lua", "vim", "sh" },
      config = function()
        require("nvim-treesitter.configs").setup({
          endwise = {
            enable = true,
          },
        })
      end,
    },
    {
      -- <C-A> and <C-X> support for dates, roman numerals, ordinals (1st, 2nd, etc.), d<C-A> sets date under cusror to current date (d<C-A> for UTC)
      "tpope/vim-speeddating",
      event = { "VeryLazy" }, -- very lazy until 'keys' works
      -- keys = { "<C-X>", "<C-A>" }, -- C-X loads the plugin, C-A doesn't ?
      -- test blocks
      -- "Mon, 27 Dec 1999 00:00:03 +0000",
      -- "Sat, 01 Jan 2000 00:00:03 +0000",
    },
    {
      -- git magic
      "tpope/vim-fugitive",
      cmd = { "G", "Git" },
    },
    {
      "sickill/vim-pasta",
      keys = { "P", "p" },
    },
    {
      "scrooloose/nerdcommenter",
      cmd = {
        "NERDCommenterInsert",
        "NERDCommenterComment",
        "NERDCommenterNested",
        "NERDCommenterToggle",
        "NERDCommenterMinimal",
        "NERDCommenterInvert",
        "NERDCommenterSexy",
        "NERDCommenterYank",
        "NERDCommenterToEOL",
        "NERDCommenterAppend",
        "NERDCommenterInsert",
        "NERDCommenterAltDelims",
        "NERDCommenterAlignLeft",
        "NERDCommenterAlignBoth",
        "NERDCommenterComment",
        "NERDCommenterUncomment",
      },
    },
    {
      "ntpeters/vim-better-whitespace",
      event = { "User AstroFile" },
      cmd = { "StripWhitespace" },
      -- cond = function()
      --   return require("astronvim.utils.status").condition.buffer_matches { buftype = { "terminal" } }
      -- end
    },
    {
      "dhruvasagar/vim-table-mode",
      cmd = { "TableModeEnable", "TableModeToggle", "Tableize", "TableSort" },
    },
    {
      "editorconfig/editorconfig-vim",
    },
    {
      "nvim-treesitter/nvim-treesitter-context",
      dependencies = {
        { "nvim-treesitter/nvim-treesitter" },
      },
      event = { "User AstroFile" },
    },
    {
      "ray-x/lsp_signature.nvim",
      event = { "User AstroFile" },
      config = function()
        require("lsp_signature").setup()
      end,
    },
    -- nvim lua helpers
    -- {"tjdevries/nlua.nvim"},
    -- {"euclidianAce/BetterLua.vim"},

    {
      -- csv filetype
      "chrisbra/csv.vim",
      ft = { "csv" },
    },
    {
      -- markdown popup preview using glow
      "ellisonleao/glow.nvim",
      cmd = { "Glow" },
    },
    {
      -- golang
      "ray-x/go.nvim",
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
    {
      "tmux-plugins/vim-tmux",
      event = { "User AstroFile" },
      -- TODO: figure out conditional loading
      -- cond = function()
      --   -- local f = vim.split(vim.api.nvim_buf_get_name(0), "/")
      --   -- if f[#f] == ".tmux.conf" then
      --   --   return true
      --   -- end
      --   return vim.fn.bufname(".tmux.conf$") ~= ""
      -- end
    },
    {
      "rhysd/conflict-marker.vim",
      event = { "User AstroFile" },
    },
    {
      -- YAML support for JSON Schemas
      "someone-stole-my-name/yaml-companion.nvim",
      dependencies = {
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
    {
      -- Adds lightbulb to gutter when LSP Code Actions are available
      "kosayoda/nvim-lightbulb",
      event = { "VeryLazy" },
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

    -- astronvim plugin overrides below
    {
      "lewis6991/gitsigns.nvim",
      opts = {
        numhl = true,
      },
    },
    {
      "jose-elias-alvarez/null-ls.nvim",
      opts = function(_, config)
        -- config variable is the default configuration table for the setup function call

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
          -- b.diagnostics.editorconfig_checker,
          b.formatting.jq,            -- JSON
          b.formatting.terraform_fmt, -- Terraform
          -- b.completion.spell, -- spelling completions (conflict with cmp-spell?)
          -- b.diagnostics.proselint, -- https://github.com/amperser/proselint
          -- b.code_actions.proselint, -- https://github.com/amperser/proselint
          b.diagnostics.actionlint, -- GH Actions https://github.com/rhysd/actionlint
          -- b.diagnostics.commitlint, -- commit messages https://commitlint.js.org/
        }
        return config
      end,
    },
    {
      "williamboman/mason-lspconfig.nvim",
      opts = function(_, opts)
        -- add more things to the ensure_installed table protecting against community packs modifying it
        opts.automatic_installation = true

        -- https://github.com/williamboman/mason-lspconfig.nvim/tree/main#available-lsp-servers
        opts.ensure_installed = require("astronvim.utils").list_insert_unique(opts.ensure_installed, {
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
          "lua_ls",
          "terraformls",
          "tflint",
          "tsserver",
          "vimls",
          "yamlls",
        })
      end,
    },
    {
      "jay-babu/mason-nvim-dap.nvim",
      opts = function(_, opts)
        -- add more things to the ensure_installed table protecting against community packs modifying it
        opts.ensure_installed = require("astronvim.utils").list_insert_unique(opts.ensure_installed, {
          "go-debug-adapter",
          "js-debug-adapter",
          "python",
        })
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
        -- add more things to the ensure_installed table protecting against community packs modifying it
        opts.auto_install = true
        opts.endwise = { enable = true }
        --
        -- Tip: `:TSInstall! all` <-- requires the treesitter cli to be installed
        opts.ensure_installed = require("astronvim.utils").list_insert_unique(opts.ensure_installed, {
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
        })
      end,
    },
  },
  lsp = {
    config = {
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
  end,
}

return config
