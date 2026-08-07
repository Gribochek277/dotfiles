local M = {}

local layout_pairs = {
  {
    cyr = "ёйцукенгшщзхъфывапролджэячсмитьбю.ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,",
    lat = "`qwertyuiop[]asdfghjkl;'zxcvbnm,./~QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?",
  },
  {
    cyr = "ґйцукенгшщзхїфівапролджєячсмитьбю.ҐЙЦУКЕНГШЩЗХЇФІВАПРОЛДЖЄЯЧСМИТЬБЮ,",
    lat = "\\qwertyuiop[]asdfghjkl;'zxcvbnm,./|QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?",
  },
}

local function build_char_map(from, to)
  local result = {}
  local from_chars = vim.fn.split(from, "\\zs")
  local to_chars = vim.fn.split(to, "\\zs")

  assert(#from_chars == #to_chars, "layout tables must be the same length")

  for i, lhs in ipairs(from_chars) do
    result[lhs] = to_chars[i]
  end

  return result
end

local latin_to_layout = {}
local layout_to_latin = {}

for _, pair in ipairs(layout_pairs) do
  latin_to_layout[#latin_to_layout + 1] = build_char_map(pair.lat, pair.cyr)
  layout_to_latin[#layout_to_latin + 1] = build_char_map(pair.cyr, pair.lat)
end

local function translate_char(char, char_map)
  return char_map[char] or char
end

local function translate_token(token, char_map)
  local inner = token:sub(2, -2)
  local lowered = inner:lower()

  if lowered == "leader" or lowered == "localleader" then
    return token
  end

  local prefix, key = inner:match("^(.*%-)([^%-]+)$")
  if prefix and #key == 1 then
    return "<" .. prefix .. translate_char(key, char_map) .. ">"
  end

  return token
end

local function translate_lhs(lhs, char_map)
  local translated = {}
  local i = 1

  while i <= #lhs do
    local char = lhs:sub(i, i)

    if char == "<" then
      local token_end = lhs:find(">", i, true)
      if token_end then
        translated[#translated + 1] = translate_token(lhs:sub(i, token_end), char_map)
        i = token_end + 1
      else
        translated[#translated + 1] = translate_char(char, char_map)
        i = i + 1
      end
    else
      translated[#translated + 1] = translate_char(char, char_map)
      i = i + 1
    end
  end

  return table.concat(translated)
end

local function mode_key(mode)
  if type(mode) == "table" then
    return table.concat(mode, ",")
  end

  return tostring(mode)
end

function M.set(mode, lhs, rhs, opts)
  local seen = {}
  local variants = { lhs }

  if type(lhs) == "string" then
    for _, char_map in ipairs(latin_to_layout) do
      local translated = translate_lhs(lhs, char_map)
      if translated ~= lhs then
        variants[#variants + 1] = translated
      end
    end
  end

  for _, variant in ipairs(variants) do
    local key = mode_key(mode) .. "\0" .. variant
    if not seen[key] then
      seen[key] = true
      vim.keymap.set(mode, variant, rhs, opts)
    end
  end
end

function M.enable_builtin_layout_maps()
  for _, char_map in ipairs(layout_to_latin) do
    for lhs, rhs in pairs(char_map) do
      vim.keymap.set({ "n", "x", "o" }, lhs, rhs, { remap = true, silent = true })
    end
  end
end

function M.expand_specs(specs)
  local expanded = {}
  local seen = {}

  for _, spec in ipairs(specs) do
    expanded[#expanded + 1] = spec

    local lhs = spec[1]
    if type(lhs) == "string" then
      for _, char_map in ipairs(latin_to_layout) do
        local translated = translate_lhs(lhs, char_map)
        local key = translated .. "\0" .. mode_key(spec.mode)

        if translated ~= lhs and not seen[key] then
          seen[key] = true
          local copy = vim.deepcopy(spec)
          copy[1] = translated
          expanded[#expanded + 1] = copy
        end
      end
    end
  end

  return expanded
end

return M
