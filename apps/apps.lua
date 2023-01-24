local t = {}

-- Global apps tab
t.tab = {}

-- App utility functions
t.util = {}

-- Register app
---@param title string App name
---@param fn function(stack: stack) RPN Stack
function t.add(title, fn)
   local function wrap(...)
      return coroutine.wrap(fn)(...)
   end
   table.insert(t.tab, {title = title, fn = wrap})
end

return t
