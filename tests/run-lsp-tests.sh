#!/usr/bin/env bash
# What lua/carve/lsp.lua does, asserted rather than assumed.
#
# Loading is not behaviour: a module that loads cleanly and attaches to nothing
# would pass a `require` check. So this drives the real attach path with
# vim.lsp.start stubbed out, and asserts on what the module WOULD have spawned.
#
# Requires Neovim. Skips (exit 0) when it is absent, so the classic-Vim half of
# this repository stays testable on a machine without it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v nvim > /dev/null 2>&1; then
  echo "SKIP: nvim not installed"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/proj/docs"
git -C "${WORK}/proj" init -q .
printf '# hi\n' > "${WORK}/proj/docs/a.crv"

PROBE="${WORK}/probe.lua"
cat > "${PROBE}" <<LUA
local calls = {}
vim.lsp.start = function(cfg) table.insert(calls, cfg) return 1 end

-- 1. A server that is not installed must be a no-op with a reason, not an
--    error and not an attach. Anything else means every .crv file a reader
--    opens without the server produces noise.
local path, reason = require('carve.lsp').setup({ cmd = { 'carve-lsp-definitely-not-installed' } })
assert(path == nil, 'expected no attach path for a missing server, got ' .. tostring(path))
assert(reason and reason:match('not found'), 'expected a "not found" reason, got ' .. tostring(reason))
assert(#calls == 0, 'a missing server still tried to start')

-- 2. With an executable present, one of the three paths must be chosen.
path = require('carve.lsp').setup({ cmd = { 'sh', '-c', 'true' } })
assert(path == 'builtin' or path == 'lspconfig' or path == 'autocmd',
  'no attach path chosen: ' .. tostring(path))

-- 3. The workspace root must be the project, not the file's own directory.
--    Rename and find-references are workspace-wide, so a root of docs/ would
--    silently narrow them to one folder.
if path == 'autocmd' then
  vim.cmd('edit ${WORK}/proj/docs/a.crv')
  vim.cmd('set filetype=carve')
  assert(#calls > 0, 'the FileType autocmd did not fire for a .crv buffer')
  local cfg = calls[#calls]
  assert(cfg.root_dir == '${WORK}/proj',
    'expected the git root as root_dir, got ' .. tostring(cfg.root_dir))
  assert(cfg.settings and cfg.settings.carve ~= nil,
    'settings were not nested under the carve section')
end

print('lsp tests ok (' .. path .. ')')
LUA

cd "${HERE}"
out="$(nvim --headless --clean --cmd "set runtimepath^=${HERE}" -c "luafile ${PROBE}" -c 'q' 2>&1)"
echo "${out}"
case "${out}" in
  *"lsp tests ok"*) ;;
  *) echo "FAIL: assertions did not complete"; exit 1 ;;
esac
