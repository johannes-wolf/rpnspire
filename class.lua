return function(base)
  local classdef = {}

  setmetatable(classdef, {
    __index = base,
    __call = function(_, ...)
      local inst = {
        class = classdef,
        super = base or nil
      }
      setmetatable(inst, {__index = classdef})
      if inst.init then
        inst:init(...)
      end
      return inst
    end})

  return classdef
end
