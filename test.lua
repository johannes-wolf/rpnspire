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
      setmetatable(inst, {__index = classdef})
      if inst.init then
        inst:init(...)
      end
      return inst
    end})

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

-- luacheck: ignore Infix RPNExpression
require 'rpn'
local Test = require 'testlib'


-- Print a list of tokens
---@param stack TokenPair[]
local function debug_print_stack(stack)
  for idx, v in ipairs(stack) do
    print(string.format('[%03d|%s] %s', idx, v[2]:subs(1, 4), v[1]))
  end
end


local test = {}

function test.tokenize_infix()
  local function fail(str, reason)
    local res = Infix.tokenize(str)
    Test.assert((not res), reason)
  end

  local function expect(str, tokens)
    local res = Infix.tokenize(str)

    Test.assert(res ~= nil, "Token list is nil")
    if not res then return end

    Test.assert(#res == #tokens, "Token count missmatch "..str)
    for i=1, #tokens do
      Test.assert(res[i][1] == tokens[i][1],
                  "Token value missmatch. Expected '"..tokens[i][1].."' got '"..res[i][1].."'")
      Test.assert(res[i][2]:sub(1, #tokens[i][2]) == tokens[i][2],
                  "Token type missmatch. Expected '"..tokens[i][1].."' got '"..res[i][1].."' ("..str..")")
    end
  end

  expect("",     {})
  expect("    ", {})

  -- Number
  expect("1",   {{'1',   'n'}})
  expect("1.",  {{'1.',  'n'}})
  expect(".1",  {{'.1',  'n'}})
  expect("1.1", {{'1.1', 'n'}})
  expect("123", {{'123', 'n'}})
  fail("1.1.",  'Number followed by point')
  fail(".",     'Point is not a valid number')

  -- Number exponents
  expect("3"..Sym.EE.."5",             {{'3'..Sym.EE..'5',  'n'}})
  expect("3"..Sym.EE.."+5",            {{'3'..Sym.EE..'+5', 'n'}})
  expect("3"..Sym.EE.."-5",            {{'3'..Sym.EE..'-5', 'n'}})
  expect("3"..Sym.EE..Sym.NEGATE.."5", {{'3'..Sym.EE..Sym.NEGATE..'5', 'n'}})
  fail("3"..Sym.EE.."5.1",             'Point after exponent')

  -- Number bases
  expect("0b10", {{'0b10', 'n'}})
  expect("0hf0", {{'0hf0', 'n'}})
  expect("0hfx", {{'0hf', 'n'}, {'x', 'w'}}) -- As allowed by TI
  fail("0b12",   'Non binary digit in binary number')

  -- Operators
  expect("+",        {{'+', 'o'}})
  expect("-",        {{'-', 'o'}})
  expect("*",        {{'*', 'o'}})
  expect("/",        {{'/', 'o'}})
  expect(Sym.NEGATE, {{Sym.NEGATE, 'o'}})

  -- Units
  expect("_m", {{'_m', 'u'}})

  -- String
  expect('"hello"', {{'"hello"', 'str'}})

  -- List
  expect('{1,2}', {{'{', 'sy'}, {'1', 'n'}, {',', 'sy'}, {'2', 'n'}, {'}', 'sy'}})

  -- Matrix
  expect('[1,2]', {{'[', 'sy'}, {'1', 'n'}, {',', 'sy'}, {'2', 'n'}, {']', 'sy'}})

  -- Function
  expect("f(1)", {{'f', 'f'}, {'(', 'sy'}, {'1', 'n'}, {')', 'sy'}})

  -- Expressions
  expect("solve(0.5((x + 3)^2 - 10.53)=0, {x,y})", {
           {'solve', 'f'},
           {'(',     'sy'},
           {'0.5',   'n'},
           {'(',     'sy'},
           {'(',     'sy'},
           {'x',     'w'},
           {'+',     'o'},
           {'3',     'n'},
           {')',     'sy'},
           {'^',     'o'},
           {'2',     'n'},
           {'-',     'o'},
           {'10.53', 'n'},
           {')',     'sy'},
           {'=',     'o'},
           {'0',     'n'},
           {',',     'sy'},
           {'{',     'sy'},
           {'x',     'w'},
           {',',     'sy'},
           {'y',     'w'},
           {'}',     'sy'},
           {')',     'sy'},
  })
end

function test.infix_to_rpn_to_infix()
  local function expect(str, other)
    other = other or str

    do
      print('Expression: ' .. str)
      local tree = ExpressionTree.from_infix(Infix.tokenize(str))
      Test.assert(tree)

      local new = tree:infix_string()
      Test.assert(new and new == other, "Expected " .. (other or 'nil') .. " got " .. (new or "nil"))
    end
  end

  local function fail(str)
    Test.expect_fail(function()
      local expr = ExpressionTree.from_infix(Infix.tokenize(str))
      Test.assert(not expr,
                  "Expected fromInfix to return nil (input: '" .. str .. "')\n")

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
  for _,v in ipairs({'-', '/'}) do
    expect("x"..v.."x"..v.."x")
    expect("(x"..v.."x)"..v.."x", "x"..v.."x"..v.."x")
    expect("x"..v.."(x"..v.."x)")
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

function test.keybind_manager()
  local last = nil
  local kbd = KeybindManager()

  local function expect(seq, n)
    kbd:resetSequence()
    last = nil
    for _,v in ipairs(seq) do
      kbd:dispatchKey(v)
    end
    Test.assert(last == n, "Expected action "..(n or "nil").." got "..(last or "nil"))
  end

  kbd:setSequence({'a', 'b', '1'}, function() last = '1' end)
  kbd:setSequence({'a', 'b', '2'}, function() last = '2' end)
  kbd:setSequence({'a', 'c', '3'}, function() last = '3' end)
  kbd:setSequence({'b'}, function() last = '4' end)

  expect({}, nil)
  expect({'c'}, nil)
  expect({'b'}, '4')
  expect({'a', 'b', '2'}, '2')
end

function test.rpn_input()
  UIStack.draw = function() end
  UIInput.draw = function() end

  local text = ''
  local rpn = RPNInput({
      text = function() return text end,
      split = function() return text, '', '' end,
      set_text = function(str) text = str end
  })

  local function expectStack(key, stack_infix)
    StackView.stack = {}
    text = ''
    for _,v in ipairs(key) do
      if v == 'ENTER' then
        rpn:onEnter()
      else
        if not rpn:onCharIn(v) then
          text = text..v
        end
      end
    end

    if type(stack_infix) == 'string' then
      if not Test.assert(#StackView.stack > 0,
                         "Expected stack to be not empty!") then
        return
      end

      local stack_top = StackView.stack[#StackView.stack]
      Test.assert(stack_top.infix == stack_infix,
                  "Expected stack top to be '"..stack_infix.."' but it is '"..stack_top.infix.."'")
    else
      for idx,v in ipairs(stack_infix) do
        local stack_top = StackView.stack[#StackView.stack - idx + 1]
        Test.assert(stack_top.infix == v,
                    "Expected stack top to be '"..v.."' but it is '"..stack_top.infix.."'")
      end
    end
  end

  ---@diagnostic disable-next-line: duplicate-set-field
  rpn.isBalanced = function() return true end

  expectStack({'1', 'ENTER'}, '1')
  expectStack({'1', 'ENTER', '2', 'ENTER'}, {'2', '1'})
  expectStack({'1', '2', 'ENTER'}, '12')

  -- Operators
  expectStack({'1', 'ENTER', '2', 'ENTER', '+'}, '1+2')
  expectStack({'1', 'ENTER', '2', '+'}, '1+2')

  -- Remove double negation/not
  expectStack({'1', 'ENTER', Sym.NEGATE}, Sym.NEGATE..'1')
  expectStack({'1', 'ENTER', Sym.NEGATE, Sym.NEGATE}, '1')
  expectStack({'1', 'ENTER', 'not'}, 'not 1')
  expectStack({'1', 'ENTER', 'not', 'not'}, '1')

  -- Inline negation
  expectStack({'1', Sym.NEGATE, 'ENTER'}, Sym.NEGATE..'1')
  --expectStack({'1', Sym.NEGATE, Sym.NEGATE, 'ENTER'}, '1') -- Not working because of missing usub implementation!

  -- Unit power suffix
  expectStack({'2', '_m', '^', '2', 'ENTER'}, '2*_m^2')

  -- Functions
  expectStack({'1', 'ENTER', 'sin', 'ENTER'}, 'sin(1)')
  expectStack({'1', 'ENTER', '2', '+', 'sin', 'ENTER'}, 'sin(1+2)')
  expectStack({'sin(2)', 'ENTER'}, 'sin(2)')

  -- Lists
  expectStack({'{', '1', ',', '2', '}', 'ENTER'}, '{1,2}')

  -- Auto removal of store operations
  expectStack({'1', 'ENTER', 'a', Sym.STORE, '2', 'ENTER', 'b', Sym.STORE, '+'}, '1+2')
  expectStack({'a', 'ENTER', '1', ':=', '2', 'ENTER', 'b', Sym.STORE, '+'}, '1+2')
  expectStack({'1', 'ENTER', 'a', Sym.STORE, 'b', 'ENTER', '2', ':=', '+'}, '1+2')
  expectStack({'a', 'ENTER', '1', ':=', 'b', 'ENTER', '2', ':=', '+'}, '1+2')

  -- Modify both sides
  expectStack({'x', 'ENTER', '2', '*', '10', '=', '2', '/'}, 'x*2/2=10/2')
  expectStack({'x', 'ENTER', '2', '*', '10', '=', '2', '/', '1', 'and'}, 'x*2/2=10/2 and 1') -- Do not logical op

  -- ANS
  expectStack({'123', 'ENTER', '2', 'ENTER', '@2*@1', 'ENTER'}, '123*2')

  -- Unbalanced (ALG) input
  ---@diagnostic disable-next-line: duplicate-set-field
  rpn.isBalanced = function() return false end
  expectStack({'1', '+', '2', 'x', 'ENTER'}, '1+2*x')
  expectStack({'{', '1', '+', '2', ',', '3', '}', 'ENTER'}, '{1+2,3}')
end

function test.stack_to_list()
  local function expect(infix_list, n, stack_result)
    StackView.stack = {}
    for _,v in ipairs(infix_list) do
      StackView:pushInfix(v)
    end
    StackView:toList(n)

    if not Test.assert(#StackView.stack > 0,
                       "Expected stack to be not empty!") then
      return
    end
    local stack_top = StackView.stack[#StackView.stack]
    Test.assert(stack_top.infix == stack_result,
                "Expected stack top to be '"..stack_result.."' but it is '"..stack_top.infix.."'")
  end

  -- List of numbers
  expect({'1'}, 10, '{1}')
  expect({'1'}, 0, '{}')
  expect({'1'}, 1, '{1}')
  expect({'1', '2'}, 1, '{2}')
  expect({'1', '2', '3'}, 1, '{3}')
  expect({'1', '2', '3'}, 2, '{2,3}')
  expect({'1', '2', '3'}, 3, '{1,2,3}')

  -- List with functions
  expect({'abs(1)', 'root(2,3)', '3'}, 3, '{abs(1),root(2,3),3}')

  -- Join lists
  expect({'{1}', '2'}, 2, '{1,2}')
  expect({'{1,2,3}', '4'}, 2, '{1,2,3,4}')
  expect({'{1,2,3}', '{4}'}, 2, '{1,2,3,4}')
  expect({'{x,y,z}', '{1,2,3}', '4'}, 3, '{x,y,z,1,2,3,4}')
  expect({'{x,y,z}', '1', '{2,3,4}'}, 3, '{x,y,z,1,2,3,4}')
end

function test.rect()
  local a = {x = 10, y = 10, width = 10, height = 10}

  Test.assert(not Rect.is_point_in_rect(a, 0, 0))
  Test.assert(not Rect.is_point_in_rect(a, 30, 30))
  Test.assert(Rect.is_point_in_rect(a, 15, 15))

  Test.assert(not Rect.intersection(a, 0, 0, 5, 5))
  Test.assert(Rect.intersection(a, a.x, a.y, a.width, a.height))
  Test.assert(Rect.intersection(a, 0, 0, 15, 15))
  Test.assert(Rect.intersection(a, 15, 15, 5, 5))
end

Test.run(test)
