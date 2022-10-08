local on_attach = require("plugins.configs.lspconfig").on_attach
local capabilities = require("plugins.configs.lspconfig").capabilities

local lspconfig = require "lspconfig"

--  Refer to this doc for lspconfig server name to mason package name mappings:
--  https://github.com/williamboman/mason-lspconfig.nvim/blob/main/doc/server-mapping.md
--
-- Refer to this doc for all LSP config:
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
--
-- Maybe check out: https://github.com/williamboman/mason-lspconfig.nvim
local servers = {
  "bashls",
  "dockerls",
  "eslint",
  -- "golangci_lint_ls",
  "gopls",
  "graphql",
  "groovyls",
  "jsonls",
  "kotlin_language_server",
  "marksman",
  "pylsp",
  "sumneko_lua",
  "terraformls",
  "tflint",
  "tsserver",
  "vimls",
  "yamlls",
}

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
  }
end
