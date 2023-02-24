local expr  = require 'expressiontree'

---@class matrix # Matrix helper class
local matrix = { mt = {} }
matrix.mt.__index = matrix.mt

function matrix.new(m, n)
   return setmetatable({m = m or 0, n = n or 0}, matrix.mt)
end

function matrix.mt:__len()
   return self.m
end

-- Set from ti matrix
---@param mat expr Matrix
function matrix.mt:from_expr(mat)
   self:resize(0, 0)
   if mat:isa(expr.MATRIX) then
      for m, row in ipairs(mat.children or {}) do
         if row:isa(expr.MATRIX) then
            for n, col in ipairs(row.children or {}) do
               self:set(m, n, col:infix_string())
            end
         else
            -- [x,y,z] -> [[x,y,z]]
            self:set(1, m, row:infix_string())
         end
      end
   end
   return self
end

-- Return as ti matrix
---@param zero? expr Zero expression
function matrix.mt:to_expr(zero)
   zero = zero or expr.num(0)

   local rows = {}
   for i = 1, self.m do
      local row = {}
      for j = 1, self.n do
         local v = self:get(i, j)
         if type(v) == 'string' then
            table.insert(row, expr.from_string(v))
         elseif type(v) == 'number' then
            table.insert(row, expr.num(v))
         elseif expr.is_expr(v) then
            table.insert(row, v)
         else
            table.insert(row, zero)
         end
      end
      table.insert(rows, expr.matrix(row))
   end

   return expr.matrix(rows)
end

-- Set values from list with column size n
---@param lst expr Any expression
---@param n? number Columns
function matrix.mt:from_list(lst, n)
   n = n or 1
   self:resize(0, 0)
   if not lst or not lst.children or #lst.children == 0 then
      return self
   end

   self:resize(math.floor(#lst.children / n) + 1, n)
   for i, item in ipairs(lst.children) do
      self:set(math.floor((i - 1) / n + 1), (i - 1) % n + 1, item:infix_string())
   end
   return self
end

-- Store cells as flat list
---@param zero? expr Zero expression
---@return expr
function matrix.mt:to_list(zero)
   zero = zero or expr.num(0)

   local items = {}
   for i = 1, self.m do
      for j = 1, self.n do
         local v = self:get(i, j)
         if type(v) == 'string' then
            table.insert(items, expr.from_string(v))
         elseif type(v) == 'number' then
            table.insert(items, expr.num(v))
         elseif expr.is_expr(v) then
            table.insert(items, v)
         else
            table.insert(items, zero)
         end
      end
   end

   return expr.list(items)
end

-- Transpose data
function matrix.mt:transpose()
   for j = 1, self.n do
      for i = 1, self.m do
         local tmp = self:get(i, j)
         self:set(i, j, self:get(j, i))
         self:set(j, i, tmp)
      end
   end
   self.m, self.n = self.n, self.m
   return self
end

-- Determine matrix size
---@return number Rows
---@return number Columns
function matrix.mt:size()
   return self.m, self.n
end

-- Resize matrix to m, n
---@param m number
---@param n number
function matrix.mt:resize(m, n)
   if m < self.m then
      for i = m + 1, self.m, 1 do
         self[i] = nil
      end
   end
   if n < self.n then
      for i = 1, self.m do
         if self[i] then
            for j = n + 1, self.n, 1 do
               self[i][j] = nil
            end
         end
      end
   end

   self.m = m
   self.n = n
   return self
end

-- Fill vaules with %value up to m, n
---@param m number|nil       Row count (or self.m)
---@param n number|nil       Column count (or self.n)
---@param value any          Value to set
---@param overwrite? boolean Overwrite existing values
function matrix.mt:fill(m, n, value, overwrite)
   m = m or self.m
   n = n or self.n
   for i = 1, m do
      for j = 1, n do
         self[i] = self[i] or {}
         self[i][j] = (overwrite and value) or self[i][j] or value
      end
   end
end

function matrix.mt:clear()
   for _, row in ipairs(self.data) do
      for i = 1, #row do
         row[i] = nil
      end
   end
end

-- Set value at m, n
---@param m number
---@param n number
---@param value any
function matrix.mt:set(m, n, value)
   self[m] = self[m] or {}
   self[m][n] = value
   self:resize(math.max(m, self.m), math.max(n, self.n))
end

-- Get value at m, n
---@return any
function matrix.mt:get(m, n)
   return self[m] and self[m][n]
end

return matrix
