local class = require 'class'
local ui = require 'ui.shared'

---@class ui.view
---@field parent    ui.view
---@field children  ui.view[]
---@field font_size? number
---@field clip      boolean
---@field scroll    ui.point # Scroll offset
---@field layout?    ui.layout
---@field border?   number # Border color
---@field background? number # Background color
ui.view = class()

function ui.view:init(layout)
   self.layout = layout
   self.children = {}
   self.clip = true
   self.scroll = ui.point(0, 0)
end

-- Add child view
---@param child ui.view
function ui.view:add_child(child)
   if child.parent then
      child.parent:remove_child(child)
   end
   self.children = self.children or {}
   table.insert(self.children, child)
   child.parent = self
   return child
end

-- Remove child view
---@param child ui.view
function ui.view:remove_child(child)
   if child.parent == self then
      for idx, v in ipairs(self.children) do
	 if v == child then
	    table.remove(self.children, idx)
	    break
	 end
      end
      child.parent = nil
   end
end

-- Recursive layout child views
---@param parent_frame? ui.rect
function ui.view:layout_children(parent_frame)
   if parent_frame and self.layout and self.layout.update then
      self.layout:update(parent_frame)
   end

   local r = self:frame():clone():offset(self.scroll.x, self.scroll.y)
   for _, v in ipairs(self.children or {}) do
      v:layout_children(r)
   end
end

function ui.view:frame()
   if self.layout then
      return self.layout:frame()
   end
   return ui.rect(0, 0, 0, 0)
end

function ui.view:text_height(s)
   s = s or 'A'
   return ui.GC.with_gc(function(gc)
	 if self.font_size then
	    gc:set_font_size(self.font_size)
	 end
	 return gc:text_height(s)
   end)
end

-- Draw view
---@param gc ui.GC
function ui.view:draw(gc, dirty)
   if not self:frame():intersects_rect(dirty) then
      return
   end

   if self.clip then
      gc:push_clip(self:frame():clone())
   end

   local old_font
   if self.font_size then
      old_font = gc:set_font_size(self.font_size)
   end

   self:draw_self(gc, dirty)

   if old_font ~= self.font_size then
      gc:set_font_size(old_font)
   end

   if self.children then
      self:draw_children(gc:sub(), dirty)
   end

   if self.clip then
      gc:reset_clip()
   end
end

-- Draw self
function ui.view:draw_self(gc)
   if self.border or self.background then
      local r = self:frame()
      gc:draw_rect(r.x, r.y, r.width, r.height, self.border, self.background)
   end
end

-- Draw children
function ui.view:draw_children(gc, dirty)
   for _, v in ipairs(self.children) do
      v:draw(gc, dirty)
   end
end

-- Ensure frame f (in absolute coordinates) is visible
---@param view_frame ui.rect  This views frame
---@param f          ui.rect  Rect to scroll to
function ui.view:ensure_visible(view_frame, f)
   if view_frame.height == 0 or view_frame.width == 0 then return end

   self.scroll = self.scroll or ui.point(0, 0)

   if f.x < view_frame.x then
      self.scroll.x = self.scroll.x + (view_frame.x - f.x)
   elseif f:max_x() > view_frame:max_x() then
      self.scroll.x = self.scroll.x + (view_frame:max_x() - f:max_x())
   end

   if f.y < view_frame.y then
      self.scroll.y = self.scroll.y + (view_frame.y - f.y)
   elseif f:max_y() > view_frame:max_y() then
      self.scroll.y = self.scroll.y + (view_frame:max_y() - f:max_y())
   end

   self:layout_children()
   return self.scroll
end

-- Test if self is focused
function ui.view:has_focus()
   return ui.get_focus() == self
end
