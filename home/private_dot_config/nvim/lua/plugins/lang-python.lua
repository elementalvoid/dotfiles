-- NOTE: `ty` is set as the LSP in lua/conf/options.lua

return {
  {
    "benomahony/uv.nvim",
    opts = {
      picker_integration = true,
      keymaps = {
        prefix = "<leader>p", -- Change prefix to <leader>u
      },
    },
  },
}
