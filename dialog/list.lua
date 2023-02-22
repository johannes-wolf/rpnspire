local ui = require 'ui'

local t = {}

-- Display dialog sync
function t.display_sync(options)
   local co = coroutine.running()
   local dlg = t.display(options)

   local res
   function dlg.on_cancel()
      res = nil
      coroutine.resume(co)
   end
   function dlg.on_done(row)
      res = row.result
      coroutine.resume(co)
   end

   assert(co)
   coroutine.yield(co)
   return res
end

-- Display dialog
---@param options table<string, any>
---@param oninit? function(label: ui.label, list: ui.list)
---@return list_dlg
function t.display(options, oninit)
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

   local top = 0
   if options.title then
      dlg.label = ui.label(ui.rel{left = 0, right = 0, top = 0, height = 20})
      dlg.label.text = options.title or ''
      dlg.label.background = 0
      dlg.label.foreground = 0xffffff
      dlg.window:add_child(dlg.label)
      top = top + 20
   end

   dlg.list = ui.list(ui.rel{left = 0, right = 0, bottom = 0, top = top})
   dlg.list.items = options.items
   dlg.list.font_size = options.font_size or dlg.list.font_size
   dlg.list.row_size = options.row_size or dlg.list.row_size
   dlg.window:add_child(dlg.list)

   if oninit then oninit(dlg.label, dlg.list) end

   dlg.list:update_rows()
   dlg.list:set_selection(options.selection or 1)

   local session = ui.push_modal(dlg.window)
   function dlg.cancel()
      ui.pop_modal(session)
   end

   function dlg.list:on_enter_key()
      dlg.cancel()
      dlg.on_done(self:get_item())
   end

   function dlg.list:on_escape()
      dlg.cancel()
      dlg.on_cancel()
   end

   ui.set_focus(dlg.list)
   return dlg
end

return t
