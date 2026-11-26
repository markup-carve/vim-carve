#!/usr/bin/env bash
# :CarveImport against a real Carve 0.2 `carve` CLI. Skips when none is on PATH,
# unless CARVE_REQUIRE_CLI is set: CI builds carve-js `main` at a pinned commit
# and sets it, so a missing CLI there fails instead of passing silently.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

version="$(carve --version 2>/dev/null || true)"
if [[ "$version" != 0.2* ]]; then
  if [[ -n "${CARVE_REQUIRE_CLI:-}" ]]; then
    echo "CARVE_REQUIRE_CLI is set but 'carve --version' gave '${version}'" >&2
    exit 1
  fi
  echo "SKIP: no Carve 0.2 CLI on PATH"
  exit 0
fi
if ! command -v nvim > /dev/null 2>&1; then
  echo "SKIP: nvim not installed"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
printf '# Hello *world*\n' > "${WORK}/doc.md"

cat > "${WORK}/test.lua" <<LUA
local import = require('carve.import')
local target = import.import('${WORK}/doc.md', { open = false })
assert(target == '${WORK}/doc.crv', tostring(target))
local f = assert(io.open(target))
local got = f:read('*a')
f:close()
assert(got == '= Hello /world/\n', got)
print('cli import ok')
LUA

nvim --headless --clean --cmd "set runtimepath^=${HERE}" -c "luafile ${WORK}/test.lua" -c 'qa!' 2>&1 | tee "${WORK}/out"
grep -q 'cli import ok' "${WORK}/out"
echo
echo "cli tests ok (${version})"
