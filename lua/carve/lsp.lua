-- carve.nvim: optional language-server integration for the Carve markup
-- language, backed by markup-carve/carve-lsp.
--
-- This is a SEPARATE module from require('carve') on purpose. The tree-sitter
-- path and the language-server path answer different questions and are wanted
-- independently: tree-sitter knows the document's shape, the server knows what
-- its identifiers mean - which `[^note]` has no definition, which `</#id>`
-- points at nothing, and that `**bold**` is a Markdown habit rendering as two
-- literal asterisks in Carve. Someone may want either without the other.
--
-- Nothing here runs automatically. plugin/carve.lua deliberately does not call
-- it: attaching a language server starts a process, and that is the reader's
-- decision, not a side effect of installing a syntax plugin.
--
--   require('carve.lsp').setup()
--
-- Install the server with:  npm i -g @markup-carve/carve-lsp
--
-- Three attach paths are tried in order, so this works on Neovim 0.8 through
-- current, with or without nvim-lspconfig:
--
--   1. vim.lsp.config + vim.lsp.enable (Neovim 0.11+). The built-in registry.
--   2. nvim-lspconfig, when it is installed. Matches what carve-lsp's own
--      README documents, so a reader who already set it up by hand gets the
--      same client rather than a second one.
--   3. A FileType autocmd calling vim.lsp.start. No dependency at all.
--      vim.lsp.start reuses an existing client for the same root, so opening
--      twenty .crv files in one project starts one server, not twenty.

local M = {}

local NAME = 'carve_lsp'

local DEFAULTS = {
  -- The server command. The npm package installs a bin named exactly
  -- `carve-lsp`; --stdio is how it speaks.
  cmd = { 'carve-lsp', '--stdio' },
  -- Filetypes to attach on. `crv` is included because a reader may map the
  -- extension to that name rather than to `carve`.
  filetypes = { 'carve', 'crv' },
  -- Markers that locate the workspace root. Rename, find-references and
  -- go-to-definition are workspace-wide in carve-lsp - renaming a heading id
  -- updates every reference pointing at it - so the root matters. A server
  -- given none can only see the open file.
  root_markers = { '.git' },
  -- Server settings, sent as the `carve` section. See carve-lsp's README for
  -- the keys (formatter, severities, include resolution).
  settings = {},
  -- Called with (client, bufnr) on attach, for keymaps.
  on_attach = nil,
  -- Attach even outside a project, with the file's own directory as the root.
  single_file_support = true,
}

-- Whether the server is actually installed. Returning false rather than
-- attaching keeps a missing server a no-op instead of a stream of errors on
-- every .crv file opened.
local function executable(cmd)
  local bin = cmd and cmd[1]
  return type(bin) == 'string' and vim.fn.executable(bin) == 1
end

local function find_root(bufnr, markers, single_file_support)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' then
    return single_file_support and vim.uv ~= nil and vim.uv.cwd() or vim.fn.getcwd()
  end
  local dir = vim.fs.dirname(path)
  -- vim.fs.find with upward is available from 0.8, which is this module's floor.
  local found = vim.fs.find(markers, { path = dir, upward = true, type = 'directory' })[1]
    or vim.fs.find(markers, { path = dir, upward = true })[1]
  if found then
    return vim.fs.dirname(found)
  end
  if single_file_support then
    return dir
  end
  return nil
end

-- Path 1: the built-in registry, Neovim 0.11+.
local function attach_builtin(opts)
  if type(vim.lsp.config) ~= 'function' or type(vim.lsp.enable) ~= 'function' then
    return false
  end
  local ok = pcall(vim.lsp.config, NAME, {
    cmd = opts.cmd,
    filetypes = opts.filetypes,
    root_markers = opts.root_markers,
    settings = { carve = opts.settings },
    on_attach = opts.on_attach,
  })
  if not ok then
    return false
  end
  return pcall(vim.lsp.enable, NAME)
end

-- Path 2: nvim-lspconfig, when present.
local function attach_lspconfig(opts)
  local ok, lspconfig = pcall(require, 'lspconfig')
  if not ok then
    return false
  end
  local configs_ok, configs = pcall(require, 'lspconfig.configs')
  if not configs_ok then
    return false
  end
  if not configs[NAME] then
    configs[NAME] = {
      default_config = {
        cmd = opts.cmd,
        filetypes = opts.filetypes,
        root_dir = lspconfig.util.root_pattern(unpack(opts.root_markers)),
        single_file_support = opts.single_file_support,
        settings = { carve = opts.settings },
      },
    }
  end
  return pcall(function()
    lspconfig[NAME].setup({ on_attach = opts.on_attach })
  end)
end

-- Path 3: no dependency. One autocmd, vim.lsp.start per buffer.
local function attach_autocmd(opts)
  if type(vim.lsp.start) ~= 'function' then
    return false
  end
  local group = vim.api.nvim_create_augroup('CarveLsp', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = opts.filetypes,
    desc = 'Attach carve-lsp',
    callback = function(args)
      local root = find_root(args.buf, opts.root_markers, opts.single_file_support)
      if not root then
        return
      end
      -- vim.lsp.start deduplicates on (name, root_dir, cmd), so this starts one
      -- server per project rather than one per buffer.
      vim.lsp.start({
        name = NAME,
        cmd = opts.cmd,
        root_dir = root,
        settings = { carve = opts.settings },
        on_attach = opts.on_attach,
      }, { bufnr = args.buf })
    end,
  })
  return true
end

--- Set up the Carve language server.
---
--- Returns the path that was used - 'builtin', 'lspconfig' or 'autocmd' - or
--- nil when nothing was set up, along with a reason. Returning rather than
--- erroring keeps a missing server from breaking a config on startup.
---@param opts table|nil
---@return string|nil path, string|nil reason
function M.setup(opts)
  opts = vim.tbl_deep_extend('force', vim.deepcopy(DEFAULTS), opts or {})

  if not executable(opts.cmd) then
    return nil, string.format(
      "%s not found on PATH; install it with `npm i -g @markup-carve/carve-lsp`",
      tostring(opts.cmd[1])
    )
  end

  if attach_builtin(opts) then
    return 'builtin'
  end
  if attach_lspconfig(opts) then
    return 'lspconfig'
  end
  if attach_autocmd(opts) then
    return 'autocmd'
  end
  return nil, 'no supported attach path (needs Neovim 0.8+)'
end

--- The resolved defaults, for a reader who wants to build their own config
--- from them rather than call setup().
function M.defaults()
  return vim.deepcopy(DEFAULTS)
end

return M
