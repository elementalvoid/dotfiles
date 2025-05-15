return {
  {
    "saghen/blink.compat",
    -- override optional so that emoji completion works
    -- still breaks treesitter completion ¯\_(ツ)_/¯
    optional = false,
  },
  {
    "saghen/blink.cmp",
    -- build = "cargo build --release",
    dependencies = {
      "hrsh7th/cmp-emoji",
      -- "ray-x/cmp-treesitter", -- disabled, fails with blink.compat for some reason
    },
    opts = {
      completion = {
        accept = {
          -- Write completions to the `.` register
          dot_repeat = true,
          -- Create an undo point when accepting a completion item
          create_undo_point = true,
        },
      },
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
  {
    "xzbdmw/colorful-menu.nvim",
    config = function()
      require("blink.cmp").setup({
        completion = {
          menu = {
            draw = {
              -- We don't need label_description now because label and label_description are already
              -- combined together in label by colorful-menu.nvim.
              columns = { { "kind_icon" }, { "label", gap = 1 } },
              components = {
                label = {
                  text = function(ctx)
                    return require("colorful-menu").blink_components_text(ctx)
                  end,
                  highlight = function(ctx)
                    return require("colorful-menu").blink_components_highlight(ctx)
                  end,
                },
              },
            },
          },
        },
      })
    end,
  },
}
