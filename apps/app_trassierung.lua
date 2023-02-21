local apps   = require 'apps.apps'
local ask    = require('dialog.input').display_sync
local choice = require('dialog.choice').display_sync

-- Generate polynom prototype of specified degree
---@param deg number Polynom degree
---@return string
local function gen_fn_prototype(deg, _c)
   local alpha = { 'a', 'b', 'c', 'd', 'e', 'f' }
   _c = _c or deg
   if _c == 0 then return alpha[deg + 1] end
   return alpha[deg - _c + 1] .. '*x^' .. tostring(_c) .. '+' .. gen_fn_prototype(deg, _c - 1)
end

local function run_trassierung(stack)
   local deg = tonumber(ask { title = 'deg(g)', text = '3' })
   if not deg then return end

   local proto = ask { title = 'g(x)', text = gen_fn_prototype(deg) }
   if not proto then return end

   math.evalStr('delvar g')
   math.evalStr(string.format('%s=:g(x)', proto))

   local lo, hi = '0', '0'
   lo = ask { title = 'low x' }
   if not lo then return end
   hi = ask { title = 'high x' }
   if not hi then return end

   local lofn, hifn = 'f1', 'f2'
   lofn = ask { title = 'low fn', text = lofn }
   if not lofn then return end
   hifn = ask { title = 'high fn', text = hifn }
   if not lofn then return end

   local eqs = {}
   table.insert(eqs, 'g(x)=' .. lofn .. '(x)|x=' .. lo)
   table.insert(eqs, 'g(x)=' .. hifn .. '(x)|x=' .. hi)
   table.insert(eqs, 'derivative(g(x),x)=' .. 'derivative(' .. lofn .. '(x),x)|x=' .. lo)
   table.insert(eqs, 'derivative(g(x),x)=' .. 'derivative(' .. hifn .. '(x),x)|x=' .. hi)

   if choice { title = '2nd diff?', items = dlg_choice.yesno } then
      table.insert(eqs, 'derivative(derivative(g(x),x),x)=' .. 'derivative(derivative(' .. lofn .. '(x),x),x)|x=' .. lo)
      table.insert(eqs, 'derivative(derivative(g(x),x),x)=' .. 'derivative(derivative(' .. hifn .. '(x),x),x)|x=' .. hi)
   end

   stack:push_infix('system(' .. table.concat(eqs, ',') .. ')')

   if choice { title = 'solve?', items = dlg_choice.yesno } then
      -- TODO: ...
   end
end

apps.add('trassierung g(x)', 'Smooth join fns', run_trassierung)
