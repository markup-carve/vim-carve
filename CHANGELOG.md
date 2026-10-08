# Changelog

All notable changes to vim-carve are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases before 0.1.6 are described on the
[releases page](https://github.com/markup-carve/vim-carve/releases).

## [Unreleased]

## [0.1.6] - 2026-10-08

### Fixed

- The bundled `sample.crv` matches its cross-reference against the id's own
  case. `</#plan>` was written as though it reached a heading `{#Plan}`; names
  compare case exactly from carve 0.1.8, so it did not, and the plugin no
  longer presents it as though it did (#58).
