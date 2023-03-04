local class = require 'class'
local ui    = require 'ui.shared'
local expr  = require 'expressiontree'
local operators  = require 'ti.operators'

local function inherit_attribs(parent, child)
   if not parent then return end
   child.font_size = parent.font_size or child.font_size
   child.font_style = parent.font_style or child.font_style
end

local text_node = class()
text_node.normal = 14 -- Normal font size
text_node.small = 9   -- Small font size

function text_node:init(text, font_size)
   self.text = text
   self.font_size = font_size or text_node.normal
end

function text_node:inherit(parent)
   inherit_attribs(parent, self)
   self.size = nil
end

function text_node:meassure()
   if not self.size then
      self.size = ui.point(ui.GC.text_size(self.text, self.font_size))
      self.baseline = self.size.y
   end
   return self.size
end

function text_node:draw(gc, x, y)
   local size = self:meassure()
   local f = ui.rect(x, y, size.x, size.y)
   gc:set_font_size(self.font_size)
   gc:draw_text(self.text, f.x, f.y, f.width, f.height, 0, 0, 0)
end

local super_node = class()
function super_node:init(base, super)
   self.base = base
   self.super = super
end

function super_node:inherit(parent)
   inherit_attribs(parent, self)
   self.base:inherit(self)
   inherit_attribs(self, self.super)
   self.super.font_size = text_node.small
   self.super:inherit()
   self.size = nil
end

function super_node:meassure()
   if not self.size then
      self.super_size = self.super:meassure()
      self.base_size = self.base:meassure()
      self.size = ui.point(self.base_size.x + self.super_size.x - 0,
                           self.base_size.y + self.super_size.y - 4)
      self.baseline = self.size.y
   end
   return self.size
end

function super_node:draw(gc, x, y)
   local size = self:meassure()
   local frame = ui.rect(x, y, size.x, size.y)

   local base_frame = frame:aligned_rect('bottom', 'left', self.base_size.x, self.base_size.y)
   self.base:draw(gc, base_frame.x, base_frame.y)

   local super_frame = frame:aligned_rect('top', 'right', self.super_size.x, self.super_size.y)
   self.super:draw(gc, super_frame.x, super_frame.y)
end

local fraction_node = class()
function fraction_node:init(num, denom)
   self.num = num
   self.denom = denom
end

function fraction_node:inherit(parent)
   inherit_attribs(parent, self)
   self.num:inherit(self)
   self.denom:inherit(self)
   self.size = nil
end

function fraction_node:meassure()
   if not self.size then
      self.num_size = self.num:meassure()
      self.denom_size = self.denom:meassure()
      self.size = ui.point(math.max(self.num_size.x, self.denom_size.x) + 4,
                           self.num_size.y + self.denom_size.y)

      local a_height = select(2, ui.GC.text_size('1', self.font_size or text_node.normal))
      self.baseline = self.num_size.y + a_height/2
      self.barline = self.baseline - a_height/2
   end
   return self.size
end

function fraction_node:draw(gc, x, y)
   local size = self:meassure()
   local frame = ui.rect(x, y, size.x, size.y)

   gc:draw_line(frame.x + 1, frame.y + self.barline, frame:max_x() - 1, frame.y + self.barline, 0)

   local num_frame = frame:aligned_rect('top', 'center', self.num_size.x, self.num_size.y)
   self.num:draw(gc, num_frame.x, num_frame.y)

   local denom_frame = frame:aligned_rect('bottom', 'center', self.denom_size.x, self.denom_size.y)
   self.denom:draw(gc, denom_frame.x, denom_frame.y)
end

local row_node = class()

row_node.left_paren = {
   width = 3
}
function row_node.left_paren.draw(gc, x, y, w, h)
   local sh = 3
   local lx, rx = x, x + w
   local ty, by = y + sh, y + h - sh

   gc:draw_line(lx, ty, rx, y)
   gc:draw_line(lx, ty, lx, by)
   gc:draw_line(lx, by, rx, y+h)
end

row_node.right_paren = {
   width = 3
}
function row_node.right_paren.draw(gc, x, y, w, h)
   row_node.left_paren.draw(gc, x+w, y, -w, h)
end

function row_node:init(nodes, left, right)
   self.nodes = nodes or {}
   self.left = left
   self.right = right
end

function row_node:inherit(parent)
   inherit_attribs(parent, self)
   for _, v in ipairs(self.nodes) do
      v:inherit(self)
   end
   self.size = nil
end

function row_node:meassure()
   if not self.size then
      self.size = ui.point(0, 0)
      self.baseline = 1

      if self.left then
         self.size.x = self.size.x + self.left.width
      end

      if self.right then
         self.size.x = self.size.x + self.right.width
      end

      for _, v in ipairs(self.nodes) do
         local node_size = v:meassure()
         self.size.x = self.size.x + node_size.x
         self.size.y = math.max(self.size.y, node_size.y)
         self.baseline = math.max(self.baseline, v.baseline or node_size.y)
      end
   end
   return self.size
end

function row_node:draw(gc, x, y)
   local size = self:meassure()
   local frame = ui.rect(x, y, size.x, size.y)
   local base_frame = frame:aligned_rect('top', 'left', size.x, self.baseline)

   if self.left then
      self.left.draw(gc, x, y, self.left.width, size.y)
      base_frame.x = base_frame.x + self.left.width
   end

   for _, v in ipairs(self.nodes) do
      local sub_size = v:meassure()
      local sub_frame = base_frame:aligned_rect('bottom', 'left', sub_size.x, v.baseline)

      v:draw(gc, sub_frame.x, sub_frame.y)

      base_frame.x = sub_frame:max_x()
   end

   if self.right then
      self.right.draw(gc, base_frame.x, y, self.right.width, size.y)
      base_frame.x = base_frame.x + self.right.width
   end
end


local function build_view_hirarchy(e)
   if not e then return text_node('nil') end

   local function child(idx)
      return build_view_hirarchy(e.children[idx])
   end

   local function children()
      local list = {}
      for _, v in ipairs(e.children) do
         table.insert(list, build_view_hirarchy(v))
      end
      return list
   end

   local view
   if e.kind == expr.OPERATOR then
      if e.text == '/' then
         return fraction_node(child(1), child(2))
      elseif e.text == '^' then
         return super_node(child(1), child(2))
      end

      local name, prec, _, side, assoc, aggr_assoc = operators.query_info(e.text)
      assoc = assoc == 'r' and 2 or (assoc == 'l' and 1 or 0)

      local row = {}
      for idx, operand in ipairs(e.children or {}) do
         if #row > 0 and side == 0 then
            table.insert(row, text_node(name))
         end

         if operand.kind == expr.OPERATOR then
            local _, operand_prec = operators.query_info(operand.text)
            if (operand_prec < prec) or
                ((aggr_assoc or idx ~= assoc) and operand_prec < prec + (assoc ~= 0 and 1 or 0)) then
               table.insert(row, row_node({build_view_hirarchy(operand)}, row_node.left_paren, row_node.right_paren))
            else
               table.insert(row, build_view_hirarchy(operand))
            end
         else
            table.insert(row, build_view_hirarchy(operand))
         end
      end

      if side < 0 then
         table.insert(row, 1, text_node(name))
      end
      if side > 0 then
         table.insert(row, text_node(name))
      end
      return row_node(row)
   elseif e.kind == expr.FUNCTION or e.kind == expr.FUNCTION_STAT then
      view = row_node({text_node(e.text), row_node(children(), row_node.left_paren, row_node.right_paren)})
   end

   if not view then
      view = text_node(e.text)
   end

   for _, v in ipairs(e.children or {}) do
      view.children = view.children or {}
      table.insert(view.children, build_view_hirarchy(v))
   end

   return view
end

---@class ui.expression : ui.view
ui.expression = class(ui.view)

function ui.expression:init(layout)
   ui.view.init(self, layout)

   self:set_expression(expr.from_string('x/y^2+1'))
end

function ui.expression:set_expression(e)
   if type(e) == 'string' then
      local ok, res = pcall(function()
            return expr.from_string(e)
      end)
      e = ok and res
   end
   self.e = e
   self.nodes = build_view_hirarchy(self.e)
   self.nodes:inherit(nil)
end

function ui.expression:draw_self(gc)
   if not self.nodes then return end

   local frame = self:frame()
   self.nodes:draw(gc, frame.x, frame.y)
end
