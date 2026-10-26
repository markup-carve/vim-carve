# carve.vim

Vim and Neovim highlighting for Carve `.crv` files. The optional Neovim parser uses the Tree-sitter Carve revision pinned in the setup guide. See the [Carve documentation](https://markup-carve.github.io/carve/) for the markup language.

## Features

- File detection and regex highlighting in Vim or Neovim.
- Optional Tree-sitter queries, folds, and indentation in Neovim.
- Optional `carve-lsp` integration.

## Install

With vim-plug, add this line and run `:PlugInstall`:

```vim
Plug 'markup-carve/vim-carve'
```

## Usage

Open a `.crv` file. For optional Neovim setup, follow the [guide](docs/guide.md#tree-sitter-neovim).

## Documentation

- [Carve documentation](https://markup-carve.github.io/carve/)
- [Setup and full guide](docs/guide.md)
- [Documentation index](docs/README.md)

## License

[MIT](LICENSE)
