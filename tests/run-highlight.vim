" Assertion runner for the Carve syntax file.
"
" Reads tests/highlight.crv, where an assertion is a line beginning with `%%`
" whose carets mark columns of the LAST non-assertion line, followed by the
" syntax group every marked column must carry:
"
"     # Heading one
"     %%^^^^^^^^^^^^ carveHeading1
"
" The leading `%%` is TRANSPARENT: a caret in column N marks column N-2 of the
" target, so column 1 is markable (`%%^`) even though the comment token sits
" there in the assertion line itself.
"
" The form is Sublime's, and it is in the document rather than beside it so a
" case cannot drift from the source it describes. `%%` is a Carve comment, so
" the file is still a valid Carve document.
"
" Exits non-zero on the first mismatch, naming line, column, wanted and found.
set nocompatible
filetype plugin on
syntax enable
setfiletype carve

let s:failures = []
let s:checks = 0
let s:target = 0

for s:lnum in range(1, line('$'))
  let s:line = getline(s:lnum)
  if s:line !~# '^%%\s*\^'
    if s:line !~# '^%%'
      let s:target = s:lnum
    endif
    continue
  endif
  if s:target == 0
    call add(s:failures, 'line ' . s:lnum . ': assertion with no preceding source line')
    continue
  endif
  let s:want = matchstr(s:line, '\^\+\s\+\zs\S\+')
  if s:want ==# ''
    call add(s:failures, 'line ' . s:lnum . ': assertion names no syntax group')
    continue
  endif
  for s:col in range(1, strlen(s:line))
    if s:line[s:col - 1] !=# '^'
      continue
    endif
    let s:checks += 1
    let s:tcol = s:col - 2
    let s:id = synID(s:target, s:tcol, 1)
    let s:got = s:id ? synIDattr(s:id, 'name') : '(none)'
    if s:got !=# s:want
      call add(s:failures, printf('line %d col %d: want %s, got %s  [%s]',
            \ s:target, s:tcol, s:want, s:got, getline(s:target)))
    endif
  endfor
endfor

if empty(s:failures)
  call writefile(['highlight: ' . s:checks . ' column assertion(s) passed'], '/dev/stdout')
  qa!
endif

call writefile(['highlight: ' . len(s:failures) . ' failure(s)'] + s:failures, '/dev/stderr')
cquit
