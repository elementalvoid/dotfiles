-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- consider / use for inspiration:
-- https://github.com/m4xshen/dotfiles/blob/main/nvim/nvim/lua/config/mappings.lua
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- https://github.com/ThePrimeagen/neovimrc/blob/master/lua/theprimeagen/remap.lua

require("which-key").add({
  {
    "<leader>q",
    function()
      require("utils.buffers").smart_quit()
    end,
    desc = "quit",
  },
  { "<leader>w", "<cmd>write<cr>", desc = "+write" },
  {
    "<leader>wq",
    function()
      require("utils.buffers").smart_quit(true)
    end,
    desc = "write and quit",
  },
  { "Y", "y$", desc = "Let Y behaves like D rather than dd" },
  {
    "[b",
    function()
      vim.cmd("bprev")
    end,
    desc = "Buffer previous",
  },
  {
    "]b",
    function()

    end,
    desc = "Buffer next",
  },
  { "f", "@=(foldlevel('.')?'za':\"\\<Space>\")<CR>", desc = "Fold toggle" },

  -- here for the pretty grouping in the ui, using `keys` in plugins doesn't load early enough
  { "<leader>t", group = "Telescope" },
  { "<leader>S", desc = "Surround UI" },
})
