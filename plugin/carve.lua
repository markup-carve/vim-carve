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
    return node == nil or vim.treesitter.get_node_text(node, source) ~= 'carve'
  end, { force = true })
end)
