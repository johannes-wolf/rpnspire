local sym = require "ti.sym"
local lexer = require "ti.lexer"
local operators = require "ti.operators"
local functions = require "ti.functions"
local expr = require "expressiontree"
local config = require "config.config"
local stack = {}

---@param str string
---@return expr
local function parse_inifix(str)
   str = str or '0'
   local tokens = lexer.tokenize(str) or error { desc = "Tokenizing input" }
   return expr.from_infix(tokens) or error { desc = "Parsing input" }
end

---@class rpn_stack_node
---@field rpn expr           # Input expression
---@field infix string       # Input infix string
---@field result string|nil  # Result infix string
local rpn_stack_node = {}
rpn_stack_node.__index = rpn_stack_node

-- Parse infix output and return expression tree
---@return expr
function rpn_stack_node:result_expr()
   return parse_inifix(self.result)
end

-- Return input expression
---@reutrn expr
function rpn_stack_node:input_expr()
   return self.rpn
end

-- Deep copy self
---@return rpn_stack_node
function rpn_stack_node:clone()
   return setmetatable({ rpn = self.rpn:clone(), infix = self.infix, result = self.result }, rpn_stack_node)
end

-- Reevaluate nodes expr and update infix and result
---@param s rpn_stack Owning stack
function rpn_stack_node:eval(s)
   local infix = self.rpn:infix_string()
   local res, _ = s:eval_str(infix)
   if res then
      self.infix = infix
      self.result = res
      return true
   end
end

---@class rpn_stack
---@field stack     rpn_stack_node[]
---@field on_change function(stack: rpn_stack, range: {low, high})
local rpn_stack = {}
rpn_stack.__index = rpn_stack

-- RPN Stack constructor
---@return rpn_stack
function stack.new()
   return setmetatable({ stack = {} }, rpn_stack)
end

-- Deep clone self
---@return rpn_stack
function rpn_stack:clone()
   local nodes = {}
   for _, v in ipairs(self.stack) do
      table.insert(nodes, v:clone())
   end
   return setmetatable({stack = nodes, on_change = self.on_change}, rpn_stack)
end

-- Evaluate (infix) string
---@param str string
function rpn_stack:eval_str(str)
   local res, err = math.evalStr(str)
   if res and not err then
      local ok, res2 = pcall(function()
         local expr = parse_inifix(res)
         return expr and expr:infix_string()
      end)
      if ok then
         res = res2 or res
      end
   end

   -- Ignore unknown-function errors (for allowing to define functions in RPN mode)
   if err and err == 750 then
      return str, nil
   end
   if err and err ~= 750 then
      error { code = err }
   end
   return res, err
end

-- Return top stack entry
---@param n? number Index (< 0 means from top, > 0 from bottom)
---@return rpn_stack_node|nil
function rpn_stack:top(n)
   n = n or 0
   return self.stack[n <= 0 and #self.stack + n or n]
end

-- Pop entries from the stack
---@param n number?  Number of entries to pop
---@return expr[]
function rpn_stack:pop_n(n)
   assert(n and n > 0)

   local nodes = {}
   local old_len = #self.stack
   local new_len = #self.stack - n + 1

   for _ = 1, n do
      local root = self:pop(new_len).rpn
      if not root then
         error({ desc = 'Too few items on stack' })
      end

      table.insert(nodes, root)
   end

   if self.on_change then
      self:on_change({ old_len, new_len })
   end
   return nodes
end

-- Pop single item
---@param idx? number
---@param from_top? boolean
---@return rpn_stack_node|nil
function rpn_stack:pop(idx, from_top)
   if from_top then
      idx = (#self.stack - idx + 1) or #self.stack
   else
      idx = idx or #self.stack
   end
   if idx <= 0 or idx > #self.stack then return end
   local v = table.remove(self.stack, idx)
   if self.on_change then
      self:on_change({ idx, idx })
   end
   return v
end

---@param tab rpn_stack_node
function rpn_stack:reeval_infix(tab)
   local tokens = lexer.tokenize(tab.infix)
   if not tokens or #tokens == 0 then
      error({ desc = 'Parsing infix expression' })
   end

   local expr = expr.from_infix(tokens)
   if not expr then
      error({ desc = 'Building expression' })
   end

   local infix = expr:infix_string()
   local res, err = self:eval_str(infix)
   if res then
      tab.rpn = expr
      tab.infix = infix
      tab.result = res or err
   end

   if self.on_change then
      self:on_change()
   end
end

---@param tab rpn_stack_node
function rpn_stack:_push(tab)
   assert(tab and getmetatable(tab) == rpn_stack_node)
   table.insert(self.stack, tab)
   if self.on_change then
      self:on_change({ #self.stack, #self.stack })
   end
   return tab
end

---@param expr expr
function rpn_stack:push_expr(expr)
   assert(expr)

   local infix = expr:infix_string()
   local res, err = self:eval_str(infix)
   if res then
      return self:_push(setmetatable({ rpn = expr, infix = infix, result = res or err }, rpn_stack_node))
   end
end

---@param str string
function rpn_stack:push_infix(str)
   return self:push_expr(parse_inifix(str))
end

function rpn_stack:assert_size(n, operation)
   if #self.stack < (n or 1) then
      error { desc = string.format("%sToo few arguments", operation and (operation .. ': ')) }
   end
end

function rpn_stack:notify_change(range_begin, range_end)
   if self.on_change then
      range_begin = range_begin or 0
      if range_begin <= 0 then
         range_begin = #self.stack + range_begin
      end
      self:on_change({ range_begin, range_end or range_begin or #self.stack })
   end
end

--[[ OPERATOR HANDLING ]] --

-- Push and evaluate operator
---@param str string Operator name
---@param argc? number Operator agument count
function rpn_stack:push_operator(str, argc)
   local special = {
      [sym.NEGATE] = self.push_negate,
      ['not']      = self.push_lnot,
      ["^2"]       = self.push_sq,
      ["10^"]      = self.push_alog,
      ["1/x"]      = self.push_invert,
      ["|"]        = self.push_with,
   }
   if special[str] then
      return (special[str])(self)
   end

   local op_name, _, op_argc = operators.query_info(str)
   if not op_name then return end

   self:assert_size(argc or op_argc, op_name)
   local args = self:pop_n(argc or op_argc)
   local expr = args[1]
   table.remove(args, 1)
   return self:push_expr(expr:apply_operator(str, args))
end

-- Push | (with)
function rpn_stack:push_with()
   self:assert_size(2, "WITH")
   local args = self:pop_n(2)

   if config.with_mode == 'smart' then
      local left, right = args[1], args[2]

      if left.kind == expr.OPERATOR and left.text == '|' then
         local condition = { left.children[2] }
         table.insert(condition, right)

         left.children[2] = expr.op('and', condition)
         self:push_expr(left)
         return true
      end
   end

   local op_name = operators.query_info('|')
   if not op_name then return end

   local expr = args[1]
   table.remove(args, 1)
   return self:push_expr(expr:apply_operator('|', args))
end

-- Push X^2
---@param idx? number Stack index or top
function rpn_stack:push_sq(idx)
   self:assert_size(1, "SQ")
   local top = self:top(idx)
   assert(top)
   top.rpn = expr.op('^', { top.rpn, expr.node('2', 'number') })

   if top:eval(self) then
      self:notify_change(idx)
   end
   return top
end

-- Push 10^X
function rpn_stack:push_alog(idx)
   self:assert_size(1, "ALOG")
   local top = self:top(idx)
   assert(top)
   top.rpn = expr.op('^', { expr.node('10', 'number'), top.rpn })

   if top:eval(self) then
      self:notify_change(idx)
   end
   return top
end

-- Invert stack node
---@param idx? number Stack index or top
function rpn_stack:push_invert(idx)
   self:assert_size(1, 'INV')
   local top = self:top(idx)
   assert(top)
   if top.rpn.kind == expr.OPERATOR and top.rpn.text == '/' then
      local num = top.rpn.children[1]
      if num.kind == expr.NUMBER and num.text == '1' then
         top.rpn = top.rpn.children[2]
      else
         local denom = table.remove(top.rpn.children)
         top.rpn.children[1] = denom
         top.rpn.children[2] = num
      end
   else
      top.rpn = expr.op('/', { expr.node('1', 'number'), top.rpn })
   end

   if top:eval(self) then
      self:notify_change(idx)
   end
   return top
end

-- Negate stack node
---@param idx? number Stack index or top
function rpn_stack:push_negate(idx)
   self:assert_size(1, 'NEG')
   local top = self:top(idx)
   assert(top)
   if top.rpn.kind == expr.OPERATOR and top.rpn.text == sym.NEGATE then
      top.rpn = top.rpn.children[1]
   else
      top.rpn = expr.op(sym.NEGATE, { top.rpn })
   end

   if top:eval(self) then
      self:notify_change(idx)
   end
   return top
end

-- Not stack node
---@param idx? number Stack index or top
function rpn_stack:push_lnot(idx)
   self:assert_size(1, 'NOT')
   local top = self:top(idx)
   assert(top)
   if top.rpn.kind == expr.OPERATOR and top.rpn.text == 'not' then
      top.rpn = top.rpn.children[1]
   else
      top.rpn = expr.op('not', { top.rpn })
   end

   if top:eval(self) then
      self:notify_change(idx)
   end
   return top
end

-- Push function call
---@param str string Function name
---@param argc? number Override argument count
function rpn_stack:push_function(str, argc, builtin_only)
   local fn_name, fn_argc, fn_is_stat = functions.query_info(str, builtin_only)
   if not fn_name then return end

   self:assert_size(argc or fn_argc, fn_name)
   local args = self:pop_n(argc or fn_argc)
   local e = expr.node(str, fn_is_stat and expr.FUNCTION_STAT or expr.FUNCTION, args)
   return self:push_expr(e)
   --if fn_is_stat then
   --   self:push_expr(expr.node('stat.results', 'word', {}))
   --end
end

-- Push container and set top n items as child
---@param kind expr_kind
---@param consume_n? number
function rpn_stack:push_container(kind, consume_n)
   self:assert_size(consume_n, 'WRAP')

   local children = consume_n > 0 and self:pop_n(consume_n) or {}
   return self:push_expr(expr.node(kind, kind, children))
end

-- Join arguments upwards, default to constructing matrices
--   {a} and {b} -> {a, {b}}
--   {a} and b   -> {a,  b }
function rpn_stack:smart_append()
   self:assert_size(2, 'APPEND')

   local args = self:pop_n(2)
   local a, b = args[1], args[2]

   local kind = expr.MATRIX ---@type expr_kind
   if a:isa(expr.LIST) then
      kind = expr.LIST
   end

   if not a:isa(kind) then
      a = expr.node(kind, kind, {a})
   end

   table.insert(a.children, b)
   return self:push_expr(a)
end

-- Explode arguments ((a and b) and c) -> (a and b), c
function rpn_stack:explode()
   self:assert_size(1, 'EXPLODE')

   local top = self:pop_n(1)[1]
   for _, v in ipairs(top.children or {}) do
      self:push_expr(v)
   end
end

-- Explode recursive ((a and b) and c) -> a, b, c
function rpn_stack:explode_recursive()
   self:assert_size(1, 'SEXPLODE')

   local top = self:pop_n(1)[1]
   local answers = top:collect_operands_recursive()
   for _, v in ipairs(answers) do
      self:push_expr(v)
   end
end

--[[ COMMON STACK OPERATIONS ]] --

-- Duplicate
---@param n number
function rpn_stack:dup(n)
   n = n or #self.stack
   if n >= 1 and n <= #self.stack then
      self:_push(self.stack[n]:clone())
   end
end

-- Swap X/Y
function rpn_stack:swap()
   if #self.stack < 2 then return end

   local x, y = table.remove(self.stack), table.remove(self.stack)
   table.insert(self.stack, x)
   table.insert(self.stack, y)

   if self.on_change then
      self:on_change({ #self.stack - 1, #self.stack })
   end
end

-- Roll
---@param n number
function rpn_stack:roll(n)
   if #self.stack < 2 then return end

   n = n or 1
   if n > 0 then
      for _ = 1, n do
         table.insert(self.stack, 1, table.remove(self.stack))
      end
   else
      for _ = 1, math.abs(n) do
         table.insert(self.stack, table.remove(self.stack, 1))
      end
   end

   if self.on_change then
      self:on_change(nil)
   end
end

return stack
