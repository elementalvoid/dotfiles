---@diagnostic disable: unused-local

local copilot = {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        -- required for copilot_cmp
        suggestion = { enabled = false },
        panel = { enabled = false },

        filetypes = {
          markdown = true,
          help = true,
        },
      })
    end,
  },
  {
    "zbirenbaum/copilot-cmp",
    dependencies = "copilot.lua",
    opts = {},
    -- config = function(_, opts)
    --   local copilot_cmp = require("copilot_cmp")
    --   copilot_cmp.setup(opts)
    --   -- attach cmp source whenever copilot attaches
    --   -- fixes lazy-loading issues with the copilot cmp source
    --   local lsp_zero = require('lsp-zero')
    --   lsp_zero.on_attach(function(client)
    --     copilot_cmp._on_insert_enter({})
    --   end, "copilot")
    -- end,
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
      { "nvim-lua/plenary.nvim" },  -- for curl, log wrapper
      --     'nvim-telescope/telescope.nvim', -- for telescope picker for actions
    },
    event = "VeryLazy",
    build = "make tiktoken", -- Only on MacOS or Linux
    config = function(_, opts)
      local chat = require("CopilotChat")
      require("CopilotChat.integrations.cmp").setup()

      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-chat",
        callback = function()
          vim.opt_local.relativenumber = false
          vim.opt_local.number = false
        end,
      })

      chat.setup(opts)

      -- Inline chat with Copilot
      vim.api.nvim_create_user_command("CopilotChatInline", function(args)
        chat.ask(args.args, {
          window = {
            layout = "float",
            relative = "cursor",
            width = 1,
            height = 0.4,
            row = 1,
          },
        })
      end, { nargs = "*", range = true })
    end,
    opts = {
      -- See Configuration:
      -- https://github.com/CopilotC-Nvim/CopilotChat.nvim/blob/canary/lua/CopilotChat/config.lua
      -- https://www.lazyvim.org/extras/coding/copilot-chat
      selection = function(source)
        local select = require("CopilotChat.select")
        return select.visual(source) or select.buffer(source)
      end,
      mappings = {
        complete = {
          insert = '',
        },
      },
    },
    keys = {
      { "<leader>a", "  CopilotChat" },
      -- Show help actions with telescope
      {
        "<leader>ah",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.help_actions())
        end,
        desc = "CopilotChat - Help actions",
      },
      -- Show prompts actions with telescope
      {
        "<leader>ap",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
        end,
        desc = "CopilotChat - Prompt actions",
      },
      { "<leader>ad", "<cmd>CopilotChatDebugInfo<cr>", desc = "CopilotChat - Debug Info" },
      { "<leader>af", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "CopilotChat - Fix Diagnostic" },
      { "<leader>al", "<cmd>CopilotChatReset<cr>", desc = "CopilotChat - Clear buffer and chat history" },
      --     -- Code related commands
      --     { "<leader>aR", "<cmd>CopilotChatRefactor<cr>",      desc = "CopilotChat - Refactor code" },
      --     { "<leader>an", "<cmd>CopilotChatBetterNamings<cr>", desc = "CopilotChat - Better Naming" },
      {
        "<leader>ax",
        ":CopilotChatInline<cr>",
        desc = "CopilotChat - Inline chat",
      },
      -- Custom input for CopilotChat
      {
        "<leader>ai",
        function()
          local input = vim.fn.input("Ask Copilot: ")
          if input ~= "" then
            vim.cmd("CopilotChat " .. input)
          end
        end,
        desc = "CopilotChat - Ask input",
      },
      --     -- Quick chat with Copilot
      --     {
      --       "<leader>aq",
      --       function()
      --         local input = vim.fn.input("Quick Chat: ")
      --         if input ~= "" then
      --           vim.cmd("CopilotChatBuffer " .. input)
      --         end
      --       end,
      --       desc = "CopilotChat - Quick chat",
      --     },
      --   },
    },
  },
}

return copilot
