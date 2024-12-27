return {
  {
    "saghen/blink.cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
    opts = {
      keymap = {
        preset = "super-tab",
      },
      sources = {
        -- adding any nvim-cmp sources here will enable them
        -- with blink.compat
        compat = {"emoji"},
      },
    },
  },
}
