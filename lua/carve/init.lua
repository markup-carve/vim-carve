-- carve.nvim: tree-sitter integration for the Carve markup language.
--
-- The classic Vim regex syntax (syntax/carve.vim) works everywhere with no
-- setup. This module is the *optional* Neovim tree-sitter path that gives
-- richer, parser-driven highlighting, folds, indents, injections and
-- text objects using the bundled queries under queries/carve/*.scm.
--
-- The tree-sitter grammar must be compiled per platform. There are two
-- supported ways to make the `carve` parser available:
--
--   1. nvim-treesitter (recommended): register a parser config that points at
--      the tree-sitter-carve repo, then `:TSInstall carve` compiles it. Call
--      require('carve').setup() once on startup; it wires the config in if
--      nvim-treesitter is present.
--
--   2. Pre-compiled parser: if you already have a `carve.so` (e.g. from
--      `tree-sitter build`), pass its path and this module registers it via
--      `vim.treesitter.language.add('carve', { path = ... })`.
--
-- Either way, the filetype `carve` is mapped to the `carve` language so the
-- bundled queries apply.

local M = {}

local DEFAULTS = {
  -- Absolute path to a compiled parser (carve.so / carve.dylib / carve.dll).
  -- When set, registered directly without nvim-treesitter.
  parser_path = nil,
  -- URL used by the nvim-treesitter parser config for :TSInstall carve.
  install_url = 'https://github.com/markup-carve/tree-sitter-carve',
  -- Branch/revision to install from.
  install_revision = 'main',
  -- Map the `carve` filetype to the `carve` language.
  register_filetype = true,
}

-- Register a pre-compiled parser shared object, if a path was given and the
-- modern API is available. Returns true on success.
local function register_parser_path(path)
  if not path then
    return false
  end
  if vim.uv and vim.uv.fs_stat(path) == nil and vim.loop and vim.loop.fs_stat(path) == nil then
    return false
  end
  local ok = pcall(vim.treesitter.language.add, 'carve', { path = path })
  return ok
end

-- Wire the grammar into nvim-treesitter's parser table so `:TSInstall carve`
-- and automatic highlighting work. No-op if nvim-treesitter is absent.
local function register_with_nvim_treesitter(opts)
  local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
  if not ok then
    return false
  end
  local get_configs = parsers.get_parser_configs
  if type(get_configs) ~= 'function' then
    return false
  end
  local configs = get_configs()
  configs.carve = {
    install_info = {
      url = opts.install_url,
      files = { 'src/parser.c' },
      branch = opts.install_revision,
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
    filetype = 'carve',
  }
  return true
end

function M.setup(opts)
  opts = vim.tbl_deep_extend('force', vim.deepcopy(DEFAULTS), opts or {})

  -- Map the filetype to the language so queries under queries/carve apply.
  if opts.register_filetype and vim.treesitter.language.register then
    pcall(vim.treesitter.language.register, 'carve', 'carve')
  end

  -- Prefer an explicit compiled parser if one was provided.
  local registered = register_parser_path(opts.parser_path)

  -- Otherwise integrate with nvim-treesitter for install + runtime.
  if not registered then
    register_with_nvim_treesitter(opts)
  end

  return M
end

-- Convenience: start tree-sitter highlighting for the current buffer. Useful
-- for users not running nvim-treesitter's auto-start. Returns true on success.
function M.start(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok = pcall(vim.treesitter.start, bufnr, 'carve')
  return ok
end

return M
