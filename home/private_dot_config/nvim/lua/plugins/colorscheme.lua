--[[
================================================================================
 NORD PALETTE REFERENCE
================================================================================

 Polar Night (dark backgrounds)
   nord0  #2e3440  darkest background
   nord1  #3b4252  elevated UI bg
   nord2  #434c5e  active line / selection
   nord3  #4c566a  comments, guides

 Snow Storm (light text)
   nord4  #d8dee9  variables, fields (text)
   nord5  #e5e9f0  subtle text
   nord6  #eceff4  brightest text

 Frost (blues / cyans)
   nord7  #8fbcbb  classes, types (teal-ish)
   nord8  #88c0d0  functions, primary accent (cyan)
   nord9  #81a1c1  keywords, operators (steel blue)
   nord10 #5e81ac  pragmas, deep blue

 Aurora (accent colors)
   nord11 #bf616a  errors, red
   nord12 #d08770  annotations, orange
   nord13 #ebcb8b  warnings, yellow
   nord14 #a3be8c  strings, green
   nord15 #b48ead  numbers, purple

================================================================================
 NORD DARK  →  Catppuccin Mocha
================================================================================

 Catppuccin role  │ Purpose               │ Nord color
 ─────────────────┼───────────────────────┼──────────────────────────────────
 base             │ main background       │ nord0   #2e3440
 mantle           │ slightly deeper bg    │ interp  #283040  (below nord0)
 crust            │ deepest bg            │ interp  #222730  (below nord0)
 ─────────────────┼───────────────────────┼──────────────────────────────────
 surface0         │ raised surface        │ nord1   #3b4252
 surface1         │ more raised           │ nord2   #434c5e
 surface2         │ highest surface       │ nord3   #4c566a
 ─────────────────┼───────────────────────┼──────────────────────────────────
 overlay0         │ subtle overlays       │ interp  #677690  (nord3 → nord4)
 overlay1         │ mid overlay           │ interp  #7b8799
 overlay2         │ strong overlay        │ interp  #8a96a8
 ─────────────────┼───────────────────────┼──────────────────────────────────
 subtext0         │ muted text            │ nord4   #d8dee9
 subtext1         │ secondary text        │ nord5   #e5e9f0
 text             │ primary text          │ nord6   #eceff4
 ─────────────────┼───────────────────────┼──────────────────────────────────
 teal             │ teal                  │ nord7   #8fbcbb
 sky              │ bright blue/cyan      │ nord8   #88c0d0
 blue             │ blue accent           │ nord9   #81a1c1
 sapphire         │ deeper blue           │ nord10  #5e81ac
 lavender         │ lavender              │ interp  #9aaccc  (blue-lav blend)
 ─────────────────┼───────────────────────┼──────────────────────────────────
 red              │ errors                │ nord11  #bf616a
 peach            │ orange                │ nord12  #d08770
 yellow           │ warnings              │ nord13  #ebcb8b
 green            │ strings               │ nord14  #a3be8c
 mauve            │ purple                │ nord15  #b48ead
 maroon           │ darker red            │ interp  #b05060  (darkened red)
 pink             │ pink                  │ interp  #c09abe  (lightened mauve)
 flamingo         │ soft pink-red         │ interp  #c07888
 rosewater        │ lightest accent       │ interp  #d4a0a8

 Notes:
 · mantle/crust extrapolated below nord0 — no official Nord colors exist there;
   step size matches the spacing between nord0–nord3.
 · overlay0/1/2 interpolated across the large nord3→nord4 gap to preserve
   Catppuccin's layering semantics.
 · lavender, maroon, flamingo, pink, rosewater have no Nord equivalents;
   derived by shifting nearby hues to fill the roles without clashing.

================================================================================
 NORD LIGHT  →  Catppuccin Latte
================================================================================

 Snow Storm becomes backgrounds; Polar Night becomes text.
 Aurora colors are darkened/saturated for readability on the light bg.

 Source YAML (Gogh "Nord Light"):
   background  #EBEAF2  light lavender-white
   foreground  #004F7C  deep navy
   color_02    #E64569  red
   color_03    #069F5F  green
   color_04    #DAB752  yellow (original; see note)
   color_05    #439ECF  blue
   color_06    #D961DC  magenta
   color_07    #00B1BE  cyan
   color_09    #3E89A1  bright black
   color_10    #E4859A  bright red
   color_13    #6FBBE2  bright blue
   color_14    #E586E7  bright magenta
   color_15    #96DCDA  bright cyan
   color_16    #DEDEDE  bright white

 Catppuccin role  │ Purpose               │ Color     │ Source
 ─────────────────┼───────────────────────┼───────────┼──────────────────────
 base             │ main background       │ #EBEAF2   │ background
 mantle           │ slightly deeper bg    │ #E0DFE8   │ darkened base
 crust            │ deepest bg            │ #D5D4DE   │ further darkened
 ─────────────────┼───────────────────────┼───────────┼──────────────────────
 surface0         │ raised surface        │ #DEDEDE   │ color_16 bright white
 surface1         │ more raised           │ #D0CFD9   │ interpolated
 surface2         │ highest surface       │ #B3B3B3   │ color_08 white
 ─────────────────┼───────────────────────┼───────────┼──────────────────────
 overlay0         │ subtle overlay        │ #7A8FA0   │ interpolated
 overlay1         │ mid overlay           │ #5B7A90   │ interpolated
 overlay2         │ strong overlay        │ #3E89A1   │ color_09 bright black
 ─────────────────┼───────────────────────┼───────────┼──────────────────────
 subtext0         │ muted text            │ #2A6A8F   │ lightened fg
 subtext1         │ secondary text        │ #1A5878   │ mid fg
 text             │ primary text          │ #004F7C   │ foreground
 ─────────────────┼───────────────────────┼───────────┼──────────────────────
 teal             │ teal                  │ #96DCDA   │ color_15 bright cyan
 sky              │ bright cyan           │ #00B1BE   │ color_07 cyan
 blue             │ blue                  │ #439ECF   │ color_05
 sapphire         │ deeper blue           │ #2D7FAA   │ darkened blue
 lavender         │ lavender              │ #6FBBE2   │ color_13 bright blue
 ─────────────────┼───────────────────────┼───────────┼──────────────────────
 red              │ errors                │ #E64569   │ color_02
 peach            │ orange                │ #C4813A   │ derived warm
 yellow           │ warnings              │ #A68B00   │ color_04 darkened *
 green            │ strings               │ #069F5F   │ color_03
 mauve            │ purple/magenta        │ #D961DC   │ color_06
 maroon           │ darker red            │ #C93050   │ darkened red
 pink             │ pink                  │ #E586E7   │ color_14 bright magenta
 flamingo         │ soft pink             │ #E4859A   │ color_10 bright red
 rosewater        │ lightest accent       │ #EAA0B0   │ lightened flamingo

 Notes:
 · yellow changed from #DAB752 → #A68B00 (dark goldenrod) for contrast;
   original color_04 gives only ~2.8:1 on the light bg, below WCAG AA (4.5:1).
 · peach has no YAML analog — derived as warm orange between yellow and red,
   darkened for light-bg contrast.
 · teal uses bright cyan (#96DCDA) not #00B1BE, which is more saturated and
   better reserved for sky's primary-accent role.
 · rosewater extrapolated lighter than flamingo to maintain accent gradient.

--]]

return {
  {
    "LazyVim/LazyVim",
    dependencies = {
      "catppuccin/nvim",
    },
    opts = {
      colorscheme = "catppuccin",
    },
  },
  {
    "catppuccin/nvim",
    opts = {
      flavour = "auto",
      background = {
        light = "latte",
        dark = "mocha",
      },
      color_overrides = {
        mocha = {
          -- Polar Night (backgrounds)
          base = "#2e3440",
          mantle = "#283040",
          crust = "#222730",
          -- Polar Night (surfaces / UI chrome)
          surface0 = "#3b4252",
          surface1 = "#434c5e",
          surface2 = "#4c566a",
          -- Overlays (between surfaces and text)
          overlay0 = "#677690",
          overlay1 = "#7b8799",
          overlay2 = "#8a96a8",
          -- Snow Storm (text)
          subtext0 = "#d8dee9",
          subtext1 = "#e5e9f0",
          text = "#eceff4",
          -- Frost (blues / cyans)
          sapphire = "#5e81ac",
          blue = "#81a1c1",
          lavender = "#9aaccc",
          sky = "#88c0d0",
          teal = "#8fbcbb",
          -- Aurora (accent colors)
          green = "#a3be8c",
          yellow = "#ebcb8b",
          peach = "#d08770",
          red = "#bf616a",
          maroon = "#b05060",
          mauve = "#b48ead",
          pink = "#c09abe",
          flamingo = "#c07888",
          rosewater = "#d4a0a8",
        },
        latte = {
          -- Backgrounds (Snow Storm inverted for light ambiance)
          base = "#EBEAF2",
          mantle = "#E0DFE8",
          crust = "#D5D4DE",
          -- Surfaces
          surface0 = "#DEDEDE",
          surface1 = "#D0CFD9",
          surface2 = "#B3B3B3",
          -- Overlays
          overlay0 = "#7A8FA0",
          overlay1 = "#5B7A90",
          overlay2 = "#3E89A1",
          -- Text (Polar Night used as text on light bg)
          subtext0 = "#2A6A8F",
          subtext1 = "#1A5878",
          text = "#004F7C",
          -- Frost
          lavender = "#6FBBE2",
          blue = "#439ECF",
          sapphire = "#2D7FAA",
          sky = "#00B1BE",
          teal = "#96DCDA",
          -- Aurora
          green = "#069F5F",
          yellow = "#A68B00", -- dark goldenrod, changed from #DAB752 for better contrast
          peach = "#C4813A",
          red = "#E64569",
          maroon = "#C93050",
          mauve = "#D961DC",
          pink = "#E586E7",
          flamingo = "#E4859A",
          rosewater = "#EAA0B0",
        },
      },
    },
  },
}
