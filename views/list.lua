local class = require 'class'
local ui = require 'ui.shared'

---@alias list_item table<string, any>

---@class ui.list : ui.view
---@field sel             number
---@field items           table<any>
---@field row_match       function(view: ui.list, data: any, typeahead: string): boolean
---@field row_update      function(view: ui.list, row: ui.view, data: any)
---@field row_constructor function(view: ui.list, data: any)
---@field row_size        number
ui.list = class(ui.view)

local function string_row_constructor(_, str)
   assert(type(str) == 'string')
   local v = ui.label()
   v.text = str
   return v
end

local function string_row_match(_, row, str)
   return row:find(str or '')
end

function ui.list:init(layout)
   ui.view.init(self, layout)
   self.items = {}
   self.sel = 1
   self.clip = true
   self.row_constructor = string_row_constructor
   self.row_match = string_row_match
   self.row_size = 20
end

function ui.list:update_rows()
   local old_size = #self.children
   local new_size = #self.items

   local height = self.row_size
   if self.row_update then
      for idx = 1, math.min(old_size, new_size) do
	 self:row_update(self.children[idx], self.items[idx])
      end

      if new_size > old_size then
	 for idx = old_size + 1, new_size do
	    local v = self.items[idx]
	    local c = self:row_constructor(v)
	    self.children[idx] = c
	    c.parent = self
	    c.layout = ui.rel({top = (idx - 1) * height, left = 0, right = 0, height = height})
	 end
	 self:layout_children(nil)
      elseif new_size < old_size then
	 for idx = new_size + 1, old_size do
	    self.children[idx] = nil
	 end
	 self:layout_children(nil)
      end
   else
      self.children = {}

      for idx, v in ipairs(self.items) do
	 local c = self:add_child(self:row_constructor(v))
	 c.layout = ui.rel({top = (idx - 1) * height, left = 0, right = 0, height = height})
      end

      self:layout_children(nil)
   end

   self:set_selection(self.sel > #self.items and #self.items or self.sel)
end

function ui.list:draw_self(gc, dirty)
   local r = self:frame()
   ui.fill_rect(gc, r)

   local has_focus = ui.get_focus() == self
   for idx, v in ipairs(self.children) do
      if idx == self.sel and has_focus then
	 ui.fill_rect(gc, v:frame(), ui.style.sel_background)
      elseif idx % 2 == 0 then
	 ui.fill_rect(gc, v:frame(), ui.style.background)
      else
	 ui.fill_rect(gc, v:frame(), ui.style.alt_background)
      end
   end

   ui.frame_rect(gc, r)
end

function ui.list:set_selection(idx)
   idx = idx or self.sel
   if idx == 'end' then
      idx = #self.items
   elseif idx == 'up' then
      idx = idx - 1
   elseif idx == 'down' then
      idx = idx + 1
   end

   if idx < 1 then
      idx = #self.items
   elseif idx > #self.items then
      idx = 1
   end

   self.sel = idx
   if self.children[self.sel] then
      self:ensure_visible(self:frame(), self.children[self.sel]:frame())
   end
end

function ui.list:get_item(idx)
   idx = idx or self.sel
   return self.items[idx]
end

-- Scroll to item at index
---@param idx? number|'end'
function ui.list:scroll_to_item(idx)
   idx = idx or self.sel
   if idx == 'end' then idx = #self.items end

   if self.children[idx] then
      self:ensure_visible(self:frame(), self.children[idx]:frame())
   end
end

-- Events

function ui.list:on_up()
   self:set_selection(self.sel - 1)
end

function ui.list:on_down()
   self:set_selection(self.sel + 1)
end

function ui.list:on_char(c)
   if c and self.row_match then
      for idx, v in ipairs(self.items) do
	 if self:row_match(v, c) then
	    self:set_selection(idx)
	    return
	 end
      end
   end
end
