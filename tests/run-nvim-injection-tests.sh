#!/usr/bin/env bash
# What the bundled injections.scm does inside a real Neovim, against the pinned
# grammar. run-treesitter-captures.sh reads highlights.scm through the
# tree-sitter CLI, which never evaluates an injection.
#
# Requires Neovim and a C compiler. Skips (exit 0) without Neovim. NVIM_BIN
# picks another binary, so the same assertions run on several releases.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
nvim_bin="${NVIM_BIN:-nvim}"
cc="${CC:-cc}"
upstream="${CARVE_TREE_SITTER_DIR:-}"

if ! command -v "$nvim_bin" > /dev/null 2>&1; then
  echo "SKIP: nvim not installed"
  exit 0
fi

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

mkdir -p "$work/rt/parser"
(cd "$upstream" && "$cc" -o "$work/rt/parser/carve.so" -I./src src/parser.c src/scanner.c \
  -Os -std=c11 -shared -fPIC -w)

cat > "$work/init.lua" <<LUA
vim.opt.runtimepath:prepend('$work/rt')
vim.opt.runtimepath:prepend('$root')
vim.cmd('filetype plugin indent on')
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'carve',
  callback = function(args) vim.treesitter.start(args.buf, 'carve') end,
})
LUA

# Prints the languages injected into the buffer, one per line, into $work/out.
cat > "$work/probe.lua" <<'LUA'
local parser = vim.treesitter.get_parser(0)
parser:parse(true)
local langs = {}
for lang in pairs(parser:children()) do
  table.insert(langs, lang)
end
table.sort(langs)
local f = assert(io.open(vim.env.PROBE_OUT, 'w'))
f:write(table.concat(langs, '\n'), '\n')
f:close()
LUA

version="$("$nvim_bin" --version | head -n1)"
self_safe="$("$nvim_bin" --clean --headless -c 'lua io.stdout:write(vim.fn.has("nvim-0.10"))' -c 'qa!' 2>&1)"

pass=0
fails=()

# run_case NAME SOURCE EXPECTED_LANGS (space separated, sorted, '' for none)
run_case() {
  local name="$1" source="$2" want="$3"
  printf '%s' "$source" > "$work/case.crv"
  rm -f "$work/out"
  local status=0
  PROBE_OUT="$work/out" timeout 60 "$nvim_bin" --clean -u "$work/init.lua" --headless \
    "$work/case.crv" -c "luafile $work/probe.lua" -c 'qa!' > "$work/log" 2>&1 || status=$?
  if ((status != 0)); then
    fails+=("$name: nvim exited with $status"$'\n'"$(cat "$work/log")")
    return
  fi
  local got
  got="$(tr '\n' ' ' < "$work/out" | sed 's/ *$//')"
  if [[ "$got" != "$want" ]]; then
    fails+=("$name: injected [$got], expected [$want]")
    return
  fi
  pass=$((pass + 1))
}

# A Carve sample inside Carve crashed Neovim 0.9 (vim-carve#51). 0.10.0 is the
# first release that parses the self-injection, so below it the fence stays
# plain text instead of taking the editor down.
if [[ "$self_safe" == 1 ]]; then
  want_self='carve'
else
  want_self=''
fi
run_case 'a carve fence does not crash, and injects carve where that is safe' \
  $'Hi\n\n```carve\n*bold*\n```\n' "$want_self"
run_case 'a raw carve block does not crash' \
  $'``` =carve\n*bold*\n```\n' "$want_self"

if ((${#fails[@]})); then
  printf 'nvim injection failures (%s):\n' "$version"
  printf '  %s\n' "${fails[@]}"
  exit 1
fi
printf 'nvim injections: %d assertion(s) passed on %s.\n' "$pass" "$version"
