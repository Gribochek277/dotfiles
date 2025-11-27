return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
 {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
          "lua",
          "vim",
          "vimdoc",
          "javascript",
          "html",
          "c_sharp",
          "typescript",
          "markdown",
          "markdown_inline",
    },
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
  },
 }, 
   {
    "williamboman/mason.nvim",
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      },
      ensure_installed = {
        "lua-language-server",
        
        "xmlformatter",
        "csharpier",
        "prettier",
      
        "stylua",
        "bicep-lsp",
        "html-lsp",
        "css-lsp",
        "eslint-lsp",
        "typescript-language-server",
        "json-lsp",
        "rust-analyzer",

        -- !
        "roslyn",
        "rzls",
        -- "csharp-language-server",
        -- "omnisharp",
      },
    },
  },
  {
    "seblyng/roslyn.nvim",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    ft = { "cs", "razor" },
    opts = {
      -- your configuration comes here; leave empty for default settings
    },
},
{
    -- Debug Framework
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
    },
    config = function()
      require "configs.nvim-dap"
    end,
    event = "VeryLazy",
  },
  { "nvim-neotest/nvim-nio" },
  {
    -- UI for debugging
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    config = function()
      require "configs.nvim-dap-ui"
    end,
  },
  {
    "nvim-neotest/neotest",
    requires = {
      {
        "Issafalcon/neotest-dotnet",
      }
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter"
    }
  },
  {
    "Issafalcon/neotest-dotnet",
    lazy = false,
    dependencies = {
      "nvim-neotest/neotest"
    }
  },
 {
    'ramboe/ramboe-dotnet-utils',
    dependencies = { 'mfussenegger/nvim-dap' }
  },
-- .config/nvim/lua/plugins/init.lua
-- ...
{
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy", -- Or `LspAttach`
    priority = 1000,    -- needs to be loaded in first
    config = function()
      require('tiny-inline-diagnostic').setup()
      vim.diagnostic.config({ virtual_text = false }) -- Only if needed in your configuration, if you already have native LSP diagnostics
    end
  },
{
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    config = function()
      require "configs.conform"
    end,
  },{ 'nvim-mini/mini.icons', version = '*' },
{
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  },
  keys = {
      },
}
}
