local opt = vim.opt
local o = vim.o

o.autoread = true

opt.number = true
opt.relativenumber = true

opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true

opt.wrap = true
opt.linebreak = true

opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

opt.cursorline = true

opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"
opt.splitright = true
opt.splitbelow = true

opt.backspace = "indent,eol,start"
opt.clipboard = "unnamedplus"
opt.completeopt = { "menu", "menuone", "noselect" }
opt.mouse = "a"

opt.swapfile = false
opt.backup = false
opt.undofile = true

opt.timeoutlen = 300
opt.updatetime = 250

opt.scrolloff = 8
opt.sidescrolloff = 8

opt.encoding = "utf-8"
opt.fileencoding = "utf-8"

opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldenable = false
opt.foldlevel = 99
opt.foldlevelstart = 99
