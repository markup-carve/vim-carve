# Changelog

All notable changes to vim-carve are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases before 0.1.6 are described on the
[releases page](https://github.com/markup-carve/vim-carve/releases).

## [Unreleased]

## [0.1.7] - 2026-10-14

### Fixed

- Frontmatter without a closing `---` no longer colors the rest of the
  buffer; the opening dashes are a thematic break (#70).
- Bare emphasis needs a word boundary outside its delimiters, so
  `snake_case_name`, `a/b/c`, `2*3*4`, `key=value=x`, `==x==` and URL paths
  stay plain. Emphasis and single-backtick code spans may cross one line
  break (#70).
- A list marker or `^ ` line after a paragraph stays prose, and a caption is
  colored only below a block that takes one, not after a heading, a
  paragraph or at the start of the document. A marker after a lazy
  continuation line still opens the next item (#70).
- Inside `> ` quotes, headings, list markers, definition terms, tables and
  container fences are recognized, and a quoted fence body stays code until
  its closer or the end of the quote. Indented headings and definitions
  inside list items are recognized (#70).
- `-->`, `<--`, `==>`, `<==`, `<=>` and the other engine arrows are
  typography; `=>` and upper-case `(C)`, `(R)`, `(TM)` are not (#70).
- `%%` opens a comment only at the start of a line or after a space, so
  `50%% off` and a tab before `%%` stay text (#70).
- `[ref]: url` and `[^id]: text` definition lines are no longer colored as
  links. A `|` line without a closing pipe is not a table row (#70).
- Section folding skips `#` lines inside code and comment blocks and
  `#######` lines; the list indent knows the `. item`, `a. item`, `iv) item`
  and `-{.c} item` markers and no longer treats `+ x` as a bullet (#70).
- `:TSInstall carve` builds the tree-sitter-carve 0.1.9 tag instead of 0.1.6,
  which misses the parser hang fix and the near-linear inline scan. The bundled
  queries are re-copied to match, so they compile against the installed grammar
  (#69).
- Quote text uses the normal text color by default instead of the comment color (#61).
- A `^ text` line before the first block remains prose, including after
  leading blank lines (#66, #67).

### Added

- PHP fences are highlighted by default. A body without a `<?php` opener is
  read as PHP, not as the HTML that Vim's own `php.vim` assumes at its top
  level (#63).

## [0.1.6] - 2026-10-08

### Fixed

- The bundled `sample.crv` matches its cross-reference against the id's own
  case. `</#plan>` was written as though it reached a heading `{#Plan}`; names
  compare case exactly from carve 0.1.8, so it did not, and the plugin no
  longer presents it as though it did (#58).
