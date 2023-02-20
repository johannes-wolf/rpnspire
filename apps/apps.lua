local t = {}

-- Global apps tab
t.tab = {}

-- App utility functions
t.util = {}

-- Register app
---@param title string App name
---@param description string Descriptive text
---@param fn function(stack: stack) RPN Stack
function t.add(title, description, fn)
   local function wrap(...)
      return coroutine.wrap(fn)(...)
   end
   assert(title)
   table.insert(t.tab, {title = title, description = description or '', fn = wrap})
end

return t
