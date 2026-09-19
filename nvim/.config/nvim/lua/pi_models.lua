--- Dynamic model registry for pi.nvim backed by ~/.pi/agent/models.json.
--- The list is re-read from disk every time the picker opens, so models
--- added, renamed or removed in pi's config show up without editing this
--- file. The active choice persists across restarts. pi.nvim rebuilds its
--- command from require("pi.config").get() on every request, so mutating
--- that live table switches the model at runtime.
local M = {}

local MODELS_FILE = vim.fn.expand "~/.pi/agent/models.json"
local STATE_FILE = vim.fn.stdpath "state" .. "/pi-model.last"

-- Local llama.cpp instances come first in the picker, in this order.
local LOCAL_PROVIDERS = { "llamacpp-box", "llamacpp-localhost" }

-- Short tag shown next to a provider's models.
local PROVIDER_TAGS = {
  ["llamacpp-box"] = "box",
  ["llamacpp-localhost"] = "local",
  ["freellmapi"] = "free",
}

local entries_cache = nil

-- Index of the active entry (default: first, i.e. llamacpp-box).
M.current = 1

--- Build one flat entry for the picker list.
local function build_entry(provider, model)
  return {
    label = PROVIDER_TAGS[provider] or provider,
    name = model.name or model.id,
    provider = provider,
    model = model.id,
  }
end

--- Read pi's model registry from disk into a flat, sorted entry list.
local function load_entries()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(MODELS_FILE), "\n"))
  end)
  if not ok or type(data) ~= "table" or type(data.providers) ~= "table" then
    return {}
  end

  local local_buckets, remote = {}, {}
  for _, provider in ipairs(LOCAL_PROVIDERS) do
    local_buckets[provider] = {}
  end
  for provider, spec in pairs(data.providers) do
    local models = type(spec) == "table" and spec.models
    if type(models) == "table" then
      local bucket = local_buckets[provider] or remote
      for _, model in ipairs(models) do
        if type(model) == "table" and type(model.id) == "string" then
          table.insert(bucket, build_entry(provider, model))
        end
      end
    end
  end

  local function by_name(a, b)
    return a.name < b.name
  end
  local result = {}
  for _, provider in ipairs(LOCAL_PROVIDERS) do
    table.sort(local_buckets[provider], by_name)
    vim.list_extend(result, local_buckets[provider])
  end
  table.sort(remote, by_name)
  vim.list_extend(result, remote)
  return result
end

--- Re-read the registry from disk, keeping the current selection when
--- possible. Returns false (and notifies) when the registry is unreadable.
function M.refresh()
  entries_cache = load_entries()
  if vim.tbl_isempty(entries_cache) then
    vim.notify("pi: cannot read " .. MODELS_FILE, vim.log.levels.ERROR)
    return false
  end
  M.current = math.min(M.current, #entries_cache)
  return true
end

--- Compact badge for a model id, e.g. "Qwen3.8-27B" or "glm-5.2".
local function short_id(id)
  if not id then
    return "default"
  end
  local tail = id:match "[^/]+$"
  return tail:gsub("%-GGUF.*$", "")
end

--- Restore the last picked provider/model across restarts.
local function restore_current()
  if vim.fn.filereadable(STATE_FILE) ~= 1 then
    return
  end
  local ok, saved = pcall(vim.json.decode, table.concat(vim.fn.readfile(STATE_FILE), "\n"))
  if not ok or type(saved) ~= "table" then
    return
  end
  for i, e in ipairs(M.entries()) do
    if e.provider == saved.provider and e.model == saved.model then
      M.current = i
      return
    end
  end
end

--- Cached, possibly stale list; safe for the status line.
function M.entries()
  if entries_cache == nil then
    if not M.refresh() then
      entries_cache = {
        { label = "default", name = "pi default", provider = nil, model = nil },
      }
      M.current = 1
    end
    restore_current()
  end
  return entries_cache
end

function M.entry()
  return M.entries()[M.current]
end

--- Short label for the lualine component, e.g. "π box·Qwen3.8-27B".
function M.label()
  local e = M.entry()
  if not e.model then
    return "π default"
  end
  return string.format("π %s·%s", e.label, short_id(e.model))
end

--- Persist the active selection across restarts.
function M.save()
  local e = M.entry()
  vim.fn.mkdir(vim.fn.fnamemodify(STATE_FILE, ":h"), "p")
  vim.fn.writefile({ vim.json.encode { provider = e.provider, model = e.model } }, STATE_FILE)
end

--- Write the active entry into pi.nvim's live config.
--- Requiring pi.config lazily loads the plugin if needed.
function M.apply()
  local ok, pi_config = pcall(require, "pi.config")
  if not ok then
    return
  end
  local cfg = pi_config.get()
  cfg.provider = M.entry().provider
  cfg.model = M.entry().model
end

function M.pick()
  if not M.refresh() then
    return
  end
  local entries = entries_cache
  vim.ui.select(entries, {
    prompt = "pi model",
    format_item = function(e)
      local mark = (e == M.entry()) and "●" or "○"
      return string.format("%s %s · %s", mark, e.label, e.name)
    end,
  }, function(choice)
    if not choice then
      return
    end
    for i, e in ipairs(entries) do
      if e == choice then
        M.current = i
        break
      end
    end
    M.save()
    M.apply()
    vim.notify("pi → " .. choice.name)
  end)
end

return M
