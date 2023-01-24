local class = require 'class'
local ui = require 'ui'

---@class ui.container : ui.view
---@field style      nil|'2D'|'3D'
---@field background number  Color
---@field border     number  Color
ui.container = class(ui.view)

function ui.container:init(layout)
   ui.view.init(self, layout)
   self.clip = true
end

function ui.container:draw_self(gc, dirty)
   if self.style == 'none' then return end

   local r = self:frame()
   if self.style == '2D' then
      ui.fill_rect(gc, r, self.background)
      ui.frame_rect(gc, r, self.border)
   elseif self.style == '3D' then
      ui.fill_rect(gc, r, self.background)
      local inner = r:clone():inset(-1, -1):offset(-1, -1)
      ui.fill_rect(gc, inner, self.border)
   else
      ui.fill_rect(gc, r, self.background)
   end
end
