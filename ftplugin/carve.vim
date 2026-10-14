" Carve filetype plugin
" Part of markup-carve/vim-carve
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

" Carve uses %% for line comments.
setlocal commentstring=%%\ %s
setlocal comments=b:%%

" Word/keyword tweaks so @mentions, #tags and #ids select sensibly.
setlocal iskeyword+=-

" Wrapping suited to prose.
setlocal linebreak
setlocal breakindent

" Optional concealing: off by default so raw markup stays visible. Users can
" opt in with `let g:carve_conceal = 1` in their config.
if get(g:, 'carve_conceal', 0)
  setlocal conceallevel=2
  setlocal concealcursor=
endif

" Folding by section headings is available but disabled by default. Enable
" with `let g:carve_folding = 1`.
if get(g:, 'carve_folding', 0)
  setlocal foldmethod=expr
  setlocal foldexpr=CarveFoldLevel(v:lnum)
endif

let b:undo_ftplugin = 'setlocal commentstring< comments< iskeyword<'
      \ . ' linebreak< breakindent< conceallevel< concealcursor<'
      \ . ' foldmethod< foldexpr<'

" A heading is one to six `#` and a space. With syntax on, a `#` line inside a
" code block or a comment block is not a heading, so it opens no fold.
if !exists('*CarveFoldLevel')
  function! CarveFoldLevel(lnum) abort
    let l:hashes = matchstr(getline(a:lnum), '^#\{1,6}\ze \+\S')
    if l:hashes ==# ''
      return '='
    endif
    if exists('g:syntax_on') && get(b:, 'current_syntax', '') ==# 'carve'
          \ && synIDattr(synID(a:lnum, 1, 1), 'name') !~# '^carveHeading'
      return '='
    endif
    return '>' . len(l:hashes)
  endfunction
endif

let &cpo = s:save_cpo
unlet s:save_cpo
