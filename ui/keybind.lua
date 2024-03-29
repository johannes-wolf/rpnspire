local ui = require 'ui.shared'

---@alias sequence_table table<string, any|function>

---@class ui.keybindings
---@field seq table # Current sequence
---@field on_seq function(self) # Try sequences
---@field on_exec function(any) # Execute callback for non function actions
local kbd = {}
kbd.__index = kbd

function ui.keybindings()
   return setmetatable({ seq = {} }, kbd)
end

-- Try call current sequence in tab
-- Example:
--   try_call({'.', {'a', function() ... end}})
--     or
--   try_call({'.', {'a', { function() ... end, 'description'} }})
---@param tab sequence_table Sequence table
---@return any|nil Matched action or nil
function kbd:try_call_table(tab)
   local t = tab or {}
   for i, v in ipairs(self.seq) do
      local at_end = i == #self.seq
      if not t or type(t) ~= 'table' then
         return nil
      end
      if t[v] or (v:find('^[0-9]+$') and t['%d']) then
         t = t[v] or t['%d']
         if at_end then
            return self:exec(t)
         end
      end
   end
end

function kbd:reset()
   self.seq = {}
end

function kbd:exec(tab)
   -- Binding tables can contain { fn, description-string }
   if type(tab) == 'table' and type(tab[1]) == 'function' then
      tab = tab[1]
   end

   if type(tab) == 'function' then
      tab(self.seq)
      self:reset()
      return true
   end
   return tab
end

function kbd:on_return()
   return self:on_char('return')
end

function kbd:on_escape()
   if #self.seq > 0 then
      self:reset()
      return true
   end
   return false
end

function kbd:on_enter_key()
   return self:on_char('enter')
end

function kbd:on_left()
   return self:on_char('left')
end

function kbd:on_right()
   return self:on_char('right')
end

function kbd:on_up()
   return self:on_char('up')
end

function kbd:on_down()
   return self:on_char('down')
end

function kbd:on_backspace()
   return self:on_char('backspace')
end

function kbd:on_tab()
   return self:on_char('tab')
end

function kbd:on_char(c)
   if self.on_seq then
      table.insert(self.seq, tostring(c))
      if self:on_seq() then
         return true
      end
      self:reset()
   end

   return false
end
