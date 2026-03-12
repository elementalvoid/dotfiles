-- Get Node.js path from mise
local function get_node_path()
  local handle = io.popen("mise where node@25 2>/dev/null")
  if not handle then
    return nil
  end
  local result = handle:read("*a"):gsub("\n", "")
  handle:close()
  if result ~= "" then
    return result .. "/bin/node"
  end
  return nil
end

return {
  -- {
  --   "ThePrimeagen/99",
  --   config = function()
  --     local _99 = require("99")
  --     _99.setup({
  --       _99.OpenCodeProvider, -- the default, just being explicit
  --       model = "github-copilot/claude-sonnet-4.6",
  --     })
  --     -- take extra note that i have visual selection only in v mode
  --     -- technically whatever your last visual selection is, will be used
  --     -- so i have this set to visual mode so i dont screw up and use an
  --     -- old visual selection
  --     --
  --     -- likely ill add a mode check and assert on required visual mode
  --     -- so just prepare for it now
  --     vim.keymap.set("v", "<leader>9v", function()
  --       _99.visual()
  --     end)
  --
  --     --- if you have a request you dont want to make any changes, just cancel it
  --     vim.keymap.set("n", "<leader>9x", function()
  --       _99.stop_all_requests()
  --     end)
  --
  --     vim.keymap.set("n", "<leader>9s", function()
  --       _99.search()
  --     end)
  --   end,
  -- },

  {
    "zbirenbaum/copilot.lua",
    opts = function()
      return {
        copilot_node_command = get_node_path(),
      }
    end,
  },

  -- blink customization
  {
    "giuxtaposition/blink-cmp-copilot",
    enabled = false,
  },
  {
    "saghen/blink.cmp",
    dependencies = { "fang2hou/blink-copilot" },
    opts = {
      sources = {
        default = { "copilot" },
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-copilot",
            score_offset = 100,
            async = true,
          },
        },
      },
    },
  },
}
