-- https://codecompanion.olimorris.dev

require("which-key").add({
  {
    { "<leader>a", mode = { "n", "v" }, group = "🤖 Code Companion" },
    { "<leader>aa", "<cmd>CodeCompanionChat<cr>", mode = { "n", "v" }, desc = "🤖 Chat" },
    { "<leader>aA", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "🤖 Actions" },
    {
      "<leader>ad",
      function()
        require("codecompanion").prompt("debug")
      end,
      desc = "Debug Code",
      mode = { "v" },
    },
    {
      "<leader>ar",
      function()
        require("codecompanion").prompt("refactor")
      end,
      desc = "Refactor Code",
      mode = { "v" },
    },
    {
      "<leader>as",
      function()
        require("codecompanion").prompt("summarize")
      end,
      desc = "Summarize Code",
      mode = { "v" },
    },
    {
      "<leader>ao",
      function()
        require("codecompanion").prompt("optimize")
      end,
      desc = "Optimize Code",
      mode = { "v" },
    },
  },
})

return {
  {
    "ravitemer/mcphub.nvim",
    lazy = false,
    build = "bundled_build.lua",
    opts = {
      use_bundled_binary = true,
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion" },
  },
  {
    "Davidyz/VectorCode",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    event = "VeryLazy",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 3, {
        -- See: https://ravitemer.github.io/mcphub.nvim/extensions/lualine.html
        function()
          -- Check if MCPHub is loaded
          if not vim.g.loaded_mcphub then
            return "󰐻 -"
          end

          local count = vim.g.mcphub_servers_count or 0
          local status = vim.g.mcphub_status or "stopped"
          local executing = vim.g.mcphub_executing

          -- Show "-" when stopped
          if status == "stopped" then
            return "󰐻 -"
          end

          -- Show spinner when executing, starting, or restarting
          if executing or status == "starting" or status == "restarting" then
            local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
            local frame = math.floor(vim.loop.now() / 100) % #frames + 1
            return "󰐻 " .. frames[frame]
          end

          return "󰐻 " .. count
        end,
        color = function()
          if not vim.g.loaded_mcphub then
            return { fg = "#6c7086" } -- Gray for not loaded
          end

          local status = vim.g.mcphub_status or "stopped"
          if status == "ready" or status == "restarted" then
            return { fg = "#50fa7b" } -- Green for connected
          elseif status == "starting" or status == "restarting" then
            return { fg = "#ffb86c" } -- Orange for connecting
          else
            return { fg = "#ff5555" } -- Red for error/stopped
          end
        end,
      })
    end,
  },
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/mcphub.nvim",
    },
    lazy = false,

    opts = {
      extensions = {
        mcphub = {
          callback = "mcphub.extensions.codecompanion",
          opts = {
            make_vars = true,
            make_slash_commands = true,
            show_result_in_chat = true,
          },
        },
        vectorcode = {
          opts = {
            add_tool = true,
          },
        },
      },
      prompt_library = {
        ["Optimize"] = {
          strategy = "chat",
          description = "Optimize for performance",
          opts = {
            short_name = "optimize",
            modes = { "v", "n" },
          },
          prompts = {
            {
              role = "user",
              content = [[
Please optimize the following code with these goals:
- Improve performance and reduce resource usage.
- Identify and eliminate bottlenecks or inefficient patterns.
- Use idiomatic optimizations and best practices for the language.
- Watch for common security issues (such as those in the OWASP Top Ten) and suggest improvements where relevant.
- Do not change the code's external behavior.
After optimizing, provide a brief summary of the main changes and performance improvements you made.
]],
            },
          },
        },

        ["Debug"] = {
          strategy = "chat",
          description = "Identify potential bugs",
          opts = {
            short_name = "debug",
            modes = { "v", "n" },
          },
          prompts = {
            {
              role = "user",
              content = [[
Please review the following code and:
- Identify potential bugs, edge cases, and logic errors.
- Suggest fixes and improvements to error handling.
- Highlight any areas that may cause unexpected behavior.
- Watch for common security issues (such as those in the OWASP Top Ten) and suggest improvements where relevant.
- Do not change the code's external behavior unless necessary for correctness.
After your review, provide a summary of your findings and recommendations.
]],
            },
          },
        },

        ["Refactor"] = {
          strategy = "chat",
          description = "Refactor code for clarity, maintainability, and best practices",
          opts = {
            short_name = "refactor",
            modes = { "v", "n" },
          },
          prompts = {
            {
              role = "user",
              content = [[
Please refactor the following code with the following goals:
- Improve readability, maintainability, and modularity.
- Use idiomatic constructs and best practices for the language.
- Remove duplication and unnecessary complexity.
- Use clear, concise naming for variables, functions, and classes.
- Add comments where they clarify non-obvious logic.
- Watch for common security issues (such as those in the OWASP Top Ten) and suggest improvements where relevant.
- Do not change the code's external behavior.
After refactoring, provide a brief summary of the main changes you made.
]],
            },
          },
        },
        ["Summarize"] = {
          strategy = "chat",
          description = "Summarize code purpose and structure",
          opts = {
            short_name = "summarize",
            modes = { "v", "n" },
          },
          prompts = {
            {
              role = "user",
              content = [[
Please provide a concise summary of the following code:
- Explain its overall purpose and main functionality.
- Highlight key components, logic, and any important dependencies.
- Mention any potential security concerns (such as those in the OWASP Top Ten) if relevant.
Write your summary in clear, developer-friendly language.
]],
            },
          },
        },
      },
    },
  },
}
