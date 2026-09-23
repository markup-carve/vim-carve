-- :CarveImport - convert Markdown, HTML, Djot or BBCode to a sibling .crv
-- file with `carve migrate`, then open it.

local M = {}

M.formats = {
  md = 'markdown',
  markdown = 'markdown',
  mdown = 'markdown',
  html = 'html',
  htm = 'html',
  djot = 'djot',
  dj = 'djot',
  bbcode = 'bbcode',
  bb = 'bbcode',
}

function M.format_for(path)
  local ext = path:match('%.([^./\\]+)$')
  return ext and M.formats[ext:lower()] or nil
end

function M.target_for(path)
  local stem = path:match('^(.*)%.[^./\\]+$') or path
  return stem .. '.crv'
end

-- vim.g.carve_command may be a string or a list, e.g. { 'npx', '-y', '@markup-carve/carve' }.
function M.command()
  local cmd = vim.g.carve_command or 'carve'
  if type(cmd) == 'string' then
    return { cmd }
  end
  return vim.deepcopy(cmd)
end

local function run(argv)
  if vim.system then
    local res = vim.system(argv, { text = true }):wait()
    return res.code, res.stdout or '', res.stderr or ''
  end
  local out, err = {}, {}
  local job = vim.fn.jobstart(argv, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data) out = data end,
    on_stderr = function(_, data) err = data end,
  })
  if job <= 0 then
    return -1, '', 'could not start ' .. argv[1]
  end
  local code = vim.fn.jobwait({ job })[1]
  return code, table.concat(out, '\n'), table.concat(err, '\n')
end

local function fail(msg)
  vim.notify('CarveImport: ' .. msg, vim.log.levels.ERROR)
  return nil, msg
end

--- Convert `file` (default: the current buffer's file) and open the result.
--- Returns the target path, or nil and a reason.
---@param file string|nil
---@param opts table|nil { format = string, force = boolean, open = boolean }
function M.import(file, opts)
  opts = opts or {}
  if not file or file == '' then
    file = vim.api.nvim_buf_get_name(0)
  end
  if file == '' then
    return fail('no file given and the buffer has no name')
  end
  file = vim.fn.fnamemodify(file, ':p')
  if vim.fn.filereadable(file) ~= 1 then
    return fail('cannot read ' .. file)
  end
  local format = opts.format or M.format_for(file)
  if not format then
    return fail('unknown source format for ' .. file .. ' (known: md, html, djot, bbcode)')
  end
  local target = M.target_for(file)
  if target == file then
    return fail(file .. ' is already a Carve file')
  end
  for _, path in ipairs({ file, target }) do
    local buf = vim.fn.bufnr(path)
    if buf ~= -1 and vim.bo[buf].modified then
      return fail(path .. ' has unsaved changes; write or discard them first')
    end
  end
  local cmd = M.command()
  if vim.fn.executable(cmd[1]) ~= 1 then
    return fail(cmd[1] .. ' not found on PATH; set g:carve_command')
  end
  if not opts.force and vim.fn.filereadable(target) == 1 then
    if vim.fn.confirm(target .. ' exists. Overwrite?', '&Yes\n&No', 2) ~= 1 then
      return nil, 'canceled'
    end
  end

  vim.list_extend(cmd, { 'migrate', '--from', format, file })
  local code, stdout, stderr = run(cmd)
  if code ~= 0 then
    local msg = vim.trim(stderr ~= '' and stderr or stdout)
    return fail(string.format('carve migrate failed (exit %d): %s', code, msg))
  end
  -- carve-js 0.1.7 run through a .bin or global symlink exits 0 without output.
  if not stdout:find('%S') and table.concat(vim.fn.readfile(file), '\n'):find('%S') then
    return fail('carve migrate printed no output for ' .. vim.fn.fnamemodify(file, ':t')
      .. ' (carve-js 0.1.7 does that when run through a symlink); set g:carve_command')
  end

  -- Write beside the target and rename, so a failed write keeps the old file.
  local tmp = target .. '.carveimport'
  local fh, err = io.open(tmp, 'wb')
  local ok = fh and fh:write(stdout)
  ok = fh and fh:close() and ok
  -- vim.fn.rename, unlike os.rename, replaces an existing target on Windows.
  if ok and vim.fn.rename(tmp, target) ~= 0 then
    ok, err = false, 'rename failed'
  end
  if not ok then
    os.remove(tmp)
    return fail('cannot write ' .. target .. ': ' .. tostring(err))
  end

  if opts.open ~= false then
    local bufnr = vim.fn.bufnr(target)
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      vim.api.nvim_buf_call(bufnr, function() vim.cmd('silent! edit!') end)
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(target))
  end
  return target
end

return M
