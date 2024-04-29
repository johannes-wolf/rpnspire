platform.apiLevel = '2.4'
-- luacheck: ignore class
-- luacheck: ignore platform
-- luacheck: ignore on

local advice = require 'advice'
local ui = require 'ui'
local config = require 'config.config'
require 'views.menu'
require 'views.edit'
require 'views.label'
require 'views.container'
require 'views.list'
require 'views.richedit'

require 'tableext'
require 'stringext'

local dlg_error = require 'dialog.error'
local rpn_controller = require 'rpn.controller'

local function draw_logo(gc, frame)
   local center = frame:center()
   gc:set_font(nil, "b", 80)
   gc:draw_text("rpn", 0, 0, frame.width/2, frame.height, 1, 0)
   gc:set_font(nil, "bi", 80)
   gc:draw_text("spire", frame.width/2, 0, frame.width/2, frame.height, -1, 0)
 end

local function build_main_view()
   local edit_height = 20

   local main_view = ui.container(ui.rel({ top = 0, bottom = 0, left = 0, right = 0 }))
   main_view.style = 'none'

   local edit = ui.edit(ui.rel { left = 0, right = 0, bottom = 0, height = edit_height })
   main_view:add_child(edit)

   local list = ui.list(ui.rel({ top = 0, bottom = edit_height, left = 0, right = 0 }))
   if config.enable_splash then
      list.draw_self = advice.after(list.draw_self, function(self, gc, dirty)
         if not self.items or #self.items == 0 then
            draw_logo(gc, self:frame())
         end 
      end)
   end
   main_view:add_child(list)

   local controller = rpn_controller.new(main_view, edit, list)
   return main_view, controller
end

function on.construction()
   -- luacheck: ignore toolpalette
   toolpalette.enableCopy(true)
   toolpalette.enableCut(true)
   toolpalette.enablePaste(true)

   local root = ui.push_modal()

   local main_view, main_controller = build_main_view()
   root.main = main_view
   main_controller:initialize()

   ui.set_focus(main_controller.edit)
end

function on.resize(w, h)
   ui.resize(w, h)
end

function on.mouseDown(x, y)
   ui.on_event('mouse_down', x, y)
end

function on.rightMouseDown(x, y)
   ui.on_event('rmouse_down', x, y)
end

function on.escapeKey()
   ui.on_event('escape')
end

function on.tabKey()
   ui.on_event('tab')
end

function on.backtabKey()
   ui.on_event('backtab')
end

function on.returnKey()
   ui.on_event('return')
end

function on.arrowRight()
   ui.on_event('right')
end

function on.arrowLeft()
   ui.on_event('left')
end

function on.arrowUp()
   ui.on_event('up')
end

function on.arrowDown()
   ui.on_event('down')
end

function on.charIn(c)
   ui.on_event('char', c)
end

function on.enterKey()
   ui.on_event('enter_key')
end

function on.backspaceKey()
   ui.on_event('backspace')
end

function on.clearKey()
   ui.on_event('clear')
end

function on.contextMenuKey()
   ui.on_event('ctx')
end

function on.contextMenu()
   ui.on_event('ctx')
end

function on.help()
   ui.on_event('help')
end

function on.cut()
   ui.on_event('cut')
end

function on.copy()
   ui.on_event('copy')
end

function on.paste()
   ui.on_event('paste')
end

function on.paint(gc)
   ui.paint(ui.GC(gc, 0, 0))
end

if platform.registerErrorHandler then
   platform.registerErrorHandler(function(line, msg)
      print(string.format('ERROR (line %d) %s', line or 0, msg or ''))
      dlg_error.display('Internal Error', msg)
      return true
   end)
end
