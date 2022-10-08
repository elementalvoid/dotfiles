local present, null_ls = pcall(require, "null-ls")

if not present then
   return
end

local b = null_ls.builtins

local sources = {
   -- Lua
   -- b.formatting.stylua,

   -- Shell
   b.formatting.shfmt,
   b.diagnostics.shellcheck.with { diagnostics_format = "#{m} [#{c}]" },

  -- Terraform
  b.formatting.terraform_fmt,

  -- Python
  b.diagnostics.pylint,
  b.diagnostics.black,
}

local M = {}

-- local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

M.setup = function()
  null_ls.setup({
    debug = true,
    sources = sources,

    -- format on save
    -- on_attach = function(client, bufnr)
    --   if client.supports_method("textDocument/formatting") then
    --     vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
    --     vim.api.nvim_create_autocmd("BufWritePre", {
    --       group = augroup,
    --       buffer = bufnr,
    --       callback = function()
    --         vim.lsp.buf.format({ bufnr = bufnr })
    --       end,
    --     })
    --   end
    --   vim.api.nvim_create_autocmd("CursorHold", {
    --     buffer = bufnr,
    --     callback = function()
    --       local opts = {
    --         focusable = false,
    --         close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
    --         border = "rounded",
    --         source = "always",
    --         prefix = " ",
    --         scope = "cursor",
    --       }
    --       vim.diagnostic.open_float(nil, opts)
    --     end,
    --   })
    -- end,
  })
end

return M
