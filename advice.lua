local m = {}

function m.before(old, new)
   return function(...)
      new(...)
      return old(...)
   end
end

function m.after(old, new)
   return function(...)
      local r = old(...)
      new(...)
      return r
   end
end

function m.around(old, new)
   return function(...)
      return new(old, ...)
   end
end

function m.arguments(old, new)
   return function(...)
      return old(new(...))
   end
end

function m.result(old, new)
   return function(...)
      return new(old(...))
   end
end

return m
