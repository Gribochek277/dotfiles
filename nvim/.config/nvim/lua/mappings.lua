local map = vim.keymap.set
local builtin = require("telescope.builtin")
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<Esc>", { noremap = true, silent = true })
map("i", "kj", "<Esc>", { noremap = true, silent = true })

map("n", "<C-p>", builtin.find_files, {})

map("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })
map("i", "<C-e>", "<End>", { desc = "move end of line" })
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })

map("n", "<C-h>", "<C-w>h", { desc = "switch window left" })
map("n", "<C-l>", "<C-w>l", { desc = "switch window right" })
map("n", "<C-j>", "<C-w>j", { desc = "switch window down" })
map("n", "<C-k>", "<C-w>k", { desc = "switch window up" })

map("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })
-- place this in one of your configuration file(s)
local hop = require('hop')
local directions = require('hop.hint').HintDirection
vim.keymap.set('', 'f', function()
  hop.hint_char2({ current_line_only = false })
end, {remap=true})
-- tabufline
if require("nvconfig").ui.tabufline.enabled then
  map("n", "<leader>bn", "<cmd>enew<CR>", { desc = "[B]uffer [N]ew" })

  map("n", "<tab>", function()
    require("nvchad.tabufline").next()
  end, { desc = "buffer goto next" })

  map("n", "<leader>bl", function()
    require("nvchad.tabufline").next()
  end, { desc = "[L]Buffer Goto Next(TAB)" })

  map("n", "<S-tab>", function()
    require("nvchad.tabufline").prev()
  end, { desc = "buffer goto prev" })

  map("n", "<leader>bh", function()
    require("nvchad.tabufline").prev()
  end, { desc = "[H]Buffer Goto Prev(SHIFT+TAB)" })

  map("n", "<leader>bc", function()
    require("nvchad.tabufline").close_buffer()
  end, { desc = "Buffer [C]lose" })
end

-- Comment
map("n", "<leader>/", "gcc", { desc = "toggle comment", remap = true })
map("v", "<leader>/", "gc", { desc = "toggle comment", remap = true })

-- terminal
map("t", "<C-x>", "<C-\\><C-N>", { desc = "terminal escape terminal mode" })

-- toggleable
map({ "n", "t" }, "<A-v>", function()
  require("nvchad.term").toggle { pos = "vsp", id = "vtoggleTerm" }
end, { desc = "terminal toggleable vertical term" })

map({ "n", "t" }, "<A-h>", function()
  require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
end, { desc = "terminal toggleable horizontal term" })

map({ "n", "t" }, "<A-i>", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "terminal toggle floating term" })


local opts = { noremap = true, silent = true }

map("n", "<F5>", "<Cmd>lua require'dap'.continue()<CR>", opts)
map("n", "<F6>", "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>", opts)
map("n", "<F9>", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", opts)
map("n", "<F10>", "<Cmd>lua require'dap'.step_over()<CR>", opts)
map("n", "<F11>", "<Cmd>lua require'dap'.step_into()<CR>", opts)
map("n", "<F8>", "<Cmd>lua require'dap'.step_out()<CR>", opts)

local wk = require("which-key")
wk.add({
  -- File
  { "<leader>f",  group = "[F]ile" },
  { "<leader>ff", "<cmd>Telescope find_files<cr>",                                                  desc = "[F]ind [F]iles(CTRL+p)" },
  { "<leader>fa", "<cmd>Telescope find_files follow=true no_ignore=true hidden=true<CR>",           desc = "[F]ind [A]ll Files" },
  { "<leader>fn", "<cmd>enew<CR>",                                                                  desc = "[N]ew [F]ile" },
  { "<leader>fr", "<cmd>Telescope oldfiles<CR>",                                                    desc = "[R]ecent [F]iles" },

  -- Code
  { "<leader>c",  group = "[C]ode" },
  { "<leader>cf", function() require("conform").format { lsp_fallback = true } end,                 desc = "Format" },
  { "<leader>cg", group = "[G]oto" },

  -- UI
  { "<leader>u",  group = "[U]i" },
  { "<leader>ut", function() require("nvchad.themes").open() end,                                   desc = "Telescope Nvchad [T]hemes" },
  { "<leader>un", "<cmd>set nu!<CR>",                                                               desc = "Toggle Line [N]umber" },
  { "<leader>ur", "<cmd>set rnu!<CR>",                                                              desc = "Toggle [R]elative Number" },
  { "<leader>uc", "<cmd>NvCheatsheet<CR>",                                                          desc = "Toggle Nv[c]heatsheet" },

  -- Debug
  { "<leader>d",  group = "[D]ebug" },
  { "<leader>dc", "<Cmd>lua require'dap'.continue()<CR>",                                           desc = "[C]ontinue(F5)" },
  { "<leader>db", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>",                                  desc = "Toggle [B]reakpoint(F9)" },
  { "<leader>do", "<Cmd>lua require'dap'.step_over()<CR>",                                          desc = "Step [O]ver(F10)" },
  { "<leader>di", "<Cmd>lua require'dap'.step_into()<CR>",                                          desc = "Step [I]nto(F11)" },
  { "<leader>do", "<Cmd>lua require'dap'.step_out()<CR>",                                           desc = "Step [O]ut(F8)" },
  { "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>",                                          desc = "Open [R]EPL" },
  { "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>",                                           desc = "Re-run [L]ast" },
  { "<leader>dt", "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>",                    desc = "Debug [T]est" },

  -- Git
  { "<leader>g",  group = "[G]it" },
  { "<leader>gc", "<cmd>Telescope git_commits<CR>",                                                 desc = "[C]ommits" },
  { "<leader>gs", "<cmd>Telescope git_status<CR>",                                                  desc = "[S]tatus" },

  -- Terminal
  { "<leader>t",  group = "[T]erminal" },
  { "<leader>th", function() require("nvchad.term").new { pos = "sp" } end,                         desc = "[H]orizontal" },
  { "<leader>tv", function() require("nvchad.term").new { pos = "vsp" } end,                        desc = "[V]ertical" },
  { "<leader>tf", function() require("nvchad.term").toggle { pos = "float", id = "floatTerm" } end, desc = "[F]loat" },

  -- Which-key
  { "<leader>w",  group = "[W]hich-key" },
  { "<leader>wa", "<cmd>WhichKey <CR>",                                                             desc = "[A]ll Keymaps" },
  { "<leader>wq", function() vim.cmd("WhichKey " .. vim.fn.input "WhichKey: ") end,                 desc = "[Q]uery Lookup" },

  -- Search / Telescope
  { "<leader>s",  group = "[S]earch" },
  { "<leader>sw", "<cmd>Telescope live_grep<CR>",                                                   desc = "[W]ord(Live Grep)" },
  { "<leader>sb", "<cmd>Telescope buffers<CR>",                                                     desc = "[B]uffers" },
  { "<leader>sh", "<cmd>Telescope help_tags<CR>",                                                   desc = "[H]elp Tags" },
  { "<leader>sm", "<cmd>Telescope marks<CR>",                                                       desc = "[M]arks" },
  { "<leader>sz", "<cmd>Telescope current_buffer_fuzzy_find<CR>",                                   desc = "Fu[z]zy Find Buffer" },

  -- Tree / Files
  { "<leader>e",  group = "[E]xplorer" },
  { "<leader>et", "<cmd>NvimTreeToggle<CR>",                                                        desc = "[T]oggle Tree" },
  { "<leader>ef", "<cmd>NvimTreeFocus<CR>",                                                         desc = "[F]ocus Tree" },

  -- Buffer
  { "<leader>b",  group = "[B]uffer" },

})
