-- Auto-registration for Neovim. Guarded so it is a no-op in classic Vim
-- (which never sources *.lua under plugin/) and harmless when tree-sitter is
-- unavailable. The regex syntax is the baseline; this only adds the
-- filetype->language mapping so bundled queries can apply if a `carve` parser
-- gets installed. It deliberately does NOT compile or download anything.

if vim.g.loaded_carve then
  return
end
vim.g.loaded_carve = true

-- Map the `carve` filetype to the `carve` tree-sitter language. This is cheap
-- and safe even when no parser is installed yet.
pcall(function()
  if vim.treesitter and vim.treesitter.language and vim.treesitter.language.register then
    vim.treesitter.language.register('carve', 'carve')
  end
end)

-- Neovim 0.9 segfaults when a Carve document injects Carve into itself (a
-- ```carve fence); 0.10.0 is the first release that parses it. The bundled
-- injections.scm guards every document-named language with this predicate.
pcall(function()
  local query = vim.treesitter.query
  local self_injection_safe = vim.fn.has('nvim-0.10') == 1
  query.add_predicate('carve-injectable?', function(match, _, source, predicate)
    if self_injection_safe then
      return true
    end
    local node = match[predicate[2]]
    if type(node) == 'table' then
      node = node[#node]
    end
    local lang = node and vim.treesitter.get_node_text(node, source):lower()
    return lang ~= 'carve' and lang ~= 'crv'
  end, { force = true })
end)

-- A fence's info string is what people type (`js`, `py`, `sh`), not a parser
-- name. Resolve it through Vim's filetype detection first, the way
-- nvim-treesitter's markdown queries do; the table covers extensions that
-- need file contents to detect. Namespaced so it never races nvim-treesitter's
-- own set-lang-from-info-string! at startup.
pcall(function()
  local aliases = { crv = 'carve', ex = 'elixir', pl = 'perl', sh = 'bash', uxn = 'uxntal', ts = 'typescript' }
  vim.treesitter.query.add_directive('carve-set-lang-from-info-string!', function(match, _, source, directive, metadata)
    local node = match[directive[2]]
    if type(node) == 'table' then
      node = node[#node]
    end
    if not node then
      return
    end
    local alias = vim.treesitter.get_node_text(node, source):lower()
    local ft = vim.filetype.match({ filename = 'a.' .. alias }) or aliases[alias] or alias
    local lang = vim.treesitter.language.get_lang(ft) or ft
    -- Same guard as carve-injectable?, on the RESOLVED name: `crv` resolves to
    -- carve too, and Neovim 0.9 segfaults on that self-injection.
    if lang == 'carve' and vim.fn.has('nvim-0.10') == 0 then
      return
    end
    -- 0.9 takes this as the parser name as-is; 0.10+ resolves it again.
    metadata['injection.language'] = lang
  end, { force = true })
end)

vim.api.nvim_create_user_command('CarveImport', function(args)
  local import = require('carve.import')
  local file = args.args ~= '' and vim.fn.expand(args.args) or vim.api.nvim_buf_get_name(0)
  local format
  if file ~= '' and not import.format_for(file) then
    local names = { 'markdown', 'html', 'djot', 'bbcode' }
    local choice = vim.fn.confirm('Source format of ' .. vim.fn.fnamemodify(file, ':t') .. '?',
      '&markdown\n&html\n&djot\n&bbcode', 0)
    if choice == 0 then
      return
    end
    format = names[choice]
  end
  import.import(file, { format = format, force = args.bang })
end, {
  nargs = '?',
  bang = true,
  complete = 'file',
  desc = 'Convert Markdown/HTML/Djot/BBCode to a sibling .crv with carve migrate',
})
