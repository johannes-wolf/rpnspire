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
---@return number Selected row index
---@return number Selected column index
function t.display_sync(options, on_init)
   local co = coroutine.running()
   local dlg = t.display(options, on_init)

   local res, sel, col
   function dlg.on_cancel()
      res = nil
      coroutine.resume(co)
   end
   function dlg.on_done(row)
      res = row.result or row
      sel = dlg.list.sel
      col = dlg.list.col
      coroutine.resume(co)
   end

   assert(co)
   coroutine.yield(co)
   return res, sel, col
end

-- Display dialog
---@param options table<string, any>
---@param on_init? function(label: ui.label, list: ui.list)
---@return any
function t.display(options, on_init)
   if options.filter then
      local dlg = require 'dialog.filterlist'
      return dlg.display(options, options.filter, on_init)
   else
      local dlg = require 'dialog.list'
      return dlg.display(options, on_init)
   end
end

return t
