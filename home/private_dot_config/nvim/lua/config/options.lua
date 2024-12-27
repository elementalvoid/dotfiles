-- Default options: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt

opt.breakindent = true -- wrap indent to match  line start
opt.cmdheight = 0 -- hide command line unless needed
opt.copyindent = true -- copy the previous indentation on autoindenting
opt.cursorlineopt = "both"
opt.fileencoding = "utf-8" -- file content encoding for the buffer
opt.foldcolumn = "1"
opt.history = 100 -- number of commands to remember in a history table
opt.infercase = true -- infer cases in keyword completion
opt.laststatus = 3 -- global statusline
opt.preserveindent = true -- preserve indent structure as much as possible
opt.relativenumber = false
opt.scrolloff = 4
opt.showtabline = 2 -- always display tabline
opt.softtabstop = 2
opt.timeoutlen = 300 -- shorten key timeout length a little bit for which-key
opt.title = true -- set terminal title to the filename and path
opt.updatetime = 300 -- length of time to wait before triggering the plugin
opt.writebackup = false -- disable making a backup before overwriting a file

-- Disable LazyVim auto format
vim.g.autoformat = false
