vim.g.mapleader = ';'

vim.cmd([[
  set runtimepath^=~/.vim runtimepath+=~/.vim/after
  let &packpath = &runtimepath
  source ~/.vimrc
]])

vim.opt.spell = true
vim.opt.spelllang = { 'en_us' }

-- MAPPINGS
--local map = nvchad.map

