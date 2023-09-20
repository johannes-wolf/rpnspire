local apps       = require 'apps.apps'
local choice     = require('dialog.choice').display_sync
local sym        = require('ti.sym')
local ui         = require('ui.shared')

-- Replace
--   E with sym.EE
--   - with sym.NEGATE
local function replace_symbols(str)
   return (str:gsub('E', sym.EE)):gsub('-', sym.NEGATE)
end

local function C(symbol, name, value, unit)
   return { symbol, name, replace_symbols(value), unit }
end

local constants = {
   C("NA",   "Avogadro's number",       "6.02214076E23",    "1/mol"),
   C("k",    "Boltzmann",               "1.380649E-23",     "J/K"),
   C("R",    "Universal gas",           "8.31446261815324", "J/mol K"),
   C("StdT", "Standard temperature",    "273.15",           "K"),
   C("StdP", "Standard pressure",       "101.325",          "kPa"),
   C("c",    "Speed of light Vakuum",   "2.99792458E8",     "m/s"),
   C("e",    "Elemental charge",        "1.60217646E-19",   "Coul"),
   C("me",   "Elektron rest mass",      "9.10938188E-31",   "kg"),
   C("mn",   "Neutron rest mass",       "1.67492716E-27",   "kg"),
   C("mp",   "Proton rest mass",        "1.67262158E-27",   "kg"),
}

local function run_consts(stack)
   local function filter(str)
      if not str then
         return constants
      end

      str = str:gsub('', '.*'):lower()

      local items = {}
      for _, v in ipairs(constants) do
         if v[1]:lower():find(str) or v[2]:lower():find(str) then
            table.insert(items, v)
         end
      end

      return items
   end

   local function cell_constructor(_, _, data)
      local cell = ui.container()

      local symbol = cell:add_child(ui.label( ui.rel { left = 0, width = 40, top = 0, bottom = 0 } ))
      symbol.text = data[1]

      local name = cell:add_child(ui.label( ui.rel { left = 40, right = 0, top = 1, height = '50%' } ))
      name.text = data[2]
      name.align = -1

      local value = cell:add_child(ui.label( ui.rel { left = 40, right = 0, bottom = 1, height = '50%' } ))
      value.text = data[3]
      value.align = -1
      if data[4] then
         value.text = value.text .. ' ' .. data[4]
      end

      return cell
   end

   local result = choice({
      title = 'Constants',
      filter = filter
   }, function(_, _, list)
         list.cell_constructor = cell_constructor
         list.row_size = 36
   end)

   if not result then return end

   local value, unit = result[3], result[4] or ''
   unit = unit:gsub('[a-zA-Z]+', function(match)
         match = (match == 'K' or match == 'C') and sym.DEGREE .. match or match
         return '_'..match
   end)

   stack:push_infix(value .. unit)
end

apps.add('constants', 'Constants lib', run_consts)
