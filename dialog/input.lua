local ui = require 'ui'

local t = {}

---@alias init_callback function(label: ui.label, edit: ui.edit)

-- Display dialog (sync)
---@param options? table<string, any> Dialog options
---@param on_init? init_callback Initializer
function t.display_sync(options, on_init)
   local co = coroutine.running()
   local dlg = t.display(options, on_init)

   local res
   dlg.on_cancel = function()
      res = nil
      coroutine.resume(co)
   end
   dlg.on_done = function(text)
      res = text
      coroutine.resume(co)
   end

   assert(co)
   coroutine.yield(co)
   return res
end

-- Display dialog (sync)
---@param options? table<string, any> Dialog options
---@param on_init? init_callback Initializer
function t.display_sync_n(n, options, on_init)
   local co = coroutine.running()
   local dlg = t.display_n(n, options, on_init)

   local res
   dlg.on_cancel = function()
      res = nil
      coroutine.resume(co)
   end
   dlg.on_done = function(text)
      res = text
      coroutine.resume(co)
   end

   assert(co)
   coroutine.yield(co)
   return res
end

-- Display dialog
---@param options? table<string, any> Dialog options
---@param on_init? init_callback Initializer
---@return input_dlg
function t.display(options, on_init)
   options = options or {}

   ---@class input_dlg
   ---@field window    ui.container
   ---@field label     ui.label
   ---@field edit      ui.edit
   ---@field cancel    function()
   ---@field on_done   function(string)
   ---@field on_cancel function()
   local dlg = {
      on_done = function() end,
      on_cancel = function() end,
   }

   dlg.window = ui.container(ui.rel{left = 10, right = 10, height = 2*20})
   dlg.window.style = '2D'

   dlg.label = ui.label(ui.rel{left = 0, right = 0, top = 0, height = '50%'})
   dlg.label.text = options.title or ''
   dlg.label.background = 0
   dlg.label.foreground = 0xffffff
   dlg.window:add_child(dlg.label)

   dlg.edit = ui.edit(ui.rel{left = 0, right = 0, bottom = 0, height = '50%'})
   dlg.window:add_child(dlg.edit)

   local session = ui.push_modal(dlg.window)
   dlg.cancel = function()
      ui.pop_modal(session)
   end

   dlg.edit.on_enter_key = function(this)
      dlg.cancel()
      dlg.on_done(this.text)
   end

   dlg.edit.on_escape = function(_)
      dlg.cancel()
      dlg.on_cancel()
   end

   local completion = require 'completion'
   completion.setup_edit(dlg.edit)

   dlg.window:layout_children()
   if options.text then dlg.edit:insert_text(options.text, true) end
   if options.cursor then dlg.edit:set_cursor(options.cursor) end

   if on_init then
      on_init(dlg.label, dlg.edit)
   end

   ui.set_focus(dlg.edit)
   return dlg
end

-- Display dialog with n inputs
---@param n int Number of inputs
---@param options? table<string, any> Dialog options
---@param on_init? init_callback Initializer
---@return input_dlg
function t.display_n(n, options, on_init)
   options = options or {}

   ---@class input_dlg
   ---@field window    ui.container
   ---@field label     ui.label
   ---@field edit      table<ui.edit>
   ---@field cancel    function()
   ---@field on_done   function(string)
   ---@field on_cancel function()
   local dlg = {
      on_done = function() end,
      on_cancel = function() end,
   }

   dlg.window = ui.container(ui.rel{left = 10, right = 10, height = (n+1)*20})
   dlg.window.style = '2D'

   dlg.label = ui.label(ui.rel{left = 0, right = 0, top = 0, height = 20})
   dlg.label.text = options.title or ''
   dlg.label.background = 0
   dlg.label.foreground = 0xffffff
   dlg.window:add_child(dlg.label)
   dlg.edit = {}
   dlg.text = {}

   local y = 20
   for i = 1, n do
      local edit = ui.edit(ui.rel{left = 0, right = 0, top = y, height = 20})
      edit.n = i
      dlg.edit[i] = edit
      dlg.window:add_child(dlg.edit[i])
      y = y + 20
   end

   local session = ui.push_modal(dlg.window)
   dlg.cancel = function()
      ui.pop_modal(session)
   end

   local cancel = function(_)
      dlg.cancel()
      dlg.on_cancel()
   end

   local next_or_submit = function(this)
      dlg.text[this.n] = this.text
      if this.n >= n then
         dlg.cancel()
         dlg.on_done(dlg.text)
      else
         ui.set_focus(dlg.edit[this.n + 1])
      end
   end

   local focus_prev = function(this)
      if this.n == 1 then
         ui.set_focus(dlg.edit[n])
      else
         ui.set_focus(dlg.edit[this.n - 1])
      end
   end

   local focus_next = function(this)
      if this.n >= n then
         ui.set_focus(dlg.edit[1])
      else
         ui.set_focus(dlg.edit[this.n + 1])
      end
   end

   for _, e in ipairs(dlg.edit) do
      e.on_escape = cancel
      e.on_enter_key = next_or_submit
      e.on_down = focus_next
      e.on_up = focus_prev
   end

   local completion = require 'completion'
   for _, edit in ipairs(dlg.edit) do
      completion.setup_edit(edit)
   end

   dlg.window:layout_children()
   if options.text then dlg.edit[1]:insert_text(options.text, true) end
   if options.cursor then dlg.edit[1]:set_cursor(options.cursor) end

   if on_init then
      on_init(dlg.label, dlg.edit)
   end

   ui.set_focus(dlg.edit[1])
   return dlg
end

return t
