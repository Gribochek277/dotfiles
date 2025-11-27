-- lua/configs/conform.lua

local opts = {
  async = true,
  formatters_by_ft = {
    cs = { "csharpier_formatter" },
    csproj = { "csharpier_formatter" }
  },
  formatters = {
    csharpier_formatter = {
      command = "csharpier",
      args = {
        "format",
        "--write-stdout",
      },
      to_stdin = true,
    },
  },
  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

require("conform").setup(opts)
