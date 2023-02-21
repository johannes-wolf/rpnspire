local operators = require 'ti.operators'
local sym = require 'ti.sym'
local config = require 'config.config'

local m = {}

---@enum expr_kind
---  | 'n' # Number
---  | 'x' # Symbol
---  | 'u' # Unit
---  | 'o' # Operator
---  | 'f' # Function
---  | 's' # String
---  | 'l' # List
---  | 'm' # Matrix/Vector
---  | '#' # Subscript
m.NUMBER = 'n'
m.SYMBOL = 'x'
m.UNIT = 'u'
m.OPERATOR = 'o'
m.FUNCTION = 'f'
m.FUNCTION_STAT = 't'
m.STRING = 's'
m.LIST = '{'
m.MATRIX = '['
m.SUB = '#'

-- For faster access w/o lookup store kinds in locals
local k_num, k_sym, k_unit, k_op, k_fn, k_fns, k_str, k_lst, k_mat, k_sub =
m.NUMBER, m.SYMBOL, m.UNIT, m.OPERATOR, m.FUNCTION, m.FUNCTION_STAT, m.STRING, m.LIST, m.MATRIX, m.SUB


---@class expr
---@field kind expr_kind
---@field text string
---@field children expr[]
local t = {}
t.__index = t

function m.node(text, kind, children)
   return setmetatable({ text = text, kind = kind, children = children or {} }, t)
end

function m.op(text, children)
   return m.node(text, k_op, children)
end

-- Test node for equality
---@param kind? expr_kind
---@param text? string
---@return boolean
function t:isa(kind, text)
   return ((kind and (kind == self.kind)) or not kind) and
       ((text and (text == self.text)) or not text)
end

function t:print()
   local function to_string_recurse(node, level)
      level = level or 0
      local indent = string.rep('  ', level)
      print(string.format('%s%s (%s)', indent, node.text, (node.kind or '?'):sub(1, 1)))

      if node.children then
         for _, child in ipairs(node.children) do
            to_string_recurse(child, level + 1)
         end
      end
   end

   return to_string_recurse(self)
end

-- Return a deep copy of self
---@return expr
function t:clone()
   local children = {}
   for i, v in ipairs(self.children or {}) do
      children[i] = v:clone()
   end
   return m.node(self.text, self.kind, children)
end

---@return string
function t:prefix_string()
   if self.children and #self.children > 0 then
      local child_string = {}
      for _, v in ipairs(self.children) do
         table.insert(child_string, v:prefix_string())
      end
      return string.format("(%s %s)", self.text, table.concat(child_string, ' '))
   end
   return self.text
end

-- Converts the node tree to an infix representation
---@return string Infix string representation
function t:infix_string()
   local function node_to_infix(node)
      if node.kind == k_op then
         local name, prec, _, side, assoc, aggr_assoc = operators.query_info(node.text)
         assoc = assoc == 'r' and 2 or (assoc == 'l' and 1 or 0)

         local str = nil
         for idx, operand in ipairs(node.children) do
            if str and side == 0 then str = str .. name end
            str = str or ''
            if operand.kind == k_op then
               local _, operand_prec = operators.query_info(operand.text)
               if (operand_prec < prec) or
                   ((aggr_assoc or idx ~= assoc) and operand_prec < prec + (assoc ~= 0 and 1 or 0)) then
                  str = str .. '(' .. node_to_infix(operand) .. ')'
               else
                  str = str .. node_to_infix(operand)
               end
            else
               str = str .. node_to_infix(operand)
            end
         end

         if side < 0 then str = name .. str end
         if side > 0 then str = str .. name end
         return str
      elseif node.kind == k_fn then
         return node.text .. '(' ..
             table.join_str(node.children, ',', node_to_infix) ..
             ')'
      elseif node.kind == k_fns then
         return node.text .. ' ' ..
             table.join_str(node.children, ',', node_to_infix)
      elseif node.kind == k_lst then
         return node.text ..
             table.join_str(node.children, ',', node_to_infix) ..
             '}'
      elseif node.kind == k_mat then
         local is_matrix = false
         if node.children and #node.children >= 1 and node.children[1].text == '[' then
            is_matrix = true
         end

         return node.text ..
             table.join_str(node.children, is_matrix and '' or ',', node_to_infix) ..
             ']'
      elseif node.kind == k_sub then
         assert(node.children and #node.children >= 2)

         return node_to_infix(node.children[1]) ..
             '[' .. table.join_str({ table.unpack(node.children, 2) }, ',', node_to_infix) .. ']'
      elseif node.kind == k_num then
         local text = node.text
         if node.text:sub(1, 1) == '-' then
            text = sym.NEGATE .. node.text:sub(2)
         end

         -- This is a hack to get numbers formatted as specified by the
         -- documents settings: Convert them to a string and remove the
         -- resulting quotes.
         if config.use_document_settings then
            local function unquote_result(str)
               if str and str:sub(1, 1) == '"' and str:usub(-1) == '"' then
                  return str:usub(2, -2)
               end
               return str
            end

            return unquote_result(math.evalStr('string(' .. text .. ')')) or text
         end

         return text
      else
         return node.text
      end
   end

   local ok, res = pcall(function()
      return node_to_infix(self)
   end)

   if not ok then
      error(res)
   end

   return res
end

-- Helper function returning true if `node` is a relational operator
local function node_is_rel_operator(node)
   if node.kind == k_op then
      return node.text == '=' or node.text == '<' or node.text == '>' or
          node.text == '/=' or node.text == sym.NEQ or node.text == sym.LEQ or
          node.text == sym.GEQ
   end
end

-- Construct an expr from a list of tokens
---@param tokens table  List of tokens
function m.from_infix(tokens)
   assert(type(tokens) == 'table')

   -- PRATT Parser
   local parser = {
      idx = 1,
      infix = {},
      prefix = {},

      make_node = function(kind, text, children)
         return m.node(text, kind, children)
      end,

      eof = function(self)
         return self.idx > #tokens
      end,

      lookahead = function(self, offset)
         offset = self.idx + (offset or 0)
         if offset <= #tokens then
            local text, kind = table.unpack(tokens[offset])
            if kind == 'operator' or kind == 'syntax' then
               return { kind = text, text = text }
            end
            return { kind = kind, text = text }
         end
      end,

      match = function(self, token)
         local t = self:current()
         if t then
            return t.kind == token.kind and (not token.text or t.text == token.text)
         end
         return false
      end,

      current = function(self)
         return self:lookahead(0)
      end,

      consume = function(self)
         if not self:eof() then
            local t = self:lookahead(0)
            self.idx = self.idx + 1
            return t
         end
      end,

      precedence = function(self, token)
         local p = self.infix[token.kind]
         return p and p.precedence or 0
      end,

      assoc = function(self, token)
         local p = self.infix[token.kind]
         return p and p.assoc or 'left'
      end,

      parse_infix = function(self, left, prec)
         while not self:eof() and
             (prec < self:precedence(self:current()) or
                 (self:assoc(self:current()) == 'right' and prec <= self:precedence(self:current()))) do
            local t = self:consume()
            local p = self.infix[t.kind]
            if not p then
               error({ desc = 'No infix parser for ' .. t.kind })
            end
            left = p:parse(self, left, t)
         end
         return left
      end,

      parse_precedence = function(self, prec)
         local t = self:current()
         if not t then
            error({ desc = 'Token is nil' })
         end

         local p = self.prefix[t.kind]
         if not p then
            error({ desc = 'No prefix parser for ' .. t.kind .. ': ' .. t.text })
         end
         self:consume()
         local left = p:parse(self, t)
         return self:parse_infix(left, prec)
      end,

      ---@return expr
      parse = function(self)
         return self:parse_precedence(0)
      end,

      parse_up_to = function(self, kind)
         local e = self:parse()
         if not e then
            error({ desc = 'Expected expression' })
         end

         if not self:match({ kind = kind }) then
            error({ desc = 'Expected ' .. kind .. ' got ' .. self:current().kind })
         end
         self:consume()
         return e
      end,

      parse_list = function(self, stop_token, delim_token)
         local e = {}
         if self:match(stop_token) then
            self:consume()
            return e
         end

         while true do
            table.insert(e, self:parse())

            if not self:match(stop_token) then
               if self:match(delim_token) then
                  self:consume()
               elseif self:eof() then
                  error({ desc = 'Expected token got EOF' })
               else
                  error({ desc = 'Expected ' .. delim_token.kind .. ' got ' .. self:current().kind })
               end
            else
               self:consume()
               break
            end
         end

         return e
      end,

      add_prefix = function(self, kind, parselet)
         if type(kind) ~= 'table' then kind = { kind } end
         for _, v in ipairs(kind) do
            self.prefix[v] = parselet
         end
      end,

      add_infix = function(self, kind, parselet)
         if type(kind) ~= 'table' then kind = { kind } end
         for _, v in ipairs(kind) do
            self.infix[v] = parselet
         end
      end,

      add_prefix_op = function(self, kind, prec)
         self:add_prefix(kind, {
            parse = function(self, p, t)
               return p.make_node(k_op, t.text, { p:parse_precedence(prec) })
            end
         })
      end,

      add_infix_op = function(self, kind, prec, assoc)
         self:add_infix(kind, {
            precedence = prec,
            assoc = assoc or 'left',
            parse = function(self, p, left, t)
               return m.op(t.text, { left, p:parse_precedence(self.precedence) })
            end
         })
      end,

      add_suffix_op = function(self, kind, prec)
         self:add_infix(kind, {
            precedence = prec,
            parse = function(self, p, left, t)
               return p:parse_infix(left, 0)
            end
         })
      end,
   }

   -- Number/Word
   parser:add_prefix({ 'number', 'word', 'unit', 'string' }, {
      parse = function(self, p, t)
         local k
         if t.kind == 'number' then k = k_num
         elseif t.kind == 'word' then k = k_sym
         elseif t.kind == 'unit' then k = k_unit
         elseif t.kind == 'string' then k = k_str
         end

         assert(k, t.kind)
         return p.make_node(k, t.text)
      end
   })

   -- Function
   parser:add_prefix('function', {
      parse = function(self, p, t)
         local ident = t.text
         if not p:match({ kind = '(' }) then
            error({ desc = 'Expected ( got ' .. p:current().text })
         end

         p:consume()
         local args = p:parse_list({ kind = ')' }, { kind = ',' })
         return p.make_node(k_fn, ident, args)
      end
   })

   parser:add_prefix('(', {
      parse = function(self, p, t)
         return p:parse_up_to(')')
      end
   })

   -- Lists
   parser:add_prefix('{', {
      parse = function(self, p, t)
         return p.make_node(k_lst, '{', p:parse_list({ kind = '}' }, { kind = ',' }))
      end
   })

   -- Vectors/Matrices
   parser:add_prefix('[', {
      parse = function(self, p, t)
         -- Matrix
         if p:current() and p:current().kind == '[' then
            local rows = {}
            while p:current() and p:current().kind == '[' do
               p:consume()
               local row = p:parse_list({ kind = ']' }, { kind = ',' })
               if not row then
                  error({ desc = 'Expected matrix row' })
               end
               table.insert(rows, p.make_node(k_mat, '[', row))
            end
            if not p:match({ kind = ']' }) then
               error({ desc = 'Expected ] got ' .. p:current().kind })
            end
            p:consume()

            return p.make_node(k_mat, '[', rows)
         end

         -- Vector
         return p.make_node(k_mat, '[', p:parse_list({ kind = ']' }, { kind = ',' }))
      end
   })

   -- Handle implicit multiplication
   parser:add_infix({ '(', '{', 'number', 'word', 'function', 'unit' }, {
      precedence = 13,
      parse = function(self, p, left, t)
         local right = p:parse_infix(p.prefix[t.kind]:parse(p, t), self.precedence)
         return m.op('*', { left, right })
      end
   })

   -- Handle Subscripts
   parser:add_infix({ '[' }, {
      precedence = 17,
      parse = function(self, p, left, t)
         -- Implicit matrix multiplication
         if p:current() and p:current().kind == '[' then
            return m.op('*', { left, parser.prefix['[']:parse(p, t) })
         end

         local indices = p:parse_list({ kind = ']' }, { kind = ',' })
         return m.node('_[', k_sub, { left, table.unpack(indices) })
      end
   })

   -- Operators
   parser:add_prefix_op({ '#' }, 18)
   parser:add_suffix_op({ '!', '%', '@t', sym.RAD, sym.GRAD, sym.DEGREE, sym.TRANSP }, 17)
   parser:add_infix_op({ '^' }, 16, 'right')
   parser:add_prefix({ '-', sym.NEGATE }, {
      parse = function(self, p, t)
         return m.op(sym.NEGATE, { p:parse_precedence(15) })
      end
   })
   parser:add_infix_op({ '&' }, 14)
   parser:add_infix_op({ '*', '/' }, 13)
   parser:add_infix_op({ '+', '-' }, 12)
   parser:add_infix_op({ '=', '/=', '<', '>', '<=', '>=', sym.NEQ, sym.LEQ, sym.GEQ }, 11)
   parser:add_prefix_op({ 'not' }, 10)
   parser:add_infix_op({ 'and', 'or' }, 10)
   parser:add_infix_op({ 'xor', 'nor', 'nand' }, 9)
   parser:add_infix_op({ '=>', sym.LIMP }, 8)
   parser:add_infix_op({ '<=>', sym.DLIMP }, 7)
   parser:add_infix_op({ '|' }, 6)
   parser:add_infix_op({ ':=', ':=', sym.STORE }, 5)
   parser:add_infix_op({ '@>', sym.CONVERT }, 1)

   local t = parser:parse()
   if not parser:eof() then
      error({ desc = 'Error parsing expression at ' .. parser:current().kind .. ': ' .. parser:current().text })
   end
   return t
end

-- Match node for a sub-expression
---@param subexpr expr Subexpression to match against
---@param limit? boolean Limit to first match
---@param meta? boolean Make words match anything
---@return table Matches           List of matches found
function t:find_subexpr(subexpr, limit, meta)
   local matches = {}
   local metavars = {}

   -- a Haystack
   -- b Needle
   local function match_subtree_recurse(a, b)
      if b.kind == k_sym then
         if not metavars[b.text] then
            metavars[b.text] = a
            return true
         else
            return match_subtree_recurse(a, metavars[b.text])
         end
      end

      if a.kind == b.kind and a.text == b.text then
         if not a.children and not b.children then
            return true
         end

         if (a.children ~= nil) ~= (b.children ~= nil) or #a.children ~= #b.children then
            return false
         end

         for idx, child in ipairs(a.children or {}) do
            if not match_subtree_recurse(child, b.children[idx]) then
               return false
            end
         end

         return true
      end
   end

   local function find_subexpr_recurse(start, start_idx, a, b)
      if match_subtree_recurse(a, b) then
         table.insert(matches, { parent = start, index = start_idx, node = a })
         if limit then
            return true
         end
      end

      for idx, child in ipairs(a.children or {}) do
         if find_subexpr_recurse(a, idx, child, b) and limit then
            return
         end
      end
   end

   find_subexpr_recurse(nil, nil, self, subexpr)
   if #matches > 0 then
      return matches, metavars
   end
end

-- Returns `true` if self does contain subexpr (at any level)
---@param subexpr expr  Subexpression to search for
---@return boolean Result
function t:contains_subexpr(subexpr)
   return self:find_subexpr(subexpr, true)
end

-- Substitutes all word tokens that exist in `vars` with the
-- node stored in vars.
---@param vars  table  Mapping from identifier to node
function t:substitute_vars(vars)
   self:map_all(function(node)
      if node.kind == k_sym then
         local repl = vars[node.text]
         if repl then
            return repl:clone()
         end
      end
      return nil
   end)
   return self
end

-- Rewrite all occurances of `subexpr` in self with `with`, replacing all variables of `subexpr`
-- with their matched nodes.
---@param subexpr expr  Expression to replace
---@param with    expr  Expression to replace with
function t:rewrite_subexpr(subexpr, with)
   local target = self
   local matches, metavars = target:find_subexpr(subexpr, false, true)

   with = with:substitute_vars(metavars or {})
   for _, match in ipairs(matches or {}) do
      if match.parent then
         match.parent.children[match.index] = with
      else
         target = with
      end
   end

   return self
end

-- Returns the left side of the expression or the whole expression
function t:left()
   if node_is_rel_operator(self) then
      return self.children[1]
   else
      return self
   end
end

-- Returns the right side of the expression or the whole expression
function t:right()
   if node_is_rel_operator(self) then
      return self.children[2]
   end
end

-- Applies operator `op` to the expression, with arguments `arguments`.
---@param op string          Operator symbol
---@param arguments expr[]  List of additional operator arguments (nodes) (besides self)
---@return expr
function t:apply_operator(op, arguments)
   local apply_on_both_sides = {
      ['+'] = true, ['-'] = true, ['*'] = true, ['/'] = true,
      ['^'] = true, ['!'] = true, ['%'] = true, [sym.NEGATE] = true
   }

   if node_is_rel_operator(self) and apply_on_both_sides[op] then
      self:map_level(function(node)
         return node:apply_operator(op, arguments)
      end)
   else
      local args = {}
      for i, v in ipairs(arguments) do
         args[i] = v:clone()
      end

      local operator = m.op(op, args)
      table.insert(operator.children, 1, self)
      self = operator
   end
   return self
end

-- Calls function for each argument at optional level `level`.
-- If the function returns a value, the visited node will be replaced by that.
---@param fn function     Callback (node, parent) : node?
---@param level? integer  Optional level
function t:map_level(fn, level)
   level = level or 1

   local function recursive_map_level(node, level_)
      if level_ == 1 then
         for idx, child in ipairs(node.children or {}) do
            local replace = fn(child, node)
            if replace then
               node.children[idx] = replace
            end
         end
      elseif node.children then
         for _, child in ipairs(node.children) do
            recursive_map_level(child, level_ - 1)
         end
      end
   end

   return recursive_map_level(self, level)
end

function t:map_all(fn)
   local function map_recursive(node)
      for idx, child in ipairs(node and node.children or {}) do
         local replace = fn(child, node)
         if replace then
            node.children[idx] = replace
         else
            map_recursive(child)
         end
      end
   end

   local replace = fn(self, nil)
   if replace then
      self.text = replace.text
      self.kind = replace.kind
      self.children = replace.children
   else
      map_recursive(self)
   end
   return self
end

-- Collect operands of nested (same) operations
--   (1 and 2) and 3 -> {1,2,3}
---@return expr[]
function t:collect_operands_recursive()
   local kind, text = self.kind, self.text
   local res = {}

   local function merge_operands_rec(node)
      if node:isa(kind, text) then
         for _, v in ipairs(node.children) do
            merge_operands_rec(v)
         end
      else
         table.insert(res, node)
      end
   end

   merge_operands_rec(self)
   return res
end

return m
