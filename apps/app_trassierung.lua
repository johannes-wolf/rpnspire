local apps = require 'apps.apps'
local dlg_input = require 'dialog.input'
local dlg_choice = require 'dialog.choice'

-- Generate polynom prototype of specified degree
---@param deg number Polynom degree
---@return string
local function gen_fn_prototype(deg, _c)
  local alpha = {'a', 'b', 'c', 'd', 'e', 'f'}
  _c = _c or deg
  if _c == 0 then return alpha[deg + 1] end
  return alpha[deg - _c + 1]..'*x^'..tostring(_c)..'+'..gen_fn_prototype(deg, _c - 1)
end

-- Sync ask for text input
---@param co thread App thread
---@param title string Dialog title
---@param value string? Initial edit text
---@return string|nil
local function ask_input(title, value)
  return dlg_input.display_sync(title, function(_, edit)
				   if value then
				      edit:set_text(value, true)
				   end
  end)
end

local function run_trassierung(stack)
   local deg = tonumber(ask_input('deg(g)', '3'))
   if not deg then return end

   local proto = ask_input('g(x)', gen_fn_prototype(deg))
   if not proto then return end

   math.evalStr('delvar g')
   math.evalStr(string.format('%s=:g(x)', proto))

   local lo, hi = '0', '0'
   lo = ask_input('low x')
   if not lo then return end
   hi = ask_input('high x')
   if not hi then return end

   local lofn, hifn = 'f1', 'f2'
   lofn = ask_input('low fn', lofn)
   if not lofn then return end
   hifn = ask_input('high fn', hifn)
   if not lofn then return end

   local eqs = {}
   table.insert(eqs, 'g(x)='..lofn..'(x)|x='..lo)
   table.insert(eqs, 'g(x)='..hifn..'(x)|x='..hi)
   table.insert(eqs, 'derivative(g(x),x)='..'derivative('..lofn..'(x),x)|x='..lo)
   table.insert(eqs, 'derivative(g(x),x)='..'derivative('..hifn..'(x),x)|x='..hi)

   if dlg_choice.display_sync('2nd diff?', dlg_choice.yesno) then
      table.insert(eqs, 'derivative(derivative(g(x),x),x)='..'derivative(derivative('..lofn..'(x),x),x)|x='..lo)
      table.insert(eqs, 'derivative(derivative(g(x),x),x)='..'derivative(derivative('..hifn..'(x),x),x)|x='..hi)
   end

   stack:push_infix('system('..table.concat(eqs, ',')..')')

   if dlg_choice.display_sync('solve?', dlg_choice.yesno) then
      -- TODO: ...
   end
end

apps.add('Trassierung g(x)', run_trassierung)
