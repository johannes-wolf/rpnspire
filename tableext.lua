-- Join table to string
---@param self table             Self
---@param separator string       Separator string
---@param transform_fn function  Transformation function (any) : string
---@return string
function table.join_str(self, separator, transform_fn)
   if not self then return '' end

   separator = separator or ' '
   local str = ''
   for idx, item in ipairs(self) do
      if idx > 1 then
         str = str .. separator
      end
      str = str .. (transform_fn and transform_fn(item) or tostring(item))
   end
   return str
end

function table.dump(self)
   if type(self) == "table" then
      local s = '{ '
      for k, v in pairs(self) do
         if type(k) ~= 'number' then k = '"' .. k .. '"' end
         s = s .. '[' .. k .. '] = ' .. table.dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(self)
   end
end

-- Deep copy table
---@param t table  Input table
---@return table
function table_clone(t)
   if type(t) ~= 'table' then return t end
   local meta = getmetatable(t)
   local target = {}
   for k, v in pairs(t) do
      if type(v) == 'table' then
         target[k] = table_clone(v)
      else
         target[k] = v
      end
   end
   setmetatable(target, meta)
   return target
end

-- Copy certain table fields
---@param source table   Source table
---@param fields table   List of field names to copy
---@param target? table  Target table
---@return table
function table_copy_fields(source, fields, target)
   target = target or {}
   for _, v in ipairs(fields) do
      if type(source[v]) == 'table' then
         target[v] = table_clone(source[v])
      else
         target[v] = source[v]
      end
   end
   return target
end

if not table.unpack then
   table.unpack = unpack
end
