--- Client for the pi-name extension: discover and connect to running pi
--- agent instances (named via --pi-name / $PI_NAME). A connected agent
--- becomes the target for ask/ref (pi_agent routes to it); connection
--- state is shown in lualine as "π@name".
---
--- Instances live as unix sockets in ~/.pi/agent/pi-name/<name>.sock,
--- created by the pi-name extension in TUI sessions only. Protocol:
--- one JSON object per line (see the extension for the reference).
local M = {}

local REGISTRY_DIR = vim.fn.expand "~/.pi/agent/pi-name"
local HELLO_TIMEOUT_MS = 800
local SPAWN_POLL_MS = 300
local SPAWN_POLL_TRIES = 40 -- ~12 s (pi startup with extensions/MCP takes a while)

local conn = nil -- { handle, buf, info, busy, hello_done, queue, last_text }

--- opts: registry_dir (socket dir, for tests)
function M.setup(opts)
  if opts and opts.registry_dir then
    REGISTRY_DIR = opts.registry_dir
  end
end

local function lualine_refresh()
  pcall(function()
    require("lualine").refresh()
  end)
end

local function pi_log(line)
  local ok, agent = pcall(require, "pi_agent")
  if ok and agent.append_log then
    agent.append_log(line)
  end
end

local function conn_name(c)
  return c.info and c.info.name or "?"
end

--- Handle one protocol line coming from a connected instance.
local function handle_line(c, obj)
  if obj.type == "hello" then
    c.hello_done = true
    c.info = {
      name = obj.name,
      cwd = obj.cwd,
      model = obj.model,
      sessionName = obj.sessionName,
    }
    c.busy = obj.busy and true or false
    while #c.queue > 0 do
      pcall(c.handle.write, c.handle, table.remove(c.queue, 1), nil)
    end
    vim.notify("pi: connected to " .. obj.name .. " (" .. obj.model .. ")", vim.log.levels.INFO, {
      title = "pi connect",
    })
    pi_log("◆ @" .. obj.name)
    lualine_refresh()
  elseif obj.type == "error" then
    vim.notify("pi @" .. conn_name(c) .. ": " .. (obj.message or "error"), vim.log.levels.ERROR, {
      title = "pi error",
    })
    if c.hello_done then
      return
    end
    -- Failed handshake: drop the connection.
    if conn == c then
      M.disconnect()
    end
  elseif obj.type == "agent_start" then
    c.busy = true
    lualine_refresh()
  elseif obj.type == "agent_end" then
    c.busy = false
    local name = conn_name(c)
    local text = c.last_text
    c.last_text = nil
    if text and text ~= "" then
      vim.notify(text:gsub("%s+", " "):sub(1, 220), vim.log.levels.INFO, {
        title = "pi @" .. name .. " done",
      })
    else
      vim.notify("pi @" .. name .. ": done", vim.log.levels.INFO, { title = "pi @" .. name .. " done" })
    end
    pi_log("✓ done @" .. name)
    lualine_refresh()
  elseif obj.type == "message_end" and obj.message and obj.message.role == "assistant" then
    local parts = {}
    for _, part in ipairs(obj.message.content or {}) do
      if part.type == "text" and part.text then
        parts[#parts + 1] = part.text
      end
    end
    local text = table.concat(parts, "\n")
    if text ~= "" then
      c.last_text = text
    end
  elseif obj.type == "tool_execution_start" then
    pi_log("▲ @" .. conn_name(c) .. " " .. (obj.toolName or "?"))
  end
end

local function read_loop(c)
  return function(_, data)
    if conn ~= c then
      return
    end
    if not data then
      -- The instance closed the connection (pi exited or crashed).
      M.disconnect()
      vim.notify("pi: connection to " .. conn_name(c) .. " lost", vim.log.levels.WARN, {
        title = "pi connect",
      })
      return
    end
    c.buf = c.buf .. data
    local idx
    while true do
      idx = c.buf:find("\n", 1, true)
      if not idx then
        break
      end
      local line = c.buf:sub(1, idx - 1):gsub("\r$", "")
      c.buf = c.buf:sub(idx + 1)
      if line == "" then
        goto continue
      end
      local ok, obj = pcall(vim.json.decode, line)
      if ok and type(obj) == "table" then
        handle_line(c, obj)
        if conn ~= c then
          return
        end
      end
      ::continue::
    end
  end
end

--- Handshake an instance; returns its info or nil (dead / timeout / error).
function M.hello(path)
  local handle = vim.uv.new_pipe()
  local state = { done = false, info = nil }
  local timer = vim.uv.new_timer()
  local buf = ""

  local function finish()
    if state.done then
      return
    end
    state.done = true
    pcall(timer.stop, timer)
    pcall(timer.close, timer)
    if not handle:is_closing() then
      pcall(handle.close, handle)
    end
  end

  timer:start(HELLO_TIMEOUT_MS, 0, function()
    finish()
  end)

  pcall(handle.connect, handle, path, function(err)
    if err then
      finish()
      return
    end
    handle:read_start(function(_, data)
      if not data or state.done then
        return
      end
      buf = buf .. data
      local idx = buf:find("\n", 1, true)
      if not idx then
        return
      end
      local line = buf:sub(1, idx - 1):gsub("\r$", "")
      local ok, obj = pcall(vim.json.decode, line)
      if ok and type(obj) == "table" then
        if obj.type == "hello" then
          state.info = {
            name = obj.name,
            cwd = obj.cwd,
            model = obj.model,
            sessionName = obj.sessionName,
          }
        end
      end
      finish()
    end)
    handle:write(vim.json.encode { cmd = "hello" } .. "\n", nil)
  end)
  vim.wait(HELLO_TIMEOUT_MS + 50, function()
    return state.done
  end)
  return state.info
end

--- Names of all sockets in the registry dir (live or stale).
function M.registry_names()
  local names = {}
  local dir = vim.uv.fs_scandir(REGISTRY_DIR)
  if dir then
    local name
    repeat
      name = vim.uv.fs_scandir_next(dir)
      if name and name:match "%.sock$" then
        names[#names + 1] = name:gsub("%.sock$", "")
      end
    until not name
  end
  table.sort(names)
  return names
end

--- Discover running instances: a list of info tables with a `path` field.
function M.discover()
  local out = {}
  for _, name in ipairs(M.registry_names()) do
    local path = REGISTRY_DIR .. "/" .. name .. ".sock"
    local info = M.hello(path)
    if info then
      info.path = path
      out[#out + 1] = info
    end
  end
  return out
end

--- Connect to an instance (path from discover()). Replaces any connection.
function M.connect(path)
  M.disconnect()
  local handle = vim.uv.new_pipe()
  local c = { handle = handle, buf = "", info = nil, busy = false, hello_done = false, queue = {}, last_text = nil }
  conn = c
  pcall(handle.connect, handle, path, function(err)
    if err then
      if conn == c then
        conn = nil
      end
      vim.notify("pi: cannot connect: " .. tostring(err), vim.log.levels.ERROR, { title = "pi connect" })
      lualine_refresh()
      return
    end
    handle:read_start(read_loop(c))
    handle:write(vim.json.encode { cmd = "hello" } .. "\n", nil)
  end)
  return true
end

function M.connect_instance(info)
  M.connect(info.path)
end

function M.disconnect()
  if conn then
    local c = conn
    conn = nil
    pcall(c.handle.close, c.handle)
  end
  lualine_refresh()
end

--- Info of the connected instance, or nil.
function M.active()
  if conn and conn.hello_done then
    return conn.info
  end
  return nil
end

--- True while the connected agent is running a turn.
function M.busy()
  return conn and conn.busy or false
end

--- Send a prompt to the connected agent. While the agent is busy the
--- message is queued as a follow-up (delivered when the turn settles).
function M.send_message(message)
  if not (conn and conn.hello_done) then
    vim.notify("pi: no agent connected (<leader>at)", vim.log.levels.WARN)
    return false
  end
  local payload = { cmd = "prompt", message = message }
  if conn.busy then
    payload.deliverAs = "followUp"
  end
  local line = vim.json.encode(payload) .. "\n"
  if conn.hello_done then
    if not pcall(conn.handle.write, conn.handle, line, nil) then
      M.disconnect()
      vim.notify("pi: connection to " .. conn_name(conn) .. " lost", vim.log.levels.WARN, {
        title = "pi connect",
      })
      return false
    end
  else
    conn.queue[#conn.queue + 1] = line
  end
  pi_log("▶ @" .. conn_name(conn) .. " " .. message:gsub("%s+", " "):sub(1, 80))
  return true
end

function M.abort()
  if not (conn and conn.hello_done) then
    return false
  end
  pcall(conn.handle.write, conn.handle, vim.json.encode { cmd = "abort" } .. "\n", nil)
  vim.notify("pi @" .. conn_name(conn) .. ": abort sent", vim.log.levels.INFO, { title = "pi abort" })
  pi_log("✕ abort @" .. conn_name(conn))
  return true
end

--- Lualine component: "π@name", plus an hourglass while the agent works.
function M.component()
  if not M.active() then
    return ""
  end
  local info = M.active()
  return "π@" .. info.name .. (M.busy() and " ⏳" or "")
end

local function sock_path(name)
  return REGISTRY_DIR .. "/" .. name .. ".sock"
end

--- Spawn a named agent in a new ghostty window, then connect to it.
function M.spawn()
  if vim.fn.executable "ghostty" == 0 then
    vim.notify("pi: ghostty not found in PATH — cannot spawn an agent", vim.log.levels.ERROR)
    return
  end
  local names = {}
  for _, n in ipairs(M.registry_names()) do
    names[n] = true
  end
  local i = 1
  while names["nvim-" .. i] do
    i = i + 1
  end
  local name = "nvim-" .. i
  local cwd = vim.fn.getcwd()
  -- Ghostty config keys use the --key=value syntax (space form is rejected
  -- and shows a Configuration Errors overlay).
  local jobid = vim.fn.jobstart({
    "ghostty",
    "--title=pi: " .. name,
    "--working-directory=" .. cwd,
    "-e",
    "sh",
    "-c",
    "PI_NAME=" .. name .. " exec pi",
  }, { detach = true, silent = true })
  if jobid == -1 then
    vim.notify("pi: failed to spawn ghostty", vim.log.levels.ERROR)
    return
  end
  vim.notify("pi: spawning " .. name .. " (new ghostty window)…", vim.log.levels.INFO, { title = "pi connect" })
  local tries = SPAWN_POLL_TRIES
  local function poll()
    if conn and conn.info then
      return -- user connected/disconnected meanwhile
    end
    if vim.uv.fs_stat(sock_path(name)) then
      M.connect_instance { path = sock_path(name) }
      return
    end
    tries = tries - 1
    if tries <= 0 then
      vim.notify("pi: " .. name .. " did not come up — check the ghostty window", vim.log.levels.WARN)
      return
    end
    local timer = vim.uv.new_timer()
    timer:start(SPAWN_POLL_MS, 0, function()
      timer:close()
      poll()
    end)
  end
  poll()
end

local function format_instance(info)
  local cwd = info.cwd and vim.fn.fnamemodify(info.cwd, ":~") or ""
  return string.format("%s  %s  %s%s", info.name, cwd, info.model, info.busy and "  [busy]" or "")
end

--- Pick a running instance (spawn one if there are none) and connect.
function M.pick()
  if conn then
    M.disconnect()
  end
  local instances = M.discover()
  if #instances == 0 then
    M.spawn()
    return
  end
  if #instances == 1 then
    M.connect_instance(instances[1])
    return
  end
  vim.ui.select(instances, {
    prompt = "pi agent",
    format_item = format_instance,
  }, function(choice)
    if choice then
      M.connect_instance(choice)
    end
  end)
end

--- Toggle: connected → disconnect, otherwise pick (or spawn) and connect.
function M.toggle()
  if conn and conn.hello_done then
    local name = conn.info.name
    M.disconnect()
    vim.notify("pi: disconnected from " .. name, vim.log.levels.INFO, { title = "pi connect" })
    return
  end
  M.pick()
end

return M
