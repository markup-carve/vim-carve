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

# The checkbox is a task marker only when content follows it on the line.
for case in '!carveTaskMark|- [ ]' '!carveTaskMark|- [ ]   ' \
            'carveTaskMark|- [ ] done' 'carveTaskMark|- [ ] +' \
            $'carveTaskMark|- [ ] \tdone' $'!carveTaskMark|- [ ]\tdone'; do
  expected="${case%%|*}"
  src="${case#*|}"
  printf '%s\n' "$src" > "$work/case.crv"
  "$vim_bin" -u NONE -N -es \
    -c 'syntax on' \
    -c "set runtimepath^=$root" \
    -c "edit $work/case.crv" \
    -c 'set filetype=carve' \
    -c "redir! > $work/out" \
    -c 'echo synIDattr(synID(1, 3, 1), "name")' \
    -c 'redir END' \
    -c 'qa!' </dev/null >/dev/null 2>&1
  actual="$(tr -d '\r\n' < "$work/out")"
  actual="${actual:-none}"
  if [[ "$actual" == "$expected" || ( "$expected" == '!carveTaskMark' && "$actual" != 'carveTaskMark' ) ]]; then
    pass=$((pass + 1))
  else
    fails+=("$src: expected $expected at checkbox, got $actual")
  fi
done

# A lone `+` is the marker only where it attaches the next block: at an open
# container's marker column with a block at that column next, or right after a
# block opener (PART 9 SS17). Every other `+` stays text. The first `+` that
# ends a line is checked; each row was read against carve-js main.
while IFS='|' read -r expected src; do
  [[ -z "$expected" || "$expected" == \#* ]] && continue
  printf '%b\n' "$src" > "$work/case.crv"
  pos="$(awk '/\+[ \t]*$/ { print NR, index($0, "+"); exit }' "$work/case.crv")"
  "$vim_bin" -u NONE -N -es \
    -c 'syntax on' \
    -c "set runtimepath^=$root" \
    -c "edit $work/case.crv" \
    -c 'set filetype=carve' \
    -c "redir! > $work/out" \
    -c "echo join(map(synstack(${pos% *}, ${pos#* }), 'synIDattr(v:val, \"name\")'))" \
    -c 'redir END' \
    -c 'qa!' </dev/null >/dev/null 2>&1
  stack="$(tr -d '\r\n' < "$work/out")"
  if [[ " $stack " == *Continuation* ]]; then actual=M; else actual=T; fi
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1))
  else
    fails+=("$src: expected $expected at the +, got $actual ($stack)")
  fi
done <<'CASES'
M|- a\n+\nb
M|- a\n  - b\n  +\n  c
M|- a\n  - b\n+\npara
M|  - a\n  +\n  b
M|1. a\n+\nb
M|- a\n\n+\nb
M|- a\nlazy\n+\nb
M|- a\n+\n> q
M|- a\n+\n```\nx\n```
M|> quoted\n+\n> attached
M|:: t\n: a\n+\n- b
M|[^a]: x\n+\n- b
M|> - a\n> +\n> para
M|> - a\n>+\n> para
M|> +\nflush
M|>+\nflush
M|> > +\nflush
M|>> +\nflush
M|> outer\n> > +\nflush
M|- a\n  > +\npara
M|- +\nflush
M|- [ ] +\nflush
M|- > +\nflush
M|- - +\nflush
M|:: t\n: +\nflush
M|[^a]: +\nflush
T|- a\n  +\n  b
T|- a\n    +\n    b
T|- a\n  - b\n  +\npara
T|- a\n  - b\n+\n  c
T|- a\n+\n- b
T|1. a\n+\n2. b
T|- a\n+
T|- a\n+\n\nb
T|text\n- a\n+\nb
T|para\n+\nx
T|para\n\n+\nb
T|+\nx
T|> a\n> +\n> b
T|> +\n> x
T|> +
T|> +\n\nafter
T|> a\n> +\nflush
T|>   +\n> para
T|> - a\n> +\npara
T|> +\n- c
T|: +\nflush
T|: a\n+\n- b
M|                    - a\n                    +\n                    b
T|[^a]: +\n- x
T|[^a]: +\n  > q
T|```\n+\n```
T|- a\n  ```\n  +\n  x\n  ```
CASES

# A `:` line is a description only below a term; a lazy colon line in a quote
# and a lone one are paragraph text (carve#3493).
for case in 'carveDefBody|:: t\n: d' 'carveDefBody|:: t\n\n: d' '-|: d' \
            '-|> a\n: d' '-|> :: t\n: d' '-|:: t\n\nfoo\n: d'; do
  expected="${case%%|*}"
  printf '%b\n' "${case#*|}" > "$work/case.crv"
  "$vim_bin" -u NONE -N -es \
    -c 'syntax on' \
    -c "set runtimepath^=$root" \
    -c "edit $work/case.crv" \
    -c 'set filetype=carve' \
    -c "redir! > $work/out" \
    -c 'echo synIDattr(synID(line("$"), 1, 1), "name")' \
    -c 'redir END' \
    -c 'qa!' </dev/null >/dev/null 2>&1
  actual="$(tr -d '\r\n' < "$work/out")"
  actual="${actual:--}"
  if [[ "$actual" == "$expected" || ( "$expected" == - && "$actual" != carveDefBody ) ]]; then
    pass=$((pass + 1))
  else
    fails+=("${case#*|}: expected $expected on the last line, got $actual")
  fi
done

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
  -c 'echo synIDattr(synID(4, 1, 0), "name")' \
  -c 'redir END' \
  -c 'qa!' </dev/null >/dev/null 2>&1
actual="$(tr -d '\r\n' < "$work/out")"
if [[ "$actual" == carve* ]]; then
  fails+=("caret after filetype switch: unexpected Carve group $actual")
else
  pass=$((pass + 1))
fi

# A buffer may select Carve syntax without changing its filetype.
"$vim_bin" -u NONE -N -es \
  -c 'syntax on' \
  -c "set runtimepath^=$root" \
  -c "edit $work/case.crv" \
  -c 'set filetype=text | set syntax=carve' \
  -c "redir! > $work/out" \
  -c 'echo synIDattr(synID(3, 1, 1), "name")' \
  -c 'redir END' \
  -c 'qa!' </dev/null >/dev/null 2>&1
actual="$(tr -d '\r\n' < "$work/out")"
if [[ -n "$actual" ]]; then
  fails+=("caret with syntax=carve: expected no group, got $actual")
else
  pass=$((pass + 1))
fi

# Changing only the syntax must stop the Carve refresh hook.
"$vim_bin" -u NONE -N -es \
  -c 'syntax on' \
  -c "set runtimepath^=$root" \
  -c "edit $work/case.crv" \
  -c 'set filetype=carve | set syntax=markdown' \
  -c "call append(0, '') | doautocmd TextChanged" \
  -c "redir! > $work/out" \
  -c 'echo synIDattr(synID(4, 1, 0), "name")' \
  -c 'redir END' \
  -c 'qa!' </dev/null >/dev/null 2>&1
actual="$(tr -d '\r\n' < "$work/out")"
if [[ "$actual" == carve* ]]; then
  fails+=("caret after syntax switch: unexpected Carve group $actual")
else
  pass=$((pass + 1))
fi

# Reloading the syntax must rebuild its line-specific opening caret match.
"$vim_bin" -u NONE -N -es \
  -c 'syntax on' \
  -c "set runtimepath^=$root" \
  -c "edit $work/case.crv" \
  -c 'set filetype=carve | edit' \
  -c "redir! > $work/out" \
  -c 'echo synIDattr(synID(3, 1, 1), "name")' \
  -c 'redir END' \
  -c 'qa!' </dev/null >/dev/null 2>&1
actual="$(tr -d '\r\n' < "$work/out")"
if [[ -n "$actual" ]]; then
  fails+=("caret after syntax reload: expected no group, got $actual")
else
  pass=$((pass + 1))
fi

# CSV and TSV separators resolve to Operator, which default colorschemes color.
for grp in carveCsvSeparator carveTsvSeparator; do
  "$vim_bin" -u NONE -N -es \
    -c 'syntax on' \
    -c "set runtimepath^=$root" \
    -c "edit $work/case.crv" \
    -c 'set filetype=carve' \
    -c "redir! > $work/out" \
    -c "silent hi $grp" \
    -c 'redir END' \
    -c 'qa!' </dev/null >/dev/null 2>&1
  actual="$(tr -d '\r\n' < "$work/out")"
  if [[ "$actual" == *"links to Operator" ]]; then
    pass=$((pass + 1))
  else
    fails+=("$grp: expected Operator, got $actual")
  fi
done

# A long line of unclosed openers makes the NFA engine give up; the emphasis
# patterns must not fall back to the backtracking engine, which rejects their
# wide Unicode classes (E945, E339).
printf '*a %.0s' $(seq 1 400) > "$work/case.crv"
printf '\n' >> "$work/case.crv"
"$vim_bin" -u NONE -N -es \
  -c 'syntax on' \
  -c "set runtimepath^=$root" \
  -c "edit $work/case.crv" \
  -c 'set filetype=carve' \
  -c "redir! > $work/out" \
  -c 'echo synIDattr(synID(1, 1100, 1), "name")' \
  -c 'redir END' \
  -c 'qa!' </dev/null >/dev/null 2>&1 || true
if grep -q 'E[0-9]\+:' "$work/out"; then
  fails+=("long unclosed emphasis line: $(grep -o 'E[0-9]\+:.*' "$work/out" | head -n1)")
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
