return {
  async = true,
  formatters_by_ft = {
    cs = { "csharpier_formatter" },
    csproj = { "csharpier_formatter" },
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
  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
}
