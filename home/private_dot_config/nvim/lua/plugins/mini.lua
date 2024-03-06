return {
  {
    'echasnovski/mini.nvim',
    version = false,
    config = function()
      require('mini.trailspace').setup()
      require('mini.comment').setup()
      require('mini.indentscope').setup {
        draw = {
          animation = require('mini.indentscope').gen_animation.none()
        },
      }
      require('mini.move').setup()
      -- require('mini.pairs').setup()
      -- require('mini.bufremove').setup()
      -- require('mini.surround').setup()

      require('mini.misc').setup()
      MiniMisc.setup_auto_root()
      MiniMisc.setup_restore_cursor()
    end
  },
}
