# Changelog

All notable changes to vim-carve are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases before 0.1.6 are described on the
[releases page](https://github.com/markup-carve/vim-carve/releases).

## [Unreleased]

## [0.1.7] - 2026-10-14

### Fixed

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
