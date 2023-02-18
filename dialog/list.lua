local ui = require 'ui'

local t = {}

-- Display dialog
---@param title?    string
---@param items     table<any>
---@param data      'string'|'simple'|'key-value'|'custom'
---@param oninit?   function(label: ui.label, list: ui.list)
---@return list_dlg
function t.display(title, items, data, oninit)
   ---@class list_dlg
   ---@field window    ui.container
   ---@field label     ui.label
   ---@field list      ui.list
   ---@field cancel    function()
   ---@field on_done   function(data)
   ---@field on_cancel function()
   local dlg = {
      on_done = function() end,
      on_cancel = function() end,
   }

   local function construct_simple(_, row)
      local l = ui.label(ui.rel{})
      l.text = row.title
      return l
   end

   local function match_simple(_, row, str)
      return row.title:find(str)
   end

   local function construct_keyvalue(_, row)
      local wnd = ui.container(ui.rel{})
      wnd.background = nil
      local key_l = ui.label(ui.rel{left = ui.style.padding, right = '50%', top = 0, bottom = 0})
      key_l.text = row.key
      key_l.align = -1
      wnd:add_child(key_l)
      local value_l = ui.label(ui.rel{left = '50%', right = ui.style.padding, top = 0, bottom = 0})
      value_l.text = row.value
      value_l.align = -1
      wnd:add_child(value_l)
      return wnd
   end

   local function match_key(_, row, str)
      return row.key:find(str)
   end

   dlg.window = ui.container(ui.rel{left = 10, right = 10, top = 10, bottom = 10})
   dlg.window.style = '2D'

   dlg.label = ui.label(ui.rel{left = 0, right = 0, top = 0, height = 20})
   dlg.label.text = title or ''
   dlg.label.background = 0
   dlg.label.foreground = 0xffffff
   dlg.window:add_child(dlg.label)

   dlg.list = ui.list(ui.rel{left = 0, right = 0, bottom = 0, top = 20})
   dlg.list.items = items
   if data == 'simple' then
      dlg.list.row_constructor = construct_simple
      dlg.list.row_match = match_simple
      dlg.list:update_rows()
   elseif data == 'key-value' then
      dlg.list.row_constructor = construct_keyvalue
      dlg.list.row_match = match_key
      dlg.list:update_rows()
   elseif data == 'string' then
      dlg.list:update_rows()
   else
      -- Do not update rows yet
   end
   dlg.window:add_child(dlg.list)

   if oninit then oninit(dlg.label, dlg.list) end

   local session = ui.push_modal(dlg.window)
   dlg.cancel = function()
      ui.pop_modal(session)
   end

   dlg.list.on_enter_key = function(this)
      dlg.cancel()
      dlg.on_done(this:get_item())
   end

   dlg.list.on_escape = function(_)
      dlg.cancel()
      dlg.on_cancel()
   end

   ui.set_focus(dlg.list)
   return dlg
end

return t
