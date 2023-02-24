local ui = require 'ui'

local t = {}

function t.display_sync(title, text)
   local co = coroutine.running()
   local dlg = t.display(title, text)

   local res
   function dlg.on_cancel()
      res = nil
      coroutine.resume(co)
   end
   function dlg.on_done()
      res = true
      coroutine.resume(co)
   end

   assert(co)
   coroutine.yield(co)
   return res
end

-- Display dialog
---@param title?    string
---@param oninit?   function(ui.label, ui.label)
---@return error_dlg
function t.display(title, text, oninit)
   ---@class error_dlg
   ---@field window    ui.container
   ---@field label     ui.label
   ---@field text      ui.label
   ---@field cancel    function()
   ---@field on_cancel function()
   local dlg = {
      on_done = function() end,
      on_cancel = function() end,
   }

   dlg.window = ui.container(ui.rel{left = 10, right = 10, height = 2*20})
   dlg.window.style = '2D'

   dlg.label = ui.label(ui.rel{left = 0, right = 0, top = 0, height = '50%'})
   dlg.label.text = title or 'Error'
   dlg.label.background = 0x0
   dlg.label.foreground = 0xffffff
   dlg.window:add_child(dlg.label)

   dlg.text = ui.label(ui.rel{left = 0, right = 0, bottom = 0, height = '50%'})
   dlg.text.text = text or ''
   dlg.window:add_child(dlg.text)

   if oninit then oninit(dlg.label, dlg.text) end

   local session = ui.push_modal(dlg.window)
   dlg.cancel = function()
      ui.pop_modal(session)
   end

   dlg.window.on_char = function(_)
      dlg.cancel()
      dlg.on_cancel()
   end

   dlg.window.on_escape = function(_)
      dlg.cancel()
      dlg.on_cancel()
   end

   dlg.window.on_enter_key = function(_)
      dlg.cancel()
      dlg.on_cancel()
   end

   ui.set_focus(dlg.window)
   return dlg
end

return t
