local apps       = require 'apps.apps'
local ask        = require('dialog.input').display_sync
local choice     = require('dialog.choice').display_sync

local function run_find_n(stack)
   local p = "0.50"
   local op = ">="
   local limit = "1"
   local low = "0"
   local high = "100"
   local r_op = ">="
   local r = "0.50"

   while true do
      local action = choice({
         title = 'Binom - Find n - ' .. string.format('P(X%s%s)%s%s', op, limit, r_op, r),
         items = {
            {align = -1, title = 'p = ' .. p, result = 'p'},
            {align = -1, title = 'X', result = 'x'},
            {align = -1, title = op, result = 'o'},
            {align = -1, title = limit, result = 'l'},
            {align = -1, title = r_op, result = 'r_op'},
            {align = -1, title = r, result = 'r'},
            {align = -1, title = 'n low = ' .. low, result = 'low'},
            {align = -1, title = 'n high = ' .. high, result = 'high'},
            {align =  0, title = 'Find... ', result = 'e'},
         }
      })
      if action == 'p' then
         p = ask {title = 'p', text = p} or p
      elseif action == 'l' or action == 'x' then
         limit = ask {title = 'Limit', text = limit} or limit
      elseif action == 'o' then
         op = choice {
            title = "Operator",
            items = {
               { title = "=",  result = "=" },
               { title = ">=", result = ">=" },
               { title = "<=", result = "<=" },
            }
         } or op
      elseif action == 'r_op' then
         r_op = choice {
            title = "Operator",
            items = {
               { title = "=",  result = "=" },
               { title = ">", result = ">" },
               { title = ">=", result = ">=" },
               { title = "<", result = "<" },
               { title = "<=", result = "<=" },
            }
         } or r_op
      elseif action == 'r' then
         r = ask {title = 'r', text = r} or r
      elseif action == 'low' then
         low = ask {title = 'Lower bound (n)', text = low} or low
      elseif action == 'high' then
         high = ask {title = 'Upper bound (n)', text = high} or high
      elseif action == 'e' then
         break
      else
         return
      end
   end

   local function eval(n)
      local fn
      if op == '=' then
         fn = string.format('binomPdf(%s,%s,%s)', n, p, limit)
      elseif op == '<=' then
         fn = string.format('binomCdf(%s,%s,%s,%s)', n, p, 0, limit)
      elseif op == '>=' then
         fn = string.format('binomCdf(%s,%s,%s,%s)', n, p, limit, n)
      end
      return math.evalStr(fn .. r_op .. r)
   end

   low = tonumber(low) or 0
   high = tonumber(high) or 100
   for n = low, high do
      local res = eval(n)
      if res == 'true' then
         choice{
            title = "Results",
            items = {
               { title = "n = " .. tostring(n - 2) .. "; " .. eval(n - 2) },
               { title = "n = " .. tostring(n - 1) .. "; " .. eval(n - 1) },
               { title = "n = " .. tostring(n + 0) .. "; " .. res },
               { title = "n = " .. tostring(n + 1) .. "; " .. eval(n + 1) },
               { title = "n = " .. tostring(n + 2) .. "; " .. eval(n + 2) },
            }
         }
      end
   end
end

apps.add('binom - find n', 'Binom - Find n', run_find_n)
