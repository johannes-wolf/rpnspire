local ui = require 'ui'

local t = {}

t.yesno = {
  {title = 'yes', result = true, seq = {'y'}},
  {title = 'no', result = false, seq = {'n'}},
}

-- Display dialog (sync)
---@param options table Dialog options
---@param on_init? function()
---@return any Selected item
---@return number Selection index
function t.display_sync(options, on_init)
   local co = coroutine.running()
   local dlg = t.display(options.title, options.items, on_init)
   dlg.list:set_selection(options.selection or 1)

   local res, sel
   function dlg.on_cancel()
      res = nil
      coroutine.resume(co)
   end
   function dlg.on_done(row)
      res = row.result
      sel = dlg.list.sel
      coroutine.resume(co)
   end

   assert(co)
   coroutine.yield(co)
   return res, sel
end

-- Display dialog
---@param title string Dialog title
---@param items table<list_item> Choices
---@param on_init? function(label: ui.label, list: ui.list)
---@return any
function t.display(title, items, on_init)
   local dlg_list = require 'dialog.list'
   return dlg_list.display(title, items, on_init)
end

return t
