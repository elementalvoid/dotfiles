return {
  {
    "saghen/blink.compat",
    -- override optional so that emoji completion works
    -- still breaks treesitter completion ¯\_(ツ)_/¯
    optional = false,
  },
  {
    "saghen/blink.cmp",
    build = "cargo build --release",
    dependencies = {
      "hrsh7th/cmp-emoji",
      -- "ray-x/cmp-treesitter",
    },
    opts = {
      keymap = {
        preset = "super-tab",
      },
      sources = {
        -- adding any nvim-cmp sources here will enable them
        -- with blink.compat
        compat = {
          "emoji",
          -- "treesitter",
        },
      },
    },
  },
}
