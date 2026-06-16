return {
  "saghen/blink.cmp",
  version = "1.*",
  dependencies = {
    "saghen/blink.compat",
    "rafamadriz/friendly-snippets",
  },
  opts = {
    keymap = {
      ["<C-y>"] = { "select_and_accept" },
      ["<C-e>"] = { "cancel" },
      ["<C-p>"] = { "select_prev", "fallback" },
      ["<C-n>"] = { "select_next", "fallback" },
      ["<C-d>"] = { "scroll_documentation_down", "fallback" },
      ["<C-u>"] = { "scroll_documentation_up", "fallback" },
      ["<CR>"] = { "accept", "fallback" },
      ["<Tab>"] = { "select_and_accept", "fallback" },
      ["<S-Tab>"] = { "select_prev", "fallback" },
    },
    appearance = {
      use_nvim_cmp_as_default = true,
    },
    completion = {
      documentation = { auto_show = true },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    snippets = {
      preset = "default",
    },
  },
  opts_extend = { "sources.default" },
}
