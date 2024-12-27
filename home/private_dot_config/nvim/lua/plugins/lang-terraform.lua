return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Format is <server-name> = { settings ... }. Manuualy nesting the settings
        -- block is not required.

        terraformls = {
          -- make terraformls shutup: https://github.com/hashicorp/terraform-ls/issues/1271
          cmd = { "terraform-ls", "serve", "-log-file", "/dev/null" },
        },
      },
    },
  },
}
