return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = {
      prompts = {
        CustomChat = {
          prompt = "",
          mapping = "<leader>ai",
          description = "Custom Chat (Copilot)",
          selection = require("CopilotChat.select").none,
        },
      },
    },
  },
}
