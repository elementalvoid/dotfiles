-- Consider:
-- https://github.com/ray-x/navigator.lua
-- https://github.com/lukas-reineke/cmp-under-comparator
-- https://github.com/hkupty/iron.nvim -- repl
-- https://github.com/DNLHC/glance.nvim -- A pretty window for previewing, navigating and editing your LSP locations in one place, inspired by vscode's peek preview.
--
-- nvim-ts-autotag
-- ts-comments.nvim

return {
  {
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    keys = { "<C-g>s", "<C-g>S", "ys", "yss", "yS", "ySS", "S", "gS", "ds", "cs", "cS" },
    opts = {},
  },
  {
    -- magic nvim-surround keymaps
    "roobert/surround-ui.nvim",
    lazy = false,
    keys = {
      { "<leader>ss", desc = "Surround UI" },
    },
    opts = {
      root_key = "ss",
    },
  },
}
