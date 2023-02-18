local class = require 'class'
local ui = require 'ui'
local sym = require 'ti.sym'
local bindings = require 'config.bindings'

---@class ui.edit : ui.view
---@field on_complete function(ui.edit, string) : list<list<string>>
---@field on_complete_done function(ui.edit, string)
ui.edit = class(ui.view)
ui.edit.paren_pairs = {
   ['('] = ')',
   ['{'] = '}',
   ['['] = ']',
   ['"'] = '"',
}

ui.edit.closing_parens = {}
for k, v in pairs(ui.edit.paren_pairs) do
   ui.edit.closing_parens[v] = k
end

local function special_char_menu(edit)
   local chars = {
      { title = '[', hint = 'lbracket (' },
      { title = ']', hint = 'rbracket )' },
      { title = '{', hint = 'lbrace (' },
      { title = '}', hint = 'rbrace )' },
      { title = '|', hint = 'pipe with' },
      { title = sym.INFTY, hint = 'infinity infty' },
      { title = sym.CONVERT, hint = 'convert to as' },
      { title = sym.NEQ, hint = 'neq not equal' },
      { title = '<', hint = 'lt less' },
      { title = sym.LEQ, hint = 'leq less equal' },
      { title = '>', hint = 'gt greater' },
      { title = sym.GEQ, hint = 'geq greater equal' },
      { title = '!', hint = 'exclamation factorial' },
   }

   local m = ui.menu.menu_at_point(edit, chars)
   m.autoexec = true
   m.on_exec = function(_, item)
      edit:insert_text(item.title)
   end
end

-- Initializer
---@param layout ui.layout
function ui.edit:init(layout)
   ui.view.init(self, layout)
   self.text = ""
   self.cursor = 1
   self.selection = 0

   self.kbd = {
      [bindings.leader] = {
         ['%d'] = function(seq)
            self:insert_text('.' .. tostring(seq[#seq]), false)
         end,
         ['c'] = function()
            special_char_menu(self)
         end,
      },
   }
   if bindings.edit then
      bindings.edit(self, self.kbd)
   end
end

-- Set view text
---@param text string
function ui.edit:set_text(text)
   self.text = text or ""
   self:set_cursor('end')
end

-- Get view text
---@return string
function ui.edit:get_text()
   return self.text_left .. self.text_right
end

-- Returns if the cursor is at the rightmost position
---@return boolean
function ui.edit:is_cursor_at_end()
   return self.cursor > self.text:ulen()
end

-- Set cursor (and selection)
---@param pos  number|'end'|'left'|'right'  Position
---@param sel? number|'all'                 Selection size
function ui.edit:set_cursor(pos, sel)
   pos = pos or 'end'
   if pos == 'left' then
      if self.selection > 0 then
         pos = self.cursor
      else
         pos = self.cursor - 1
      end
   elseif pos == 'right' then
      if self.selection > 0 then
         pos = self.cursor + self.selection
      else
         pos = self.cursor + 1
      end
   elseif pos == 'end' then
      pos = self.text:ulen() + 1
   end

   self.cursor = math.min(math.max(pos, 1), self.text:ulen() + 1)

   if sel == 'all' then
      self.selection = self.text:ulen() - self.cursor + 1
   end

   self.selection = sel or 0
   if self.selection < 0 then
      self.cursor = self.cursor + self.selection
      self.selection = -1 * self.selection
   end

   self:ensure_visible(self:frame():clone():inset(ui.style.padding), self:cursor_frame())
end

-- Returns text as left|selection|right
---@return string, string, string
function ui.edit:split_text()
   if not self.text then return '', '', '' end

   local c = self.cursor - 1
   return string.usub(self.text, 1, c),
       string.usub(self.text, c + 1, self.selection + c),
       string.usub(self.text, c + 1 + self.selection)
end

-- Returns the cursors frame
---@return ui.rect
function ui.edit:cursor_frame(gc)
   if not gc then
      return ui.GC.with_gc(function(gc)
         return self:cursor_frame(gc)
      end)
   end

   local r = self:frame():clone():inset(ui.style.padding)
   local left, mid, right = self:split_text()
   local cx = gc:text_width(left) + r.x
   local sx = self.scroll.x

   local block_width = 2
   if #right > 0 or #mid > 0 then
      local char_width
      if #mid > 0 then
         char_width = gc:text_width(mid)
      else
         char_width = gc:text_width(right:usub(1, 1))
      end
      block_width = char_width
   end

   return ui.rect(cx + sx, r.y, block_width, r.height)
end

function ui.edit:draw_cursor(gc)
   local r = self:cursor_frame(gc)
   gc:draw_rect(r.x, r.y, r.width, r.height,
                nil, ui.get_focus() == self and ui.style.caret or ui.style.caret_inactive)
end

function ui.edit:draw_self(gc, dirty)
   local r = self:frame()

   local b = r:clone():inset(ui.style.padding, 0)
   local x, y, w, h = b.x, b.y, b.width, b.height

   ui.fill_rect(gc, r)
   self:draw_cursor(gc)

   local tx, ty = x + self.scroll.x, y --+ self.scroll.y
   local left, mid, right = self:split_text()
   tx = select(2, gc:draw_text(left, tx, ty, w, h, nil, 0, ui.style.text))
   tx = select(2, gc:draw_text(mid, tx, ty, w, h, nil, 0, ui.style.text))
   tx = select(2, gc:draw_text(right, tx, ty, w, h, nil, 0, ui.style.text))

   ui.frame_rect(gc, r)
end

-- Insert text
---@param text string   Text to insert at the current cursor position
---@param sel  boolean  Select inserted text
function ui.edit:insert_text(text, sel)
   local left, mid, right = self:split_text()

   local closing_paren = ui.edit.paren_pairs[text]
   if closing_paren then
      if mid and #mid > 0 then
         mid = text .. mid .. closing_paren
      else
         mid = text .. closing_paren
      end
   elseif #right > 0 and ui.edit.closing_parens[text] and text == right:usub(1, 1) then
      mid = ""
   else
      mid = text or ""
   end

   self.text = left .. mid .. right
   if sel then
      self.selection = sel and mid:ulen() or 0
   else
      self:set_cursor(self.cursor + text:ulen())
   end
end

function ui.edit:on_backspace()
   local left, mid, right = self:split_text()
   if mid and #mid > 0 then
      mid = ""
      self:set_cursor(self.cursor)
   else
      local closing_paren = ui.edit.paren_pairs[left:usub(-1)]
      if closing_paren then
         if right and #right and right:usub(1, 1) == closing_paren then
            right = right:usub(2)
         end
      end

      left = left:usub(1, left:ulen() - 1)
      self:set_cursor(math.max(self.cursor - 1, 1))
   end

   self.text = left .. mid .. right
end

function ui.edit:on_char(c)
   self:insert_text(c, false)
end

function ui.edit:on_left()
   self:set_cursor('left')
end

function ui.edit:on_right()
   self:set_cursor('right')
end

function ui.edit:on_up()
   self:set_cursor(1)
end

function ui.edit:on_down()
   self:set_cursor('end')
end

function ui.edit:on_clear()
   self:set_text('')
end

function ui.edit:on_tab()
   if self.selection > 0 then
      self:set_cursor('right')
   else
      self:try_complete(select(1, self:split_text()))
   end
end

function ui.edit:on_cut()
   -- luacheck: ignore clipboard
   clipboard.addText(self.text)
   self:set_text('')
end

function ui.edit:on_copy()
   -- luacheck: ignore clipboard
   clipboard.addText(self.text)
end

function ui.edit:on_paste()
   -- luacheck: ignore clipboard
   self:insert_text(clipboard.getText(), true)
end

function ui.edit:try_complete(word)
   -- Apply configured snippets
   local config = require 'config.config'
   for k, v in pairs(config.snippets or {}) do
      local i, j = word:find(k..'$')
      if i then
         local left, right = self.text:sub(1, i - 1), self.text:sub(j + 1)
         self.text = left .. v
         self.cursor = self.text:ulen() + 1
         self.text = self.text .. right
         return
      end
   end

   local list = {}
   if self.on_complete then
      list = self:on_complete(word)
   end

   if #list == 1 then
      if type(list[1] == 'table') then
         self:insert_text(list[1][2], true)
      else
         self:insert_text(list[1], true)
      end
   elseif #list > 1 then
      self:complete_via_menu(list)
   end
end

function ui.edit:complete_via_menu(l)
   local items = {}
   for _, v in ipairs(l) do
      if type(v) == 'table' then
         table.insert(items, { title = v[1], action = v[2], replace = v.replace })
      else
         table.insert(items, { title = v, action = v })
      end
   end

   local cursor_frame = self:cursor_frame()
   local menu = ui.menu.menu_at_point(self, items, ui.point(cursor_frame.x, cursor_frame.y))

   menu.autoexec = true
   menu.filter_mode = 'fuzzy'
   menu.on_exec = function(menu, item)
      self:insert_text(item.action, true)
      if self.on_complete_done then
         self:on_complete_done(item.title, item.action)
      end
      menu:close('recurse')
   end
   menu.on_backspace = function(this)
      this:close('recurse')
   end
end
