#!/usr/bin/env bash
# What the BUNDLED tree-sitter queries capture, against the PINNED grammar.
#
# Every other check here is satisfied by a pin that is simply wrong: the query
# files are present, they match upstream byte for byte (tools/check-query-drift.sh
# compares against the same pinned commit), and the Vim syntax assertions read
# syntax/carve.vim, which the tree-sitter half never touches. So a stale
# install_revision - the grammar Neovim users actually compile - was the one
# thing nothing could notice.
#
# It went unnoticed once already: `queries/carve/highlights.scm` captures the
# include parts by bare node name, so `@label:"two words"` painted only `"two`
# for as long as the pin predated the grammar fix, with every job green.
#
# An assertion is `row|column|capture|end-column|name`, resolved the way an
# editor resolves overlapping captures: the LAST capture starting at that
# position wins. `-` for the end column skips the span check, and `-` for the
# capture asserts that nothing colors that position.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
ts_cli="${TS_CLI:-npx --yes tree-sitter-cli@0.22.1}"
upstream="${CARVE_TREE_SITTER_DIR:-}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [[ -z "$upstream" ]]; then
  rev="$(sed -n "s/.*install_revision = '\([0-9a-f]\{40\}\)'.*/\1/p" "$root/lua/carve/init.lua" | head -n1)"
  if [[ -z "$rev" ]]; then
    echo "Could not extract a pinned rev from lua/carve/init.lua's install_revision" >&2
    exit 1
  fi
  git clone --quiet https://github.com/markup-carve/tree-sitter-carve "$work/ts"
  git -C "$work/ts" checkout --quiet "$rev"
  upstream="$work/ts"
fi

# The tree-sitter CLI caches the built library by LANGUAGE NAME, keyed on the
# source mtime - two revisions of this grammar answer with whichever built
# first, and a checkout older than the cache is never recompiled. So the parser
# is copied into a scratch directory with fresh mtimes and the cache is a fresh
# XDG_CACHE_HOME per run. `src/parser.c` is committed upstream, so there is
# nothing to generate.
parser="$work/parsers/tree-sitter-carve"
mkdir -p "$parser"
cp -R "$upstream/src" "$parser/src"
for meta in grammar.js package.json tree-sitter.json; do
  [[ -f "$upstream/$meta" ]] && cp "$upstream/$meta" "$parser/$meta"
done
touch "$parser/src/"*.c
export XDG_CACHE_HOME="$work/cache"
mkdir -p "$work/config/tree-sitter"
printf '{"parser-directories": ["%s/parsers"]}\n' "$work" > "$work/config/tree-sitter/config.json"

# Captures that are not a color land on the same nodes the color patterns do.
not_a_color='^(spell|nospell|conceal|none)$'

run_case() {
  local name="$1" source="$2" row="$3" column="$4" want="$5" want_end="$6"
  printf '%s' "$source" > "$work/case.crv"
  local out
  if ! out="$($ts_cli query --config-path "$work/config/tree-sitter/config.json" \
      --scope text.carve --captures "$root/queries/carve/highlights.scm" \
      "$work/case.crv" 2>&1)"; then
    fails+=("$name: the query did not run"$'\n'"$out")
    return
  fi
  local got='-' got_end='-'
  while IFS='|' read -r capture srow scol erow ecol; do
    [[ "$srow" == "$row" && "$scol" == "$column" ]] || continue
    [[ "$erow" == "$row" ]] || continue
    [[ "$capture" =~ $not_a_color ]] && continue
    got="$capture"
    got_end="$ecol"
  done < <(printf '%s\n' "$out" | sed -n \
    's/.*capture: [0-9]* - \([A-Za-z0-9_.]*\), start: (\([0-9]*\), \([0-9]*\)), end: (\([0-9]*\), \([0-9]*\)).*/\1|\2|\3|\4|\5/p')
  if [[ "$got" != "$want" ]]; then
    fails+=("$name: at $row:$column the winning capture is $got, expected $want")
    return
  fi
  if [[ "$want_end" != '-' && "$got_end" != "$want_end" ]]; then
    fails+=("$name: at $row:$column the $got capture ends at column $got_end, expected $want_end")
  fi
}

fails=()
checks=0

# A quoted option value is an `attribute_value` and holds spaces. The span is
# the whole point of these two: the short reading kept the `constant` name.
#
#   {{ part.crv @label:"two words" }}
#   0  3        12    18 19        30
run_case 'a double-quoted option value holding a space is one value' \
  '{{ part.crv @label:"two words" }}'$'\n' 0 19 constant 30
run_case 'a single-quoted option value holding a space is one value' \
  "{{ part.crv @label:'two words' }}"$'\n' 0 19 constant 30

# With a `#` inside the quotes the short reading did not paint a short value:
# `#tag"` is no `include_extra` either, so no directive parsed at all and both
# halves fell back to inline rules - a selector painted as a hashtag inside a
# construct the core leaves literal.
#
#   {{ part.crv @label:"a #tag" }}
#   0  3        12    18 19 22
run_case 'the option name of a directive with a quoted # is an option name' \
  '{{ part.crv @label:"a #tag" }}'$'\n' 0 12 variable.parameter -
run_case 'a # inside a quoted option value is not a tag' \
  '{{ part.crv @label:"a #tag" }}'$'\n' 0 22 - -

# The controls. The first is the bound on the widening - a quoted alternative
# requires its closer, so an unterminated quote falls back to the unquoted run
# and still stops at the space. The second proves the tag rule still reaches a
# real tag: dropping it would pass the row above on its own.
run_case 'control: an unterminated quote still stops at the space' \
  '{{ part.crv @label:"two words }}'$'\n' 0 19 constant 23
run_case 'control: a tag outside a directive is still a tag' \
  'see #intro here'$'\n' 0 4 tag -
checks=6

if ((${#fails[@]})); then
  printf 'tree-sitter capture failures:\n'
  printf '  %s\n' "${fails[@]}"
  printf '\n%d of %d assertions failed.\n' "${#fails[@]}" "$checks"
  exit 1
fi
printf 'tree-sitter captures: %d assertion(s) passed against the pinned grammar.\n' "$checks"
