local class = require 'class'
local ui = require 'ui.shared'
local geom = require 'ui.geometry'

---@class ui.GC
local GC = class()

local a_height = {}

function GC.screen_width()
   return platform.window:width()
end

function GC.screen_height()
   return platform.window:height()
end

function GC.a_height(s)
   s = s or 11
   local h = a_height[s]
   if not h then
      h = platform.withGC(function(gc)
	 gc:setFont('sansserif', 'r', s)
	 return gc:getStringHeight('A')
      end)
      a_height[s] = h
   end
   return h
end

function GC.with_gc(fn)
   return platform.withGC(function(gc)
      return fn(ui.GC(gc))
   end)
end

function GC:init(gc, offx, offy)
   self.gc = gc
   self.clip = ui.rect(0, 0, GC.screen_width(), GC.screen_height())
   self.offset = {x = offx or 0, y = offy or 0}
end

function GC:push_clip(r)
   assert(r)
   r = self.clip:intersection_rect(r)
   self.gc:clipRect('set', r.x, r.y, r.width + 1, r.height + 1)
   self.sub_clip = r
end

function GC:reset_clip()
   local r = self.sub_clip or self.clip
   if r then
      self.gc:clipRect('set', r.x, r.y, r.width + 1, r.height + 1)
   else
      self.gc:clipRect('reset')
   end
end

function GC:clip_rect(r)
   self.clip = r or self.clip
   if r then
      self.gc:clipRect('set', r.x, r.y, r.width + 1, r.height + 1)
   else
      self.gc:clipRect('reset')
   end
   return self.clip
end

function GC:xy(x, y)
   return (x or 0) + self.offset.x,
          (y or 0) + self.offset.y
end

function GC:sub(offx, offy)
   local gc = GC(self.gc, offx, offy)
   gc.clip = (self.sub_clip or self.clip):clone()
   gc.offset.x = gc.offset.x + self.offset.x
   gc.offset.y = gc.offset.y + self.offset.y
   return gc
end

function GC:set_color(c)
   self.gc:setColorRGB(c or 0)
end

-- Draw rectangle
---@param stroke number?  Stroke color
---@param fill   number?  Fill color
function GC:draw_rect(x, y, w, h, stroke, fill)
   x, y = self:xy(x, y)
   if fill then
      self.gc:setColorRGB(fill)
      self.gc:fillRect(x, y, w, h)
   end
   if stroke then
      self.gc:setColorRGB(stroke)
      self.gc:drawRect(x, y, w, h)
   end
end

function GC:draw_line(x, y, x2, y2, color)
   self.gc:setColorRGB(color or 0)
   self.gc:drawLine(x, y, x2, y2)
end

function GC:text_width(text)
   return text and self.gc:getStringWidth(text) or 0
end

function GC:text_height(text)
   return text and self.gc:getStringHeight(text) or 0
end

function GC:set_font_size(s)
   self.gc:setFont('sansserif', 'r', s or 11)
end

function GC:draw_text(text, x, y, w, h, halign, valign, color)
  halign = halign or -1
  valign = valign or -1
  x, y = self:xy(x, y)
  if h and halign >= 0 then
    local text_w = self.gc:getStringWidth(text)
    if halign == 0 then
      x = x + w/2 - text_w/2
    else
      x = x + w - text_w
    end
  end
  if w and valign >= 0 then
    local text_h = self.gc:getStringHeight(text)
    if valign == 0 then
      y = y + h/2 - text_h/2
    else
      y = y + h - text_h
    end
  end
  if color then
     self.gc:setColorRGB(color)
  end
  return x, self.gc:drawString(text, x, y), y
end

ui.GC = GC
