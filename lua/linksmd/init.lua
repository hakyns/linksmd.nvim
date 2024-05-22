local default_opts = require('linksmd.utils.opts')
local ufiles = require('linksmd.utils.files')
local plenary_path = require('plenary.path')

local M = {}

local function clear_globals()
  _G.linksmd = {
    flags = {
      pos = nil,
    },
    nui = {
      tree = {
        level = 0,
        parent_files = {},
        breadcrumb = {},
      },
    },
  }
end

M.setup = function(opts)
  local main_opts = default_opts

  if opts then
    main_opts = vim.tbl_deep_extend('force', main_opts, opts)
  end

  M.opts = main_opts

  clear_globals()
end

M.display = function(resource, display_init, follow_dir)
  vim.cmd('messages clear')

  clear_globals()

  if display_init ~= nil and display_init ~= '' and (display_init == 'telescope' or display_init == 'nui') then
    M.opts.display_init = display_init
  end

  local root_dir = nil
  follow_dir = follow_dir or nil

  if M.opts.notebook_main ~= nil then
    if not plenary_path:new(M.opts.notebook_main):exists() then
      vim.notify(
        '[linksmd] You need to pass a correct notebook_main or nil',
        vim.log.levels.WARN,
        { render = 'minimal' }
      )
      return
    end

    root_dir = M.opts.notebook_main
  else
    root_dir = ufiles.get_root_dir()
  end

  if root_dir == nil then
    vim.notify('[linksmd] You need to go to any notebook', vim.log.levels.WARN, { render = 'minimal' })
    return
  end

  if follow_dir ~= nil then
    if not plenary_path:new(follow_dir):exists() then
      vim.notify(
        '[linksmd] You need to pass a correct directory for this notebook or nil',
        vim.log.levels.WARN,
        { render = 'minimal' }
      )

      return
    end
  end

  M.opts.buffer = {
    id = vim.api.nvim_get_current_buf(),
    cursor = vim.api.nvim_win_get_cursor(0),
    line = vim.api.nvim_get_current_line(),
  }

  _G.linksmd.flags.level = nil

  local flag = nil
  local level_flag = 1
  local load_flag = false
  local file_note = nil

  for data_filter in M.opts.buffer.line:gmatch('%b()') do
    if data_filter:find('#') then
      flag = data_filter:sub(2, -2)

      if flag:find('^#') then
        if flag:find('^#$') then
          load_flag = true
          M.opts.resource = 'headers'
        else
          for kflag, vflag in pairs(M.opts.flags) do
            if '#' .. vflag == flag then
              load_flag = true
              M.opts.resource = kflag
              break
            end
          end
        end
      else
        local pos_a, pos_b = flag:find('^.*#$')

        if pos_a and pos_b then
          file_note = flag:sub(pos_a, pos_b - 1)

          if not plenary_path:new(string.format('%s/%s', root_dir, file_note)):exists() then
            vim.notify('[linksd] No found the flag note', vim.log.levels.WARN, { render = 'minimal' })
            return
          end

          load_flag = true
          M.opts.resource = 'headers'
        end
      end

      if load_flag then
        _G.linksmd.flags.level = level_flag
        break
      end
    end

    level_flag = level_flag + 1
  end

  if not load_flag then
    if M.opts.resources[resource] then
      M.opts.resource = resource
    else
      M.opts.resource = 'notes'
    end

    _G.linksmd.flags.level = nil
  end

  if M.opts.resource == 'headers' then
    if file_note == nil then
      local full_filename = vim.api.nvim_buf_get_name(0)

      file_note = string.gsub(full_filename, '^' .. root_dir .. '/', '')
    end

    require('linksmd.headers'):init(M.opts, root_dir, file_note):launch()
    return
  end

  if M.opts.display_init == 'nui' then
    require('linksmd.manager'):init(M.opts, root_dir, follow_dir, {}):launch()
  elseif M.opts.display_init == 'telescope' then
    require('linksmd.finder'):init(M.opts, root_dir, {}, false):launch()
  else
    vim.notify('[linksmd] You need to configure the display_init', vim.log.levels.WARN, { render = 'minimal' })
  end
end
-- vim.cmd('message clear')
-- M.setup()
-- M.display(nil, 'nui')

return M
