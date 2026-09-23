#!/usr/bin/env bash
# lua/carve/import.lua against a stub `carve` CLI. Skips when nvim is absent.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v nvim > /dev/null 2>&1; then
  echo "SKIP: nvim not installed"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat > "${WORK}/ok" <<'STUB'
#!/bin/sh
echo "$1 $2 $3"
echo '*bold*'
STUB
cat > "${WORK}/bad" <<'STUB'
#!/bin/sh
echo 'carve migrate: cannot read' >&2
exit 2
STUB
# carve-js 0.1.7 run through a .bin symlink exits 0 and prints nothing.
cat > "${WORK}/empty" <<'STUB'
#!/bin/sh
exit 0
STUB
cat > "${WORK}/argv" <<'STUB'
#!/bin/sh
echo "$# [$4]"
STUB
chmod +x "${WORK}/ok" "${WORK}/bad" "${WORK}/empty" "${WORK}/argv"
printf '# notes\n' > "${WORK}/my notes.md"
printf '[b]x[/b]\n' > "${WORK}/post.bbcode"
printf '**bold**\n' > "${WORK}/doc.md"
printf '<p>x</p>\n' > "${WORK}/page.html"
printf 'old\n' > "${WORK}/page.crv"

PROBE="${WORK}/probe.lua"
cat > "${PROBE}" <<LUA
local import = require('carve.import')
local function read(p) local f = assert(io.open(p)); local s = f:read('a'); f:close(); return s end
local notes = {}
vim.notify = function(msg) table.insert(notes, msg) end

assert(import.target_for('/a/b/readme.md') == '/a/b/readme.crv')
assert(import.target_for('/a/page.v2.html') == '/a/page.v2.crv')
assert(import.format_for('x.MD') == 'markdown')
assert(import.format_for('x.htm') == 'html')
assert(import.format_for('x.djot') == 'djot')
assert(import.format_for('x.bbcode') == 'bbcode')
assert(import.format_for('x.txt') == nil)
assert(import.format_for('Makefile') == nil)

vim.g.carve_command = '${WORK}/ok'
local target = import.import('${WORK}/doc.md')
assert(target == '${WORK}/doc.crv', 'target: ' .. tostring(target))
assert(read(target) == 'migrate --from markdown\n*bold*\n', 'content: ' .. read(target))
assert(vim.api.nvim_buf_get_name(0) == target, 'the result was not opened')

vim.fn.confirm = function() return 2 end
local declined = import.import('${WORK}/page.html')
assert(declined == nil and read('${WORK}/page.crv') == 'old\n', 'declined overwrite still wrote')

vim.fn.confirm = function() return 1 end
assert(import.import('${WORK}/page.html') == '${WORK}/page.crv')
assert(read('${WORK}/page.crv') == 'migrate --from html\n*bold*\n')

vim.g.carve_command = { '${WORK}/bad' }
local failed, reason = import.import('${WORK}/doc.md', { force = true, open = false })
assert(failed == nil and reason:match('exit 2') and reason:match('cannot read'), tostring(reason))
assert(#notes > 0, 'the CLI error was not reported')
assert(read('${WORK}/doc.crv') == 'migrate --from markdown\n*bold*\n', 'a failed run clobbered the target')

vim.g.carve_command = '${WORK}/argv'
assert(import.import('${WORK}/my notes.md', { open = false }) == '${WORK}/my notes.crv')
assert(read('${WORK}/my notes.crv') == '4 [${WORK}/my notes.md]\n', read('${WORK}/my notes.crv'))

vim.g.carve_command = '${WORK}/empty'
failed, reason = import.import('${WORK}/post.bbcode', { open = false })
assert(failed == nil and reason:match('no output'), tostring(reason))
assert(vim.fn.filereadable('${WORK}/post.crv') == 0, 'an empty conversion was written')

vim.g.carve_command = '${WORK}/ok'
vim.cmd('edit ${WORK}/post.bbcode')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { '[i]unsaved[/i]' })
failed, reason = import.import(nil, { open = false })
assert(failed == nil and reason:match('unsaved'), tostring(reason))
assert(vim.fn.filereadable('${WORK}/post.crv') == 0, 'converted the file on disk, not the edited buffer')
vim.cmd('bwipeout!')

vim.g.carve_command = '${WORK}/no-such-carve'
failed, reason = import.import('${WORK}/post.bbcode', { open = false })
assert(failed == nil and reason:match('not found'), tostring(reason))
assert(vim.fn.filereadable('${WORK}/post.crv') == 0, 'a missing CLI still wrote a file')

assert(vim.fn.exists(':CarveImport') == 2, ':CarveImport is not defined')
print('import tests ok')
LUA

cd "${HERE}"
nvim --headless --clean --cmd "set runtimepath^=${HERE}" --cmd 'runtime plugin/carve.lua' \
  -c "luafile ${PROBE}" -c 'qa!' 2>&1 | tee "${WORK}/out"
grep -q 'import tests ok' "${WORK}/out"
