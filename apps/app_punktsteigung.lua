local apps   = require 'apps.apps'
local lexer  = require 'ti.lexer'
local expr   = require 'expressiontree'
local ask    = require('dialog.input').display_sync
local choice = require('dialog.choice').display_sync

local function eval(str, fallback)
   return select(1, math.evalStr(str)) or fallback
end

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

local function eval_bool(str)
   local res = eval(str)
   if res == 'false' then return false end
   if res == 'true' then return true end
end

local function run_tangent(stack)
   local fx = ask { title = 'f(x)', text = eval('f1(x)') }

   local x = ask { title = 'x' }
   local y = eval(string.format('(%s)|x=%s', fx, x))
   local m = eval(string.format('derivative(%s,x)|x=%s', fx, x))
   if not m then m = ask { title = 'm' } end

   stack:push_infix(string.format('%s*(x-%s)+%s', m, x, y))
end
apps.add('tangent t(x)', 'Tangent', run_tangent)

local function run_tangent_pt(stack)
   local fx = ask { title = 'f(x)', text = eval('f1(x)') }
   if not fx then return end
   local pt = { x = ask { title = 'x' }, y = ask { title = 'y' } }
   if not (pt.x and pt.y) then return end

   local store = choice('Store results?', {
      { title = 'As t1(x) ...', result = 'tx', seq = {'t'} },
      { title = 'As f2(x) ...', result = 'fx', seq = {'f'} },
      { title = 'No', result = false, seq = {'n'} },
   })

   local fd = eval(string.format('derivative(%s,x)', fx))

   local n = 1
   each_result(string.format('solve((%s)-(%s)=(%s)*(x-(%s)),x)', fx, pt.y, fd, pt.x),
       function(e)
          local x = eval('right('..e:infix_string()..')')
          local y = eval(string.format('(%s)|x=%s', fx, x))
          local m = eval(string.format('derivative(%s,x)|x=%s', fx, x))
          if not m then return end

          local tx = string.format('%s*(x-%s)+%s', m, x, y)
          if eval_bool(string.format('((%s)=%s)|x=%s', tx, pt.y, pt.x)) ~= false then
             stack:push_expr(e)
             stack:push_infix(string.format('%s*(x-%s)+%s', m, x, y))
             if store then
                local fn
                if store == 'tx' then
                   fn = string.format('t%d(x)', n)
                elseif store == 'fx' then
                   fn = string.format('f%d(x)', n+1)
                end

                stack:push_infix(fn)
                stack:push_rstore()
             end
             n = n + 1
          else
             print('Skipping function')
          end
       end)
end
apps.add('tangent t(x) p(x,y)', 'Tangent through p(x,y)', run_tangent_pt)
