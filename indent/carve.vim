" Carve indent file
" Part of markup-carve/vim-carve
" Minimal indent: keep list / blockquote prefixes aligned on <CR> and ==.
if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetCarveIndent()
setlocal indentkeys=!^F,o,O
setlocal autoindent

let b:undo_indent = 'setlocal indentexpr< indentkeys< autoindent<'

if exists('*GetCarveIndent')
  finish
endif

function! GetCarveIndent() abort
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let prev = getline(lnum)
  let prev_indent = indent(lnum)

  " Continue a blockquote. The marker takes a space, or stands alone on its
  " line - `>no space` is a paragraph, so it must not hold the quote indent
  " (markup-carve/carve#525, same rule as syntax/carve.vim).
  if prev =~# '^[ \t]*>\( \|$\)'
    return prev_indent
  endif

  " Continue inside a list item: align the body under the marker text.
  let m = matchlist(prev, '^\(\s*\)\%(\([-*+]\)\|\(\d\+[.)]\)\)\s\+')
  if !empty(m)
    " Width of the leading whitespace plus the marker plus following spaces.
    return strdisplaywidth(matchstr(prev, '^\(\s*\)\%(\([-*+]\)\|\(\d\+[.)]\)\)\s\+'))
  endif

  return prev_indent
endfunction
