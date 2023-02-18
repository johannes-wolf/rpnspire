local ui = require 'ui.shared'

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


---@class ui.layout # Layout base
---@field update function(base : ui.rect, view : ui.view)
---@field frame function() : ui.rect

---@class ui.relative_layout : ui.layout
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
local relative_layout = {}
relative_layout.__index = relative_layout

function ui.relative_layout(t, l, r, b, w, h, minw, maxw, minh, maxh)
   local res = setmetatable({}, relative_layout)
   res.t, res.t_rel = parse_percentage_string(t)
   res.l, res.l_rel = parse_percentage_string(l)
   res.b, res.b_rel = parse_percentage_string(b)
   res.r, res.r_rel = parse_percentage_string(r)
   res.w, res.w_rel = parse_percentage_string(w)
   res.h, res.h_rel = parse_percentage_string(h)
   res.min_w = minw or 0
   res.max_w = maxw
   res.min_h = minh or 0
   res.max_h = maxh
   return res
end

function relative_layout:frame()
   return self._frame or ui.rect(0, 0, 0, 0)
end

function relative_layout:update(base, view)
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
---@return    ui.relative_layout
function ui.rel(tab)
   return ui.relative_layout(tab.top,
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
