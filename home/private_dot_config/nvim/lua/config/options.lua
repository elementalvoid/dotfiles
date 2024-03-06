vim.g.mapleader = " " -- set leader key
vim.g.maplocalleader = " " -- set default local leader key

-- TODO: are all these astro-specific?
-- vim.g.max_file = { size = 1024 * 100, lines = 10000 } -- set global limits for large files
-- vim.g.autoformat_enabled = true -- enable or disable auto formatting at start (lsp.formatting.format_on_save must be enabled)
-- vim.g.autopairs_enabled = true -- enable autopairs at start
-- vim.g.cmp_enabled = true -- enable completion at start
-- vim.g.codelens_enabled = true -- enable or disable automatic codelens refreshing for lsp that support it
-- vim.g.diagnostics_mode = 3 -- set the visibility of diagnostics in the UI (0=off, 1=only show in status line, 2=virtual text off, 3=all on)
-- vim.g.highlighturl_enabled = true -- highlight URLs by default
-- vim.g.icons_enabled = true -- disable icons in the UI (disable if no nerd font is available)
-- vim.g.inlay_hints_enabled = false -- enable or disable LSP inlay hints on startup (Neovim v0.10 only)
-- vim.g.lsp_handlers_enabled = true -- enable or disable default vim.lsp.handlers (hover and signature help)
-- vim.g.semantic_tokens_enabled = true -- enable or disable LSP semantic tokens on startup
-- vim.g.ui_notifications_enabled = true -- disable notifications (TODO: rename to  notifications_enabled in AstroNvim v4)
-- vim.g.git_worktrees = nil -- enable git integration for detached worktrees (specify a table where each entry is of the form { toplevel = vim.env.HOME, gitdir=vim.env.HOME .. "/.dotfiles" })

vim.opt.breakindent = true -- wrap indent to match  line start
vim.opt.clipboard = "unnamedplus" -- connection to the system clipboard
vim.opt.cmdheight = 0 -- hide command line unless needed
vim.opt.completeopt = { "menu", "menuone", "noselect" } -- Options for insert mode completion
vim.opt.copyindent = true -- copy the previous indentation on autoindenting
vim.opt.cursorline = true -- highlight the text line of the cursor
vim.opt.cursorlineopt = "both"
vim.opt.expandtab = true -- enable the use of space in tab
vim.opt.fileencoding = "utf-8" -- file content encoding for the buffer
vim.opt.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
vim.opt.foldcolumn = "1"
vim.opt.foldenable = true -- enable fold for nvim-ufo
vim.opt.foldlevel = 99 -- set high foldlevel for nvim-ufo
vim.opt.foldlevelstart = 99 -- start with all code unfolded
vim.opt.history = 100 -- number of commands to remember in a history table
vim.opt.ignorecase = true -- case insensitive searching
vim.opt.infercase = true -- infer cases in keyword completion
vim.opt.laststatus = 3 -- global statusline
vim.opt.linebreak = true -- wrap lines at 'breakat'
vim.opt.mouse = "a" -- enable mouse support
vim.opt.number = true -- show numberline
vim.opt.preserveindent = true -- preserve indent structure as much as possible
-- vim.opt.pumheight = 10 -- height of the pop up menu
-- vim.opt.relativenumber = true -- show relative numberline
vim.opt.scrolloff = 8
vim.opt.shiftwidth = 2 -- number of space inserted for indentation
vim.opt.showmode = false -- disable showing modes in command line
vim.opt.showtabline = 2 -- always display tabline
vim.opt.signcolumn = "yes" -- always show the sign column
vim.opt.smartcase = true -- case sensitive searching
vim.opt.softtabstop = 2
vim.opt.splitbelow = true -- splitting a new window below the current one
vim.opt.splitright = true -- splitting a new window at the right of the current one
vim.opt.tabstop = 2 -- number of space in a tab
vim.opt.termguicolors = true -- enable 24-bit RGB color in the TUI
vim.opt.timeoutlen = 300 -- shorten key timeout length a little bit for which-key
vim.opt.title = true -- set terminal title to the filename and path
vim.opt.undofile = true -- enable persistent undo
vim.opt.updatetime = 300 -- length of time to wait before triggering the plugin
vim.opt.virtualedit = "block" -- allow going past end of line in visual block mode
vim.opt.wrap = false -- disable wrapping of lines longer than the width of window
vim.opt.writebackup = false -- disable making a backup before overwriting a file
