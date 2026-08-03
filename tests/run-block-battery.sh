#!/usr/bin/env bash
# Run the shared block battery against this syntax file.
#
# tests/lib/block-battery.json is carve-grammars' table, vendored. Six copies of
# these block rules exist across the Carve editor integrations, and the same
# rule has been fixed across all of them twice; the second time one copy
# silently missed it and only a hand comparison caught it. The battery is that
# comparison made routine.
#
# tests/cases.txt stays as well, and is not redundant: it pins vim-specific
# detail the battery cannot express, such as WHICH heading level a line gets.
# The battery pins the classification every grammar must agree on.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
vim_bin="${VIM_BIN:-vim}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Vim's syntax groups are named after Carve constructs; the battery names
# classifications. Map one to the other so both stay readable.
classify() {
  case "$1" in
    carveHeading[1-6]) echo heading ;;
    carveCaption) echo caption ;;
    carveBlockquote) echo quote ;;
    carveDefTerm | carveDefBody) echo deflist ;;
    carveList*) echo list ;;
    "") echo none ;;
    *) echo "none" ;;
  esac
}

mapfile -t rows < <(python3 - "$root/tests/lib/block-battery.json" <<'PY'
import json, sys
with open(sys.argv[1]) as handle:
    data = json.load(handle)
for shape in data["shapes"]:
    # Tab-separated, with the source last so trailing spaces survive the split.
    print("{}\t{}\t{}".format(shape["want"], shape.get("why", ""), shape["src"]))
PY
)

pass=0
fails=()
for row in "${rows[@]}"; do
  want="${row%%$'\t'*}"
  rest="${row#*$'\t'}"
  why="${rest%%$'\t'*}"
  src="${rest#*$'\t'}"

  # A trailing line keeps the shape off the last line of the buffer, where a
  # `$`-anchored rule behaves differently.
  printf '%s\nafter\n' "$src" > "$work/case.crv"
  "$vim_bin" -u NONE -N -es \
    -c 'syntax on' \
    -c "set runtimepath^=$root" \
    -c "edit $work/case.crv" \
    -c 'set filetype=carve' \
    -c "redir! > $work/out" \
    -c 'echo synIDattr(synID(1, 1, 1), "name")' \
    -c 'redir END' \
    -c 'qa!' </dev/null >/dev/null 2>&1
  group="$(tr -d '\r\n' < "$work/out")"
  got="$(classify "$group")"

  if [[ "$got" == "$want" ]]; then
    pass=$((pass + 1))
  else
    fails+=("$(printf '%q' "$src"): want=${want} got=${got} (group=${group:-none})${why:+   ($why)}")
  fi
done

if ((${#fails[@]})); then
  printf 'The shared block battery disagrees with this syntax:\n'
  printf '  %s\n' "${fails[@]}"
  printf '\n%d of %d shapes wrong. The battery records what carve-rs renders;\n' \
    "${#fails[@]}" "$((pass + ${#fails[@]}))"
  printf 'change the syntax, not the battery.\n'
  exit 1
fi
printf 'block battery: %d shapes agree.\n' "$pass"
