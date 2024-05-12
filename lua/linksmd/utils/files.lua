local plenary_scandir = require('plenary').scandir.scan_dir
local plenary_async = require('plenary.async')

local M = {}

M.get_root_dir = function()
  local mkdnflow_ok, mkdnflow = pcall(require, 'mkdnflow')

  if not mkdnflow_ok then
    vim.notify('[linksmd] You need add mkdnflow as dependency', vim.log.levels.WARN, { render = 'minimal' })

    return nil
  end

  return mkdnflow.root_dir
end

M.get_files = function(root_dir, extensions, dir_resource)
  local files = {
    all = {},
    files = {},
    dirs = {},
  }

  local dir_files = root_dir

  if dir_resource ~= nil then
    dir_files = dir_files .. dir_resource
  end

  local scandir = plenary_scandir(dir_files, { hidden = false })

  for i = #scandir, 1, -1 do
    table.insert(files.all, scandir[i])
  end

  local ext = string.format(',%s,', table.concat(extensions, ','))

  for _, file in ipairs(files.all) do
    local file_ext = file:gsub('.*%.', '')

    if string.find(ext, ',' .. file_ext .. ',') then
      local treat_file = string.gsub(file, '^' .. root_dir .. '/', '')

      table.insert(files.files, treat_file)

      for dir in treat_file:gmatch('(.+)/.+%.' .. file_ext .. '$') do
        if not vim.tbl_contains(files.dirs, dir) then
          table.insert(files.dirs, dir)
        end
      end
    end
  end

  return files
end

M.read_file = function(path)
  local err_open, fd = plenary_async.uv.fs_open(path, 'r', 438)
  if err_open then
    vim.notify('[linksmd] ' .. err_open, vim.log.levels.ERROR, { render = 'minimal' })
    return
  end

  local err_fstat, stat = plenary_async.uv.fs_fstat(fd)
  if err_fstat then
    vim.notify('[linksmd] ' .. err_fstat, vim.log.levels.ERROR, { render = 'minimal' })
    return
  end

  local err_read, data = plenary_async.uv.fs_read(fd, stat.size, 0)
  if err_read then
    vim.notify('[linksmd] ' .. err_read, vim.log.levels.ERROR, { render = 'minimal' })
    return
  end

  local err_close = plenary_async.uv.fs_close(fd)
  if err_close then
    vim.notify('[linksmd] ' .. err_close, vim.log.levels.ERROR, { render = 'minimal' })
    return
  end

  return data
end

M.apply_file = function(opts, file, buffer)
  local col_remove = 0

  if opts.buffer.flag then
    col_remove = #opts.buffer.flag + 1
  end

  vim.api.nvim_buf_set_text(
    buffer.id,
    buffer.cursor[1] - 1,
    buffer.cursor[2] - col_remove,
    buffer.cursor[1] - 1,
    buffer.cursor[2],
    { file }
  )
end

return M
