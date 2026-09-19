--- Dynamic model registry for pi_agent.
--- The picker asks pi itself which models are available (`pi --list-models`)
--- every time it opens, so the list always matches pi's own picker: models
--- from every provider with working credentials, refreshed catalogs
--- included. A synchronous parse of ~/.pi/agent/models.json serves as the
--- fallback and provides the default selection. The active choice
--- persists across restarts and is read by pi_agent on every request.
local M = {}

local PI_BIN = vim.fn.exepath "pi"
local MODELS_FILE = vim.fn.expand "~/.pi/agent/models.json"
local MODELS_STORE_FILE = vim.fn.expand "~/.pi/agent/models-store.json"
local AUTH_FILE = vim.fn.expand "~/.pi/agent/auth.json"
local SETTINGS_FILE = vim.fn.expand "~/.pi/agent/settings.json"
local STATE_FILE = vim.fn.stdpath "state" .. "/pi-model.last"

local CACHE_TTL_MS = 10 * 60 * 1000 -- 10 minutes

-- Local llama.cpp instances are pinned to the top of the picker.
local LOCAL_PROVIDERS = { "llamacpp-box", "llamacpp-localhost" }

-- Short tag shown next to a provider's models.
local PROVIDER_TAGS = {
  ["llamacpp-box"] = "box",
  ["llamacpp-localhost"] = "local",
  ["freellmapi"] = "free",
  ["opencode-go"] = "og",
  nvidia = "nv",
}

-- Routing pseudo-models get pinned to the top of their provider.
local SPECIAL_MODELS = { auto = 0, fusion = 1 }

local cache, cache_key, cache_at = nil, nil, 0
local job_running = false
local waiters = {}

-- Active selection { provider, model, label, name, ... }.
local current = nil

--- Short tag for a provider, falling back to the provider name itself.
local function provider_tag(provider)
  return PROVIDER_TAGS[provider] or provider
end

--- Format a token count like pi's own table ("262.1K", "1.0M").
local function format_tokens(n)
  n = tonumber(n) or 0
  if n >= 1e6 then
    return string.format("%.1fM", n / 1e6)
  end
  if n >= 1e3 then
    return string.format("%.1fK", n / 1e3)
  end
  return tostring(n)
end

--- Build one flat entry for the picker list.
local function build_entry(provider, model, ctx, thinking, images)
  return {
    provider = provider,
    model = model,
    label = provider_tag(provider),
    name = string.format("%s · %s", provider, model),
    ctx = ctx,
    thinking = thinking,
    images = images,
  }
end

--- Local instances first, routing models on top within a provider.
local function sort_entries(entries)
  local function provider_rank(p)
    for i, local_provider in ipairs(LOCAL_PROVIDERS) do
      if local_provider == p then
        return i
      end
    end
    return #LOCAL_PROVIDERS + 1
  end
  table.sort(entries, function(a, b)
    local ra, rb = provider_rank(a.provider), provider_rank(b.provider)
    if ra ~= rb then
      return ra < rb
    end
    if a.provider ~= b.provider then
      return a.provider < b.provider
    end
    local sa, sb = SPECIAL_MODELS[a.model] or 2, SPECIAL_MODELS[b.model] or 2
    if sa ~= sb then
      return sa < sb
    end
    return a.model < b.model
  end)
end

--- Parse the provider/model/context table printed by `pi --list-models`.
local function parse_pi_models(stdout)
  local entries = {}
  for line in stdout:gmatch "[^\r\n]+" do
    local provider, model, ctx, max_out, thinking, images =
      line:match "^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*$"
    if provider and provider ~= "provider" then
      table.insert(entries, build_entry(provider, model, ctx, thinking == "yes", images == "yes"))
    end
  end
  return entries
end

--- Read a JSON file from disk, or nil on any failure.
local function read_json(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(data) ~= "table" then
    return nil
  end
  return data
end

--- Models explicitly configured in ~/.pi/agent/models.json (fallback list).
local function load_registry_entries()
  local data = read_json(MODELS_FILE)
  if not data or type(data.providers) ~= "table" then
    return {}
  end
  local entries = {}
  for provider, spec in pairs(data.providers) do
    local models = type(spec) == "table" and spec.models
    if type(models) == "table" then
      for _, model in ipairs(models) do
        if type(model) == "table" and type(model.id) == "string" then
          local input = type(model.input) == "table" and model.input or {}
          table.insert(
            entries,
            build_entry(
              provider,
              model.id,
              format_tokens(model.contextWindow),
              model.reasoning == true,
              vim.tbl_contains(input, "image")
            )
          )
        end
      end
    end
  end
  sort_entries(entries)
  return entries
end

--- Signature of the files whose changes invalidate the model cache.
local function source_signature()
  return vim.fn.getftime(MODELS_FILE) .. ":" .. vim.fn.getftime(MODELS_STORE_FILE) .. ":" .. vim.fn.getftime(AUTH_FILE)
end

local function cache_valid()
  return cache ~= nil and cache_key == source_signature() and vim.loop.now() - cache_at < CACHE_TTL_MS
end

--- Ask pi for the available models and cache the result. Calls back with
--- the entry list or nil when the query fails. Callbacks issued while a
--- query is already in flight are queued and served from its result.
local function fetch_available(callback)
  if PI_BIN == "" then
    callback(nil)
    return
  end
  if job_running then
    table.insert(waiters, callback)
    return
  end
  job_running = true
  vim.system({ PI_BIN, "--list-models" }, { text = true, timeout = 20000 }, function(result)
    job_running = false
    local entries = nil
    if result.code == 0 and type(result.stdout) == "string" and result.stdout ~= "" then
      local parsed = parse_pi_models(result.stdout)
      if not vim.tbl_isempty(parsed) then
        sort_entries(parsed)
        cache = parsed
        cache_key = source_signature()
        cache_at = vim.loop.now()
        entries = parsed
      end
    end
    -- Jump out of the fast-event context before touching the UI.
    vim.schedule(function()
      local pending = waiters
      waiters = {}
      callback(entries)
      for _, waiter in ipairs(pending) do
        waiter(entries)
      end
    end)
  end)
end

--- Refresh the cache in the background so the next pick is instant.
local function refresh_background()
  if cache_valid() then
    return
  end
  fetch_available(function() end)
end

--- pi's own default provider/model from ~/.pi/agent/settings.json.
local function pi_settings_default()
  local data = read_json(SETTINGS_FILE)
  if data and type(data.defaultProvider) == "string" and type(data.defaultModel) == "string" then
    return data.defaultProvider, data.defaultModel
  end
  return nil
end

--- The last picked provider/model, if any.
local function saved_selection()
  local data = read_json(STATE_FILE)
  if data and type(data.provider) == "string" and type(data.model) == "string" then
    return data.provider, data.model
  end
  return nil
end

--- Build a standalone entry for a provider/model pair (no list lookup).
local function synth_entry(provider, model)
  if not provider or not model then
    return { provider = nil, model = nil, label = "default", name = "pi default" }
  end
  return {
    provider = provider,
    model = model,
    label = provider_tag(provider),
    name = string.format("%s · %s", provider, model),
  }
end

function M.init_default()
  local provider, model = saved_selection()
  if not provider then
    provider, model = pi_settings_default()
  end
  if provider then
    current = synth_entry(provider, model)
    return
  end
  local entries = load_registry_entries()
  current = entries[1] or synth_entry(nil, nil)
end

function M.entry()
  if current == nil then
    M.init_default()
  end
  return current
end

--- Compact badge for a model id, e.g. "Qwen3.8-27B" or "glm-5.2".
local function short_id(id)
  if not id then
    return "default"
  end
  local tail = id:match "[^/]+$"
  return tail:gsub("%-GGUF.*$", "")
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
--- Pure-Lua IO (safe from any callback context); the state dir always exists.
function M.save()
  local e = M.entry()
  local f = io.open(STATE_FILE, "w")
  if not f then
    return
  end
  f:write(vim.json.encode { provider = e.provider, model = e.model })
  f:close()
end

local function is_current(e)
  local active = M.entry()
  return e.provider == active.provider and e.model == active.model
end

local function show_picker(entries)
  vim.ui.select(entries, {
    prompt = "pi model",
    format_item = function(e)
      local details = {}
      if e.ctx then
        table.insert(details, e.ctx .. " ctx")
      end
      if e.thinking then
        table.insert(details, "think")
      end
      if e.images then
        table.insert(details, "img")
      end
      local suffix = #details > 0 and ("  [" .. table.concat(details, " ") .. "]") or ""
      return string.format("%s %s%s", is_current(e) and "●" or "○", e.name, suffix)
    end,
  }, function(choice)
    if not choice then
      return
    end
    current = choice
    M.save()
    vim.notify("pi → " .. choice.name)
  end)
end

function M.pick()
  if cache_valid() then
    show_picker(cache)
    refresh_background()
    return
  end
  vim.notify("pi: querying available models…", vim.log.levels.INFO)
  fetch_available(function(entries)
    if entries then
      show_picker(entries)
      return
    end
    local fallback = load_registry_entries()
    if not vim.tbl_isempty(fallback) then
      vim.notify("pi: --list-models unavailable, showing models.json", vim.log.levels.WARN)
      show_picker(fallback)
      return
    end
    vim.notify("pi: no models available", vim.log.levels.ERROR)
  end)
end

-- Warm the cache on load so the first pick is instant.
refresh_background()

return M
