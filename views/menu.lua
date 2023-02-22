local ui = require 'ui.shared'

-- Calculate optimal menu frame for point
---@param pt   ui.point
---@param menu ui.menu
local function menu_frame_at_point(pt, menu)
   local ctx_height = ui.GC.screen_height()
   local ctx_width = ui.GC.screen_width()

   local optimal_height = menu:max_height()
   if pt.y + optimal_height > ctx_height then
      pt.y = pt.y + (ctx_height - pt.y - optimal_height)
      if pt.y < 0 then
         pt.y = 0
         optimal_height = ctx_height
      end
   end

   local optimal_width = menu:max_width()
   if pt.x + optimal_width > ctx_width then
      pt.x = pt.x + (ctx_width - pt.x - optimal_width)
      if pt.x < 0 then
         pt.x = 0
         optimal_width = ctx_width
      end
   end
   return ui.rect(pt.x, pt.y, optimal_width, optimal_height):inset(-ui.style.padding)
end

---@class ui.menu ui.view
---@field items       table
---@field filter_mode nil|'fuzzy'
---@field autoexec    boolean
---@field on_exec     function(self: ui.menu, item: any)
ui.menu = class(ui.view)
ui.menu.submenu_marker_size = 4

function ui.menu.setup_gc(gc)
   gc:set_font_size(9)
end

-- Construct and present temporary menu at point
---@param parent ui.view    Parent view
---@param items  table      Items
---@param pt     ui.point?  Point
function ui.menu.menu_at_point(parent, items, pt)
   pt = pt or parent:frame():origin()

   local m = ui.menu()
   m.items = items
   m.origin = parent
   m:open_at_point(pt)
   ui.set_focus(m)
   return m
end

function ui.menu:init()
   self.isa = ui.menu.class
   self.clip = false
   self.items = {}
   self.sel = 1
   self.scroll = ui.point(0, 0)
   self.autoexec = false -- Auto execute single item
end

-- Returns the maximum width of all menu items
function ui.menu:max_width()
   return ui.GC.with_gc(function(gc)
      ui.menu.setup_gc(gc)
      local w = 0
      for _, v in ipairs(self.items) do
         w = math.max(w, self:item_width(v, gc))
      end
      return w
   end)
end

function ui.menu:max_height()
   return #self.items * self:item_height()
end

function ui.menu:item_height()
   return 16
end

local function item_has_children(item)
   return item.action and type(item.action) == 'table' and #item.action > 0
end

function ui.menu:item_width(item, gc)
   local w = gc:text_width(item.title)
   if item_has_children(item) then
      w = w + ui.style.padding + 2 * ui.menu.submenu_marker_size
   end

   return w
end

function ui.menu:frame()
   return self._frame
end

function ui.menu:draw_self(gc)
   if not self._frame then return end
   ui.menu.setup_gc(gc)
   local prev_clip = gc:clip_rect(self._frame)
   ui.fill_rect(gc, self._frame)

   for idx, v in ipairs(self.items) do
      local f = self:get_item_frame(idx)
      if f.y < ui.GC.screen_height() and f:max_y() > 0 then
         if idx == self.sel then
            local s = f:clone():inset(-ui.style.padding, 0)
            gc:draw_rect(s.x, s.y, s.width, s.height, nil, 0xff0000)
         end
         self:draw_item(v, gc, f.x, f.y, f.width, f.height)
      end
   end

   ui.frame_rect(gc, self._frame)
   gc:clip_rect(prev_clip)
end

function ui.menu:draw_item(item, gc, x, y, w, h)
   gc:draw_text(item.title, x, y, w, h, nil, 0, ui.style.text)

   if item_has_children(item) then
      gc:draw_rect(x + w - ui.style.padding - ui.menu.submenu_marker_size,
                   y + h / 2 - ui.menu.submenu_marker_size / 2,
                   ui.menu.submenu_marker_size,
                   ui.menu.submenu_marker_size,
                   nil, ui.style.border)
   end

   return y + self:item_height()
end

function ui.menu:get_item(idx)
   idx = idx or self.sel
   return self.items[idx]
end

function ui.menu:get_item_frame(idx)
   idx = idx or self.sel
   local f = self._frame:clone():inset(ui.style.padding)
   return ui.rect(f.x, f.y + self:item_height() * (idx - 1) + self.scroll.y, f.width, self:item_height())
end

function ui.menu:set_selection(idx)
   self.sel = idx or self.sel
   if self.sel < 1 then self.sel = #self.items end
   if self.sel > #self.items then self.sel = 1 end

   self:ensure_visible(self._frame, self:get_item_frame(self.sel))
end

function ui.menu:on_up()
   self:set_selection(self.sel - 1)
end

function ui.menu:on_down()
   self:set_selection(self.sel + 1)
end

function ui.menu:on_tab()
   self:set_selection(self.sel + 1)
end

-- Close this menu
---@param mode 'recurse'|nil  Mode
function ui.menu:close(mode)
   if self.parent then
      if mode == 'recurse' and getmetatable(self.parent) == getmetatable(self) then
         self.parent:close(mode)
      end
      self.parent:remove_child(self)
   end
   ui.set_focus(self.origin)
end

function ui.menu:on_left()
   self:close()
end

function ui.menu:on_right()
   local s = self:get_item()
   if s and type(s.action) == 'table' then
      self:exec()
   end
end

function ui.menu:open_at_point(pt)
   self._pt = pt:clone()
   self._frame = menu_frame_at_point(pt, self)
   ui.get_modal().main:add_child(self)
   return self
end

function ui.menu:exec(idx)
   local s = self:get_item(idx or self.sel)
   if s then
      if type(s.action) == 'table' then
         local f = self:get_item_frame()
         local sub = ui.menu()
         sub.items = s.action
         sub:open_at_point((f:top_right()):offset(-2, 2))
         ui.set_focus(sub)
      elseif type(s.action) == 'function' then
         s.action()
         self:close('recurse')
      elseif self.on_exec then
         assert(type(self.on_exec) == 'function')
         self:on_exec(s)
         self:close()
      end
   end
end

function ui.menu:on_escape()
   if self.filter then
      self:set_filter(nil)
   else
      self:close('recurse')
   end
end

function ui.menu:on_enter_key()
   self:exec()
end

function ui.menu:on_enter()
   print('ENTER')
   if not ui.menu then
      ui.menu = self
   end
end

function ui.menu:on_exit()
   if ui.menu == self then
      ui.menu = nil
   end
end

-- Filter

function ui.menu:filter_match_item(str, item)
   return item.title:find(str) or (item.hint or ''):find(str)
end

function ui.menu:set_filter(str)
   if str and #str > 0 then
      self.filter = str
   else
      self.filter = nil
   end

   if self.filter then
      local filtered_items = {}
      for _, v in ipairs(self.items) do
         if self:filter_match_item(str, v) then
            table.insert(filtered_items, v)
         end
      end

      self.full_items = self.full_items or self.items
      self.items = filtered_items
   else
      self.items = self.full_items
   end

   if self._pt then
      self:open_at_point(self._pt)
      self:set_selection()
   end
end

function ui.menu:on_backspace()
   if not self.filter then return end

   self.filter = self.filter:usub(1, self.filter:ulen() - 1)
   self:set_filter(self.filter)
end

function ui.menu:on_char(c)
   if c == '.' or c == '[' or c == '(' or c == '%' then
      c = '%' .. c
   end
   if self.filter_mode == 'fuzzy' then
      c = c == ' ' and '.+' or '.*' .. c
   else
      c = c == ' ' and '.*' or c
   end

   self.filter = (self.filter or '') .. c
   self:set_filter(self.filter)

   if self.autoexec and #self.items == 1 then
      self:exec()
   end
end
