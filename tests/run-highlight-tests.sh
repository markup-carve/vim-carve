#!/usr/bin/env bash
# Assert what syntax/carve.vim actually highlights.
#
# The rest of CI only checks that the runtime files LOAD. That leaves every
# highlighting rule unverified, which is how two rules stayed wrong through
# several releases: `>no space` coloured as a blockquote and `- ` as a list,
# where carve-rs renders both as paragraphs.
#
# Each case in tests/cases.txt is `EXPECTED_GROUP<TAB>line`. The group is what
# the syntax reports at column 1, or `-` for none.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
vim_bin="${VIM_BIN:-vim}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# `<SP>` and `<NBSP>` keep trailing and non-ASCII spaces visible in the case
# file; an editor that strips trailing whitespace would otherwise silently
# rewrite the cases into ones that pass.
expand_markers() {
  printf '%s' "$1" | sed -e 's/<SP>/ /g' -e 's/<NBSP>/\xc2\xa0/g'
}

pass=0
fails=()
while IFS=$'\t' read -r expected line; do
  [[ -z "${expected:-}" || "$expected" == \#* ]] && continue
  src="$(expand_markers "$line")"
  printf '%s\n' "$src" > "$work/case.crv"
  "$vim_bin" -u NONE -N -es \
    -c 'syntax on' \
    -c "set runtimepath^=$root" \
    -c "edit $work/case.crv" \
    -c 'set filetype=carve' \
    -c "redir! > $work/out" \
    -c 'echo synIDattr(synID(1, 1, 1), "name")' \
    -c 'redir END' \
    -c 'qa!' </dev/null >/dev/null 2>&1
  actual="$(tr -d '\r\n' < "$work/out")"
  actual="${actual:--}"
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1))
  else
    fails+=("$(printf '%q' "$src"): expected ${expected}, got ${actual}")
  fi
done < "$here/cases.txt"

# An opening caret line is prose after one or several leading blank lines.
for blanks in 1 2; do
  printf '%*s' "$blanks" '' | tr ' ' '\n' > "$work/case.crv"
  printf '^ cap\nafter\n' >> "$work/case.crv"
  line=$((blanks + 1))
  "$vim_bin" -u NONE -N -es \
    -c 'syntax on' \
    -c "set runtimepath^=$root" \
    -c "edit $work/case.crv" \
    -c 'set filetype=carve' \
    -c "redir! > $work/out" \
    -c "echo synIDattr(synID($line, 1, 1), 'name')" \
    -c 'redir END' \
    -c 'qa!' </dev/null >/dev/null 2>&1
  actual="$(tr -d '\r\n' < "$work/out")"
  if [[ -n "$actual" ]]; then
    fails+=("caret after $blanks leading blank lines: expected no group, got $actual")
  else
    pass=$((pass + 1))
  fi
done

# The line number changes when a blank line is inserted in the open buffer.
"$vim_bin" -u NONE -N -es \
  -c 'syntax on' \
  -c "set runtimepath^=$root" \
  -c "edit $work/case.crv" \
  -c 'set filetype=carve' \
  -c "call append(0, '')" \
  -c 'doautocmd TextChanged' \
  -c "redir! > $work/out" \
  -c 'echo synIDattr(synID(4, 1, 1), "name")' \
  -c 'redir END' \
  -c 'qa!' </dev/null >/dev/null 2>&1
actual="$(tr -d '\r\n' < "$work/out")"
if [[ -n "$actual" ]]; then
  fails+=("caret after an inserted blank line: expected no group, got $actual")
else
  pass=$((pass + 1))
fi

# The Carve refresh hook must not add syntax items after a filetype switch.
"$vim_bin" -u NONE -N -es \
  -c 'syntax on' \
  -c "set runtimepath^=$root" \
  -c "edit $work/case.crv" \
  -c 'set filetype=carve | set filetype=text' \
  -c "call append(0, '') | doautocmd TextChanged" \
  -c "redir! > $work/out" \
  -c 'echo synIDattr(synID(4, 1, 1), "name")' \
  -c 'redir END' \
  -c 'qa!' </dev/null >/dev/null 2>&1
actual="$(tr -d '\r\n' < "$work/out")"
if [[ "$actual" == carve* ]]; then
  fails+=("caret after filetype switch: unexpected Carve group $actual")
else
  pass=$((pass + 1))
fi

if ((${#fails[@]})); then
  printf 'Highlight assertion failures:\n'
  printf '  %s\n' "${fails[@]}"
  printf '\n%d of %d cases failed.\n' "${#fails[@]}" "$((pass + ${#fails[@]}))"
  exit 1
fi
printf 'highlight tests: %d cases passed.\n' "$pass"
