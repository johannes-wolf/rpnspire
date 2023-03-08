local class = require 'class'
local ui = require 'ui.shared'

---@class ui.column
---@field title string # Title
---@field size number  # Size
---@field _x number    # Cached position
---@field _size number # Cached size

---@class ui.row_view
---@field _frame ui.rect
ui.row_view = class(ui.view)
function ui.row_view:init()
   ui.view.init(self, 0)
   self.clip = nil
   self.children = {}
end

function ui.row_view:draw_self() end
function ui.row_view:layout_children() end

function ui.row_view:set_frame(f)
   self._frame = f
end

function ui.row_view:frame()
   return self._frame or ui.rect(0, 0, 0, 0)
end

---@class ui.list : ui.view
---@field sel              number # Selected row
---@field col              number # Selected column
---@field style            'list'|'grid' # Style
---@field items            table<any>
---@field columns?         table<string>
---@field cell_constructor function(view: ui.list, column: ui.column, data: any)
---@field cell_update?     function(view: ui.list, cell: ui.view, column: ui.column, data: any)
---@field row_size         number|function(view: ui.list, row: ui.view, data: any) # Row height
---@field on_selection     function(view: ui.list, row: number, column: number)
ui.list = class(ui.view)

local function string_cell_constructor(list, col, str)
   local v = ui.label()
   v.font_size = list.font_size
   v.text = str
   return v
end

local function title_cell_constructor(list, col, data)
   local v = ui.label()
   v.font_size = list.font_size
   v.text = data.title
   return v
end

local function columns_cell_constructor(list, col, row)
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
         l.font_size = list.font_size
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
   self.row_size = 18
   self.style = 'list'
   self.columns = {{size = '*'}}
end

-- Set row model template
---@param kind 'string'|'title'|'columns'
function ui.list:set_row_model(kind)
   if kind == 'string' then
      self.cell_constructor = string_cell_constructor
   elseif kind == 'title' then
      self.cell_constructor = title_cell_constructor
   elseif kind == 'columns' then
      self.cell_constructor = columns_cell_constructor
   else
      assert(false, 'Invalid row model!')
   end
end

function ui.list:_row_height(row, data)
   return type(self.row_size) == 'number' and self.row_size
       or self:row_size(row, data)
end

function ui.list:_row_width(row, data)
   if self.columns then
      return self.columns[#self.columns]._x + self.columns[#self.columns]._size
   end
   return self:frame().width
end

function ui.list:item_len()
   return self.items_len or #self.items
end

function ui.list:update_rows()
   local old_size = #self.children
   local new_size = self:item_len()
   print(new_size)

   self:layout_columns()

   -- Auto detect row model type
   if new_size > 0 and not self.cell_constructor then
      local first = self.items[1]
      if type(first) == 'string' then
         self:set_row_model('string')
      elseif type(first) == 'table' and first.title then
         self:set_row_model('title')
      elseif type(first) == 'table' and #first > 0 then
         self:set_row_model('columns')
      end
   end

   if self.cell_update then
      for row_idx = 1, math.min(old_size, new_size) do
         local row_view = self.children[row_idx]
         for column_idx, column in ipairs(self.columns) do
            if row_view.children then
               self:cell_update(row_view.children[column_idx], column, self.items[row_idx])
            end
         end
      end

      if new_size > old_size then
         for idx = old_size + 1, new_size do
            local data = self.items[idx]

            local row_view = ui.row_view()
            for _, column in ipairs(self.columns) do
               local cell = row_view:add_child(self:cell_constructor(column, data))
               cell.layout = ui.rel { top = 0, left = 0, right = 0, bottom = 0 }
            end

            self.children[idx] = row_view
            row_view.parent = self
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

      for _, data in ipairs(self.items) do
         local row_view = ui.row_view()
         for _, column in ipairs(self.columns) do
            local cell = row_view:add_child(self:cell_constructor(column, data))
            cell.layout = ui.rel { top = 0, left = 0, right = 0, bottom = 0 }
         end

         self:add_child(row_view)
      end

      self:layout_children(nil)
   end

   self:set_selection(self.sel > self:item_len() and self:item_len() or self.sel)
end

function ui.list:layout_column(column, x)
   column._x = x
   if column.size == '*' then
      column._x = x
      column._size = math.max(0, self:frame().width)
   else
      column._size = column.size
   end

   return column._x + column._size
end

function ui.list:layout_columns()
   if self.columns then
      local x = 0
      for _, column in ipairs(self.columns) do
         x = self:layout_column(column, x)
      end
   end
end

function ui.list:layout_children(parent_frame)
   if parent_frame and self.layout and self.layout.update then
      self.layout:update(parent_frame)
   end

   self:layout_columns()

   local frame = self:frame():clone():offset(self.scroll.x, self.scroll.y)
   local y_offset = 0

   for idx, row_view in ipairs(self.children or {}) do
      local row_height = self:_row_height(row_view, self.items[idx])

      local row_frame
      for column_idx, column in ipairs(self.columns) do
         local cell_frame = ui.rect(column._x, y_offset, column._size, row_height)
            :offset(frame.x, frame.y):inset(ui.style.padding, 0)

         local cell_view = row_view.children[column_idx]
         if cell_view then
            cell_view:layout_children(cell_frame)
         end

         row_frame = row_frame and row_frame:union_rect(cell_frame) or cell_frame:clone()
      end

      row_view:set_frame(row_frame)
      y_offset = y_offset + row_height
   end
end

-- Return relative column position
---@return number # x coordinate
---@return number # width
function ui.list:column_position(col)
   return self.columns[col]._x, self.columns[col]._size
end

-- Returns the _visible_ row frame
function ui.list:_visible_row_frame(row)
   local child = self.children[row]
   if child then
      local my_frame = self:frame()
      local child_frame = child:frame():clone()
      child_frame.x = my_frame.x
      child_frame.width = my_frame.width
      return child_frame
   end
end

function ui.list:cell_frame(row, col)
   local row_view = self.children[row]
   if row_view and row_view.children then
      return row_view.children[col]:frame()
   end
end

function ui.list:draw_overlay(gc)
   local function draw_grid(frame)
      if not self.children or #self.children == 0 then
         return
      end

      local y1 = math.max(self.children[1]:frame().y, frame.y)
      local y2 = math.min(self.children[#self.children]:frame():max_y(), frame:max_y())
      if self.columns then
         for _, column in ipairs(self.columns) do
            gc:draw_line(column._x + column._size + self.scroll.x + frame.x, y1,
                         column._x + column._size + self.scroll.x + frame.x, y2, ui.style.border)
         end
      end
      for _, row in ipairs(self.children) do
         local row_frame = row:frame():intersection_rect(frame):inset(-ui.style.padding, 0)
         gc:draw_line(row_frame.x, row_frame:max_y(), row_frame:max_x(), row_frame:max_y(), ui.style.border)
      end
   end

   if self.style == 'grid' then
      draw_grid(self:frame())
   end
end

function ui.list:draw_self(gc)
   local r = self:frame()
   ui.fill_rect(gc, r)

   local function draw_selection()
      local rect = self:cell_frame(self.sel, self.col)
      if rect then
         ui.fill_rect(gc, rect:clone():inset(-ui.style.padding, 0), ui.style.sel_background)
      end
   end

   if self.style == 'list' then
      for idx = 1, #self.children do
         local row_frame = self:_visible_row_frame(idx)
         if idx % 2 == 0 then
            ui.fill_rect(gc, row_frame, ui.style.background)
         else
            ui.fill_rect(gc, row_frame, ui.style.alt_background)
         end
      end
   end

   local has_focus = self:has_focus()
   if has_focus then
      draw_selection()
   end

   ui.frame_rect(gc, r)
end

-- Set selection
---@param row  number|'end'
---@param col? number|'end'
function ui.list:set_selection(row, col)
   local max_row = self:item_len()

   row = row or self.sel or 1
   col = col or self.col or 1
   if row == 'end' then
      row = max_row
   end

   if row < 1 then
      row = max_row
   elseif row > max_row then
      row = 1
   end

   if col == 'end' then
      col = #self.columns
   end

   if self.columns then
      if col < 1 then
         col = #self.columns
      elseif col > #self.columns then
         col = 1
      end
   end

   self.sel = tonumber(row) or 1
   self.col = tonumber(col) or 1

   local cell_frame = self:cell_frame(self.sel, self.col)
   if cell_frame then
      self:ensure_visible(self:frame(), cell_frame:clone():inset(-ui.style.padding, 0))
   end

   if self.on_selection then
      self:on_selection()
   end
end

function ui.list:get_selection()
   return self.sel, self.col or 1
end

function ui.list:get_item(idx)
   idx = idx or self.sel
   return self.items[idx]
end

-- Scroll to item at row and column
---@param row? number|'end' Row
---@param col? number|'end' Column
function ui.list:scroll_to_item(row, col)
   row = row or self.sel or 1
   if row == 'end' then row = #self.items end

   col = col or self.col or 1
   if col == 'end' then col = #self.columns end

   if self.children[row] then
      self:ensure_visible(self:frame(), self:cell_frame(row, col))
   end
end

-- Events

function ui.list:on_up()
   self:set_selection(self.sel - 1, nil)
end

function ui.list:on_down()
   self:set_selection(self.sel + 1, nil)
end

function ui.list:on_left()
   self:set_selection(self.sel, self.col - 1)
end

function ui.list:on_right()
   self:set_selection(self.sel, self.col + 1)
end
