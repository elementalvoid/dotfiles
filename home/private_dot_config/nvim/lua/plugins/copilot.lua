-- Get Node.js path from mise
local function get_node_path()
  local handle = io.popen("mise where node@24 2>/dev/null")
  if not handle then return nil end
  local result = handle:read("*a"):gsub("\n", "")
  handle:close()
  if result ~= "" then
    return result .. "/bin/node"
  end
  return nil
end

return {
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
