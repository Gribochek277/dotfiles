return {
  "ibhagwan/fzf-lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    -- Keep vim.ui.select graphical globally. Roslyn uses it for the
    -- second step of "Fix All" actions (document/project/solution scope).
    ui_select = {
      fzf_opts = {
        ["--no-multi"] = true,
        ["--bind"] = "j:down,k:up,l:accept,h:abort,ctrl-j:down,ctrl-k:up",
      },
    },
    lsp = {
      code_actions = {
        -- Always show the picker, even when only one action is available.
        jump1 = false,
        -- Show the proposed edit in the preview pane before applying it.
        previewer = "codeaction",
        -- Code actions are single-choice; keep all actions returned by the LSP.
        fzf_opts = {
          ["--no-multi"] = true,
          -- Vim-style navigation: j/k move, l applies, h cancels.
          ["--bind"] = "j:down,k:up,l:accept,h:abort,ctrl-j:down,ctrl-k:up",
        },
      },
    },
  },
}
