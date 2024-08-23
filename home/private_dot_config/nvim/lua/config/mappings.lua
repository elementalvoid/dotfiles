-- consider / use for inspiration:
-- https://github.com/m4xshen/dotfiles/blob/main/nvim/nvim/lua/config/mappings.lua
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- https://github.com/ThePrimeagen/neovimrc/blob/master/lua/theprimeagen/remap.lua

local telescope_builtin = require("telescope.builtin")
require('which-key').add(
  {
    { "<esc>",      "<cmd>noh<cr>",                                               desc = "no highlight" },
    { "<leader>bl", function() require('utils.buffers').list_valid_buffers() end, desc = "list buffers" },
    { "<leader>f",  vim.lsp.buf.format,                                           desc = "LSP Format" },
    { "<leader>q",  function() require('utils.buffers').smart_quit() end,         desc = "quit" },
    { "<leader>w",  "<cmd>write<cr>",                                             desc = "+write" },
    { "<leader>wq", function() require('utils.buffers').smart_quit(true) end,     desc = "write and quit" },
    { "Y",          "y$",                                                         desc = "Let Y behaves like D rather than dd" },
    { "[b",         function() vim.cmd('bprev') end,                              desc = "Buffer previous" },
    { "]b",         function() vim.cmd('bnext') end,                              desc = "Buffer next" },
    { "f",          "@=(foldlevel('.')?'za':\"\\<Space>\")<CR>",                  desc = "Fold toggle" },

    {
      "<leader>F",
      function()
        MiniTrailspace.trim()
        MiniTrailspace.trim_last_lines()
      end,
      desc = "Strip Whitespace"
    },

    { "<leader>yS",  "<cmd>Telescope yaml_schema<cr>",                                           desc = "Set YAML Schem" },
    {
      "<leader>ys",
      function()
        local schema = require("yaml-companion").get_buf_schema(0)
        if schema then
          require("noice").notify(string.format("Schema: %s", schema.result[1].name), "info")
        else
          require("noice").notify("Schema not detected!", "info")
        end
      end,
      desc = "Show the detected YAML Schema"
    },

    { "<leader>L",   "<cmd>Lazy<cr>",                                                            desc = "Lazy" },

    { "<leader>l",   group = "LSP" },
    { "<leader>li",  "<cmd>LspInfo<cr>",                                                         desc = "LSP Client Info" },
    { "<leader>la",  function() require("actions-preview").code_actions() end,                   desc = "Action Preview",                             mode = { "n", "v", "x" } },
    { "<F4>",        function() require("actions-preview").code_actions() end,                   desc = "Action Preview",                             mode = { "n", "v", "x" } },

    { "<leader>t",   group = "Telescope" },
    { "<leader>tC",  telescope_builtin.command_history,                                          desc = "Command History" },
    { "<leader>tD",  function() require("telescope").load_extension('todo-comments').todo() end, desc = "Todo" },
    { "<leader>tF",  telescope_builtin.current_buffer_fuzzy_find,                                desc = "Fuzzy Find in Buffer" },
    { "<leader>tG",  telescope_builtin.live_grep,                                                desc = "Grep" },
    { "<leader>tL",  "<cmd>Telescope lazy_plugins<cr>",                                          desc = "Lazy Config Finder" },
    { "<leader>tT",  "<cmd>Telescope terraform_doc<cr>",                                         desc = "Terraform Docs" },
    { "<leader>tb",  telescope_builtin.buffers,                                                  desc = "Buffers" },
    { "<leader>tc",  telescope_builtin.commands,                                                 desc = "Commands" },
    { "<leader>td",  telescope_builtin.diagnostics,                                              desc = "Diagnostics" },
    { "<leader>tf",  telescope_builtin.fd,                                                       desc = "Find files" },
    { "<leader>tg",  group = "Git" },
    { "<leader>tgb", telescope_builtin.git_branches,                                             desc = "Branches" },
    { "<leader>tgc", telescope_builtin.git_commits,                                              desc = "Commits" },
    { "<leader>tgf", telescope_builtin.git_files,                                                desc = "Files" },
    { "<leader>tgs", telescope_builtin.git_status,                                               desc = "Status" },
    { "<leader>th",  telescope_builtin.help_tags,                                                desc = "Help" },
    { "<leader>tk",  telescope_builtin.keymaps,                                                  desc = "Keymaps" },
    { "<leader>tl",  "<cmd>Telescope lazy<cr>",                                                  desc = "Lazy Packages" },
    { "<leader>tn",  function() require("telescope").load_extension('noice').noice() end,        desc = "Noice" },
    { "<leader>to",  telescope_builtin.oldfiles,                                                 desc = "Find old files" },
    { "<leader>tq",  telescope_builtin.quickfix,                                                 desc = "Quickfix" },
    { "<leader>tr",  telescope_builtin.registers,                                                desc = "Registers" },
    { "<leader>ts",  function() require("telescope").load_extension("aerial").aerial() end,      desc = "LSP Symbols" },
    { "<leader>tt",  telescope_builtin.treesitter,                                               desc = "Function names, variables, from Treesitter!" },
    { "<leader>tv",  telescope_builtin.vim_options,                                              desc = "Vim Options" },

    { "<leader>u",   group = "UI" },
    { "<leader>us",  "<cmd>set spell!<cr>",                                                      desc = "Spelling" },
    { "<leader>uw",  "<cmd>set wrap!<cr>",                                                       desc = "Wrap" },

  }
)
