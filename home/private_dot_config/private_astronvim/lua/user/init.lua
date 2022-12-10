-- Base: https://astronvim.github.io/
-- Places to take inspiration:
-- https://github.com/s1n7ax/dotnvim/tree/main
-- https://github.com/ray-x/nvim

local function smart_quit(write)
  write = write or false
  if write then
    vim.cmd('write')
  end
  local bufs = vim.split(vim.api.nvim_exec("ls", true), "\n")
  if #bufs > 1 then
    vim.api.nvim_command('bdelete')
  else
    vim.api.nvim_command('quit')
  end
end

local config = {
  -- astronvim defaults -> ~/.config/nvim/lua/core/options.lua
  options = {
    opt = {
      background = "light",
      confirm = true, -- confirm :q with changes
      nrformats = "octal,hex,alpha", -- let Ctrl-A/X work on all formats
      relativenumber = false,
      rtp = vim.opt.rtp + "~/.config/astronvim/after", -- Add custom `after` to to runtime path
      scrolloff = 4, -- Number of lines to keep above and below the cursor
      secure = true, -- shell and write commands are not allowed in ".nvimrc" and ".exrc" in the current directory and map commands are displayed.
      shiftround = true, -- < and > will hit indentation levels
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
    }
  },

  mappings = {
    n = {
      ["<Space>"] = { "@=(foldlevel('.')?'za':\"\\<Space>\")<CR>", desc = "Fold toggle" },
      ["Y"] = { "y$", desc = "Let Y behave analogously to D rather than to dd" },
      ["<esc>"] = { "<cmd>noh<cr>", desc = "no highlight" },
      ["<leader>T"] = { "<cmd>Telescope<cr>", desc = "Open Telescope" },
      ["<leader>F"] = { "<cmd>StripWhitespace<cr>", desc = "Strip Whitespace" },
      ["<leader>q"] = { function() smart_quit() end, desc = "SmartQuit" },
      ["<leader>wq"] = { function() smart_quit(true) end, desc = "Write and SmartQuit" },
    },
    v = {
      ["<Space>"] = { "zf", desc = "Visual fold" },
    },
    i = {
      ["<leader>F"] = { "<esc><cmd>StripWhitespace<cr>a", desc = "Strip Whitespace" },
    },
  },

  colorscheme = "onedarkpro",
  --colorscheme = "dayfox",

  plugins = {
    -- additional plugins
    init = {
      -- theme
      ["olimorris/onedarkpro.nvim"] = { -- has companion config for kitty (could be converted)
        -- following commit breaks things -- https://github.com/olimorris/onedarkpro.nvim/issues/131
        --commit = "55a5af203541ddf29993758e4b7d4d95cbba72ad", -- enhanced caching
        commit = "6f13896727c82c1ff56acf483d474ba7ad88f230",
      },
      --["EdenEast/nightfox.nvim"] = {}, -- has some companion configs (tmux, iterm2, etc.)

      ["ethanholz/nvim-lastplace"] = {
        config = function()
          require('nvim-lastplace').setup()
        end
      },

      -- change, delete, add surroungings
      ["tpope/vim-surround"] = {},

      -- enable repeating supported plugin maps with '.'
      ["tpope/vim-repeat"] = {},

      -- auto-close if/for/etc.
      --["tpope/vim-endwise"] = {},
      ["RRethy/nvim-treesitter-endwise"] = {},

      -- <C-A> and <C-X> support for dates, roman numerals, ordinals (1st, 2nd, etc.), d<C-A> sets date under cusror to current date (d<C-A> for UTC)
      ["tpope/vim-speeddating"] = {},

      -- git magic
      ["tpope/vim-fugitive"] = {
        cmd = { "G", "Git" },
      },

      ["sickill/vim-pasta"] = {},

      ["scrooloose/nerdcommenter"] = {},

      ["ntpeters/vim-better-whitespace"] = {},

      ["dhruvasagar/vim-table-mode"] = {
        -- cmd = {"TableModeEnable", "TableModeToggle", "Tableize", "TableSort"},
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
      ["folke/neodev.nvim"] = {},

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
        -- TODO: lazy load
        config = function()
          require('go').setup()
          vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*.go",
            callback = function()
              require('go.format').goimport()
            end,
            --group = format_sync_grp,
          })
        end,
      },

      ["tmux-plugins/vim-tmux"] = {},

      ["rhysd/conflict-marker.vim"] = {},

      -- consider:
      -- https://github.com/ray-x/cmp-treesitter
      -- https://github.com/ray-x/sad.nvim
      -- https://github.com/ray-x/navigator.lua
      -- https://github.com/lukas-reineke/cmp-under-comparator
      -- https://github.com/someone-stole-my-name/yaml-companion.nvim
      -- kosayoda/nvim-lightbulb
      -- some sort of DAP (debug adapter)
      -- https://github.com/hkupty/iron.nvim -- repl
    },
    -- disable defaults like so:
    -- ["goolord/alpha-nvim"] = { disable = true },
    ["famiu/bufdelete.nvim"] = { disable = true },

    -- overrides below
    gitsigns = {
      numhl = true,
    },

    ["null-ls"] = function(config)
      local b = require("null-ls").builtins
      config.sources = {
        b.formatting.shfmt,
        b.diagnostics.shellcheck.with({ diagnostics_format = "#{m} [#{c}]" }),
        b.code_actions.shellcheck,

        -- Python
        b.diagnostics.pylint, -- doesn't autodetect rcfile (due to `--from-stdin` flag?). Flake8 better?
        b.formatting.black,
        b.formatting.isort,
        -- b.code_actions.refactoring, -- multiple languages .. https://github.com/ThePrimeagen/refactoring.nvim

        -- Misc.
        b.diagnostics.editorconfig_checker,
        b.formatting.jq, -- JSON
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
      ensure_installed = {
        "bashls",
        "dockerls",
        "eslint",
        -- "golangci_lint_ls",
        -- "gopls",
        "graphql",
        "groovyls",
        "jsonls",
        "kotlin_language_server",
        "marksman",
        "pyright",
        -- "pyslp", -- see extra config: https://github.com/williamboman/mason-lspconfig.nvim/blob/main/lua/mason-lspconfig/server_configurations/pylsp/README.md
        "sumneko_lua",
        "terraformls",
        "tflint",
        "tsserver",
        "vimls",
        "yamlls",
      }
    },

    ["mason-nvim-dap"] = {
      ensure_installed = {
        "go-debug-adapter",
        "js-debug-adapter",
        "python"
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
        "yaml"
      }
    }
  }
}

return config
