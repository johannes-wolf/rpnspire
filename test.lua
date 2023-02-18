-- luacheck: ignore class
---@diagnostics disable: lowercase-global
function _G.class(base)
   local classdef = {}

   setmetatable(classdef, {
      __index = base,
      __call = function(_, ...)
         local inst = {
            class = classdef,
            super = base or nil
         }
         setmetatable(inst, { __index = classdef })
         if inst.init then
            inst:init(...)
         end
         return inst
      end
   })

   return classdef
end

function string.usub(...)
   return string.sub(...)
end

function math.log10(x)
   return math.log(x, 10)
end

local RichTextStub = class()
function RichTextStub:setReadOnly()
   return self
end

function RichTextStub:setBorder()
   return self
end

_G.D2Editor = {
   newRichText = function() return RichTextStub() end
}

local GC = {
   getStringWidth = function() return 1 end,
   getStringHeight = function() return 1 end,
   drawRect = function() end,
   fillRect = function() end,
   setColorRGB = function() end,
   setFont = function() end,
}

-- luacheck: ignore platform
_G.platform = {
   withGC = function(fn) return fn(GC) end,
   window = {
      width = function() return 1 end,
      height = function() return 1 end,
      invalidate = function() end,
   }
}

math.evalStr = function(str)
   return str
end

if not unpack then
   _G.unpack = table.unpack
end

-- luacheck: ignore on
_G.on = {}
---@diagnostics enable: lowercase-global

require 'tableext'
require 'stringext'

local expr = require 'expressiontree'
local lexer = require 'ti.lexer'
local sym = require 'ti.sym'
local Test = require 'testlib'
local ui = require 'ui'
local config = require 'config.config'
config.use_document_settings = false

local test = {}

function test.tokenize_infix()
   local lexer = require 'ti.lexer'

   local function fail(str, reason)
      local res = lexer.tokenize(str)
      Test.assert((not res), reason)
   end

   local function expect(str, tokens)
      local res = lexer.tokenize(str)

      Test.assert(res ~= nil, "Token list is nil")
      if not res then return end

      Test.assert(#res == #tokens, "Token count missmatch " .. str)
      for i = 1, #tokens do
         Test.assert(res[i][1] == tokens[i][1],
                     "Token value missmatch. Expected '" .. tokens[i][1] .. "' got '" .. res[i][1] .. "'")
         Test.assert(res[i][2]:sub(1, #tokens[i][2]) == tokens[i][2],
                     "Token type missmatch. Expected '" .. tokens[i][1] .. "' got '" .. res[i][1] .. "' (" .. str .. ")")
      end
   end

   expect("", {})
   expect("    ", {})

   -- Number
   expect("1", { { '1', 'n' } })
   expect("1.", { { '1.', 'n' } })
   expect(".1", { { '.1', 'n' } })
   expect("1.1", { { '1.1', 'n' } })
   expect("123", { { '123', 'n' } })
   fail("1.1.", 'Number followed by point')
   fail(".", 'Point is not a valid number')

   -- Number exponents
   expect("3" .. sym.EE .. "5", { { '3' .. sym.EE .. '5', 'n' } })
   expect("3" .. sym.EE .. "+5", { { '3' .. sym.EE .. '+5', 'n' } })
   expect("3" .. sym.EE .. "-5", { { '3' .. sym.EE .. '-5', 'n' } })
   expect("3" .. sym.EE .. sym.NEGATE .. "5", { { '3' .. sym.EE .. sym.NEGATE .. '5', 'n' } })
   fail("3" .. sym.EE .. "5.1", 'Point after exponent')

   -- Number bases
   expect("0b10", { { '0b10', 'n' } })
   expect("0hf0", { { '0hf0', 'n' } })
   expect("0hfx", { { '0hf', 'n' }, { 'x', 'w' } }) -- As allowed by TI
   fail("0b12", 'Non binary digit in binary number')

   -- Operators
   expect("+", { { '+', 'o' } })
   expect("-", { { '-', 'o' } })
   expect("*", { { '*', 'o' } })
   expect("/", { { '/', 'o' } })
   expect(sym.NEGATE, { { sym.NEGATE, 'o' } })

   -- Units
   expect("_m", { { '_m', 'u' } })

   -- String
   expect('"hello"', { { '"hello"', 'str' } })

   -- List
   expect('{1,2}', { { '{', 'sy' }, { '1', 'n' }, { ',', 'sy' }, { '2', 'n' }, { '}', 'sy' } })

   -- Matrix
   expect('[1,2]', { { '[', 'sy' }, { '1', 'n' }, { ',', 'sy' }, { '2', 'n' }, { ']', 'sy' } })

   -- Function
   expect("f(1)", { { 'f', 'f' }, { '(', 'sy' }, { '1', 'n' }, { ')', 'sy' } })

   -- Expressions
   expect("solve(0.5((x + 3)^2 - 10.53)=0, {x,y})", {
      { 'solve', 'f' },
      { '(', 'sy' },
      { '0.5', 'n' },
      { '(', 'sy' },
      { '(', 'sy' },
      { 'x', 'w' },
      { '+', 'o' },
      { '3', 'n' },
      { ')', 'sy' },
      { '^', 'o' },
      { '2', 'n' },
      { '-', 'o' },
      { '10.53', 'n' },
      { ')', 'sy' },
      { '=', 'o' },
      { '0', 'n' },
      { ',', 'sy' },
      { '{', 'sy' },
      { 'x', 'w' },
      { ',', 'sy' },
      { 'y', 'w' },
      { '}', 'sy' },
      { ')', 'sy' },
   })
end

function test.infix_to_rpn_to_infix()
   local function expect(str, other)
      other = other or str

      do
         print('Expression: ' .. str)
         local tree = expr.from_infix(lexer.tokenize(str))
         Test.assert(tree)

         local new = tree:infix_string()
         Test.assert(new and new == other, "Expected " .. (other or 'nil') .. " got " .. (new or "nil"))
      end
   end

   local function fail(str)
      Test.expect_fail(function()
         local expr = expr.from_infix(lexer.tokenize(str))
         Test.assert(not expr,
                     "Expected from_infix to return nil (input: '" .. str .. "')\n")

         local infix = expr:infix_string()
         Test.assert(not infix,
                     "Expected infix string to be nil, is '" .. (infix or 'nil') .. "'")
      end)
   end

   expect("1+2")
   expect("1+2+3")
   expect("1+2+3+4")
   expect("1+2+3+4+5")

   -- Operator associativity
   expect("(1-2)-3", "1-2-3")
   expect("1-(2-3)")
   expect("((1-2)-3)-4", "1-2-3-4")
   expect("(2^3)^4")
   expect("2^3^4", "2^(3^4)")
   expect("2^(3^4)")
   expect("x^(y-1)=0")
   expect("solve(x^(y-1)=0,x)") -- bug#16
   expect("solve((((x*2)))=(((1))),((((((x)))))))", "solve(x*2=1,x)")

   -- Left assoc
   for _, v in ipairs({ '-', '/' }) do
      expect("x" .. v .. "x" .. v .. "x")
      expect("(x" .. v .. "x)" .. v .. "x", "x" .. v .. "x" .. v .. "x")
      expect("x" .. v .. "(x" .. v .. "x)")
   end

   expect("1/1/1")
   expect("1/(1/1)")
   expect("1*1*1")
   expect("1*1/1*1")
   expect("1*1/(1*1)")

   -- Implicit multiplication
   expect("1(3)", "1*3")
   expect("(3)1", "3*1")
   expect("5_m", "5*_m")
   expect("5{1}", "5*{1}")
   expect("{1}5", "{1}*5")

   -- Preserve function calls
   expect("abs()")
   expect("sin(pi)")
   expect("root(x)", "root(x)")
   expect("root(x,y)", "root(x,y)")

   -- Lists
   expect("{}")
   expect("{1}")
   expect("{1,2}")
   expect("{1,2,3}")
   expect("{(1+a)*2,2+b,3+c}")
   expect("{(1+a)*2,2+b,root((1+x)*2,2*y)}")

   -- Matrix
   expect("[1]", "[1]")
   expect("[1,2]", "[1,2]")
   expect("[[1,2,3][4,5,6]]")
   expect("[[1,2,3][4,5,6][7,8,9]]")
   expect("[[1+1,x,y^(2+z)][abs(x),{1,2,3},\"!\"][7,8,9]]")

   -- Remove parens
   expect("(2^2)", "2^2")
   expect("(((2^2)))", "2^2")

   -- Units
   expect("_km/_s")
   expect("(_km/_s)", "_km/_s")

   -- Syntax errors
   fail("+")
   fail(",")
   fail(")")
   fail("}")
   fail(")")
   fail("())")
   fail("(+)")
end

function test.rpn_input()
   local controller = require 'rpn.controller'
   require 'views.container'
   require 'views.edit'
   require 'views.list'
   require 'views.label'

   local edit = ui.edit(nil)
   local list = ui.list(nil)
   local rpn = controller.new({}, edit, list)
   local stack = rpn.stack
   rpn:initialize()

   local function expectStack(key, stack_infix)
      stack.stack = {}
      edit:set_text('')
      for _, v in ipairs(key) do
         if v == 'ENTER' then
            edit:on_enter_key()
         else
            edit:on_char(v)
         end
      end

      local key_str = ''
      for _, k in ipairs(key) do
         key_str = key_str .. ' ' .. k
      end
      Test.info(key_str)

      if type(stack_infix) == 'string' then
         if not Test.assert(#stack.stack > 0,
                            "Expected stack to be " .. stack_infix) then
            return
         end

         local stack_top = stack.stack[#stack.stack]
         Test.assert(stack_top.infix == stack_infix,
                     "Expected stack top to be '" .. stack_infix .. "' but it is '" .. stack_top.infix .. "'")
      else
         for idx, v in ipairs(stack_infix) do
            local stack_top = stack.stack[#stack.stack - idx + 1]
            Test.assert(stack_top.infix == v,
                        "Expected stack top to be '" .. v .. "' but it is '" .. stack_top.infix .. "'")
         end
      end
   end

   ---@diagnostic disable-next-line: duplicate-set-field
   expectStack({ '1', 'ENTER' }, '1')
   expectStack({ '1', 'ENTER', '2', 'ENTER' }, { '2', '1' })
   expectStack({ '1', '2', 'ENTER' }, '12')

   -- Operators
   expectStack({ '1', 'ENTER', '2', 'ENTER', '+' }, '1+2')
   expectStack({ '1', 'ENTER', '2', '+' }, '1+2')

   -- Remove double negation/not
   expectStack({ '1', 'ENTER', sym.NEGATE }, sym.NEGATE .. '1')
   expectStack({ '1', 'ENTER', sym.NEGATE, sym.NEGATE }, '1')
   expectStack({ '1', 'ENTER', 'not' }, 'not 1')
   expectStack({ '1', 'ENTER', 'not', 'not' }, '1')

   -- Inline negation
   expectStack({ '1', sym.NEGATE, 'ENTER' }, sym.NEGATE .. '1')
   --expectStack({'1', sym.NEGATE, sym.NEGATE, 'ENTER'}, '1') -- Not working because of missing usub implementation!

   -- Unit power suffix
   expectStack({ '2', 'ENTER', '_m', 'ENTER', '2', '^', '*' }, '2*_m^2')

   -- Functions
   expectStack({ '1', 'ENTER', 'sin', 'ENTER' }, 'sin(1)')
   expectStack({ '1', 'ENTER', '2', '+', 'sin', 'ENTER' }, 'sin(1+2)')
   expectStack({ 'sin(2)', 'ENTER' }, 'sin(2)')

   -- Lists
   expectStack({ '{', '1', ',', '2', '}', 'ENTER' }, '{1,2}')

   -- Auto removal of store operations
   config.store_mode = 'replace'
   expectStack({ '1', 'ENTER', 'a', sym.STORE, '2', 'ENTER', 'b', sym.STORE, '+' }, 'a+b')
   expectStack({ 'a', 'ENTER', '1', ':=', '2', 'ENTER', 'b', sym.STORE, '+' }, 'a+b')
   expectStack({ '1', 'ENTER', 'a', sym.STORE, 'b', 'ENTER', '2', ':=', '+' }, 'a+b')
   expectStack({ 'a', 'ENTER', '1', ':=', 'b', 'ENTER', '2', ':=', '+' }, 'a+b')

   -- Modify both sides
   expectStack({ 'x', 'ENTER', '2', '*', '10', '=', '2', '/' }, 'x*2/2=10/2')
   expectStack({ 'x', 'ENTER', '2', '*', '10', '=', '2', '/', '1', 'and' }, 'x*2/2=10/2 and 1') -- Do not logical op
end

function test.stack_to_list()
   local stack = require 'rpn.stack'

   if true then
      return -- TODO: Implement to_list
   end


   local function expect(infix_list, n, stack_result)
      local s = stack.new()
      for _, v in ipairs(infix_list) do
         s:push_infix(v)
      end
      --s:toList(n)

      if not Test.assert(#s.stack > 0,
                         "Expected stack to be not empty!") then
         return
      end
      local stack_top = s.stack[#s.stack]
      Test.assert(stack_top.infix == stack_result,
                  "Expected stack top to be '" .. stack_result .. "' but it is '" .. stack_top.infix .. "'")
   end

   -- List of numbers
   expect({ '1' }, 10, '{1}')
   expect({ '1' }, 0, '{}')
   expect({ '1' }, 1, '{1}')
   expect({ '1', '2' }, 1, '{2}')
   expect({ '1', '2', '3' }, 1, '{3}')
   expect({ '1', '2', '3' }, 2, '{2,3}')
   expect({ '1', '2', '3' }, 3, '{1,2,3}')

   -- List with functions
   expect({ 'abs(1)', 'root(2,3)', '3' }, 3, '{abs(1),root(2,3),3}')

   -- Join lists
   expect({ '{1}', '2' }, 2, '{1,2}')
   expect({ '{1,2,3}', '4' }, 2, '{1,2,3,4}')
   expect({ '{1,2,3}', '{4}' }, 2, '{1,2,3,4}')
   expect({ '{x,y,z}', '{1,2,3}', '4' }, 3, '{x,y,z,1,2,3,4}')
   expect({ '{x,y,z}', '1', '{2,3,4}' }, 3, '{x,y,z,1,2,3,4}')
end

function test.rect()
   local a = ui.rect(10, 10, 10, 10)

   Test.assert(not a:clone():intersects_rect(ui.rect(0, 0, 5, 5)))
   Test.assert(a:clone():intersects_rect(ui.rect(a.x, a.y, a.width, a.height)))
   Test.assert(a:clone():intersects_rect(ui.rect(0, 0, 15, 15)))
   Test.assert(a:clone():intersects_rect(ui.rect(15, 15, 5, 5)))
end

Test.run(test)
