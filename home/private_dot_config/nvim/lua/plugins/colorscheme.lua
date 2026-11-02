-- Nord on the catppuccin engine, with catppuccin's syntax roles.
-- Same palette and contrast rules as ~/.config/kitty and ~/.wezterm.lua:
-- text colors are 4.5:1 or better on base. Each catppuccin key keeps its hue
-- (red is red, yellow is yellow), so diagnostics, git signs and integrations
-- keep their meaning. Nord has no maroon, flamingo, pink or lavender: those
-- are Nord-adjacent hues, so parameters, fields and escapes stay distinct.
return {
  {
    "LazyVim/LazyVim",
    dependencies = {
      "catppuccin/nvim",
    },
    opts = {
      colorscheme = "catppuccin-nvim",
    },
  },
  {
    "catppuccin/nvim",
    opts = {
      flavour = "auto", -- follows vim.o.background
      background = {
        light = "latte",
        dark = "mocha",
      },
      color_overrides = {
        mocha = {
          rosewater = "#D8DEE9", -- cursor: nord4, same as kitty
          flamingo = "#C98A98", -- Identifier, Todo
          pink = "#C09ABE", -- escapes, Special, headings
          mauve = "#B691AF", -- nord15, lightened from 4.4:1: keywords
          red = "#E0848C", -- nord11, lightened from 3.1:1: errors
          maroon = "#CA8A94", -- parameters
          peach = "#D18A73", -- nord12, lightened from 4.4:1: numbers, constants
          yellow = "#EBCB8B", -- nord13: types, warnings
          green = "#A3BE8C", -- nord14: strings
          teal = "#8FBCBB", -- nord7: hints
          sky = "#88C0D0", -- nord8: operators, Search, info
          sapphire = "#839EBF", -- nord10, lightened from 3.1:1: labels
          blue = "#81A1C1", -- nord9: functions, directories
          lavender = "#9AACCC", -- fields, CursorLineNr
          text = "#D8DEE9", -- nord4: same as the kitty foreground
          subtext1 = "#C5CCD9",
          subtext0 = "#B1B9C9",
          overlay2 = "#929CB1", -- 4.5:1: comments, Pmenu text
          overlay1 = "#8490A7", -- 3.9:1: same as kitty color 8
          overlay0 = "#76839D", -- 3.3:1: NonText, line numbers
          surface2 = "#4C566A", -- nord3
          surface1 = "#434C5E", -- nord2: Visual, same as the kitty selection
          surface0 = "#3B4252", -- nord1
          base = "#2E3440", -- nord0
          mantle = "#292E39",
          crust = "#242933",
        },
        latte = {
          -- Accents are the dark ones, darkened on the same hue to 4.5:1 on nord6.
          rosewater = "#2E3440",
          flamingo = "#AA4F64",
          pink = "#905A8D",
          mauve = "#8C5D83",
          red = "#B54954",
          maroon = "#AD4E5E",
          peach = "#AA5338",
          yellow = "#8D6618",
          green = "#597442",
          teal = "#457473",
          sky = "#357587",
          sapphire = "#4E6F97",
          blue = "#496F95",
          lavender = "#516DA0",
          text = "#2E3440", -- nord0
          subtext1 = "#3B4252",
          subtext0 = "#4C566A",
          overlay2 = "#5E6A80", -- 4.7:1: comments, Pmenu text
          overlay1 = "#687591", -- 4.0:1: same as kitty color 8
          overlay0 = "#76839D", -- 3.3:1
          surface2 = "#B1BDD3",
          surface1 = "#BEC8DA", -- Visual
          surface0 = "#C8D0E0",
          base = "#ECEFF4", -- nord6
          mantle = "#E5E9F0", -- nord5
          crust = "#D8DEE9", -- nord4
        },
      },
      custom_highlights = function(c)
        return {
          LineNr = { fg = c.overlay0 }, -- default surface1 is 1.4:1
          StatusLineNC = { fg = c.overlay1 }, -- default surface1 is 1.6:1 on mantle
          LspInlayHint = { fg = c.overlay1 }, -- default overlay0 is 2.9:1 on its tinted background
        }
      end,
    },
  },
}
