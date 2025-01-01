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
    event = "VeryLazy",
    main = "rainbow-delimiters.setup",
  },
  {
    -- auto-close if/for/etc;
    "RRethy/nvim-treesitter-endwise",
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
}
