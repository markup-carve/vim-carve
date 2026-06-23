# carve.vim

Vim and Neovim support for the [Carve](https://carve.dev) markup language
(`*.crv`, `*.carve`).

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

- Filetype detection for `*.crv` and `*.carve`.
- Syntax highlighting for headings, inline emphasis (`/italic/`, `*bold*`,
  `_underline_`, `~strike~`, `=highlight=`, `^sup^`, `,,sub,,`, `` `code` ``),
  links, autolinks, images, cross-refs, references, footnotes, lists and task
  items, blockquotes and captions, fenced code (with language, `"Header"`,
  `[Label]`, and raw ` ```=html `), divs and admonitions, block/inline
  attributes, tables, math (inline `$\`..\``, display `$$\`..\``, ` ```math `),
  frontmatter, comments (`%%`, `%%% ... %%%`), mentions, tags, smart
  typography, and CriticMarkup.
- `commentstring=%% %s` and a minimal list/quote indent.
- Optional concealing (`let g:carve_conceal = 1`) and section folding
  (`let g:carve_folding = 1`).

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

## Configuration

| Global                | Default | Effect                                  |
|-----------------------|---------|-----------------------------------------|
| `g:carve_conceal`     | `0`     | `conceallevel=2` to hide markup delims. |
| `g:carve_folding`     | `0`     | Fold by ATX heading level.              |

`setup()` options (Neovim tree-sitter):

| Option              | Default                                            | Effect                                   |
|---------------------|----------------------------------------------------|------------------------------------------|
| `parser_path`       | `nil`                                              | Register a pre-compiled parser directly. |
| `install_url`       | tree-sitter-carve repo                             | URL for `:TSInstall carve`.              |
| `install_revision`  | `main`                                             | Branch/revision to install.              |
| `register_filetype` | `true`                                             | Map `carve` filetype to `carve` lang.    |

## License

MIT. The bundled queries are derived from tree-sitter-carve (also MIT). See
[LICENSE](LICENSE).
