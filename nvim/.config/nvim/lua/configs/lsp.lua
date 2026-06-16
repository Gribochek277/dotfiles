local servers = { "html", "cssls", "vtsls", "basedpyright", "roslyn" }

vim.lsp.config("html", {})
vim.lsp.config("cssls", {})
vim.lsp.config("vtsls", {})

vim.lsp.config("basedpyright", {
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "openFilesOnly",
        useLibraryCodeForTypes = true,
      },
    },
  },
})

vim.lsp.config("roslyn", {})

vim.lsp.enable(servers)

vim.diagnostic.config({
  underline = false,
  virtual_text = false,
  update_in_insert = false,
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.HINT] = " ",
      [vim.diagnostic.severity.INFO] = " ",
    },
  },
})
