# carve.vim

Vim and Neovim support for the [Carve](https://github.com/markup-carve/carve) markup language
(`*.crv`).

One repository, two highlighting layers:

- **Classic regex syntax** (`syntax/carve.vim`): works in classic Vim and in
  Neovim with no extra setup, no parser to compile. Maps Carve constructs to
  standard highlight groups so any colorscheme looks sensible.
- **Tree-sitter** (Neovim only, optional): richer, parser-driven highlighting
  plus folds, indents, language injections and text objects, using the queries
  bundled under `queries/carve/`. Requires the `carve` tree-sitter parser.

The regex layer is the always-on baseline. The tree-sitter layer is a strict
upgrade for Neovim users who install the parser.

## What you get

- Filetype detection for `*.crv`.
- Syntax highlighting for headings, inline emphasis (`/italic/`, `*bold*`,
  `_underline_`, `~strike~`, `=highlight=`, `{^sup^}`, `{,sub,}`, `` `code` ``),
  links, autolinks, images, cross-refs, references, footnotes, lists and task
  items, blockquotes and captions, fenced code (with language, `"Header"`,
  `[Label]`, and raw ` ```=html `), divs and admonitions, block/inline
  attributes, tables, math (inline `$\`..\``, display `$$\`..\``, ` ```math `),
  frontmatter, comments (`%%`, `%%% ... %%%`), mentions, tags, smart
  typography, and CriticMarkup.
- `commentstring=%% %s` and a minimal list/quote indent.
- Optional concealing (`let g:carve_conceal = 1`) and section folding
  (`let g:carve_folding = 1`).
- Optional language-server support via
  [carve-lsp](https://github.com/markup-carve/carve-lsp) (Neovim): diagnostics,
  hover, completion, go-to-definition, workspace-wide rename, find-references,
  code actions and formatting.

## Install

### vim-plug (Vim or Neovim)

```vim
Plug 'markup-carve/vim-carve'
```

### lazy.nvim (Neovim)

```lua
{
  'markup-carve/vim-carve',
  ft = { 'carve' },
  config = function()
    require('carve').setup()
  end,
}
```

### packer.nvim (Neovim)

```lua
use {
  'markup-carve/vim-carve',
  config = function()
    require('carve').setup()
  end,
}
```

### Manual

```sh
git clone https://github.com/markup-carve/vim-carve ~/.vim/pack/plugins/start/carve.vim
# Neovim:
git clone https://github.com/markup-carve/vim-carve \
  ~/.local/share/nvim/site/pack/plugins/start/carve.vim
```

That is all you need for the classic regex syntax in either editor.

## Language server (Neovim)

The regex syntax and the tree-sitter queries both describe the document's
SHAPE. The language server knows what its identifiers MEAN: which `[^note]` has
no definition, which `</#id>` cross-reference points at nothing, and that
`**bold**` is a Markdown habit that renders as two literal asterisks in Carve.
No highlighting rule can answer those.

Install the server, then opt in:

```bash
npm i -g @markup-carve/carve-lsp
```

```lua
require('carve.lsp').setup()
```

Nothing starts on its own - attaching a server spawns a process, and that is
your decision rather than a side effect of installing a syntax plugin. If the
server is not on `PATH`, `setup()` is a no-op that returns a reason instead of
erroring, so a config that calls it stays valid on a machine without it.

Three attach paths are tried in order, so this works on Neovim 0.8 through
current, with or without nvim-lspconfig:

| Path | When |
| ---- | ---- |
| `vim.lsp.config` + `vim.lsp.enable` | Neovim 0.11+ |
| nvim-lspconfig | when it is installed |
| a `FileType` autocmd calling `vim.lsp.start` | always; no dependency |

`setup()` returns which one it used (`'builtin'`, `'lspconfig'`, `'autocmd'`),
or `nil` plus a reason.

The workspace root is found by walking up for `.git`. That matters rather than
being a detail: rename, find-references and go-to-definition are workspace-wide,
so renaming a heading id updates every reference pointing at it - and a server
rooted at the file's own directory would silently narrow that to one folder.

Options, all optional:

```lua
require('carve.lsp').setup({
  cmd = { 'carve-lsp', '--stdio' },   -- the server command
  filetypes = { 'carve', 'crv' },     -- what to attach to
  root_markers = { '.git' },          -- how the workspace root is found
  settings = {},                      -- server settings; see carve-lsp's README
  single_file_support = true,         -- attach outside a project too
  on_attach = function(client, bufnr) -- your keymaps
  end,
})
```

`require('carve.lsp').defaults()` returns the table above, for building your own
config from it instead of calling `setup()`.

## Tree-sitter (Neovim)

The tree-sitter grammar lives in
[tree-sitter-carve](https://github.com/markup-carve/tree-sitter-carve) and must
be compiled per platform. There are two supported routes.

### Route 1: nvim-treesitter (recommended)

`require('carve').setup()` registers a parser config so you can install and use
the parser the normal way:

```lua
require('carve').setup()
-- then, once:
-- :TSInstall carve
```

After install, Neovim picks the parser for the `carve` filetype and applies the
bundled queries automatically.

### Route 2: a pre-compiled parser

If you already built the parser (for example with `tree-sitter build`, which
produces `carve.so`), point `setup()` at it. No nvim-treesitter required:

```lua
require('carve').setup({
  parser_path = '/path/to/carve.so',
})
-- start tree-sitter highlighting for the current buffer:
-- :lua require('carve').start()
```

This calls `vim.treesitter.language.add('carve', { path = ... })` and maps the
`carve` filetype to the `carve` language.

### Bundled queries

`queries/carve/*.scm` are copied verbatim from tree-sitter-carve and are the
source of truth: `highlights.scm`, `folds.scm`, `indents.scm`,
`injections.scm`, `locals.scm`, `textobjects.scm`, `context.scm`.

`install_revision` (below) is pinned to the exact tree-sitter-carve commit
these were copied from, so `:TSInstall carve` compiles a grammar that matches
them. Bump both together whenever the queries are re-copied - an unpinned
`main` would let the compiled grammar and the bundled queries drift apart
silently.

## Configuration

| Global                | Default | Effect                                  |
|-----------------------|---------|-----------------------------------------|
| `g:carve_conceal`     | `0`     | `conceallevel=2` to hide markup delims. |
| `g:carve_folding`     | `0`     | Fold by ATX heading level.              |

`setup()` options (Neovim tree-sitter):

| Option              | Default                                    | Effect                                                |
|---------------------|---------------------------------------------|------------------------------------------------------|
| `parser_path`       | `nil`                                       | Register a pre-compiled parser directly.              |
| `install_url`       | tree-sitter-carve repo                      | URL for `:TSInstall carve`.                           |
| `install_revision`  | `17362de88d2c3177e7c6b4d5f83841f38a42ae4d`  | Revision to install (post-0.1.2 main, at composite figures; pinned to the bundled queries).  |
| `register_filetype` | `true`                                      | Map `carve` filetype to `carve` lang.                 |

## License

The bundled queries are derived from tree-sitter-carve (also MIT);
third-party attribution is in [NOTICE](NOTICE).
