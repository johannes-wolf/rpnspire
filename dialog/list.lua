local ui = require 'ui'

local t = {}

-- Display dialog
---@param title?    string
---@param items     table<any>
---@param oninit?   function(label: ui.label, list: ui.list)
---@return list_dlg
function t.display(title, items, oninit)
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

   dlg.window = ui.container(ui.rel{left = 10, right = 10, top = 10, bottom = 10})
   dlg.window.style = '2D'

   dlg.label = ui.label(ui.rel{left = 0, right = 0, top = 0, height = 20})
   dlg.label.text = title or ''
   dlg.label.background = 0
   dlg.label.foreground = 0xffffff
   dlg.window:add_child(dlg.label)

   dlg.list = ui.list(ui.rel{left = 0, right = 0, bottom = 0, top = 20})
   dlg.list.items = items
   dlg.window:add_child(dlg.list)

   if oninit then oninit(dlg.label, dlg.list) end
   dlg.list:update_rows()

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
