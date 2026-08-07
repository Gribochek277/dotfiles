--- Shared model registry for pi.nvim: picker + lualine label.
--- pi.nvim rebuilds its command from require("pi.config").get() on every
--- request, so mutating that live table switches the model at runtime.
local M = {}

M.entries = {
  {
    label = "box·27B",
    name = "llamacpp-box · Qwen3.6-27B",
    provider = "llamacpp-box",
    model = "unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL",
  },
  {
    label = "local·35B",
    name = "llamacpp-localhost · Qwen3.6-35B-A3B",
    provider = "llamacpp-localhost",
    model = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL",
  },
  {
    label = "kimi-k3",
    name = "opencode-go · Kimi K3",
    provider = "opencode-go",
    model = "kimi-k3",
  },
  {
    label = "glm-5.2",
    name = "opencode-go · GLM 5.2",
    provider = "opencode-go",
    model = "glm-5.2",
  },
  {
    label = "ds-v4-free",
    name = "opencode · DeepSeek V4 Flash Free",
    provider = "opencode",
    model = "deepseek-v4-flash-free",
  },
}

-- Index of the active entry (default: llamacpp-box).
M.current = 1

function M.entry()
  return M.entries[M.current]
end

--- Short label for the lualine component.
function M.label()
  return "π " .. M.entry().label
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
  vim.ui.select(M.entries, {
    prompt = "pi model",
    format_item = function(e)
      local mark = (e == M.entry()) and "●" or "○"
      return string.format("%s %s", mark, e.name)
    end,
  }, function(choice)
    if not choice then
      return
    end
    for i, e in ipairs(M.entries) do
      if e == choice then
        M.current = i
        break
      end
    end
    M.apply()
    vim.notify("pi → " .. choice.name)
  end)
end

return M
