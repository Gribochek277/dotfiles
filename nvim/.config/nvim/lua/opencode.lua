local M = {}

local port = 4096
local server_url = "http://localhost:" .. port
local cmd = "opencode --port " .. port
local response_buf_name = "opencode-response"
local spinner_ns = vim.api.nvim_create_namespace("opencode-implement-spinner")
local last_model

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function ensure_insert_mode()
  vim.defer_fn(function()
    vim.cmd("startinsert")
  end, 50)
end

local function get_node_text(node, buf)
  if not node then return "" end
  return vim.treesitter.get_node_text(node, buf) or ""
end

local function trim_empty_edges(text)
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function on_opencode_win(win)
  vim.keymap.set("t", "<C-h>", "<cmd>wincmd h<CR>", { buffer = win.buf, noremap = true, silent = true })
  vim.keymap.set("t", "<C-j>", "<cmd>wincmd j<CR>", { buffer = win.buf, noremap = true, silent = true })
  vim.keymap.set("t", "<C-k>", "<cmd>wincmd k<CR>", { buffer = win.buf, noremap = true, silent = true })
  vim.keymap.set("t", "<C-l>", "<cmd>wincmd l<CR>", { buffer = win.buf, noremap = true, silent = true })
end

local terminal_opts = {
  position = "right",
  width = math.floor(vim.o.columns * 0.35),
  enter = true,
  title = "OpenCode",
  border = "rounded",
  winfixwidth = true,
  on_win = on_opencode_win,
}

function M.toggle()
  require("snacks.terminal").toggle(cmd, { win = terminal_opts })
  ensure_insert_mode()
end

function M.start()
  require("snacks.terminal").open(cmd, { win = terminal_opts })
  ensure_insert_mode()
end

function M.stop()
  local term = require("snacks.terminal").get(cmd, {
    win = { position = "right", width = math.floor(vim.o.columns * 0.35) },
  })
  if term then term:close() end
end

-- ── Response buffer (used by ask) ──

local function show_response(content)
  local buf = vim.fn.bufnr(response_buf_name)

  if buf == -1 then
    vim.cmd("rightbelow vnew")
    buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, response_buf_name)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].filetype = "markdown"
    vim.keymap.set("n", "q", "<cmd>bdelete<CR>", { buffer = buf, noremap = true, silent = true, desc = "Close response" })
  else
    local win = vim.fn.bufwinnr(buf)
    if win == -1 then
      vim.cmd("rightbelow vnew")
      vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
    else
      vim.api.nvim_set_current_win(vim.fn.win_getid(win))
    end
    vim.bo[buf].modifiable = true
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

-- ── Visual selection extraction ──

local function get_visual_range()
  local buf = vim.api.nvim_get_current_buf()
  local from = vim.api.nvim_buf_get_mark(buf, "<")
  local to = vim.api.nvim_buf_get_mark(buf, ">")

  local has_selection = from[1] > 0 and to[1] > 0
    and not (from[1] == to[1] and from[2] == to[2])

  if not has_selection then
    local cur_line = vim.fn.line(".")
    local line_text = vim.fn.getline(cur_line)
    return {
      from = { cur_line, 0 },
      to = { cur_line, #line_text },
      kind = "char",
      text = line_text,
    }
  end

  if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
    from, to = to, from
  end

  local lines = vim.fn.getline(from[1], to[1])
  local text = table.concat(lines, "\n")

  local kind = (from[1] < to[1]) and "line" or "char"

  return {
    from = from,
    to = to,
    kind = kind,
    text = text,
  }
end

-- ── OpenCode location formatter ──

local function format_location(file, range)
  local abs = vim.fn.fnamemodify(file, ":p")
  local result = abs
  result = result .. ":L" .. range.from[1]
  if range.kind ~= "line" then
    result = result .. ":C" .. (range.from[2] + 1)
  end
  if range.to[1] then
    result = result .. "-L" .. range.to[1]
    if range.kind ~= "line" and range.to[2] then
      result = result .. ":C" .. (range.to[2] + 1)
    end
  end
  return result
end

local function get_comment_above(buf, start_row)
  local comment_lines = {}
  local row = start_row - 1

  while row >= 0 do
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    if line:match("^%s*$") then
      break
    end
    if line:match("^%s*//")
      or line:match("^%s*///")
      or line:match("^%s*#")
      or line:match("^%s*%-%-")
      or line:match("^%s*;%")
      or line:match("^%s*%*")
      or line:match("^%s*/%*")
      or line:match("^%s*%*/")
    then
      table.insert(comment_lines, 1, line)
      row = row - 1
    else
      break
    end
  end

  return trim_empty_edges(table.concat(comment_lines, "\n"))
end

local function is_function_node(node_type)
  return node_type == "function_declaration"
    or node_type == "function_definition"
    or node_type == "function_item"
    or node_type == "function"
    or node_type == "local_function_statement"
    or node_type == "method_definition"
    or node_type == "method_declaration"
    or node_type == "local_function"
    or node_type == "arrow_function"
    or node_type == "anonymous_function"
    or node_type == "func_literal"
    or node_type == "function_expression"
    or node_type == "constructor_declaration"
    or node_type == "interface_method_declaration"
    or node_type == "method_signature"
end

local function extract_signature_text(buf, start_row, body_row, end_row)
  local stop_row = math.min(body_row or end_row or start_row, start_row + 12)
  local lines = vim.api.nvim_buf_get_lines(buf, start_row, stop_row + 1, false)
  local signature_lines = {}
  for _, line in ipairs(lines) do
    signature_lines[#signature_lines + 1] = line
    if line:find("{", 1, true) or line:find("=>", 1, true) then
      break
    end
  end

  local signature = table.concat(signature_lines, "\n")
  signature = signature:gsub("%s*{%s*$", "")
  return trim_empty_edges(signature)
end

local function is_container_node(node_type)
  return node_type == "class_declaration"
    or node_type == "class_definition"
    or node_type == "impl_item"
    or node_type == "namespace_declaration"
    or node_type == "module"
    or node_type == "struct_item"
    or node_type == "interface_declaration"
    or node_type == "object"
    or node_type == "program"
end

local function find_body_node(node)
  if not node then return nil end
  local queue = { node }
  local i = 1
  while queue[i] do
    local current = queue[i]
    i = i + 1
    local node_type = current:type()
    if node_type == "body"
      or node_type == "block"
      or node_type == "statement_block"
      or node_type == "declaration_list"
      or node_type == "block_statement"
    then
      return current
    end
    for child in current:iter_children() do
      queue[#queue + 1] = child
    end
  end
  return nil
end

local function find_function_context()
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then return nil end
  parser:parse()

  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local node = vim.treesitter.get_node({ bufnr = buf, pos = { row, col } })
  if not node and col > 0 then
    node = vim.treesitter.get_node({ bufnr = buf, pos = { row, col - 1 } })
  end
  if not node then return nil end

  local fn_node = node
  while fn_node and not is_function_node(fn_node:type()) do
    fn_node = fn_node:parent()
  end
  if not fn_node then return nil end

  local container = fn_node:parent()
  while container and not is_container_node(container:type()) do
    container = container:parent()
  end

  local start_row, start_col, end_row, end_col = fn_node:range()
  local body_node = find_body_node(fn_node)
  local body_row = start_row
  local body_text = ""
  if body_node then
    local body_start_row, _, body_end_row = body_node:range()
    body_row = body_start_row < body_end_row and (body_start_row + 1) or body_start_row
    body_text = trim_empty_edges(get_node_text(body_node, buf))
  end

  local signature_text = extract_signature_text(buf, start_row, body_row, end_row)
  local doc_comment = get_comment_above(buf, start_row)
  local container_text = container and trim_empty_edges(get_node_text(container, buf)) or ""
  if #container_text > 1200 then
    container_text = container_text:sub(1, 1200) .. "\n..."
  end

  local first_line = vim.api.nvim_buf_get_lines(buf, start_row, start_row + 1, false)[1] or ""
  local name = first_line:match("([%a_][%w_]*)%s*%(") or first_line:match("function%s+([%w_%.:]+)") or "function"

  return {
    name = name,
    signature = signature_text,
    comment = doc_comment,
    container = container_text,
    body = body_text,
    spinner_row = body_row,
    range = {
      from = { start_row + 1, start_col },
      to = { end_row + 1, end_col },
      kind = "char",
      text = signature_text,
    },
  }
end

local function looks_like_function_signature(line)
  local trimmed = vim.trim(line)
  if trimmed == "" then return false end
  if trimmed:match("^if%s*%(") or trimmed:match("^for%s*%(") or trimmed:match("^foreach%s*%(") then
    return false
  end
  if trimmed:match("^while%s*%(") or trimmed:match("^switch%s*%(") or trimmed:match("^catch%s*%(") then
    return false
  end
  if trimmed:match(";$") then return false end
  if not trimmed:find("(", 1, true) then return false end
  return trimmed:match("([%a_][%w_]*)%s*%(") ~= nil
end

local function find_function_context_regex()
  local buf = vim.api.nvim_get_current_buf()
  local total = vim.api.nvim_buf_line_count(buf)
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local start_row

  for row = cursor_row, math.max(0, cursor_row - 15), -1 do
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    if looks_like_function_signature(line) then
      start_row = row
      break
    end
  end

  if not start_row then
    return nil
  end

  local sig_end_row = start_row
  while sig_end_row < math.min(total - 1, start_row + 15) do
    local line = vim.api.nvim_buf_get_lines(buf, sig_end_row, sig_end_row + 1, false)[1] or ""
    if line:find("{", 1, true) or line:find("=>", 1, true) then
      break
    end
    sig_end_row = sig_end_row + 1
  end

  local signature_lines = vim.api.nvim_buf_get_lines(buf, start_row, sig_end_row + 1, false)
  local signature_text = trim_empty_edges(table.concat(signature_lines, "\n"):gsub("%s*{%s*$", ""))
  local name = signature_text:match("([%a_][%w_]*)%s*%(")
  if not name then
    return nil
  end

  local body_row = sig_end_row
  local end_row = sig_end_row
  local sig_text_full = table.concat(signature_lines, "\n")
  if sig_text_full:find("=>", 1, true) then
    end_row = sig_end_row
  else
    local depth = 0
    local started = false
    for row = sig_end_row, total - 1 do
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
      for i = 1, #line do
        local ch = line:sub(i, i)
        if ch == "{" then
          depth = depth + 1
          started = true
          if row == sig_end_row then
            body_row = row + 1
          end
        elseif ch == "}" and started then
          depth = depth - 1
          if depth == 0 then
            end_row = row
            break
          end
        end
      end
      if started and depth == 0 then
        break
      end
    end
  end

  body_row = math.min(body_row, end_row)
  local body_lines = {}
  if body_row <= end_row then
    body_lines = vim.api.nvim_buf_get_lines(buf, body_row, end_row + 1, false)
  end

  return {
    name = name,
    signature = signature_text,
    comment = get_comment_above(buf, start_row),
    container = "",
    body = trim_empty_edges(table.concat(body_lines, "\n")),
    spinner_row = math.min(body_row, total - 1),
    range = {
      from = { start_row + 1, 0 },
      to = { end_row + 1, 0 },
      kind = "char",
      text = signature_text,
    },
  }
end

local function symbol_contains(symbol, row)
  return symbol.range
    and symbol.range.start
    and symbol.range["end"]
    and symbol.range.start.line <= row
    and symbol.range["end"].line >= row
end

local function flatten_document_symbols(symbols, acc, parent_name)
  acc = acc or {}
  for _, symbol in ipairs(symbols or {}) do
    symbol._parent_name = parent_name
    acc[#acc + 1] = symbol
    if symbol.children then
      flatten_document_symbols(symbol.children, acc, symbol.name)
    end
  end
  return acc
end

local function find_function_context_lsp()
  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf })
  if #clients == 0 then return nil end

  local params = vim.lsp.util.make_text_document_params(buf)
  local responses = vim.lsp.buf_request_sync(buf, "textDocument/documentSymbol", params, 800)
  if not responses then return nil end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local function_kinds = {
    [vim.lsp.protocol.SymbolKind.Method] = true,
    [vim.lsp.protocol.SymbolKind.Function] = true,
    [vim.lsp.protocol.SymbolKind.Constructor] = true,
  }

  for _, response in pairs(responses) do
    local result = response.result
    if type(result) == "table" and result[1] and result[1].range then
      local symbols = flatten_document_symbols(result)
      for _, symbol in ipairs(symbols) do
        if function_kinds[symbol.kind] and symbol_contains(symbol, row) then
          local start_row = symbol.range.start.line
          local end_row = symbol.range["end"].line
          local signature_text = extract_signature_text(buf, start_row, start_row + 1, end_row)
          local doc_comment = get_comment_above(buf, start_row)
          local body_row = math.min(start_row + 1, end_row)
          local body_lines = vim.api.nvim_buf_get_lines(buf, body_row, end_row + 1, false)
          local body_text = trim_empty_edges(table.concat(body_lines, "\n"))

          return {
            name = symbol.name,
            signature = signature_text,
            comment = doc_comment,
            container = symbol._parent_name or "",
            body = body_text,
            spinner_row = body_row,
            range = {
              from = { start_row + 1, symbol.range.start.character or 0 },
              to = { end_row + 1, symbol.range["end"].character or 0 },
              kind = "char",
              text = signature_text,
            },
          }
        end
      end
    end
  end

  return nil
end

local function get_models()
  local result = vim.fn.system({ "opencode", "models" })
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to load opencode models"
  end
  local models = {}
  for _, line in ipairs(vim.split(result, "\n", { trimempty = true })) do
    local model = vim.trim(line)
    if model ~= "" and not model:match("^%[TokenCosts%]") then
      models[#models + 1] = model
    end
  end
  if #models == 0 then
    return nil, "No opencode models found"
  end
  return models
end

local function select_model_popup(models, callback)
  local width = 0
  for _, model in ipairs(models) do
    width = math.max(width, #model)
  end
  width = math.max(width + 4, 40)
  local height = math.min(#models + 2, 14)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " OpenCode Models ",
    title_pos = "center",
  })

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "opencode-model-select"
  vim.wo[win].cursorline = true

  local selected = 1
  if last_model then
    for i, model in ipairs(models) do
      if model == last_model then
        selected = i
        break
      end
    end
  end

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.bo[buf].modifiable = true
    local lines = {}
    for i, model in ipairs(models) do
      local prefix = i == selected and "> " or "  "
      lines[#lines + 1] = prefix .. model
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_win_set_cursor(win, { selected, 0 })
  end

  local closed = false
  local function close(choice)
    if closed then return end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    callback(choice)
  end

  local function move(delta)
    selected = ((selected - 1 + delta) % #models) + 1
    render()
  end

  local opts = { buffer = buf, nowait = true, silent = true, noremap = true }
  vim.keymap.set("n", "j", function() move(1) end, opts)
  vim.keymap.set("n", "k", function() move(-1) end, opts)
  vim.keymap.set("n", "<Down>", function() move(1) end, opts)
  vim.keymap.set("n", "<Up>", function() move(-1) end, opts)
  vim.keymap.set("n", "<CR>", function() close(models[selected]) end, opts)
  vim.keymap.set("n", "q", function() close(nil) end, opts)
  vim.keymap.set("n", "<Esc>", function() close(nil) end, opts)

  vim.api.nvim_create_autocmd("WinClosed", {
    once = true,
    callback = function(args)
      if tostring(win) == args.match then
        close(nil)
      end
    end,
  })

  render()
end

local function pick_model(callback)
  local models, err = get_models()
  if not models then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  select_model_popup(models, function(choice)
    if not choice then return end
    last_model = choice
    callback(choice)
  end)
end

local function start_spinner(buf, row)
  local frame = 1
  local timer = vim.uv.new_timer()
  if not timer then
    return function() end
  end

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.api.nvim_buf_clear_namespace(buf, spinner_ns, row, row + 1)
    vim.api.nvim_buf_set_extmark(buf, spinner_ns, row, 0, {
      virt_text = { { "implementing " .. spinner_frames[frame], "Comment" } },
      virt_text_pos = "eol",
    })
    frame = (frame % #spinner_frames) + 1
  end

  render()
  timer:start(100, 100, vim.schedule_wrap(render))

  return function()
    timer:stop()
    timer:close()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, spinner_ns, row, row + 1)
    end
  end
end

local function run_opencode_async(args, on_exit)
  vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      on_exit(result)
    end)
  end)
end

-- ── Server API (curl to local OpenCode TUI) ──

local function tui_request(body)
  if vim.fn.executable("curl") == 0 then
    vim.notify("curl not found, cannot communicate with opencode TUI", vim.log.levels.ERROR)
    return false
  end

  local url = server_url .. "/tui/publish"
  local json = vim.fn.json_encode(body)
  local args = {
    "curl", "-s", "-S", "--fail-with-body",
    "-X", "POST",
    "-H", "Content-Type: application/json",
    "-d", json,
    "--max-time", "3",
    url,
  }

  local result = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    local clean = result:gsub("\27%[[%d;]*m", "")
    vim.notify("opencode TUI request failed: " .. clean, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function tui_append_prompt(text)
  return tui_request({
    type = "tui.prompt.append",
    properties = { text = text },
  })
end

local function tui_execute_command(command)
  return tui_request({
    type = "tui.command.execute",
    properties = { command = command },
  })
end

-- ── Send selection to opencode TUI ──

function M.send_selection(submit)
  local range = get_visual_range()
  if not range then return end

  local file = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local loc = format_location(file, range)

  local text = string.format(
    "```%s\n%s\n```\n%s",
    vim.fn.expand("%:e"),
    range.text,
    loc
  )

  if not tui_append_prompt(text) then
    vim.notify("Could not reach opencode TUI. Is it running?", vim.log.levels.WARN)
    return
  end

  if submit then
    tui_execute_command("prompt.submit")
  end
end

-- ── run_opencode (used by ask) ──

local function run_opencode(file, prompt, agent)
  local args = { "opencode", "run" }
  if agent then
    vim.list_extend(args, { "--agent", agent })
  end
  if file and file ~= "" and vim.fn.filereadable(file) == 1 then
    vim.list_extend(args, { "-f", file })
  end
  vim.list_extend(args, { "--", prompt })

  vim.cmd("redraw")
  vim.api.nvim_echo({ { "Running opencode...", "MoreMsg" } }, false, {})

  local result = vim.fn.system(args)
  vim.cmd("redraw")

  if vim.v.shell_error ~= 0 then
    vim.notify("opencode exited with code " .. vim.v.shell_error, vim.log.levels.ERROR)
    return nil
  end

  if not result:match("%S") then
    vim.notify("Empty response from opencode", vim.log.levels.WARN)
    return nil
  end

  local clean = result:gsub("\27%[[%d;]*m", "")
  local lines = vim.split(clean, "\n")
  local start = 0
  for i, line in ipairs(lines) do
    if line:match("^> ") then
      start = i + 1
      break
    end
  end
  if start > 0 then
    lines = { unpack(lines, start) }
  end
  return vim.trim(table.concat(lines, "\n"))
end

-- ── Ask (inline question → response buffer) ──

function M.ask()
  if vim.fn.executable("opencode") == 0 then
    vim.notify("opencode not found in PATH", vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)

  local selection = ""
  local range = get_visual_range()
  if range and range.from[1] > 0 and range.to[1] > 0 then
    selection = "\n\n```\n" .. range.text .. "\n```"
  end

  local input = vim.fn.input("Ask opencode: ")
  if input == "" then return end

  local prompt = input .. selection

  local result = run_opencode(file, prompt, "plan")
  if result then
    show_response(result)
  end
end

-- ── Edit (replace range via opencode run, then refresh) ──

function M.edit()
  if vim.fn.executable("opencode") == 0 then
    vim.notify("opencode not found in PATH", vim.log.levels.ERROR)
    return
  end

  local range = get_visual_range()
  if not range then
    vim.notify("No visual selection", vim.log.levels.WARN)
    return
  end

  local file = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  if file == "" then
    vim.notify("Buffer has no file path", vim.log.levels.ERROR)
    return
  end

  local input = vim.fn.input("Edit with opencode: ")
  if input == "" then return end

  local prompt = string.format(
    "At lines %d-%d of this file, %s:\n```\n%s\n```",
    range.from[1],
    range.to[1],
    input,
    range.text
  )

  local args = { "opencode", "run" }
  if file and file ~= "" and vim.fn.filereadable(file) == 1 then
    vim.list_extend(args, { "-f", file })
  end
  vim.list_extend(args, { "--", prompt })

  vim.cmd("redraw")
  vim.api.nvim_echo({ { "Running opencode edit...", "MoreMsg" } }, false, {})

  vim.fn.system(args)
  vim.cmd("redraw")

  if vim.v.shell_error ~= 0 then
    vim.notify("opencode exited with code " .. vim.v.shell_error, vim.log.levels.ERROR)
    return
  end

  vim.cmd("checktime")
  vim.notify("Edit applied by opencode", vim.log.levels.INFO)
end

function M.implement_function()
  if vim.fn.executable("opencode") == 0 then
    vim.notify("opencode not found in PATH", vim.log.levels.ERROR)
    return
  end

  local ctx = find_function_context() or find_function_context_lsp() or find_function_context_regex()
  if not ctx then
    vim.notify("Could not find function under cursor", vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    vim.notify("Buffer has no file path", vim.log.levels.ERROR)
    return
  end

  if vim.bo[buf].modified then
    vim.cmd("write")
  end

  pick_model(function(model)
    local location = format_location(file, ctx.range)
    local summary = table.concat({
      "Function: " .. ctx.name,
      "Range: " .. location,
      "Model: " .. model,
    }, "\n")

    if vim.fn.confirm(summary .. "\n\nImplement this function?", "&Implement\n&Cancel", 1) ~= 1 then
      return
    end

    local prompt = table.concat({
      "Implement the function at " .. location .. ".",
      "",
      "Requirements:",
      "- Implement only this function body",
      "- Keep the existing signature unchanged",
      "- Preserve surrounding style and conventions",
      "- Use the function comment and enclosing container as context",
      "- Do not modify unrelated code",
      "- If the body contains placeholder code, replace it with a real implementation",
      "",
      "Function signature:",
      ctx.signature ~= "" and ctx.signature or "none",
      "",
      "Function comment:",
      ctx.comment ~= "" and ctx.comment or "none",
      "",
      "Enclosing context:",
      ctx.container ~= "" and ctx.container or "none",
      "",
      "Current function body:",
      ctx.body ~= "" and ctx.body or "empty",
    }, "\n")

    local stop_spinner = start_spinner(buf, ctx.spinner_row)
    local args = { "opencode", "run", "--model", model }
    if vim.fn.filereadable(file) == 1 then
      vim.list_extend(args, { "-f", file })
    end
    vim.list_extend(args, { "--", prompt })

    run_opencode_async(args, function(result)
      stop_spinner()
      if result.code ~= 0 then
        local stderr = trim_empty_edges(result.stderr or "")
        local stdout = trim_empty_edges(result.stdout or "")
        local msg = stderr ~= "" and stderr or stdout ~= "" and stdout or ("opencode exited with code " .. result.code)
        vim.notify(msg, vim.log.levels.ERROR)
        return
      end
      vim.cmd("checktime")
      vim.notify("Function implementation applied", vim.log.levels.INFO)
    end)
  end)
end

return M
