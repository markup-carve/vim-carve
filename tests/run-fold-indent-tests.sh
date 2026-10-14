#!/usr/bin/env bash
# Assert the section folds (g:carve_folding) and the list indent.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
vim_bin="${VIM_BIN:-vim}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fails=()
pass=0

# A `#` line opens a fold only when it is a heading: not inside a code block or
# a comment block, and not with seven or more `#`.
printf '%s\n' '# Title' '' 'text' '' '```bash' '## not a heading' '```' '' \
  '%%%' '### hidden heading' '%%%' '' '####### seven' '' '## Two' > "$work/fold.crv"
"$vim_bin" -Nu NONE -es \
  --cmd "set rtp^=$root" \
  --cmd 'let g:carve_folding = 1' \
  -c 'filetype plugin on' -c 'syntax on' \
  -c "edit $work/fold.crv" \
  -c "call writefile(map(range(1, line('$')), 'foldlevel(v:val)'), '$work/out')" \
  -c 'qa!' </dev/null >/dev/null 2>&1
got="$(tr '\n' ' ' < "$work/out")"
want='1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 '
if [[ "$got" == "$want" ]]; then
  pass=$((pass + 1))
else
  fails+=("fold levels: got [$got], expected [$want]")
fi

# The line after a list item is indented under the item's text.
check_indent() {
  local name="$1" line="$2" want="$3"
  printf '%s\n%s\n' "$line" 'next' > "$work/ind.crv"
  "$vim_bin" -Nu NONE -es \
    --cmd "set rtp^=$root" \
    -c 'filetype indent on' \
    -c "edit $work/ind.crv" \
    -c "let v:lnum = 2 | call writefile([GetCarveIndent()], '$work/out')" \
    -c 'qa!' </dev/null >/dev/null 2>&1
  local got
  got="$(cat "$work/out")"
  if [[ "$got" == "$want" ]]; then
    pass=$((pass + 1))
  else
    fails+=("$name: indent $got, expected $want")
  fi
}
check_indent 'bullet' '- item' 2
check_indent 'decimal' '1. item' 3
check_indent 'bare dot' '. item' 2
check_indent 'letter' 'a. item' 3
check_indent 'roman paren' 'iv) item' 4
check_indent 'glued attributes' '-{.c} item' 6
check_indent 'plus is not a bullet' '+ x' 0

if ((${#fails[@]})); then
  printf 'fold/indent failures:\n'
  printf '  %s\n' "${fails[@]}"
  exit 1
fi
printf 'fold/indent tests: %d cases passed.\n' "$pass"
