--- Non-blocking pi agent runner for Neovim.
---
--- Every request spawns its own `pi --mode rpc` job, so several requests
--- can run at once. Progress is surfaced in the status line and via
--- transient vim.notify messages — never in a window over the buffer.
--- Extensions are disabled (`--no-extensions`) because the agent runs
--- non-interactively and some extensions block waiting for user input.
local M = {}

local SYSTEM_PROMPT =
  [[You are the pi coding agent running inside Neovim. The user has sent a request and cannot reply until it completes. Do not ask questions or request clarification — act immediately and complete the task on your own.

The Context below comes from the user's current Neovim buffer and may be newer than the on-disk file. Treat it as the source of truth for that file's content. Do not re-read such files just to verify them before editing; base edits on the provided buffer content whenever possible.]]

local EMPTY_FILE_NOTE =
  [[NOTE: The file is currently empty. Create or populate it directly by applying the necessary edits.]]

local CONFIG = {
  binary = "pi",
  extensions = false, -- non-interactive run: extension tools may block on input
  skills = true,
  thinking = "off",
  system_prompt = nil,
  context = {
    max_bytes = 24000,
    ask = { surrounding_lines = 80 },
    selection = { surrounding_lines = 40 },
    diagnostics = { enabled = false },
  },
}

local next_id = 0
local sessions = {} -- active and finished, newest last
local log_lines = {}
local log_buf = nil

local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spin_idx = 1
local spinner_timer = nil

function M.setup(opts)
  CONFIG = vim.tbl_deep_extend("force", CONFIG, opts or {})
end

--- Sessions still waiting for their agent to finish.
local function active_sessions()
  local out = {}
  for _, s in ipairs(sessions) do
    if not s.ended_at then
      out[#out + 1] = s
    end
  end
  return out
end

--- Force lualine to re-render the busy indicator.
local function lualine_refresh()
  pcall(function()
    require("lualine").refresh()
  end)
end

--- Stop the spinner timer (statusline goes static when idle).
local function stop_spinner()
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
end

--- Keep the spinner turning while requests are running.
local function ensure_spinner()
  if spinner_timer then
    return
  end
  spinner_timer = vim.loop.new_timer()
  spinner_timer:start(
    0,
    120,
    vim.schedule_wrap(function()
      if #active_sessions() == 0 then
        stop_spinner()
        spin_idx = 1
        lualine_refresh()
        return
      end
      spin_idx = (spin_idx % #SPINNER) + 1
      lualine_refresh()
    end)
  )
end

local function timestamp()
  return os.date "%H:%M:%S"
end

--- Append a line to the rolling session log and live-update :PiLog.
local function log(line)
  log_lines[#log_lines + 1] = "[" .. timestamp() .. "] " .. line
  if log_buf and vim.api.nvim_buf_is_valid(log_buf) then
    vim.bo[log_buf].modifiable = true
    vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, log_lines)
    vim.bo[log_buf].modifiable = false
  end
end

local function truncate(text, max_bytes)
  if #text <= max_bytes then
    return text, false
  end
  return text:sub(1, max_bytes), true
end

local function buffer_is_file_backed(bufnr)
  return vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

--- Disk signature of a file, or nil if it does not exist.
local function file_signature(path)
  local stat = vim.loop.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil
  end
  local mt = stat.mtime
  return { size = stat.size, mtime_sec = mt and mt.sec or 0, mtime_nsec = mt and mt.nsec or 0 }
end

--- Snapshot disk signatures of every loaded file-backed buffer.
local function snapshot_files()
  local snap = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and buffer_is_file_backed(bufnr) then
      local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
      snap[path] = file_signature(path)
    end
  end
  return snap
end

--- Reload one buffer from disk, preserving the window view.
--- A buffer with unsaved local changes is left alone (warned about).
local function reload_buffer(bufnr, path)
  if vim.bo[bufnr].modified then
    vim.notify(
      "pi: file changed on disk but buffer has unsaved changes: " .. vim.fn.fnamemodify(path, ":t"),
      vim.log.levels.WARN
    )
    return false
  end
  local ok = pcall(function()
    vim.api.nvim_buf_call(bufnr, function()
      local view = vim.api.nvim_get_current_buf() == bufnr and vim.fn.winsaveview() or nil
      vim.cmd "silent edit!"
      if view then
        vim.fn.winrestview(view)
      end
    end)
  end)
  if ok then
    log("↻ reloaded " .. vim.fn.fnamemodify(path, ":t"))
  end
  return ok
end

--- Reload every loaded buffer whose file changed on disk since the
--- snapshot taken before the request started.
local function reload_changed(snapshot)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and buffer_is_file_backed(bufnr) then
      local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
      local before, after = snapshot[path], file_signature(path)
      if
        before
        and after
        and (before.size ~= after.size or before.mtime_sec ~= after.mtime_sec or before.mtime_nsec ~= after.mtime_nsec)
      then
        reload_buffer(bufnr, path)
      end
    end
  end
end

--- Build the pi command for the currently selected model.
local function build_cmd()
  local entry = require("pi_models").entry()
  local cmd = { CONFIG.binary, "--mode", "rpc", "--no-session" }
  if not CONFIG.extensions then
    cmd[#cmd + 1] = "--no-extensions"
  end
  if not CONFIG.skills then
    cmd[#cmd + 1] = "--no-skills"
  end
  if entry.provider then
    cmd[#cmd + 1] = "--provider"
    cmd[#cmd + 1] = entry.provider
  end
  if entry.model then
    cmd[#cmd + 1] = "--model"
    cmd[#cmd + 1] = entry.model
  end
  if CONFIG.thinking ~= "off" then
    cmd[#cmd + 1] = "--thinking"
    cmd[#cmd + 1] = CONFIG.thinking
  end
  if CONFIG.system_prompt then
    cmd[#cmd + 1] = "--system-prompt"
    cmd[#cmd + 1] = CONFIG.system_prompt
  end
  cmd[#cmd + 1] = "--append-system-prompt"
  cmd[#cmd + 1] = SYSTEM_PROMPT
  return cmd
end

--- Turn a raw pi RPC event into a session update, or nil to ignore it.
local function normalize(event)
  local t = event.type
  if t == "message_update" then
    local d = event.assistantMessageEvent
    if d and d.type == "thinking_delta" then
      return { type = "progress" }
    end
    if d and d.type == "error" then
      return { type = "error", message = d.reason or "unknown error" }
    end
    return nil
  end
  if t == "message_end" and event.message and event.message.role == "assistant" then
    local parts = {}
    local content = event.message.content
    if type(content) == "table" then
      for _, c in ipairs(content) do
        if type(c) == "table" and c.type == "text" and c.text then
          parts[#parts + 1] = c.text
        end
      end
    end
    return { type = "assistant_text", text = table.concat(parts, "\n") }
  end
  if t == "tool_execution_start" then
    return { type = "tool_start", tool = event.toolName or "unknown" }
  end
  if t == "tool_execution_end" then
    return { type = "tool_end" }
  end
  if t == "agent_end" then
    return { type = "done" }
  end
  if t == "response" and event.success == false then
    return { type = "error", message = event.error or "unknown error" }
  end
  return nil
end

local function finish(session, status, detail)
  if session.ended_at then
    return
  end
  session.ended_at = vim.loop.hrtime()
  if session.process and not session.process:is_closing() then
    pcall(session.process.write, session.process, nil) -- close stdin
  end

  local duration = string.format("%.1fs", (session.ended_at - session.started_at) / 1e9)
  if status == "done" then
    log(string.format("✓ done %s (%s)", session.model_desc, duration))
    local preview = session.last_text and session.last_text:gsub("%s+", " "):sub(1, 220) or ""
    if preview ~= "" then
      vim.notify(preview, vim.log.levels.INFO, { title = "pi done" })
    else
      vim.notify("pi: done (" .. duration .. ")", vim.log.levels.INFO, { title = "pi done" })
    end
    if session.file_snapshot then
      reload_changed(session.file_snapshot)
    end
  elseif status == "cancelled" then
    log(string.format("✕ cancelled %s", session.model_desc))
    vim.notify("pi: cancelled", vim.log.levels.WARN, { title = "pi cancelled" })
  else
    local err = detail or "unknown error"
    log("✗ error: " .. err)
    vim.notify("pi: " .. err, vim.log.levels.ERROR, { title = "pi error" })
  end
  if session.on_done then
    pcall(session.on_done, session)
  end
  if #active_sessions() == 0 then
    stop_spinner()
    spin_idx = 1
  end
  lualine_refresh()
end

--- Dispatch a normalized RPC event into session state.
local function handle_event(session, event)
  if event.type == "tool_start" then
    session.status = "tool"
    session.active_tool = event.tool
    log("▲ " .. event.tool)
    lualine_refresh()
  elseif event.type == "tool_end" then
    session.status = "running"
    session.active_tool = nil
    lualine_refresh()
  elseif event.type == "assistant_text" then
    session.last_text = event.text
  elseif event.type == "done" then
    session.saw_terminal = true
    finish(session, "done")
  elseif event.type == "error" then
    session.saw_terminal = true
    finish(session, "error", event.message)
  end
end

--- Feed a chunk of RPC output; events are newline-delimited JSON.
local function feed(session, chunk)
  if session.ended_at or not chunk or chunk == "" then
    return
  end
  session.tail = (session.tail or "") .. chunk
  while true do
    local newline = session.tail:find("\n", 1, true)
    if not newline then
      break
    end
    local line = session.tail:sub(1, newline - 1)
    session.tail = session.tail:sub(newline + 1)
    if line ~= "" then
      local ok, event = pcall(vim.json.decode, line)
      if ok and type(event) == "table" then
        local normalized = normalize(event)
        if normalized then
          handle_event(session, normalized)
        end
      end
    end
  end
end

--- Context collection -------------------------------------------------------

local function block(label, text)
  return string.format("%s:\n```\n%s\n```", label, text)
end

local function buffer_is_empty(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    if line:match "%S" then
      return false
    end
  end
  return true
end

local SEVERITY = { [1] = "ERROR", [2] = "WARN", [3] = "INFO", [4] = "HINT" }

--- Optional diagnostics block for the buffer (or selection range).
local function diagnostics_text(bufnr, range)
  if not CONFIG.context.diagnostics.enabled then
    return nil
  end
  local diags = vim.diagnostic.get(bufnr)
  local items = {}
  for _, d in ipairs(diags) do
    local line = (d.lnum or 0) + 1
    if not range or (line >= range.start and line <= range["end"]) then
      items[#items + 1] =
        string.format("- line %d:%d: %s [%s]", line, (d.col or 0) + 1, d.message, SEVERITY[d.severity] or "?")
    end
  end
  if vim.tbl_isempty(items) then
    return nil
  end
  local text, trimmed = truncate(table.concat(items, "\n"), CONFIG.context.max_bytes)
  return block("Diagnostics", text), trimmed
end

local function buffer_context(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local n = CONFIG.context.ask.surrounding_lines
  local start_line, end_line = math.max(1, cursor - n), math.min(#lines, cursor + n)
  local near, trimmed =
    truncate(table.concat(vim.list_slice(lines, start_line, end_line), "\n"), CONFIG.context.max_bytes)

  local parts = {
    string.format("File: %s", vim.api.nvim_buf_get_name(bufnr)),
    string.format("Cwd: %s", vim.fn.getcwd()),
    string.format("Current line: %d", cursor),
    "NOTE: The context below comes from the current Neovim buffer and may include unsaved changes; treat it as the source of truth for this file's content.",
    block(string.format("Nearby context (lines %d-%d)", start_line, end_line), near),
  }
  if trimmed then
    parts[#parts + 1] = string.format("NOTE: Context trimmed to %d bytes.", CONFIG.context.max_bytes)
  end
  local diags, diag_trimmed = diagnostics_text(bufnr)
  if diags then
    parts[#parts + 1] = diags
    if diag_trimmed then
      parts[#parts + 1] = string.format("NOTE: Diagnostics trimmed to %d bytes.", CONFIG.context.max_bytes)
    end
  end
  if buffer_is_empty(bufnr) then
    parts[#parts + 1] = EMPTY_FILE_NOTE
  end
  return table.concat(parts, "\n\n")
end

local function visual_range()
  local s, e = vim.fn.getpos "'<", vim.fn.getpos "'>"
  local start_line, end_line = s[2], e[2]
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  return { start = start_line, ["end"] = end_line }
end

local function selection_context(bufnr, range)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local n = CONFIG.context.selection.surrounding_lines
  local before = math.max(1, range.start - n)
  local after = math.min(#lines, range["end"] + n)
  local near = table.concat(vim.api.nvim_buf_get_lines(bufnr, before - 1, after, false), "\n")
  local selected = table.concat(vim.api.nvim_buf_get_lines(bufnr, range.start - 1, range["end"], false), "\n")
  local near_text, near_trimmed = truncate(near, CONFIG.context.max_bytes)
  local selected_text, selected_trimmed = truncate(selected, CONFIG.context.max_bytes)

  local parts = {
    string.format("File: %s", vim.api.nvim_buf_get_name(bufnr)),
    string.format("Cwd: %s", vim.fn.getcwd()),
    string.format("Selected lines: %d-%d", range.start, range["end"]),
    "NOTE: The context below comes from the current Neovim buffer and may include unsaved changes; treat it as the source of truth for this file's content.",
    block("Selected content", selected_text),
    block(string.format("Nearby context (lines %d-%d)", before, after), near_text),
  }
  if near_trimmed or selected_trimmed then
    parts[#parts + 1] = string.format("NOTE: Context trimmed to %d bytes.", CONFIG.context.max_bytes)
  end
  local diags, diag_trimmed = diagnostics_text(bufnr, range)
  if diags then
    parts[#parts + 1] = diags
    if diag_trimmed then
      parts[#parts + 1] = string.format("NOTE: Diagnostics trimmed to %d bytes.", CONFIG.context.max_bytes)
    end
  end
  if buffer_is_empty(bufnr) then
    parts[#parts + 1] = EMPTY_FILE_NOTE
  end
  return table.concat(parts, "\n\n")
end

local function prompt_label(bufnr, range)
  local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
  local label = file ~= "" and file or "buffer"
  if range then
    label = string.format("%s:%d-%d", label, range.start, range["end"])
  end
  return string.format("ask pi (%s): ", label)
end

--- Public API ---------------------------------------------------------------

--- Runs a request. opts: message, bufnr, range, build_context, cmd, on_done.
function M.ask(opts)
  opts = opts or {}
  local message = opts.message
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  if not message or message == "" then
    vim.notify("pi: no message provided", vim.log.levels.ERROR)
    return
  end

  local context = ""
  if opts.build_context then
    context = opts.build_context()
  elseif opts.range then
    context = selection_context(bufnr, opts.range)
  else
    context = buffer_context(bufnr)
  end
  if context ~= "" then
    message = message .. "\n\nContext:\n" .. context
  end

  local entry = require("pi_models").entry()
  next_id = next_id + 1
  local session = {
    id = next_id,
    status = "running",
    message = message,
    model_desc = entry.provider and (entry.provider .. "/" .. entry.model) or "pi default",
    source_path = vim.api.nvim_buf_get_name(bufnr),
    file_snapshot = snapshot_files(),
    tail = "",
    last_text = nil,
    active_tool = nil,
    saw_terminal = false,
    started_at = vim.loop.hrtime(),
    ended_at = nil,
    process = nil,
    on_done = opts.on_done,
  }
  sessions[#sessions + 1] = session

  local short = message:gsub("%s+", " "):sub(1, 80)
  log(string.format("▶ %s — %s", session.model_desc, short))
  lualine_refresh()
  ensure_spinner()

  local payload = vim.json.encode { type = "prompt", message = message } .. "\n"
  local cmd = opts.cmd or build_cmd()

  local ok, process = pcall(
    vim.system,
    cmd,
    {
      text = true,
      stdin = true,
      stdout = vim.schedule_wrap(function(err, data)
        if err then
          return
        end
        feed(session, data)
      end),
      stderr = vim.schedule_wrap(function(err, data)
        if err then
          return
        end
        local line = data and data:gsub("[\r\n]+$", "") or ""
        if line ~= "" then
          log("! " .. line)
        end
      end),
    },
    vim.schedule_wrap(function(result)
      if session.ended_at then
        return
      end
      if session.tail and session.tail ~= "" then
        feed(session, "\n")
      end
      if session.ended_at then
        return
      end
      if result.code ~= 0 and result.code ~= 143 then
        finish(session, "error", "pi exited with code " .. result.code)
      elseif not session.saw_terminal then
        finish(session, "error", "pi exited before completing the request")
      else
        finish(session, "done")
      end
    end)
  )

  if not ok then
    finish(session, "error", tostring(process))
    return
  end
  session.process = process
  local wrote, write_err = pcall(process.write, process, payload)
  if not wrote then
    pcall(process.kill, process, 15)
    finish(session, "error", tostring(write_err))
  end
end

--- Prompt for a request with the current buffer as context.
function M.ask_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if not buffer_is_file_backed(bufnr) then
    vim.notify("pi: requires a file buffer", vim.log.levels.ERROR)
    return
  end
  vim.ui.input({ prompt = prompt_label(bufnr) }, function(input)
    if input and input ~= "" then
      M.ask { message = input, bufnr = bufnr }
    end
  end)
end

--- Prompt for a request with the current visual selection as context.
function M.ask_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  if not buffer_is_file_backed(bufnr) then
    vim.notify("pi: requires a file buffer", vim.log.levels.ERROR)
    return
  end
  local range = visual_range()
  vim.ui.input({ prompt = prompt_label(bufnr, range) }, function(input)
    if input and input ~= "" then
      M.ask { message = input, bufnr = bufnr, range = range }
    end
  end)
end

--- Cancel every running request.
function M.cancel_all()
  local active = active_sessions()
  if #active == 0 then
    vim.notify("pi: nothing running", vim.log.levels.INFO)
    return
  end
  for _, session in ipairs(active) do
    if session.process and not session.process:is_closing() then
      pcall(session.process.kill, session.process, 15)
    end
    finish(session, "cancelled")
  end
end

--- Number of requests currently running.
function M.active_count()
  return #active_sessions()
end

--- Empty string when idle, else a busy indicator for lualine with an
--- animated spinner: "✦ ⠋" (working), "✦ ⠋ bash" (tool), "✦2 ⠋ bash,edit"
--- (parallel runs). The frames swap while a spinner timer is active.
function M.busy_component()
  local active = active_sessions()
  if #active == 0 then
    return ""
  end
  local tools, seen = {}, {}
  for _, session in ipairs(active) do
    local tool = session.status == "tool" and session.active_tool or nil
    if tool and not seen[tool] then
      seen[tool] = true
      tools[#tools + 1] = tool
    end
  end
  local parts = { #active > 1 and ("✦" .. #active) or "✦", SPINNER[spin_idx] or SPINNER[1] }
  if #tools > 0 then
    parts[#parts + 1] = table.concat(tools, ",")
  end
  return table.concat(parts, " ")
end

--- Open (or focus) the rolling session log buffer.
function M.log()
  if log_buf and vim.api.nvim_buf_is_valid(log_buf) then
    vim.api.nvim_set_current_buf(log_buf)
    return
  end
  log_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[log_buf].buftype = "nofile"
  vim.bo[log_buf].bufhidden = "wipe"
  vim.bo[log_buf].swapfile = false
  vim.bo[log_buf].modifiable = false
  vim.api.nvim_buf_set_name(log_buf, "pi-log://")
  vim.keymap.set("n", "q", "<cmd>bdelete<CR>", { buffer = log_buf, nowait = true })
  vim.api.nvim_set_current_buf(log_buf)
  if not vim.tbl_isempty(log_lines) then
    vim.bo[log_buf].modifiable = true
    vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, log_lines)
    vim.bo[log_buf].modifiable = false
  end
  vim.cmd "normal! G"
end

return M
