local class = require 'class'
local ui = require 'ui.shared'

---@class ui.list : ui.view
---@field sel             number
---@field items           table<any>
---@field row_update?     function(view: ui.list, row: ui.view, data: any)
---@field row_constructor function(view: ui.list, data: any)
---@field row_size        number
ui.list = class(ui.view)

local function string_row_constructor(_, str)
   local v = ui.label()
   v.text = str
   return v
end

local function title_row_constructor(_, data)
   local v = ui.label()
   v.text = data.title
   return v
end

local function columns_row_constructor(_, row)
   local len = #row
   local c = ui.container(ui.rel {})
   if len > 0 then
      for i = 0, len - 1 do
         local l = ui.label(ui.rel { left = string.format('%f%%', 100 / len * i),
                               width = string.format('%f%%', 100 / len),
                               top = 0,
                               bottom = 0 })
         l.align = -1
         l.text = row[i + 1] or ''
         c:add_child(l)
      end
   end
   return c
end

function ui.list:init(layout)
   ui.view.init(self, layout)
   self.items = {}
   self.sel = 1
   self.clip = true
   self.row_size = 20
end

-- Set row model template
---@param kind 'string'|'title'|'columns'
function ui.list:set_row_model(kind)
   print('Setting row model: ' .. kind)
   if kind == 'string' then
      self.row_constructor = string_row_constructor
   elseif kind == 'title' then
      self.row_constructor = title_row_constructor
   elseif kind == 'columns' then
      self.row_constructor = columns_row_constructor
   else
      assert(false, 'Invalid row model!')
   end
end

function ui.list:update_rows()
   local old_size = #self.children
   local new_size = #self.items

   -- Auto detect row model type
   if new_size > 0 and not self.row_constructor then
      print('Detecting row model')
      local first = self.items[1]
      if type(first) == 'string' then
         self:set_row_model('string')
      elseif type(first) == 'table' and first.title then
         self:set_row_model('title')
      elseif type(first) == 'table' and #first > 0 then
         self:set_row_model('columns')
      end
   end

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
            c.layout = ui.rel({ top = (idx - 1) * height, left = 0, right = 0, height = height })
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
         c.layout = ui.rel({ top = (idx - 1) * height, left = 0, right = 0, height = height })
      end

      self:layout_children(nil)
   end

   self:set_selection(self.sel > #self.items and #self.items or self.sel)
end

function ui.list:layout_children(parent_frame)
   if parent_frame and self.layout and self.layout.update then
      self.layout:update(parent_frame)
   end

   local r = self:frame():clone():inset(ui.style.padding, 0):offset(self.scroll.x, self.scroll.y)
   for _, v in ipairs(self.children or {}) do
      v:layout_children(r)
   end
end

function ui.list:row_frame(idx)
   local child = self.children[idx]
   if child then
      local my_frame = self:frame()
      local child_frame = child:frame():clone()
      child_frame.x = my_frame.x
      child_frame.width = my_frame.width
      return child_frame
   end
end

function ui.list:draw_self(gc, dirty)
   local r = self:frame()
   ui.fill_rect(gc, r)

   local has_focus = self:has_focus()
   for idx = 1, #self.children do
      local row_frame = self:row_frame(idx)
      if idx == self.sel and has_focus then
         ui.fill_rect(gc, row_frame, ui.style.sel_background)
      elseif idx % 2 == 0 then
         ui.fill_rect(gc, row_frame, ui.style.background)
      else
         ui.fill_rect(gc, row_frame, ui.style.alt_background)
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
