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

_G.on = {}

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
  return str, nil
end
math.eval = math.evalStr

if not unpack then
  _G.unpack = table.unpack
end

require 'rpn'

local function clrscr()
  os.execute('clear')
end

while true do
  print('--- stack ---')
  for idx, item in ipairs(StackView.stack) do
    print(string.format('%02d: %s = %s', idx, item.infix, item.result))
  end
  print('--- input ---')

  io.write('> ')
  local line = io.read()
  if not line or #line == 0 then
    return
  end

  if line == '.r' then
    io.write('Rewrite rule> ')
    local rule = io.read()

    io.write('Rewrite '..rule..' to> ')
    local with = io.read()

    local top = ExpressionTree(StackView:top().rpn)
    local rule_expr = ExpressionTree.from_infix(Infix.tokenize(rule))
    local rewr_expr = ExpressionTree.from_infix(Infix.tokenize(with))
    top:rewrite_subexpr(rule_expr.root, rewr_expr.root)
    StackView:pop()
    StackView:pushExpression(top)
  end

  if line == 's' then
    for _, item in ipairs(StackView.stack) do
      ExpressionTree(item.rpn):debug_print()
    end
  else
    InputView:setText(line)
    InputView:onEnter()
    clrscr()
  end
end
