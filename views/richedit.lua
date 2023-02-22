local class = require 'class'
local ui = require 'ui.shared'

---@class RichEdit

---@class ui.label : ui.view
---@field editor RichEdit
ui.richedit = class(ui.view)

-- Initializer
---@param layout ui.layout
function ui.richedit:init(layout)
   ui.view.init(self, layout)
   self.editor = D2Editor.newRichText()
   self.editor:setReadOnly(true):setBorder(0):setVisible(false)
end

function ui.richedit:set_expression(text)
   self.editor:createMathBox():setExpression(text)
end

function ui.richedit:add_child(...)
   assert(false)
end

function ui.richedit:layout_children(parent_frame)
   ui.view.layout_children(self, parent_frame)

   local f = self:frame()
   self.editor:move(f.x, f.y):resize(f.width, f.height)
end

function ui.richedit:on_enter()
   self.editor:setFocus(true):setVisible(true)
end

function ui.richedit:on_exit()
   self.editor:setFocus(false):setVisible(false)
end
