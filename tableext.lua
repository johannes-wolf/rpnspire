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

if not table.unpack then
   table.unpack = unpack
end
