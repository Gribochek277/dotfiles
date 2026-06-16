vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end
vim.opt.rtp:prepend(lazypath)

require "options"
require "autocmds"

local lazy_config = require "configs.lazy"
require("lazy").setup({
  { import = "plugins" },
}, lazy_config)

require "configs.lsp"

require("neotest").setup({
  adapters = {
    require("neotest-dotnet")
  }
})

require("tiny-inline-diagnostic").setup({
  signs = {
    left = "",
    right = "",
    diag = "●",
    arrow = "    ",
    up_arrow = "    ",
    vertical = " │",
    vertical_end = " └",
  },
  blend = {
    factor = 0.22,
  },
})

vim.g.dotnet_show_project_file = false
vim.g.dotnet_errors_only = true

require "mappings"
