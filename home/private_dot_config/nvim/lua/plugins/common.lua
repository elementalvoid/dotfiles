return {
  -- consider:
  -- https://github.com/ray-x/navigator.lua
  -- https://github.com/lukas-reineke/cmp-under-comparator
  -- https://github.com/hkupty/iron.nvim -- repl
  -- https://github.com/jay-babu/mason-nvim-dap.nvim
  -- https://github.com/gbprod/cutlass.nvim
  -- https://github.com/petertriho/nvim-scrollbar
  -- https://github.com/nvim-neo-tree/neo-tree.nvim

  -- {
  --   'folke/neoconf.nvim',
  --   cmd = 'Neoconf'
  -- },
  {
    'echasnovski/mini.nvim',
    dependencies = {
      'JoosepAlviste/nvim-ts-context-commentstring',
    },
    version = false,
    config = function()
      require('mini.trailspace').setup()
      require('mini.bufremove').setup() -- used by heirline-components
      require('mini.comment').setup({
        options = {
          -- get commentstring from ts-context-commentstring
          custom_commentstring = function()
            return require('ts_context_commentstring').calculate_commentstring() or vim.bo.commentstring
          end,
        },
      })
      require('mini.indentscope').setup({
        draw = {
          animation = require('mini.indentscope').gen_animation.none()
        },
      })
      require('mini.move').setup()
      require('mini.misc').setup()
      MiniMisc.setup_auto_root()
      MiniMisc.setup_restore_cursor()
    end
  },
  {
    'folke/todo-comments.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    opts = {},
    event = 'VeryLazy',
    cmd = { 'TodoTrouble', 'TodoTelescope', 'TodoLocList', 'TodoQuickFix' },
  },
  {
    'nvim-tree/nvim-web-devicons',
    lazy = true
  },
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({
        enable_check_bracket_line = false,
        -- use treesitter
        check_ts = true,
      })

      -- If you want insert `(` after select function or method item
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      local cmp = require('cmp')
      cmp.event:on(
        'confirm_done',
        cmp_autopairs.on_confirm_done()
      )
    end
  },
  {
    'stevearc/dressing.nvim',
    event = { "VeryLazy" },
  },
  {
    'RRethy/vim-illuminate',
    event = { "VeryLazy" },
  },
  {
    "dhruvasagar/vim-table-mode",
    cmd = { "TableModeEnable", "TableModeToggle", "Tableize", "TableSort" },
  },
  -- {
  --   "sickill/vim-pasta",
  --   keys = { "P", "p" },
  -- },
  {
    'kylechui/nvim-surround',
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    keys = { '<C-g>s', '<C-g>S', 'ys', 'yss', 'yS', 'ySS', 'S', 'gS', 'ds', 'cs', 'cS', },
    opts = {},
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
  },
  {
    -- magic nvim-surround keymaps
    'roobert/surround-ui.nvim',
    keys = { '<leader>S' },
    opts = {
      root_key = "S",
    },
    dependencies = {
      'kylechui/nvim-surround',
      'folke/which-key.nvim',
    },
  },
  {
    -- smart indentation with editorconfig support
    "tpope/vim-sleuth",
    event = { "VeryLazy" },
  },
  -- {
  --   -- enable repeating supported plugin maps with '.'
  --   "tpope/vim-repeat",
  --   keys = { "." },
  -- },
  {
    -- auto-close if/for/etc;
    "RRethy/nvim-treesitter-endwise",
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
    },
    ft = { "rb", "lua", "vim", "sh" },
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require("nvim-treesitter.configs").setup({
        endwise = {
          enable = true,
        },
      })
    end,
  },
  {
    'rebelot/heirline.nvim',
    dependencies = {
      'stevearc/aerial.nvim', -- for winbar and telescope symbols
      {
        'zeioth/heirline-components.nvim',
        opts = {
          icons = {
            BufferClose = "x",
            TabClose = "x",
          },
        }
      },
    },
    opts = function()
      local lib = require "heirline-components.all"
      return {
        opts = {
          disable_winbar_cb = function(args) -- make the breadcrumbs bar inactive when...
            local is_disabled = not require("utils.buffers").is_valid(args.buf) or
                lib.condition.buffer_matches({
                  buftype = { "terminal", "prompt", "nofile", "help", "quickfix" },
                  filetype = { "NvimTree", "neo%-tree", "dashboard", "Outline", "aerial" },
                }, args.buf)
            return is_disabled
          end,
        },
        tabline = { -- UI upper bar
          lib.component.tabline_conditional_padding(),
          lib.component.tabline_buffers(),
          lib.component.fill { hl = { bg = "tabline_bg" } },
          lib.component.tabline_tabpages()
        },
        winbar = {             -- UI breadcrumbs bar
          init = function(self) self.bufnr = vim.api.nvim_get_current_buf() end,
          fallthrough = false, -- pick the correct winbar based on condition
          lib.component.winbar_when_inactive(),
          lib.component.breadcrumbs()
        },
        statuscolumn = { -- UI left column
          init = function(self) self.bufnr = vim.api.nvim_get_current_buf() end,
          lib.component.foldcolumn(),
          lib.component.fill(),
          lib.component.numbercolumn(),
          lib.component.signcolumn(),
        } or nil,
        statusline = { -- UI statusbar
          hl = { fg = "fg", bg = "bg" },
          lib.component.mode(),
          lib.component.git_branch(),
          lib.component.file_info(),
          lib.component.git_diff(),
          lib.component.diagnostics(),
          lib.component.fill(),
          lib.component.cmd_info(),
          lib.component.fill(),
          lib.component.treesitter(),
          lib.component.lsp({ lsp_progress = false }), -- noice is doing this for us, which might not be awesome
          lib.component.compiler_state(),
          lib.component.virtual_env(),
          lib.component.nav(),
          lib.component.mode { surround = { separator = "right" } },
        },
      }
    end,
    config = function(_, opts)
      local heirline = require "heirline"
      local heirline_components = require "heirline-components.all"

      -- Setup
      heirline_components.init.subscribe_to_events()
      heirline.load_colors(heirline_components.hl.get_colors())
      heirline.setup(opts)
    end,
  },
  {
    'kevinhwang91/nvim-ufo',
    dependencies = {
      'kevinhwang91/promise-async',
      'nvim-treesitter/nvim-treesitter',
    },
    event = { 'BufEnter' },
    config = function()
      require('which-key').register({
        zR = { function() require("ufo").openAllFolds() end, "Open all folds" },
        zM = { function() require("ufo").closeAllFolds() end, "Close all folds" },
        zr = { function() require("ufo").openFoldsExceptKinds() end, "Fold less" },
        zm = { function() require("ufo").closeFoldsWith() end, "Fold more" },
        zp = { function() require("ufo").peekFoldedLinesUnderCursor() end, "Peek fold" },
      })
      ---@diagnostic disable-next-line: missing-fields
      require('ufo').setup({
        ---@diagnostic disable-next-line: unused-local
        provider_selector = function(bufnr, filetype, buftype)
          return { 'treesitter', 'indent' }
        end
      })
    end,
  },
}
