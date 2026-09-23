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
  `/*bold italic*/`, `_underline_`, `~strike~`, `=highlight=`, `{^sup^}`,
  `{,sub,}`, `` `code` ``) and their braced forms (`{*bold*}`, `{/italic/}`,
  `{_under_}`, `{~strike~}`, `{=mark=}`), links, autolinks, images in all three
  forms (`![alt](src)`, `![alt][ref]`, `![alt][]`), cross-refs, references,
  footnotes, lists and task items, blockquotes and captions, fenced code (with
  language, `"Header"`, `[Label]`), raw passthrough blocks (` ```=html `), divs
  and admonitions, line blocks (`::: |`) and local hard-break blocks
  (`::: \`), block/inline attributes, tables, math (inline `$\`..\``, display
  `$$\`..\``, ` ```math `), frontmatter, comments (`%%`, `%%% ... %%%`,
  `{% ... %}`), mentions, tags, smart typography, CriticMarkup, and the
  reserved include directive (`{{ path #section @opt:value }}`).
- Fenced code in a listed language is highlighted as that language (see
  `g:carve_fenced_languages` below). A fence closes only on its own character,
  at least as long as its opener, so a four-backtick fence can hold a
  three-backtick sample.
- A verbatim payload stays verbatim: nothing inside a code block, raw block,
  code span, inline literal, math span or comment is highlighted as markup.
- A bare delimiter never pairs across a link destination, an image source or
  an autolink (PART 9 §9 E2a), so `/see [x](http://a.b/c/) now/` is one
  italic run. Vim patterns cannot recurse, which leaves four limits: a
  destination with parentheses three deep, a link label with brackets three
  deep, a label holding a code span with `]`, and an email autolink with a
  non-ASCII character are not recognized, so a delimiter inside one can still
  close the run.
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

This route uses the parser-config API of nvim-treesitter's `master` branch
(`require('nvim-treesitter.parsers').get_parser_configs()`). The config
compiles `src/parser.c` and `src/scanner.c` and pins the grammar with
`revision`. The rewritten `main` branch of nvim-treesitter has no
`get_parser_configs()`, so there `setup()` registers nothing; use Route 2.

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

One deliberate delta: `injections.scm` guards every document-named language
with a `carve-injectable?` predicate, which `plugin/carve.lua` registers. On
Neovim below 0.10 it refuses to inject Carve into Carve, because 0.9 segfaults
on a ```` ```carve ```` fence; there such a fence stays plain text. The delta is
recorded in `tools/query-deltas/injections.scm.diff`, and the drift check
requires the file to differ from upstream by exactly that.

`install_revision` (below) is pinned to the exact tree-sitter-carve commit
these were copied from, so `:TSInstall carve` compiles a grammar that matches
them. Bump both together whenever the queries are re-copied - an unpinned
`main` would let the compiled grammar and the bundled queries drift apart
silently.

Four checks keep that honest. `tools/check-query-drift.sh` proves the copies
still match tree-sitter-carve at the pinned commit, and
`tests/run-treesitter-captures.sh` reads what those queries actually capture
from that grammar - the only check here that can notice a pin left behind, since
a stale one matches its own queries perfectly. `tests/run-nvim-injection-tests.sh`
runs `injections.scm` inside Neovim (`NVIM_BIN` picks the binary).
`tests/run-install-info-build.sh`
compiles the grammar from exactly the `install_info.files` list that
`:TSInstall carve` uses and loads the result, so a missing source file fails CI.

## Configuration

| Global                | Default | Effect                                  |
|-----------------------|---------|-----------------------------------------|
| `g:carve_conceal`     | `0`     | `conceallevel=2` to hide markup delims. |
| `g:carve_folding`     | `0`     | Fold by ATX heading level.              |

`g:carve_fenced_languages` lists the fence tags whose body gets that language's
Vim syntax, as `tag` or `tag=syntax` (the same shape as vim-markdown's
`g:markdown_fenced_languages`). A tag is skipped when no `syntax/<name>.vim`
is on the runtimepath. Each entry loads a syntax file per buffer, so the
default is short:

```vim
let g:carve_fenced_languages = ['bash=sh', 'diff', 'javascript',
      \ 'js=javascript', 'json', 'py=python', 'python', 'sh',
      \ 'ts=typescript', 'typescript', 'yaml', 'yml=yaml']
" add more, or [] to embed nothing
```

`setup()` options (Neovim tree-sitter):

| Option              | Default                                    | Effect                                                |
|---------------------|---------------------------------------------|------------------------------------------------------|
| `parser_path`       | `nil`                                       | Register a pre-compiled parser directly.              |
| `install_url`       | tree-sitter-carve repo                      | URL for `:TSInstall carve`.                           |
| `install_revision`  | `9323ff5f9d87b20372fc3f4f9052fed67dd176ff`  | Revision to install (the 0.1.6 tag; pinned to the bundled queries).  |
| `register_filetype` | `true`                                      | Map `carve` filetype to `carve` lang.                 |

## License

The bundled queries are derived from tree-sitter-carve (also MIT);
third-party attribution is in [NOTICE](NOTICE).
