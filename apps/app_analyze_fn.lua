local apps   = require 'apps.apps'
local choice = require('dialog.choice').display_sync
local ask_n  = require('dialog.input').display_sync_n
local sym    = require('ti.sym')
local ui     = require('ui.shared')
local lexer  = require 'ti.lexer'
local expr   = require 'expressiontree'
local sym    = require 'ti.sym'

local function each_result(str, fn)
   local tokens = lexer.tokenize(str)
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
  local fn, low, high = table.unpack(ask_n(3, { title = "Analyze ..." }))
  local var = "x"

  local with_str = nil
  if low:len() ~= 0 then
    with_str = (with_str and with_str .. " and ") or "|"
    with_str = with_str .. low  .. ">=" .. var
  end
  if high:len() ~= 0 then
    with_str = (with_str and with_str .. " and ") or "|"
    with_str = with_str .. var .. "<=" .. high
  end

  local function get_zeros(fn, bounds)
    local tab = {}
    each_result(math.evalStr(string.format("zeros(%s,%s)%s", fn, var, bounds or "")),
                function(z)
                   table.insert(tab, z)
                end)
    return tab
  end
  
  local function is_zero(fn, at)
    return math.evalStr(string.format("(%s|%s=%s)=0", fn, var, at)) == "true"
  end
  
  local function has_sign_change(fn, at, delta)
    local delta = "0.000001"
    local is_neg_0 = math.evalStr(string.format("(%s|%s=%s-%s)<0", fn, var, at, delta)) == "true"
    local is_neg_1 = math.evalStr(string.format("(%s|%s=%s+%s)<0", fn, var, at, delta)) == "true"
    if is_neg_0 ~= is_neg_1 then
      return (not is_neg_0 and is_neg_1) and -1 or 1
    end
    return 0
  end
  
  local results = {}

  local zeros = get_zeros(fn, with_str)
  if zeros and #zeros > 0 then
    table.insert(results, {title="Zeros", result="*zeros"})
    
    for _, v in ipairs(zeros) do
      local x = v:infix_string()
      local y = math.evalStr(string.format("%s|%s=%s", fn, var, x))
      table.insert(results, {title=string.format("%s=%s (%s|%s)", var, x, x, y), result=x})
    end
  end


  local r = choice({
    title = 'Results',
    items = results
  })
end

apps.add('analyze', 'Analyze function', run_analyze)
