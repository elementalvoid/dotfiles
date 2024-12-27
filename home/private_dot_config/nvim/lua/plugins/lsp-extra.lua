return {
  {
    "aznhe21/actions-preview.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>cA",
        function()
          require("actions-preview").code_actions()
        end,
        desc = "Action Preview",
        mode = { "n", "v", "x" },
      },
      {
        "<F4>",
        function()
          require("actions-preview").code_actions()
        end,
        desc = "Action Preview",
        mode = { "n", "v", "x" },
      },
    },
    opts = {
      telescope = {
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
          width = 0.8,
          height = 0.9,
          prompt_position = "top",
          preview_cutoff = 20,
          preview_height = function(_, _, max_lines)
            return max_lines - 15
          end,
        },
      },
    },
  },
  {
    "onsails/lspkind.nvim",
    event = { "VeryLazy" },
  },
  {
    "kosayoda/nvim-lightbulb",
    event = { "VeryLazy" },
    config = function()
      require("nvim-lightbulb").setup({
        autocmd = {
          enabled = true,
        },
        sign = {
          priority = 100,
        },
      })
    end,
  },
}
