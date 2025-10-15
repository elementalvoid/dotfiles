return {
  {
    -- hilight function args using treesitter
    "m-demare/hlargs.nvim",
    event = { "BufEnter" },
    config = function()
      require("hlargs").setup()
    end,
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "LazyFile", "VeryLazy" },
    lazy = vim.fn.argc(-1) == 0, -- load early when opening a file from the cmdline
  },
  {
    -- auto-close if/for/etc;
    "RRethy/nvim-treesitter-endwise",
    ft = { "rb", "lua", "vim", "sh" },
  },
}
