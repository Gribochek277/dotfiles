local dap = require("dap")

local mason_path = vim.fn.stdpath("data") .. "/mason/packages/netcoredbg/netcoredbg"

local function find_project_root_by_csproj(start_path)
  local current = vim.fs.dirname(start_path)

  while current do
    local csproj = vim.fs.find(function(name)
      return name:match("%.csproj$") ~= nil
    end, { path = current, type = "file", limit = 1 })

    if #csproj > 0 then
      return current, csproj[1]
    end

    local parent = vim.fs.dirname(current)
    if not parent or parent == current then
      return nil, nil
    end

    current = parent
  end
end

local function build_dll_path()
  local current_file = vim.api.nvim_buf_get_name(0)
  local project_root, csproj = find_project_root_by_csproj(current_file)

  if not project_root or not csproj then
    error("Could not find project root (no .csproj found)")
  end

  local project_name = vim.fn.fnamemodify(csproj, ":t:r")
  local net_dirs = vim.fn.glob(project_root .. "/bin/Debug/net*", false, true)

  if vim.tbl_isempty(net_dirs) then
    error("No netX.Y folders found in " .. project_root .. "/bin/Debug")
  end

  table.sort(net_dirs, function(a, b)
    return a > b
  end)

  return net_dirs[1] .. "/" .. project_name .. ".dll"
end

local netcoredbg_adapter = {
  type = "executable",
  command = mason_path,
  args = { "--interpreter=vscode" },
}

dap.adapters.netcoredbg = netcoredbg_adapter -- needed for normal debugging
dap.adapters.coreclr = netcoredbg_adapter    -- needed for unit test debugging

dap.configurations.cs = {
  {
    type = "coreclr",
    name = "launch - netcoredbg",
    request = "launch",
    program = function()
      return build_dll_path()
    end
    -- justMyCode = false,
    -- stopAtEntry = false,
    -- -- program = function()
    -- --   -- todo: request input from ui
    -- --   return "/path/to/your.dll"
    -- -- end,
    -- env = {
    --   ASPNETCORE_ENVIRONMENT = function()
    --     -- todo: request input from ui
    --     return "Development"
    --   end,
    --   ASPNETCORE_URLS = function()
    --     -- todo: request input from ui
    --     return "http://localhost:5050"
    --   end,
    -- },
    -- cwd = function()
    --   -- todo: request input from ui
    --   return vim.fn.getcwd()
    -- end,
  },
}
