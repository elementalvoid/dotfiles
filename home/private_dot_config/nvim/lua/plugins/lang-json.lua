return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Format is <server-name> = { settings ... }. Manuualy nesting the settings
        -- block is not required.

        jsonls = {
          -- filetypes = { "json", "jsonc", "json5"},
        },
      },
    },
  },
}
