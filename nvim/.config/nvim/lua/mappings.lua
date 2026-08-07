local keymaps = require("localized_keymaps")
local map = keymaps.set
local fzf = require("fzf-lua")

local function format_code()
  require("conform").format { lsp_format = "fallback" }
end

local function project_root()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)

  for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
    local root = client.config and client.config.root_dir
    if root and path:find(vim.pesc(root), 1, true) == 1 then
      return root
    end
  end

  return vim.fs.root(buf, { ".git", ".jj", "package.json", "pyproject.toml", "Cargo.toml", "go.mod" })
    or vim.fn.getcwd()
end

local function search_project_text()
  fzf.live_grep({ cwd = project_root() })
end

keymaps.enable_builtin_layout_maps()

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<Esc>", { noremap = true, silent = true })
map("i", "kj", "<Esc>", { noremap = true, silent = true })
map("i", "ол", "<Esc>", { noremap = true, silent = true })
map("i", "ло", "<Esc>", { noremap = true, silent = true })
map("t", "ол", "<C-\\><C-N>", { noremap = true, silent = true })
map("t", "ло", "<C-\\><C-N>", { noremap = true, silent = true })

map("n", "<C-p>", fzf.files, {})
map("n", "<C-f>", search_project_text, { desc = "search project text" })
map("n", "<C-S-f>", search_project_text, { desc = "search project text" })
map({ "n", "x" }, "<leader>cf", format_code, { desc = "format code" })

map("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })
map("i", "<C-e>", "<End>", { desc = "move end of line" })
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })

local function nav(dir)
  return function()
    vim.cmd.wincmd(dir)
  end
end

map("n", "<C-h>", nav("h"), { desc = "switch window left" })
map("n", "<C-j>", nav("j"), { desc = "switch window down" })
map("n", "<C-k>", nav("k"), { desc = "switch window up" })
map("n", "<C-l>", nav("l"), { desc = "switch window right" })

map("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })

local hop = require('hop')
map('', 'f', function()
  hop.hint_char2({ current_line_only = false })
end, { remap = true })

map("n", "<leader>bn", "<cmd>enew<CR>", { desc = "[B]uffer [N]ew" })

map("n", "<tab>", "<cmd>bnext<CR>", { desc = "buffer goto next" })
map("n", "<leader>bl", "<cmd>bnext<CR>", { desc = "[L]Buffer Goto Next(TAB)" })

map("n", "<S-tab>", "<cmd>bprev<CR>", { desc = "buffer goto prev" })
map("n", "<leader>bh", "<cmd>bprev<CR>", { desc = "[H]Buffer Goto Prev(SHIFT+TAB)" })

map("n", "<leader>bc", "<cmd>bdelete<CR>", { desc = "Buffer [C]lose" })

map("n", "<leader>/", "gcc", { desc = "toggle comment", remap = true })
map("v", "<leader>/", "gc", { desc = "toggle comment", remap = true })

map("n", "<leader>cr", vim.lsp.codelens.run, { desc = "[C]ode Lens [R]un" })

map("t", "<C-x>", "<C-\\><C-N>", { desc = "terminal escape terminal mode" })

map({ "n", "t" }, "<A-v>", function()
  require("snacks.terminal").toggle(nil, { win = { position = "right", width = 0.4 } })
end, { desc = "terminal toggleable vertical term" })

map({ "n", "t" }, "<A-h>", function()
  require("snacks.terminal").toggle(nil, { win = { position = "bottom", height = 0.3 } })
end, { desc = "terminal toggleable horizontal term" })

map({ "n", "t" }, "<A-i>", function()
  require("snacks.terminal").toggle(nil, { win = { position = "float" } })
end, { desc = "terminal toggle floating term" })

local dap_opts = { noremap = true, silent = true }

map("n", "<F5>", "<Cmd>lua require'dap'.continue()<CR>", dap_opts)
map("n", "<F6>", "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>", dap_opts)
map("n", "<F9>", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", dap_opts)
map("n", "<F10>", "<Cmd>lua require'dap'.step_over()<CR>", dap_opts)
map("n", "<F11>", "<Cmd>lua require'dap'.step_into()<CR>", dap_opts)
map("n", "<F8>", "<Cmd>lua require'dap'.step_out()<CR>", dap_opts)

local wk = require("which-key")
wk.add({
  { "<leader>f",  group = "[F]ile" },
  { "<leader>ff", function() fzf.files() end,                                    desc = "[F]ind [F]iles(CTRL+p)" },
  { "<leader>fa", function() fzf.files({ no_ignore = true, hidden = true }) end, desc = "[F]ind [A]ll Files" },
  { "<leader>fn", "<cmd>enew<CR>",                                               desc = "[N]ew [F]ile" },
  { "<leader>fr", function() fzf.oldfiles() end,                                 desc = "[R]ecent [F]iles" },

  { "<leader>c",  group = "[C]ode" },
  { "<leader>cf", desc = "Format", mode = { "n", "x" } },
  { "<leader>cl", "J", desc = "[L]ine join", remap = true, mode = { "x" } },
  { "<leader>cr", vim.lsp.codelens.run, desc = "[R]un CodeLens" },
  { "<leader>cg", group = "[G]oto" },

  { "<leader>u",  group = "[U]i" },
  { "<leader>un", "<cmd>set nu!<CR>",         desc = "Toggle Line [N]umber" },
  { "<leader>ur", "<cmd>set rnu!<CR>",        desc = "Toggle [R]elative Number" },

  { "<leader>d",  group = "[D]ebug" },
  { "<leader>dc", "<Cmd>lua require'dap'.continue()<CR>",     desc = "[C]ontinue(F5)" },
  { "<leader>db", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", desc = "Toggle [B]reakpoint(F9)" },
  { "<leader>do", "<Cmd>lua require'dap'.step_over()<CR>",    desc = "Step [O]ver(F10)" },
  { "<leader>di", "<Cmd>lua require'dap'.step_into()<CR>",    desc = "Step [I]nto(F11)" },
  { "<leader>dO", "<Cmd>lua require'dap'.step_out()<CR>",     desc = "Step [O]ut(F8)" },
  { "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>",    desc = "Open [R]EPL" },
  { "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>",     desc = "Re-run [L]ast" },
  { "<leader>dt", "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>", desc = "Debug [T]est" },

  { "<leader>g",  group = "[G]it" },
  { "<leader>gc", function() fzf.git_commits() end,                 desc = "[C]ommits" },
  { "<leader>gs", function() fzf.git_status() end,                  desc = "[S]tatus" },

  { "<leader>t",  group = "[T]erminal" },
  { "<leader>th", function() require("snacks.terminal").toggle(nil, { win = { position = "bottom", height = 0.3 } }) end, desc = "[H]orizontal" },
  { "<leader>tv", function() require("snacks.terminal").toggle(nil, { win = { position = "right", width = 0.4 } }) end,  desc = "[V]ertical" },
  { "<leader>tf", function() require("snacks.terminal").toggle(nil, { win = { position = "float" } }) end,               desc = "[F]loat" },

  { "<leader>w",  group = "[W]hich-key" },
  { "<leader>wa", "<cmd>WhichKey <CR>",                                          desc = "[A]ll Keymaps" },
  { "<leader>wq", function() vim.cmd("WhichKey " .. vim.fn.input "WhichKey: ") end, desc = "[Q]uery Lookup" },

  { "<leader>s",  group = "[S]earch" },
  { "<leader>sw", function() fzf.live_grep() end,              desc = "[W]ord(Live Grep)" },
  { "<leader>sb", function() fzf.buffers() end,                desc = "[B]uffers" },
  { "<leader>sh", function() fzf.help_tags() end,              desc = "[H]elp Tags" },
  { "<leader>sm", function() fzf.marks() end,                  desc = "[M]arks" },
  { "<leader>sz", function() fzf.lines() end,                  desc = "Fu[z]zy Find Buffer" },

  { "<leader>e",  group = "[E]xplorer" },
  { "<leader>et", "<cmd>NvimTreeToggle<CR>", desc = "[T]oggle Tree" },
  { "<leader>ef", "<cmd>NvimTreeFocus<CR>",  desc = "[F]ocus Tree" },

  { "<leader>b",  group = "[B]uffer" },

  { "<leader>a",  group = "[A]I" },
  { "<leader>ai", "<cmd>PiAsk<CR>",          desc = "[A]sk Pi",             mode = { "n" } },
  { "<leader>ai", ":PiAskSelection<CR>",    desc = "[A]sk Pi (selection)", mode = { "x" } },
  { "<leader>am", function() require("pi_models").pick() end, desc = "[M]odel picker" },
  { "<leader>ac", "<cmd>PiCancel<CR>",       desc = "[C]ancel request" },
  { "<leader>al", "<cmd>PiLog<CR>",          desc = "[L]og" },
})
