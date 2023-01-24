local class = require 'class'
local ui = require 'ui.shared'

---@class ui.layout

---@class ui.absolute_layout : ui.layout
local abs_layout = {}
abs_layout.__index = abs_layout

-- Initialize absoulte layout
---@param frame ui.rect  Frame
---@return      ui.absolute_layout
function ui.fixed_layout(frame)
   return setmetatable({_frame = frame:clone()}, abs_layout)
end

function abs_layout:frame()
   return self._frame
end

-- Convert input to factor, if it is a percentage string
---@param  s string|any
---@return   number      Parsed factor or s
---@return   boolean     True if first result is a factor between 0..1
local function parse_percentage_string(s)
   if type(s) == 'string' and string.sub(s, -1) == '%' then
      return tonumber(string.sub(s, 1, -2)) / 100.0, true
   end
   return s, false
end

-- Clamp value between lo and hi
---@param lo number|nil
---@param v  number
---@param hi number|nil
local function clamp(lo, v, hi)
   return math.max(math.min(hi or v, v), lo or 0)
end


local column_layout = {}
column_layout.__index = column_layout

function ui.column_layout(shared_info, index, width)
   local info = shared_info[index] or {}
   info.width = width
   shared_info[index] = info

   local res = setmetatable({info = shared_info, index = index}, column_layout)
   shared_info._columns = shared_info._columns or {}
   shared_info._columns[index] = res
   return res
end

function column_layout:update(base, view)
   local info = self.info[self.index]

   local w = info.width
   if type(w) == 'function' then w = w(base) end

   local x = 0
   for i = 1, self.index - 1 do
      x = x + self.info._columns[i]._frame.width
   end

   if not w or w == '*' then
      w = base.width - x
   end

   print(string.format('col %d frame.x %d', self.index, x))

   self._frame = ui.rect(x, 0, w, base.height):offset(base.x, base.y)
   print(self._frame)
   return self._frame
end

function column_layout:frame()
   return self._frame
end

---@class ui.tlrb_layout : ui.layout
---@field t number|string
---@field l number|string
---@field r number|string
---@field b number|string
---@field w number|string
---@field h number|string
---@field min_w number|nil  Minimum width (absolute)
---@field max_w number|nil  Maximum width (absolute)
---@field min_h number|nil  Minimun height (absolute)
---@field max_h number|nil  Maximum height (absolute)
local tlrb_layout = {}
tlrb_layout.__index = tlrb_layout

function ui.tlrb_layout(t, l, r, b, w, h, minw, maxw, minh, maxh)
   local res = setmetatable({}, tlrb_layout)
   res.t, res.t_rel = parse_percentage_string(t)
   res.l, res.l_rel = parse_percentage_string(l)
   res.b, res.b_rel = parse_percentage_string(b)
   res.r, res.r_rel = parse_percentage_string(r)
   res.w, res.w_rel = parse_percentage_string(w)
   res.h, res.h_rel = parse_percentage_string(h)
   res.min_w = minw
   res.max_w = maxw
   res.min_h = minh
   res.max_h = maxh
   return res
end

function tlrb_layout:frame()
   return self._frame or ui.rect(0, 0, 0, 0)
end

function tlrb_layout:update(base, view)
   local t, l, r, b, w, h
   local x, y
   local min_w, max_w, min_h, max_h = self.min_w, self.max_w, self.min_h, self.max_h

   t = self.t_rel and self.t * base.height or self.t
   b = self.b_rel and self.b * base.height or self.b
   h = self.h_rel and self.h * base.height or self.h
   if h == 'auto' and view.min_size then
      h = view:min_size().y
   end

   if b then
      b = base.height - b
   end

   if t and b then
      y = t
      h = clamp(min_h, b - t, max_h)
   elseif h then
      h = clamp(min_h, h, max_h)
      if t then
	 y = t
      elseif b then
	 y = b - h
      else
	 y = (base.height - h) / 2
      end
   end

   l = self.l_rel and self.l * base.width or self.l
   r = self.r_rel and self.r * base.width or self.r
   w = self.w_rel and self.w * base.width or self.w
   if w == 'auto' and view.min_size then
      w = view:min_size().x
   end

   if r then
      r = base.width - r
   end

   if l and r then
      x = l
      w = clamp(min_w, r - l, max_w)
   elseif w then
      w = clamp(min_w, w, max_w)
      if l then
	 x = l
      elseif r then
	 x = r - w
      else
	 x = (base.width - w) / 2
      end
   end

   self._frame = ui.rect(x or 0, y or 0, w or 0, h or 0):offset(base.x, base.y)
end

-- Generic relative layout constructor
---@param tab table
---@return    ui.tlrb_layout
function ui.rel(tab)
   return ui.tlrb_layout(tab.top,
			 tab.left,
			 tab.right,
			 tab.bottom,
			 tab.width,
			 tab.height,
			 tab.min_width,
			 tab.max_width,
			 tab.min_height,
			 tab.max_height)
end
