return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = require "configs.conform",
  },

  {
    "folke/snacks.nvim",
    priority = 1000,
    opts = {
      terminal = { enabled = true },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "lua", "vim", "vimdoc", "javascript", "html",
        "c_sharp", "typescript", "markdown", "markdown_inline", "python",
      },
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  {
    "williamboman/mason.nvim",
    lazy = false,
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      },
      ensure_installed = {
        "lua-language-server",
        "xmlformatter", "csharpier", "prettier",
        "stylua", "bicep-lsp", "html-lsp", "css-lsp",
        "eslint-lsp", "typescript-language-server", "json-lsp",
        "rust-analyzer", "basedpyright",
        "roslyn",
      },
    },
  },

  {
    "seblyng/roslyn.nvim",
    ft = { "cs", "razor", "cshtml" },
    opts = {},
  },

  {
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
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
  },

  {
    "Issafalcon/neotest-dotnet",
    dependencies = {
      "nvim-neotest/neotest",
    },
  },

  {
    "ramboe/ramboe-dotnet-utils",
    dependencies = { "mfussenegger/nvim-dap" },
  },

  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    config = function()
      require("tiny-inline-diagnostic").setup({
        signs = {
          left = "",
          right = "",
          diag = "●",
          arrow = "    ",
          up_arrow = "    ",
          vertical = " │",
          vertical_end = " └",
        },
        blend = {
          factor = 0.22,
        },
      })
      vim.diagnostic.config({ virtual_text = false })
    end,
  },

  { "nvim-mini/mini.icons", version = "*" },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },

  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    opts = {
      view = {
        width = 48,
      },
      on_attach = function(bufnr)
        vim.wo.wrap = true
        local map = require("localized_keymaps").set
        local api = require("nvim-tree.api")
        api.config.mappings.default_on_attach(bufnr)

        local bufopts = { buffer = bufnr, nowait = true }
        map("n", "<C-j>", "<C-w>j", bufopts)
        map("n", "<C-k>", "<C-w>k", bufopts)
        map("n", "<C-l>", "<C-w>l", bufopts)
      end,
    },
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
  },

  {
    "lewis6991/gitsigns.nvim",
    opts = {},
  },

  {
    "rafamadriz/friendly-snippets",
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_x = {
          function()
            return require("pi_models").label()
          end,
          "encoding",
          "fileformat",
          "filetype",
        },
      },
    },
  },
}
