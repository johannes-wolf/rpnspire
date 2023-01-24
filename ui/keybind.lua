local ui = require 'ui.shared'

---@class ui.keybindings
---@field root        table
---@field current_tab table
---@field current_seq table
local kbd = {}
kbd.__index = kbd

function ui.keybindings()
   return setmetatable({ root = {}, current_seq = {} }, kbd)
end

function kbd:set_seq(seq, action)
   local tab = self.root
   for idx, v in ipairs(seq) do
      if idx == #seq then
         break
      end
      if not tab[v] then
         tab[v] = {}
      end
      tab = tab[v]
   end
   tab[seq[#seq]] = action
end

function kbd:notify_seq_changed()
   if self.on_seq_changed then
      self.on_seq_changed(self.current_seq)
   end
end

function kbd:reset()
   self.current_tab = nil
   self.current_seq = {}
   self:notify_seq_changed()
end

function kbd:exec(tab)
   local fn = self.on_exec
   if type(tab) == 'function' then
      fn = tab
   end

   local res = 'reset'
   if fn then
      res = fn(self.current_seq, tab)
   end
   if not res or res == 'reset' then
      self:reset()
   end
end

function kbd:on_escape()
   if #self.current_seq > 0 then
      self:reset()
      return true
   end
   return false
end

function kbd:on_enter_key()
   self:on_char('enter')
end

function kbd:on_left()
   self:on_char('left')
end

function kbd:on_right()
   self:on_char('right')
end

function kbd:on_up()
   self:on_char('up')
end

function kbd:on_down()
   self:on_char('down')
end

function kbd:on_backspace()
   self:on_char('backspace')
end

function kbd:on_tab()
   self:on_char('tab')
end

function kbd:on_char(c)
   local tab = self.current_tab or self.root

   if c:find('^%d$') then
      table.insert(self.current_seq, tonumber(c))
      tab = tab['%d'] or tab[c]
   else
      table.insert(self.current_seq, c)
      tab = tab[c]
   end

   if tab then
      if type(tab) == 'table' then
         self.current_tab = tab
         self:notify_seq_changed()
      else
         self:exec(tab)
         self:reset()
      end
      return true
   end

   self:reset()
   return false
end
