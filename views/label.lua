local class = require 'class'
local ui = require 'ui'

---@class ui.label : ui.view
---@field text  string
---@field foreground number
---@field background number
---@field align -1|0|1
ui.label = class(ui.view)

-- Initializer
---@param layout ui.layout
function ui.label:init(layout)
   ui.view.init(self, layout)
   self.text = ""
   self.align = 0
end

-- Returns the min/optimal size of the label
---@return ui.point  Optimal size
function ui.label:min_size()
   local x, y = ui.GC.with_gc(function(gc)
      return gc:text_width(self.text), gc:text_height(self.text)
   end)
   return ui.point(x, y)
end

function ui.label:draw_self(gc, _)
   local r = self:frame()
   if self.background then
      ui.fill_rect(gc, r, self.background)
   end
   gc:draw_text(self.text, r.x, r.y, r.width, r.height, self.align, 0,
		self.foreground or ui.style.text)
end
