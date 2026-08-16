-- Theme state: remembers the last picked colorscheme across restarts.
-- `flow` is the fallback when no saved theme exists or is no longer available.
local M = {}

local FALLBACK = "flow"
local STATE_FILE = vim.fn.stdpath("state") .. "/nvim-theme.last"

local function theme_available(name)
  -- Colorschemes can be shipped as colors/<name>.vim or colors/<name>.lua.
  return vim.fn.globpath(vim.o.rtp, "colors/" .. name .. ".vim") ~= ""
      or vim.fn.globpath(vim.o.rtp, "colors/" .. name .. ".lua") ~= ""
end

function M.save(name)
  vim.fn.mkdir(vim.fn.fnamemodify(STATE_FILE, ":h"), "p")
  vim.fn.writefile({ name }, STATE_FILE)
end

function M.load_saved()
  -- filereadable returns 0/1; 0 is truthy in Lua, so compare explicitly.
  if vim.fn.filereadable(STATE_FILE) ~= 1 then
    return nil
  end
  local name = vim.fn.readfile(STATE_FILE)[1]
  if name and name ~= "" and theme_available(name) then
    return name
  end
  return nil
end

function M.startup()
  local name = M.load_saved() or FALLBACK
  vim.cmd.colorscheme(name)
  M.save(name)
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("theme.persist", {}),
    callback = function()
      M.save(vim.g.colors_name)
    end,
  })
end

return M
