return {
  "pablopunk/pi.nvim",
  cmd = { "PiAsk", "PiAskSelection", "PiCancel", "PiLog", "PiModel" },
  config = function()
    local models = require "pi_models"
    require("pi").setup {
      provider = models.entry().provider,
      model = models.entry().model,
    }
    vim.api.nvim_create_user_command("PiModel", models.pick, { desc = "Select pi model" })
  end,
}
