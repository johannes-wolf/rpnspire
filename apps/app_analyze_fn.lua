local apps   = require 'apps.apps'
local choice = require('dialog.choice').display_sync
local ask_n  = require('dialog.input').display_sync_n
local sym    = require('ti.sym')
local ui     = require('ui.shared')
local lexer  = require 'ti.lexer'
local expr   = require 'expressiontree'
local sym    = require 'ti.sym'

local function each_result(str, fn)
   local tokens = lexer.tokenize(eval(str))
   local e = tokens and expr.from_infix(tokens)
   if e then
      if e.text == '{' or e.text == 'or' or e.text == 'and' then
         for _, arg in ipairs(e:collect_operands_recursive()) do
            fn(arg)
         end
      else
         fn(e)
      end
   end
end

local function run_analyze(stack)
  local fn, low, high = table.unpack(ask_n(3), { title = "Analyze ..." })
  local var = "x"

  local with_str = nil
  if low:len() ~= 0 then
    with_str = (with_str or "|") .. low  .."<" .. var
  end
  if high:len() ~= 0 then
    with_str = (with_str or "|") .. var .."<" .. high
  end

  local function get_zeros(fn, bounds)
    local tab = {}
    each_result(math.evalStr(string.format("zeros(%s,%s)%s", fn, var, bounds or "")),
                function(z)
                   table.insert(tab, z)
                end)
    return tab
  end

  local zeros = get_zeros(fn, with_str)
  local r = choice({
    title = 'Results',
    items = (function()
      local list = {}
      for i, v in ipairs(zeros) do
        table.insert(list, {
          title=string(v), result=i
        })
      end
      return list
    end)()
  })
end

apps.add('analyze', 'Analyze function', run_analyze)
