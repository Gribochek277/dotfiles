-- Extra themes for experimenting. Loaded eagerly (low priority, after flow),
-- but never applied on startup — `require("theme").startup()` picks the
-- saved theme or the flow fallback, and `<leader>uc` (fzf-lua colorschemes)
-- switches at runtime.
return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 900,
    opts = { style = "night" },
    config = function(_, opts)
      require("tokyonight").setup(opts)
    end,
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 900,
    config = function()
      require("catppuccin").setup({ flavour = "macchiato" })
    end,
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 900,
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 900,
    config = function()
      require("rose-pine").setup()
    end,
  },
}
