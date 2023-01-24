local ui = require 'ui'

local t = {}

t.yesno = {
  {title = 'yes', result = true, seq = {'y'}},
  {title = 'no', result = false, seq = {'n'}},
}

-- Display dialog (sync)
---@param title string Dialog title
function t.display_sync(title, items, on_init)
   local co = coroutine.running()
   local dlg = t.display(title, items, on_init)

   local res
   dlg.on_cancel = function()
      res = nil
      coroutine.resume(co)
   end
   dlg.on_done = function(row)
      res = row.result
      coroutine.resume(co)
   end

   assert(co)
   coroutine.yield(co)
   return res
end

-- Display dialog
---@param title string Dialog title
---@param items table<list_item> Choices
---@param on_init? function(label: ui.label, list: ui.list)
---@return any
function t.display(title, items, on_init)
   local dlg_list = require 'dialog.list'
   local dlg = dlg_list.display(title, items, 'simple', on_init)

   dlg.list.kbd = dlg.list.kbd or ui.keybindings()
   for _, v in ipairs(items) do
      if v.seq then
	 dlg.list.kbd:set_seq(v.seq, function()
	    dlg.cancel()
	    dlg.on_done(v)
	 end)
      end
   end

   dlg.window.layout = ui.rel{left = 10, right = 10, height = 20 + #items * dlg.list.row_size}
   ui.resize()
   return dlg
end

return t
