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

require("neotest").setup {
  adapters = {
    require "neotest-dotnet",
  },
}

-- Pi agent: non-blocking requests with status bar progress (pi_agent).
-- Each request spawns its own `pi --mode rpc` job, so several can run at
-- once; progress lives in lualine + transient notifications, never in a
-- window over the buffer. Extensions are disabled inside pi_agent because
-- the agent runs non-interactively.
vim.api.nvim_create_user_command("PiAsk", function()
  require("pi_agent").ask_buffer()
end, { desc = "Ask pi with current buffer as context" })

vim.api.nvim_create_user_command("PiAskSelection", function()
  require("pi_agent").ask_selection()
end, { range = true, desc = "Ask pi with visual selection as context" })

vim.api.nvim_create_user_command("PiCancel", function()
  require("pi_agent").cancel_all()
end, { desc = "Cancel all running pi requests" })

vim.api.nvim_create_user_command("PiLog", function()
  require("pi_agent").log()
end, { desc = "Show pi session log" })

vim.api.nvim_create_user_command("PiModel", function()
  require("pi_models").pick()
end, { desc = "Select pi model" })

vim.api.nvim_create_user_command("PiConnect", function()
  require("pi_name").toggle()
end, { desc = "Connect to (or spawn) a named pi agent" })

vim.api.nvim_create_user_command("PiAgents", function()
  require("pi_name").pick()
end, { desc = "Pick a running pi agent" })

vim.api.nvim_create_user_command("PiRef", function()
  require("pi_agent").ref_selection()
end, { range = true, desc = "Send the visual selection as a line reference to the connected agent" })

require "mappings"
