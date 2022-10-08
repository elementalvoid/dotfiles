return {
  disabled = {
    n = {
      ["<leader>e"] = "", -- default mapping to focus nvtree
      ["<leader>n"] = "", -- default mapping to toggle number line
      ["<leader>q"] = "", -- default mapping to show diagnostics
      ["<leader>v"] = "", -- default mapping to open vertical terminal
      ["<leader>h"] = "", -- default mapping to open horizontal terminal
    },
  },

  custom = {
    n = {
      ["<leader>T"] = {":Telescope<CR>", "open Telescope"},
      ["<F5>"] = {":BufExplorer<CR>", "BufExplorer"},
    },
  },

  buffer_management = {
    n = {
      ["<leader>N"] = {":e ~/notes<CR>", "Edit Notes"},
      ["<leader>V"] = {":e ~/.vim/personal.vim<CR>", "Open vimrc"},
      ["<leader>e"] = {":e <c-r>=expand('%:p:h')<CR>/", "edit file in current path"},
      ["<leader>w"] = {":w<CR>", "write buffer"},
      ["<leader>q"] = {":call SmartQuit()<CR>", "SmartQuit" },
      ["<leader>wq"] = {":w<CR><esc>:call SmartQuit()<CR>", "Write and SmartQuit"},
      ["<leader>fw"] = {":w! !sudo tee %<CR><CR>:e<CR>", "Force write (sudo)"},
    },
  },
}
