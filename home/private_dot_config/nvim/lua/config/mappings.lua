-- consider / use for inspiration:
-- https://github.com/m4xshen/dotfiles/blob/main/nvim/nvim/lua/config/mappings.lua
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- https://github.com/ThePrimeagen/neovimrc/blob/master/lua/theprimeagen/remap.lua

local telescope_builtin = require("telescope.builtin")
require('which-key').register({
  ["<leader>"] = {
    w = { '<cmd>write<cr>', '+write' },
    q = { function() require('utils.buffers').smart_quit() end, 'quit' },
    wq = { function() require('utils.buffers').smart_quit(true) end, 'write and quit' },
    bl = { function() require('utils.buffers').list_valid_buffers() end, 'list buffers' },
    L = { '<cmd>Lazy<cr>', 'Lazy' },
    f = { vim.lsp.buf.format, "LSP Format" },
    F = {
      function()
        MiniTrailspace.trim()
        MiniTrailspace.trim_last_lines()
      end,
      "Strip Whitespace"
    },
    ys = {
      function()
        local schema = require("yaml-companion").get_buf_schema(0)
        if schema then
          require("noice").notify(string.format("Schema: %s", schema.result[1].name), "info")
        else
          require("noice").notify("Schema not detected!", "info")
        end
      end,
      "Show the detected YAML Schema",
    },
    yS = { "<cmd>Telescope yaml_schema<cr>", "Set YAML Schem" },

    u = {
      name = "UI",

      w = { '<cmd>set wrap!<cr>', 'Wrap'},
      s = { '<cmd>set spell!<cr>', 'Spelling'},
    },

    t = {
      name = "Telescope",
      -- see all buildtings

      f = { telescope_builtin.fd, "Find files" },
      o = { telescope_builtin.oldfiles, "Find old files" },
      G = { telescope_builtin.live_grep, "Grep" },
      b = { telescope_builtin.buffers, "Buffers" },
      h = { telescope_builtin.help_tags, "Help" },
      c = { telescope_builtin.commands, "Commands" },
      C = { telescope_builtin.command_history, "Command History" },
      k = { telescope_builtin.keymaps, "Keymaps" },
      q = { telescope_builtin.quickfix, "Quickfix" },
      d = { telescope_builtin.diagnostics, "Diagnostics" },
      r = { telescope_builtin.registers, "Registers" },
      v = { telescope_builtin.vim_options, "Vim Options" },
      F = { telescope_builtin.current_buffer_fuzzy_find, "Fuzzy Find in Buffer" },
      s = { function() require("telescope").load_extension("aerial").aerial() end, "LSP Symbols" },
      t = { telescope_builtin.treesitter, "Function names, variables, from Treesitter!" },
      T = { "<cmd>Telescope terraform_doc<cr>", "Terraform Docs" },
      l = { "<cmd>Telescope lazy<cr>", "Lazy Packages" },
      L = { "<cmd>Telescope lazy_plugins<cr>", "Lazy Config Finder" },
      n = { function() require("telescope").load_extension('noice').noice() end, "Noice" },
      D = { function() require("telescope").load_extension('todo-comments').todo() end, "Todo" },

      --- Git Telescope
      g = {
        name = "Git",
        f = { telescope_builtin.git_files, "Files" },
        b = { telescope_builtin.git_branches, "Branches" },
        s = { telescope_builtin.git_status, "Status" },
        c = { telescope_builtin.git_commits, "Commits" },
      },
    },

    l = {
      name = "LSP",
      a = { function() require("actions-preview").code_actions() end, "Action Preview", mode = { 'v', 'n', 'x' } },
      i = { "<cmd>LspInfo<cr>", "LSP Client Info" },
    },
  }, -- end '<leader>'
  -- overwrite F4 from lsp
  ['<F4>'] = { function() require("actions-preview").code_actions() end, "Action Preview", mode = { 'v', 'n', 'x' } },
  ['<esc>'] = { '<cmd>noh<cr>', 'no highlight' },
  ['Y'] = { 'y$', 'Let Y behaves like D rather than dd' },
  ['[b'] = { function () vim.cmd('bprev') end, 'Buffer previous'},
  [']b'] = { function () vim.cmd('bnext') end, 'Buffer next'},
  ['f'] = { "@=(foldlevel('.')?'za':\"\\<Space>\")<CR>", 'Fold toggle' },
})
