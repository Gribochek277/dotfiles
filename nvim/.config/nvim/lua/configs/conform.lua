return {
  default_format_opts = {
    lsp_format = "fallback",
    timeout_ms = 3000,
  },
  formatters_by_ft = {
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    cs = { "dotnet_format" },
    csproj = { "dotnet_format" },
  },
  format_on_save = {
    timeout_ms = 3000,
    lsp_format = "fallback",
  },
}
