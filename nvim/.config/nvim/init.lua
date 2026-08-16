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

-- Restore the saved colorscheme (flow as fallback) once all eager themes are on rtp.
require("theme").startup()

require("neotest").setup({
  adapters = {
    require("neotest-dotnet")
  }
})

require "mappings"
