local Layout = require('nui.layout')
local plenary_async = require('plenary.async')
local utils = require('linksmd.utils')
local DisplayTelescope = require('linksmd.display.telescope')

local M = {}

local function preview_data(bufnr_preview, root_dir, item)
  if item == nil then
    return
  end

  local path = string.format('%s/%s', root_dir, item)

  plenary_async.run(function()
    local data = utils.read_file(path)
    local text = vim.split(data and data or '', '\n')

    vim.schedule(function()
      vim.api.nvim_buf_set_lines(bufnr_preview, 0, -1, false, text)

      vim.api.nvim_buf_call(bufnr_preview, function()
        if vim.api.nvim_buf_line_count(bufnr_preview) > 5 then
          vim.api.nvim_win_set_cursor(0, { 5, 0 })
        end
      end)
    end)
  end)
end

M.enter = function(display, tree, popup_tree)
  popup_tree:map('n', display.opts.keymaps.menu_enter, function()
    ---@diagnostic disable-next-line: redefined-local
    local node = tree:get_node()

    if node.children then
      table.insert(_G.linksmd.nui.tree.parent_files, tree:get_nodes())
      _G.linksmd.nui.tree.level = _G.linksmd.nui.tree.level + 1
      table.insert(_G.linksmd.nui.tree.breadcrumb, node.text)

      tree:set_nodes(node.children)
      tree:render()

      popup_tree.border:set_text(
        'top',
        string.format(' %s -> %s ', display.opts.text.menu, table.concat(_G.linksmd.nui.tree.breadcrumb, '/')),
        'left'
      )

      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('gg', true, false, true), 'n', true)
    else
      local file = node.file
      print(file)
    end
  end)
end

M.back = function(display, tree, popup_tree, popup_preview)
  popup_tree:map('n', display.opts.keymaps.menu_back, function()
    if _G.linksmd.nui.tree.level > 0 then
      tree:set_nodes(_G.linksmd.nui.tree.parent_files[_G.linksmd.nui.tree.level])
      table.remove(_G.linksmd.nui.tree.parent_files, _G.linksmd.nui.tree.level)
      table.remove(_G.linksmd.nui.tree.breadcrumb, _G.linksmd.nui.tree.level)

      if #_G.linksmd.nui.tree.breadcrumb > 0 then
        popup_tree.border:set_text(
          'top',
          string.format(' %s -> %s ', display.opts.text.menu, table.concat(_G.linksmd.nui.tree.breadcrumb, '/')),
          'left'
        )
      else
        popup_tree.border:set_text('top', string.format(' %s ', display.opts.text.menu), 'left')
      end

      tree:render()

      vim.api.nvim_buf_set_lines(popup_preview.bufnr, 0, -1, false, {})

      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('gg', true, false, true), 'n', true)

      _G.linksmd.nui.tree.level = _G.linksmd.nui.tree.level - 1
    end
  end)
end

M.scroll_down = function(display, popup_tree, popup_preview)
  popup_tree:map('n', display.opts.keymaps.scroll_preview_down, function()
    if not display.preview.state then
      return
    end

    vim.api.nvim_buf_call(popup_preview.bufnr, function()
      local pos_line = vim.api.nvim_win_get_cursor(0)[1]

      if pos_line < vim.api.nvim_buf_line_count(popup_preview.bufnr) - 10 then
        vim.api.nvim_win_set_cursor(0, { pos_line + 12, 0 })
      end
    end)
  end)
end

M.scroll_up = function(display, popup_tree, popup_preview)
  popup_tree:map('n', display.opts.keymaps.scroll_preview_up, function()
    if not display.preview.state then
      return
    end

    vim.api.nvim_buf_call(popup_preview.bufnr, function()
      local pos_line = vim.api.nvim_win_get_cursor(0)[1]

      if pos_line > 5 then
        if pos_line - 12 < 5 then
          vim.api.nvim_win_set_cursor(0, { 5, 0 })
        else
          vim.api.nvim_win_set_cursor(0, { pos_line - 12, 0 })
        end
      end
    end)
  end)
end

M.sroll_preview = function(display, layout, tree, popup_tree, popup_preview)
  popup_tree:map('n', display.opts.keymaps.scroll_preview, function()
    if display.preview.state then
      layout:update(Layout.Box({
        Layout.Box(popup_tree, { size = '100%' }),
      }, { dir = 'col' }))
    else
      layout:update(Layout.Box({
        Layout.Box(popup_preview, { size = '60%' }),
        Layout.Box(popup_tree, { size = '40%' }),
      }, { dir = 'col' }))

      preview_data(popup_preview.bufnr, display.root_dir, tree:get_node().file)
    end

    display.preview.state = not display.preview.state
  end)
end

M.menu_down = function(display, tree, popup_tree, popup_preview)
  popup_tree:map('n', display.opts.keymaps.menu_down, function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('j', true, false, true), 'n', true)

    if not display.preview.state then
      return
    end

    local item_pos = tree:get_node().item_pos + 1
    local file = nil

    if item_pos > 0 and item_pos <= #tree:get_nodes() then
      file = tree:get_nodes()[item_pos].file

      if file ~= nil then
        preview_data(popup_preview.bufnr, display.root_dir, file)
      else
        vim.api.nvim_buf_set_lines(popup_preview.bufnr, 0, -1, false, {})
      end
    end
  end)
end

M.menu_up = function(display, tree, popup_tree, popup_preview)
  popup_tree:map('n', display.opts.keymaps.menu_up, function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('k', true, false, true), 'n', true)

    if not display.preview.state then
      return
    end

    local item_pos = tree:get_node().item_pos - 1
    local file = nil

    if item_pos > 0 and item_pos <= #tree:get_nodes() then
      file = tree:get_nodes()[item_pos].file

      if file ~= nil then
        preview_data(popup_preview.bufnr, display.root_dir, file)
      else
        vim.api.nvim_buf_set_lines(popup_preview.bufnr, 0, -1, false, {})
      end
    end
  end)
end

M.search_file = function(display, popup_tree)
  popup_tree:map('n', display.opts.keymaps.search_file, function()
    vim.api.nvim_buf_delete(popup_tree.bufnr, { force = true })

    DisplayTelescope:init(display.opts, display.root_dir, display.files, nil):launch()
  end)
end

M.search_dir = function(display, popup_tree)
  popup_tree:map('n', display.opts.keymaps.search_dir, function()
    vim.api.nvim_buf_delete(popup_tree.bufnr, { force = true })

    DisplayTelescope:init(display.opts, display.root_dir, nil, true):launch()
  end)
end

return M