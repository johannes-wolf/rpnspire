local sym = require 'ti.sym'

local t = {}

-- Unit
-- { ti-symbol, description }

t.tab = {
   ['Length'] = {
      { '_Ang', 'angstrom' },
      { '_au', 'astronomical unit' },
      { '_cm', 'centimetre' },
      { '_dm', 'decimetre' },
      { '_fath', 'fathom' },
      { '_fm', 'fermi' },
      { '_ft', 'foot' },
      { '_in', 'inch' },
      { '_km', 'kilometre' },
      { '_ltyr', 'light year' },
      { '_m', 'metre' },
      { '_\194\181m', 'micron' },
      { '_mi', 'mile' },
      { '_mil', '1/1000 inch' },
      { '_mm', 'millimetre' },
      { '_nm', 'nanometre' },
      { '_Nmi', 'nautical mile' },
      { '_pc', 'parsec' },
      { '_rod', 'rod' },
      { '_yd', 'yard' }
   },
   ['Area'] = {
      { '_acre', 'acre' },
      { '_ha', 'hectare' },
   },
   ['Volume'] = {
      { '_cup', 'cup (8 ounzes)' },
      { '_floz', 'fluid ounce' },
      { '_flozUK', 'British fluid ounce' },
      { '_gal', 'gallon' },
      { '_galUK', 'British gallon' },
      { '_flozUK', 'British fluid ounce' },
      { '_l', 'litre' },
      { '_ml', 'millilitre' },
      { '_pt', 'pint (2 cups)' },
      { '_qt', 'quart (2 pints)' },
      { '_tbsp', 'tablespoon' },
      { '_tsp', 'teaspoon' }
   },
   ['Time'] = {
      { '_day', 'day' },
      { '_hr', 'hour' },
      { '_\194\181s', 'microsecond' },
      { '_min', 'minute' },
      { '_ms', 'millisecond' },
      { '_ns', 'nanosecond' },
      { '_s', 'second' },
      { '_week', 'week' },
      { '_yr', 'year' }
   },
   ['Velocity'] = {
      { '_kph', 'kilometre per hour' },
      { '_mph', 'miles per hour' },
      { '_m/_s', 'meter per second' },
      { '_knot', 'knot' },
   },
   ['accelleration'] = {
      { '_m/_s^2', 'meter per second squared' },
   },
   ['Temperature'] = {
      { '_' .. sym.DEGREE .. 'C', 'degrees celsius' },
      { '_' .. sym.DEGREE .. 'F', 'degrees fahrenheit' },
      { '_' .. sym.DEGREE .. 'K', 'degrees kelvin' },
      { '_' .. sym.DEGREE .. 'R', 'degrees rakine' },
   },
   ['Lumninous Intensity'] = {
      { '_cd', 'candela' },
   },
   ['Amount of Substance'] = {
      { '_mol', 'mole' },
   },
   ['Mass'] = {
      { '_amu', 'atomic mass unit' },
      { '_lb', 'pound' },
      { '_mg', 'milligram' },
      { '_gm', 'gram' },
      { '_kg', 'kilogram' },
      { '_tonne', 'metric ton' },
      { '_mton', 'metric ton' },
      { '_ton', 'ton' },
      { '_oz', 'ounce' },
      { '_slug', 'slug' },
      { '_tonUK', 'long ton' },
   },
   ['Force'] = {
      { '_dyne', 'dyne' },
      { '_kgf', 'kilogram force' },
      { '_lbf', 'pound force' },
      { '_N', 'newton' },
      { '_tf', 'ton force' },
   },
   ['Energy'] = {
      { '_Btu', 'british thermal unit' },
      { '_cal', 'calorie' },
      { '_erg', 'erg' },
      { '_eV', 'electron volt' },
      { '_ftlb', 'foot-pound' },
      { '_J', 'Joule' },
      { '_kJ', 'kilojoule' },
      { '_kcal', 'kilocalorie' },
      { '_kWh', 'kilowatt-hour' },
      { '_latm', 'litre-atmosphere' },
   },
   ['Power'] = {
      { '_hp', 'horsepower' },
      { '_PS', 'metric horsepower' },
      { '_KW', 'kilowatt' },
      { '_W', 'watt' },
   },
   ['Pressure'] = {
      { '_atm', 'atmosphere' },
      { '_bar', 'bar' },
      { '_mbar', 'millibar' },
      { '_inH2O', 'inches of water' },
      { '_inHg', 'inches of mercury' },
      { '_mmH2O', 'millimetres of water' },
      { '_mmHg', 'millimetres of mercury' },
      { '_Pa', 'pascal' },
      { '_kPa', 'kilopascal' },
      { '_psi', 'pounds per square inch' },
      { '_torr', 'millimetres of mercury' },
   },
   ['Viscosity, Kinematic'] = {
      { '_St', 'stokes' },
   },
   ['Viscosity, Dynamic'] = {
      { '_P', 'poise' },
   },
   ['Frequency'] = {
      { '_GHz', 'gigahertz' },
      { '_Hz', 'hertz' },
      { '_kHz', 'kilohertz' },
      { '_MHz', 'megahertz' },
   },
   ['Electric Current'] = {
      { '_A', 'ampere' },
      { '_kA', 'kiloampere' },
      { '_mA', 'milliampere' },
      { '_' .. sym.mu .. 'A', 'microampere' },
   },
   ['Charge'] = {
      { '_coul', 'coulomb' },
   },
   ['Potential'] = {
      { '_kV', 'kilovolt' },
      { '_V', 'volt (si) (eng/us)' },
      { '_mV', 'millivolt' },
      { '_volt', 'volt' },
   },
   ['Resistance'] = {
      { '_ohm', 'ohm' },
      { '_' .. sym.Omega, 'ohm' },
      { '_k' .. sym.Omega, 'kilo-ohm' },
      { '_M' .. sym.Omega, 'mega-ohm' },
   },
   ['Conductance'] = {
      { '_mho', 'mho' },
      { '_mmho', 'millimho' },
      { '_siemens', 'siemens' },
      { '_' .. sym.mu .. 'mho', 'micromho' },
   },
   ['Capacitance'] = {
      { '_F', 'fahrad' },
      { '_nF', 'nanofahrad' },
      { '_pF', 'picofahrad' },
      { '_' .. sym.mu .. 'F', 'microfahrad' },
   },
   ['Mag Field Strength'] = {
      { '_Oe', 'oersted' },
   },
   ['Mag Flux Denstiy'] = {
      { '_Gs', 'gauss' },
      { '_T', 'tesla' },
   },
   ['Magnetic Flux'] = {
      { '_wb', 'weber' },
   },
   ['Inductance'] = {
      { '_henry', 'henry' },
      { '_mH', 'millihenry' },
      { '_nH', 'nanohenry' },
      { '_' .. sym.mu .. 'H', 'nanohenry' },
   }
}

return t
