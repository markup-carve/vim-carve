#!/usr/bin/env bash
# Builds the parser from EXACTLY the files lua/carve/init.lua hands
# nvim-treesitter, at the pinned install_revision, and loads it with every
# symbol resolved. run-treesitter-captures.sh cannot catch a short list: the
# tree-sitter CLI compiles every src/*.c regardless of install_info.
#
# Flags mirror nvim-treesitter's (master) select_compiler_args for cc/gcc/clang,
# plus -w: warnings in the generated parser.c are upstream's, not this check's.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
init="$root/lua/carve/init.lua"
cc="${CC:-cc}"
upstream="${CARVE_TREE_SITTER_DIR:-}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

files="$(python3 - "$init" <<'PY'
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
tables = re.findall(r'\bfiles\s*=\s*\{([^}]*)\}', src)
if len(tables) != 1:
    sys.exit(f'expected one install_info files table in {sys.argv[1]}, found {len(tables)}')
names = re.findall(r"""['"]([^'"]+)['"]""", tables[0])
if not names:
    sys.exit('install_info.files is empty')
print('\n'.join(names))
PY
)"

if [[ -z "$upstream" ]]; then
  rev="$(sed -n "s/.*install_revision = '\([0-9a-f]\{40\}\)'.*/\1/p" "$init" | head -n1)"
  if [[ -z "$rev" ]]; then
    echo "Could not extract a pinned rev from lua/carve/init.lua's install_revision" >&2
    exit 1
  fi
  git clone --quiet https://github.com/markup-carve/tree-sitter-carve "$work/ts"
  git -C "$work/ts" checkout --quiet "$rev"
  upstream="$work/ts"
fi

mapfile -t list <<<"$files"
echo "install_info.files: ${list[*]}"
(cd "$upstream" && "$cc" -o "$work/parser.so" -I./src "${list[@]}" -Os -std=c11 -shared -fPIC -w)

python3 - "$work/parser.so" <<'PY'
import ctypes, os, sys
lib = ctypes.CDLL(sys.argv[1], mode=os.RTLD_NOW)
lib.tree_sitter_carve
print('parser built from install_info.files loads with all symbols resolved.')
PY
