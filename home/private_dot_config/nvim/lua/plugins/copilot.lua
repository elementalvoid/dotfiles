return {
  -- Copilot Chat
  -- {
  --   "CopilotC-Nvim/CopilotChat.nvim",
  --   build = "make tiktoken",
  --   opts = {
  --     model = "claude-3.7-sonnet",
  --     prompts = {
  --       Explain = "Please explain how the following code works.",
  --       Review = "Please review the following code and provide suggestions for improvement.",
  --       Tests = "Please explain how the selected code works, then generate unit tests for it.",
  --       Refactor = "Please refactor the following code to improve its clarity and readability.",
  --       FixCode = "Please fix the following code to make it work as intended.",
  --       FixError = "Please explain the error in the following text and provide a solution.",
  --       FixLinting = "Please explain the linting errors in the following text and provide a solution.",
  --       BetterNamings = "Please provide better names for the following variables and functions.",
  --       Documentation = "Please provide documentation for the following code.",
  --       SwaggerApiDocs = "Please provide documentation for the following API using Swagger.",
  --       SwaggerJsDocs = "Please write JSDoc for the following API using Swagger.",
  --
  --       -- Text related prompts
  --       Summarize = "Please summarize the following text.",
  --       Spelling = "Please correct any grammar and spelling errors in the following text.",
  --       Wording = "Please improve the grammar and wording of the following text.",
  --       Concise = "Please rewrite the following text to make it more concise.",
  --
  --       CustomChat = {
  --         prompt = "",
  --         mapping = "<leader>ai",
  --         description = "Custom Chat (Copilot)",
  --         selection = require("CopilotChat.select").none,
  --       },
  --     },
  --   },
  -- },
  -- {
  --   "MeanderingProgrammer/render-markdown.nvim",
  --   optional = true,
  --   opts = {
  --     file_types = { "markdown", "copilot-chat" },
  --   },
  --   ft = { "markdown", "copilot-chat" },
  -- },

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
        providers = {
          copilot = {
            module = "blink-copilot",
          },
        },
      },
    },
  },

  -- enable binary server
  -- {
  --   "zbirenbaum/copilot.lua",
  --   server = {
  --     type = "binary", -- "nodejs" | "binary"
  --   },
  -- },

  -- optionally replace copilot.lua too
  -- {
  --   "zbirenbaum/copilot.lua",
  --   enabled = false,
  -- },
  -- {
  --   "github/copilot.vim",
  --   cmd = "Copilot",
  --   event = "BufWinEnter",
  --   init = function()
  --     vim.g.copilot_no_maps = true
  --   end,
  --   config = function()
  --     -- Block the normal Copilot suggestions
  --     vim.api.nvim_create_autocmd({ "FileType", "BufUnload" }, {
  --       group = "github_copilot",
  --       callback = function(args)
  --         vim.fn["copilot#On" .. args.event]()
  --       end,
  --     })
  --     vim.fn["copilot#OnFileType"]()
  --   end,
  -- },
}
