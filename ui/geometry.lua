local ui = require 'ui.shared'

local geom = {}

---@class ui.point
---@field x number
---@field y number
local point_t = {}

---@class ui.rect
---@field x number
---@field y number
---@field width number
---@field height number
local rect_t = {}

local function is_point(o)
   return getmetatable(o) == point_t
end

function geom.point(x, y)
   return setmetatable({x = x or 0, y = y or 0}, point_t)
end

-- Offset point by x, y
---@param x number
---@param y number
function point_t:offset(x, y)
   self.x = self.x + x
   self.y = self.y + y
   return self
end

function point_t:clone()
   return geom.point(self.x, self.y)
end

local function is_rect(o)
   return getmetatable(o) == rect_t
end

-- Construct rect
---@param x number
---@param y number
---@param w number
---@param h number
---@return geom.rect
function geom.rect(x, y, w, h)
   return setmetatable({x = x, y = y, width = w, height = h}, rect_t)
end

-- Unpack rect
---@return number x, number y, number width, number height
function rect_t:unpack()
   return self.x, self.y, self.width, self.height
end

-- Clone rect
---@return ui.rect
function rect_t:clone()
   return geom.rect(self.x, self.y, self.width, self.height)
end

function rect_t:offset(x, y)
   self.x = self.x + x
   self.y = self.y + y
   return self
end

function rect_t:offset_rect(x, y)
   return geom.rect(self.x + x, self.y + y, self.width, self.height)
end

function rect_t:origin()
   return geom.point(self.x, self.y)
end

function rect_t:max_x()
   return self.x + self.width
end

function rect_t:max_y()
   return self.y + self.height
end

function rect_t:top_left()
   return geom.point(self.x, self.y)
end

function rect_t:top_right()
   return geom.point(self.x + self.width, self.y)
end

function rect_t:bottom_left()
   return geom.point(self.x, self.y + self.height)
end

function rect_t:bottom_right()
   return geom.point(self.x + self.width, self.y + self.height)
end

function rect_t:center()
   return geom.point(self.x + self.width/2, self.y + self.height/2)
end

function rect_t:inset(x, y)
   x = x or 0
   y = y or x
   self.x = self.x + x
   self.y = self.y + y
   self.width = self.width - 2*x
   self.height = self.height - 2*y
   return self
end

function rect_t:contains(other)
   if is_point(other) then
      return other.x >= self.x and other.x <= self.x + self.width and
	     other.y >= self.y and other.y <= self.y + self.height
   elseif is_rect(other) then
      return self:contains(other:top_left()) and
	     self:contains(other:bottom_right())
   else
      assert(false)
   end
end

function rect_t:intersects_rect(r)
   local x1, y1 = math.max(self.x, r.x), math.max(self.y, r.y)
   local x2, y2 = math.min(self:max_x(), r:max_x()), math.min(self:max_y(), r:max_y())
   if x1 < x2 and y1 < y2 then
      return true
   end
   return false
end

function rect_t:intersection_rect(r)
   local x1, y1 = math.max(self.x, r.x), math.max(self.y, r.y)
   local x2, y2 = math.min(self:max_x(), r:max_x()), math.min(self:max_y(), r:max_y())
   if x1 < x2 and y1 < y2 then
      return geom.rect(x1, y1, x2 - x1, y2 - y1)
   end
   return geom.rect(0, 0, 0, 0)
end

-- Return union rect of self and %r
---@param r ui.rect
---@return ui.rect
function rect_t:union_rect(r)
   local x1, x2 = math.min(self.x, r.x), math.max(self:max_x(), r:max_x())
   local y1, y2 = math.min(self.y, r.y), math.max(self:max_y(), r:max_y())
   return geom.rect(x1, y1, x2 - x1, y2 - y1)
end

function rect_t:__tostring()
   return string.format("{%d, %d, %d, %d}", self.x, self.y, self.width, self.height)
end


rect_t.__index = rect_t
point_t.__index = point_t

---@class ui.point
---@field x number
---@field y number
ui.point = geom.point

---@class ui.rect
---@field x number
---@field y number
---@field width number
---@field height number
ui.rect = geom.rect

return geom
