local ui = require 'ui'
require 'views.menu'
require 'views.edit'
require 'views.label'
require 'views.container'
require 'views.list'

local settings = {
   ['stack_size'] = 'small'
}

local function show_settings()
   local settings_list = {
      {title = 'Stack Size', options = {'small', 'normal'}, key = 'stack_size'},
      {title = 'Input Size', options = {'small', 'normal'}, key = 'input_size'},
   }

   local function settings_row_constructor(list, data)
      local row = ui.container(nil)
      row.style = 'none'

      local title = ui.label(ui.rel{left = 0, top = 0, bottom = 0, width = '50%'})
      title.text = data.title

      local value = ui.label(ui.rel{right = 0, top = 0, bottom = 0, width = '50%'})
      value.text = settings[data.key] or '?'

      row:add_child(title)
      row:add_child(value)
      return row
   end

   local function edit_settings_item(list, item)
      if item.options then
	 local items = {}
	 for _, v in ipairs(item.options) do
	    table.insert(items, {title = v, action = function()
				    settings[item.key] = v
				    list:update_rows()
	    end})
	 end

	 ui.menu.menu_at_point(list, items, list:frame():center())
      end
   end

   local window = ui.container(ui.rel{top = 10, bottom = 10, left = 10, right = 10})
   window.style = '2D'

   local title = ui.label(ui.rel{top = 0, height = 20, width = 200})
   title.text = 'Settings'
   window:add_child(title)

   local list = ui.list(ui.rel{top = 20, bottom = 0, left = 0, right = 0})
   list.row_constructor = settings_row_constructor
   list.row_size = 20
   list.items = settings_list
   list:update_rows()
   window:add_child(list)

   list.on_enter_key = function(list)
      edit_settings_item(list, list:get_item())
   end

   list.on_escape = function()
      ui.pop_modal()
   end
   
   window.on_escape = function()
      ui.pop_modal()
   end

   ui.push_modal(window)
   ui.set_focus(list)
end

function on.construction()
  toolpalette.enableCopy(true)
  toolpalette.enableCut(true)
  toolpalette.enablePaste(true)

  local root = ui.push_modal()

  local main_view = ui.container(ui.rel({top = 0, bottom = 0, left = 0, right = 0}))

  local input_row = ui.container(ui.rel({bottom = 0, left = 0, right = 0, height = 20}))
  main_view:add_child(input_row)

  local edit_column = {}

  local label
  label = ui.label(ui.column_layout(edit_column, 1, function() return label:min_size().x + 2 end))
  label.text = 'Hello'
  input_row:add_child(label)

  local edit = ui.edit(ui.column_layout(edit_column, 2, '*'))
  input_row:add_child(edit)

  local stack = ui.list(ui.rel({top = 0, bottom = 20, left = 0, right = 0}))
  main_view:add_child(stack)
  stack.items = {
     'Eins',
     'Zwei',
     'Drei',
     'Vier',
  }
  stack:update_rows()

  edit.on_up = function(self)
     ui.set_focus(stack)
  end

  edit.on_enter_key = function(self)
     table.insert(stack.items, self.text)
     stack:update_rows()
     stack:set_selection('end')
     label.text = self.text
     self:set_text('')
     input_row:layout_children()
  end

  stack.on_escape = function(self)
     ui.set_focus(edit)
  end

  root.main = main_view
  ui.set_focus(edit)
end

function on.resize(w, h)
   ui.resize(w, h)
end

function on.mouseDown(x, y)
   ui.on_event('mouse_down', x, y)
   show_settings()
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

function on.paint(gc, x, y, w, h)
  local gc = ui.GC(gc, 0, 0)
  ui.paint(gc)
end
