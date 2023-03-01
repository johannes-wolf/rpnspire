local ui = require 'ui'

local t = {}

-- Display dialog
---@param options   table<string, any>
---@param filter_fn function(text): list<any> # Filter function. Must return all items when called with nil or ''.
---@param on_init?  function(label: ui.label, edit: ui.edit, list: ui.list)
---@return list_dlg
function t.display(options, filter_fn, on_init)
   ---@class list_dlg
   ---@field window    ui.container
   ---@field label     ui.label
   ---@field edit      ui.edit
   ---@field list      ui.list
   ---@field cancel    function()
   ---@field on_done   function(data)
   ---@field on_cancel function()
   local dlg = {
      on_done = function() end,
      on_cancel = function() end,
   }

   dlg.window = ui.container(ui.rel { left = 10, right = 10, top = 10, bottom = 10 })
   dlg.window.style = '2D'

   dlg.label = ui.label(ui.rel { left = 0, right = 0, top = 0, height = 20 })
   dlg.label.text = options.title or ''
   dlg.label.background = 0
   dlg.label.foreground = 0xffffff
   dlg.window:add_child(dlg.label)

   dlg.edit = ui.edit(ui.rel { left = 0, right = 0, top = 20, height = 20 })
   dlg.window:add_child(dlg.edit)

   dlg.list = ui.list(ui.rel { left = 0, right = 0, bottom = 0, top = 40 })
   dlg.list.items = filter_fn(nil)
   dlg.list.columns = options.columns or dlg.list.columns
   dlg.list.font_size = options.font_size or dlg.list.font_size
   dlg.list.row_size = options.row_size or dlg.list.row_size
   dlg.window:add_child(dlg.list)

   if on_init then on_init(dlg.label, dlg.edit, dlg.list) end
   dlg.list:update_rows()

   local session = ui.push_modal(dlg.window)
   function dlg.cancel()
      ui.pop_modal(session)
   end

   function dlg.edit:on_enter_key()
      dlg.cancel()
      dlg.on_done(dlg.list:get_item())
   end

   function dlg.edit:on_escape()
      if self.text:len() > 0 then
         self:set_text('')
      else
         dlg.cancel()
         dlg.on_cancel()
      end
   end

   function dlg.edit:on_up()
      dlg.list:on_up()
   end

   function dlg.edit:on_down()
      dlg.list:on_down()
   end

   function dlg.list:has_focus()
      return dlg.edit:has_focus()
   end

   function dlg.edit:on_text_changed(text)
      dlg.list.items = filter_fn(text)
      dlg.list:update_rows()
      dlg.list:set_selection(1)
   end

   ui.set_focus(dlg.edit)
   return dlg
end

return t
