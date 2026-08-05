#!/usr/bin/env bash
# The bundled queries are copies. Prove they still are.
#
# README calls queries/carve/*.scm "copied verbatim from tree-sitter-carve" and
# "the source of truth". Nothing enforced that, and they drifted: the heading
# level predicates were off by one, so `#### Title` got no level capture at all
# and `###### Title` was captured as level 5. Two whole rule groups were missing
# as well.
#
# A copy that nothing compares is a copy only until someone edits one side.
#
# Comparing against tree-sitter-carve's `main` meant comparing against a
# moving target: the queries could pass today and drift tomorrow with
# nothing here changing. Compare against the same commit lua/carve/init.lua's
# install_revision pins instead - the two are bumped together, so a green
# result here means the queries actually match the grammar users install.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
upstream="${CARVE_TREE_SITTER_DIR:-}"

if [[ -z "$upstream" ]]; then
  rev="$(sed -n "s/.*install_revision = '\([0-9a-f]\{40\}\)'.*/\1/p" "$root/lua/carve/init.lua" | head -n1)"
  if [[ -z "$rev" ]]; then
    echo "Could not extract a pinned rev from lua/carve/init.lua's install_revision" >&2
    exit 1
  fi
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  git clone --quiet https://github.com/markup-carve/tree-sitter-carve "$work/ts"
  git -C "$work/ts" checkout --quiet "$rev"
  upstream="$work/ts"
fi

if [[ ! -d "$upstream/queries" ]]; then
  echo "No queries/ directory in $upstream" >&2
  exit 1
fi

drifted=()
for local_file in "$root"/queries/carve/*.scm; do
  name="$(basename "$local_file")"
  remote_file="$upstream/queries/$name"
  if [[ ! -f "$remote_file" ]]; then
    drifted+=("$name: no longer exists upstream")
    continue
  fi
  if ! diff -q "$local_file" "$remote_file" >/dev/null; then
    changed="$(diff "$local_file" "$remote_file" | grep -c '^[<>]' || true)"
    drifted+=("$name: differs from upstream ($changed changed lines)")
  fi
done

if ((${#drifted[@]})); then
  printf 'Bundled queries have drifted from tree-sitter-carve:\n'
  printf '  %s\n' "${drifted[@]}"
  printf '\nThey are copies (see README). Re-copy them, or change the README.\n'
  exit 1
fi
printf 'check-query-drift: %d query file(s) match tree-sitter-carve.\n' \
  "$(ls -1 "$root"/queries/carve/*.scm | wc -l)"
