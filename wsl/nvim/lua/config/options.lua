-- Options are automatically loaded before lazy.nvim startup
-- Add any additional options here

local opt = vim.opt

opt.termguicolors = true
opt.background = "dark"
opt.number = true
opt.relativenumber = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.signcolumn = "yes"
opt.cursorline = true
opt.wrap = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.updatetime = 200
opt.timeoutlen = 300

-- tabs / indent
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- splits
opt.splitbelow = true
opt.splitright = true

-- clipboard (WSL2 — use win32yank or clip.exe)
opt.clipboard = "unnamedplus"

-- performance
opt.lazyredraw = false
opt.synmaxcol = 240
opt.ttyfast = true
