return {
  {
    "echasnovski/mini.trailspace",
    config = function()
      local wk = require("which-key")

      wk.add({
        {
          "<leader>F",
          function()
            require("mini.trailspace").trim()
            require("mini.trailspace").trim_last_lines()
          end,
          desc = "Strip Whitespace",
        },
      })
    end,
  },
}
