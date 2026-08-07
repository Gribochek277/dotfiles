local servers = { "html", "cssls", "vtsls", "basedpyright", "roslyn" }

local function on_attach(client, bufnr)
  if client:supports_method("textDocument/codeLens") then
    vim.lsp.codelens.enable(true, { bufnr = bufnr, client_id = client.id })
  end
end

-- Use fzf-lua for references and implementations triggered by code lens
local fzf = require("fzf-lua")

local function fzf_lsp_handler(fzf_fn, default_handler, empty_msg)
  return function(err, result, ctx, config)
    if err then
      return default_handler(err, result, ctx, config)
    end
    if not result or vim.tbl_isempty(result) then
      return vim.notify(empty_msg, vim.log.levels.INFO)
    end
    fzf_fn()
  end
end

local orig_references = vim.lsp.handlers["textDocument/references"]
vim.lsp.handlers["textDocument/references"] = fzf_lsp_handler(
  function() fzf.lsp_references({ includeDeclaration = true }) end,
  orig_references,
  "No references found"
)

local orig_implementation = vim.lsp.handlers["textDocument/implementation"]
vim.lsp.handlers["textDocument/implementation"] = fzf_lsp_handler(
  function() fzf.lsp_implementations() end,
  orig_implementation,
  "No implementations found"
)

vim.lsp.config("html", { on_attach = on_attach })
vim.lsp.config("cssls", { on_attach = on_attach })

vim.lsp.config("vtsls", {
  on_attach = on_attach,
  settings = {
    typescript = {
      referencesCodeLens = { enabled = true },
      implementationsCodeLens = { enabled = true },
    },
    javascript = {
      referencesCodeLens = { enabled = true },
      implementationsCodeLens = { enabled = true },
    },
  },
})

vim.lsp.config("basedpyright", {
  on_attach = on_attach,
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

vim.lsp.config("roslyn", {
  on_attach = on_attach,
  settings = {
    ["csharp|code_lens"] = {
      dotnet_enable_references_code_lens = true,
      dotnet_enable_tests_code_lens = true,
      dotnet_enable_data_flow_code_lens = false,
    },
    ["dotnet_diagnostic.IDE0090.severity"] = "none",
    ["csharp|inlay_hints"] = {
      dotnet_inlay_hints_type_annotations_enabled = false,
      dotnet_inlay_hints_variable_types_enabled = false,
    },
  },
})

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
