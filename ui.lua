-- luacheck: ignore platform
local ui = require 'ui.shared'
require 'ui.geometry'
require 'ui.gc'

ui.modal = {}
ui.style = {
   border         = 0x000000,
   text           = 0x000000,
   background     = 0xffffff,
   alt_background = 0xffeeee,
   sel_background = 0xff9999,
   caret          = 0xff0000,
   caret_inactive = 0x999999,
   padding        = 2,
}

require 'ui.keybind'
require 'ui.layout'
require 'ui.view'

ui.bindings = {}
ui.kbd = ui.keybindings()
ui.kbd.on_seq = function(self)
   local v = ui.get_focus()
   while v do
      if self:try_call_table(v.kbd) then
	 return true
      end
      v = v.parent
   end

   return self:try_call_table(ui.bindings)
end

-- Fill and outline a box
---@param r ui.rect
function ui.draw_box(gc, r)
   gc:draw_rect(r.x, r.y, r.width, r.height, ui.style.border, ui.style.background)
end

function ui.fill_rect(gc, r, color)
   color = color or ui.style.background
   gc:draw_rect(r.x, r.y, r.width, r.height, nil, color)
end

function ui.frame_rect(gc, r)
   gc:draw_rect(r.x, r.y, r.width, r.height, ui.style.border, nil)
end

-- Push and return modal session
---@param main? ui.view
---@return table Modal session
function ui.push_modal(main)
   table.insert(ui.modal, {main = main, focus = nil, idx = #ui.modal + 1})
   if main then ui.resize() end
   ui.update()
   return ui.get_modal()
end

-- Pop modal session
---@param test? table Modal session
function ui.pop_modal(test)
   assert(not test or test == ui.modal[#ui.modal])
   ui.set_focus(nil)
   table.remove(ui.modal, test and test.idx)
   ui.update()
end

-- Get current session
---@return table Current modal session
function ui.get_modal()
   return ui.modal[#ui.modal]
end

-- Call event with name on focused view
---@param name string  Event name
function ui.on_event(name, ...)
   local session = ui.modal[#ui.modal]
   local target = session.focus or session.main

   local function dispatch_event(v, ...)
      if v then
	 local handled = false
	 if ui.kbd['on_'..name] then
	    handled = ui.kbd['on_'..name](ui.kbd, ...)
	 end
	 if not handled and v['on_'..name] then
	    handled = v['on_'..name](v, ...) ~= false
	 end
	 return handled
      end
   end

   if target then
      dispatch_event(target, ...)
      ui.update()
   end
end

-- Set focus to view
---@param view ui.view?  View to focus
---@return     ui.view   Focused view
function ui.set_focus(view)
   local session = ui.modal[#ui.modal]
   if session.focus ~= view then
      ui.on_event('exit')
      session.focus = view
      if session.focus then
         ui.on_event('enter')
      end
   end
   return session.focus
end

-- Get focused view
---@return ui.view
function ui.get_focus()
   local session = ui.modal[#ui.modal]
   return session and session.focus
end

function ui.update()
   if platform.window then
      platform.window:invalidate()
   end
end

-- Notify ui about screen resize
---@param w? number Screen width
---@param h? number Screen height
function ui.resize(w, h)
   w = w or ui.GC.screen_width()
   h = h or ui.GC.screen_height()
   for _, v in ipairs(ui.modal) do
      v.main:layout_children(ui.rect(0, 0, w, h))
   end
end

function ui.paint(gc, x, y, w, h)
   local dirty = ui.rect(x or 0, y or 0, w or ui.GC.screen_width(), h or ui.GC.screen_height())
   for _, v in ipairs(ui.modal) do
      v.main:draw(gc, dirty)
   end
end

return ui
