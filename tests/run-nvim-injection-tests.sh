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

# A second parser, so an injection has somewhere to land. v0.23.1 is the last
# tree-sitter-javascript release whose committed parser.c is ABI 14, which
# Neovim 0.9 still loads.
js="${JS_TREE_SITTER_DIR:-}"
if [[ -z "$js" ]]; then
  git clone --quiet --depth 1 --branch v0.23.1 \
    https://github.com/tree-sitter/tree-sitter-javascript "$work/js" 2>/dev/null
  js="$work/js"
fi
mkdir -p "$work/rt/queries/javascript"
(cd "$js" && "$cc" -o "$work/rt/parser/javascript.so" -I./src src/parser.c src/scanner.c \
  -Os -std=c11 -shared -fPIC -w)
cp "$js/queries/highlights.scm" "$work/rt/queries/javascript/highlights.scm"

cat > "$work/init.lua" <<LUA
vim.opt.runtimepath:prepend('$work/rt')
vim.opt.runtimepath:prepend('$root')
vim.cmd('filetype plugin indent on')
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'carve',
  callback = function(args) vim.treesitter.start(args.buf, 'carve') end,
})
LUA

# Writes three lines to $PROBE_OUT: the injected languages, the language every
# code_block injection resolves to (whether or not that parser exists), and
# the captures at row 1, column 0.
cat > "$work/probe.lua" <<'LUA'
local parser = vim.treesitter.get_parser(0)
parser:parse(true)
local langs = {}
for lang in pairs(parser:children()) do
  table.insert(langs, lang)
end
table.sort(langs)
local resolved = {}
local query = vim.treesitter.query.get('carve', 'injections')
for _, _, metadata in query:iter_matches(parser:parse()[1]:root(), 0) do
  if metadata['injection.language'] then
    table.insert(resolved, metadata['injection.language'])
  end
end
local captures = {}
for _, c in ipairs(vim.treesitter.get_captures_at_pos(0, 1, 0)) do
  table.insert(captures, c.lang .. ':' .. c.capture)
end
local f = assert(io.open(vim.env.PROBE_OUT, 'w'))
f:write(table.concat(langs, ' '), '\n', table.concat(resolved, ' '), '\n', table.concat(captures, ' '), '\n')
f:close()
LUA

version="$("$nvim_bin" --version | head -n1)"

pass=0
fails=()

# run_case NAME SOURCE FIELD EXPECTED
#   FIELD 1: injected languages, 2: resolved injection languages,
#   3: captures at row 1 column 0 (EXPECTED must be one of them)
run_case() {
  local name="$1" source="$2" field="$3" want="$4"
  printf '%s' "$source" > "$work/case.crv"
  rm -f "$work/out"
  local status=0
  PROBE_OUT="$work/out" timeout 60 "$nvim_bin" --clean -u "$work/init.lua" --headless \
    "$work/case.crv" -c "luafile $work/probe.lua" -c 'qa!' > "$work/log" 2>&1 || status=$?
  if ((status != 0)) || [[ ! -s "$work/out" ]]; then
    fails+=("$name: nvim exited with $status"$'\n'"$(cat "$work/log")")
    return
  fi
  local got
  got="$(sed -n "${field}p" "$work/out")"
  if [[ "$field" == 3 ]]; then
    if [[ " $got " != *" $want "* ]]; then
      fails+=("$name: captures [$got] lack $want")
      return
    fi
  elif [[ "$got" != "$want" ]]; then
    fails+=("$name: got [$got], expected [$want]")
    return
  fi
  pass=$((pass + 1))
}

# The info string is what people type, not a parser name (vim-carve#52).
run_case 'a js fence injects javascript' \
  $'```js\nconst x = 1;\n```\n' 1 'javascript'
run_case 'a js fence body is highlighted as javascript' \
  $'```js\nconst x = 1;\n```\n' 3 'javascript:keyword'
run_case 'an upper-case JS fence injects javascript' \
  $'```JS\nconst x = 1;\n```\n' 1 'javascript'
run_case 'control: a javascript fence injects javascript' \
  $'```javascript\nconst x = 1;\n```\n' 1 'javascript'
run_case 'short tags resolve to their language' \
  $'```py\nx\n```\n\n```ts\nx\n```\n\n```sh\nx\n```\n\n```yml\nx\n```\n' 2 'python typescript bash yaml'
run_case 'an unknown tag passes through unchanged' \
  $'```nosuchlang\nx\n```\n' 2 'nosuchlang'

# A Carve sample inside Carve crashed Neovim 0.9 (vim-carve#51). 0.10.0 is the
# first release that parses the self-injection, so below it the fence stays
# plain text instead of taking the editor down. `crv` resolves to carve too.
self_safe="$("$nvim_bin" --clean --headless -c 'lua io.stdout:write(vim.fn.has("nvim-0.10"))' -c 'qa!' 2>&1)"
if [[ "$self_safe" == 1 ]]; then
  want_self='carve'
else
  want_self=''
fi
run_case 'a carve fence does not crash, and injects carve where that is safe' \
  $'Hi\n\n```carve\n*bold*\n```\n' 1 "$want_self"
run_case 'a crv fence does not crash, and injects carve where that is safe' \
  $'Hi\n\n```crv\n*bold*\n```\n' 1 "$want_self"
run_case 'a raw carve block does not crash' \
  $'``` =carve\n*bold*\n```\n' 1 "$want_self"

if ((${#fails[@]})); then
  printf 'nvim injection failures (%s):\n' "$version"
  printf '  %s\n' "${fails[@]}"
  exit 1
fi
printf 'nvim injections: %d assertion(s) passed on %s.\n' "$pass" "$version"
