vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    local map_set = require('localized_keymaps').set
    local map = function(keys, func, desc)
      map_set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    local fzf_lua = require('fzf-lua')
    local function code_actions()
      local bufnr = event.buf
      local cursor = vim.api.nvim_win_get_cursor(0)
      local row = cursor[1] - 1
      local col = cursor[2]
      local diagnostics = vim.diagnostic.get(bufnr, { lnum = row })
      local diagnostics_under_cursor = vim.tbl_filter(function(diagnostic)
        if not diagnostic.user_data or not diagnostic.user_data.lsp then
          return false
        end
        local start_col = diagnostic.col or 0
        local end_col = diagnostic.end_col or start_col
        return (start_col == end_col and col == start_col)
          or (col >= start_col and col < end_col)
      end, diagnostics)

      -- Native LSP behavior uses only diagnostics under the cursor. If the
      -- cursor is elsewhere on a line with one or more diagnostics, include
      -- that line's LSP diagnostics so their quick fixes are still offered.
      local selected_diagnostics = diagnostics_under_cursor
      if #selected_diagnostics == 0 then
        selected_diagnostics = vim.tbl_filter(function(diagnostic)
          return diagnostic.user_data and diagnostic.user_data.lsp
        end, diagnostics)
      end

      if #selected_diagnostics == 0 then
        return fzf_lua.lsp_code_actions()
      end

      return fzf_lua.lsp_code_actions({
        context = {
          diagnostics = vim.tbl_map(function(diagnostic)
            return diagnostic.user_data.lsp
          end, selected_diagnostics),
        },
      })
    end

    map('<leader>cgd', fzf_lua.lsp_definitions, '[G]oto [D]efinition')
    map('<leader>cgr', fzf_lua.lsp_references, '[G]oto [R]eferences')
    map('<leader>cgI', fzf_lua.lsp_implementations, '[G]oto [I]mplementation')
    map('<leader>cd', fzf_lua.lsp_typedefs, 'Type [D]efinition')
    map('<leader>cs', fzf_lua.lsp_document_symbols, 'Document [S]ymbols')
    map('<leader>cr', vim.lsp.buf.rename, '[R]ename variable')
    map('<leader>ca', code_actions, '[C]ode [A]ction')
    map('<leader>cgD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
      local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
        end,
      })
    end
  end,
})
