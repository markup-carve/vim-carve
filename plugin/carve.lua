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
