return {
  "0xstepit/flow.nvim",
  lazy = false,
  priority = 1000,
  tag = "v2.0.1",
  opts = {
    theme = {
      style = "dark",
      contrast = "default",
      transparent = true,
    },
    colors = {
      mode = "default",
      fluo = "pink",
    },
    ui = {
      borders = "none",
    },
  },
  config = function(_, opts)
    require("flow").setup(opts)
    vim.cmd("colorscheme flow")
  end,
}
