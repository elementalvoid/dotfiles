return {
  {
    -- YAML support for JSON Schemas
    "someone-stole-my-name/yaml-companion.nvim",
    dependencies = {
      { "nvim-telescope/telescope.nvim" },
    },
    ft = { "yaml" },
    keys = {
      { "<leader>yS", "<cmd>Telescope yaml_schema<cr>", desc = "Set YAML Schema" },
      {
        "<leader>ys",
        function()
          local schema = require("yaml-companion").get_buf_schema(0)
          if schema then
            require("noice").notify(string.format("Schema: %s", schema.result[1].name), "info")
          else
            require("noice").notify("Schema not detected!", "info")
          end
        end,
        desc = "Show the detected YAML Schema",
      },
    },
    config = function()
      require("telescope").load_extension("yaml_schema")
      local cfg = require("yaml-companion").setup({
        builtin_matchers = {
          kubernetes = {
            enabled = true,
          },
        },
        lspconfig = {
          settings = {
            yaml = {
              format = {
                enable = true,
              },
              hover = true,
              schemaDownload = {
                enable = true,
              },
              schemaStore = {
                enable = true,
                url = "https://www.schemastore.org/api/json/catalog.json",
              },
              schemas = {},
              validate = true,
            },
          },
        },
      })
      require("lspconfig")["yamlls"].setup(cfg)
    end,
  },
}
