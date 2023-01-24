-- Returns the number of utf-8 codepoints in string
---@param str string
---@return number
function string.ulen(str)
   return select(2, str:gsub('[^\128-\193]', ''))
end
