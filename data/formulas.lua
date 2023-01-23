--- BEGIN: formulas.lua

-- Formula
---@class Formula
---@field title string        Title of the formula
---@field infix string        Infix expression
---@field variables string[]  List of variables used
Formula = class()
function Formula:init(infix, variables)
  self.title = infix
  self.infix = infix
  self.variables = variables
end

-- Solve formula symbolic (call solve on it)
---@param for_var string  Variable to solve for
---@return string | nil
function Formula:solve_symbolic(for_var)
  local dummy_prefix = 'fslvdmy_'
  local withExpr = nil
  for _,key in ipairs(self.variables) do
    if key ~= for_var then
      withExpr = withExpr or ''
      if withExpr:len() > 0 then withExpr = withExpr..' and ' end
      withExpr = withExpr..key..'=' .. dummy_prefix .. key -- Trick to get a symbolic output
    end
  end

  local solveExpr = string.format('solve(%s,%s)%s', self.infix, for_var, withExpr and '|' .. withExpr or '')
  print('info: Formula:solve_symbolic: ' .. solveExpr)
  local res, err = math.evalStr(solveExpr)
  print('  res: ' .. (res or 'nil'))
  print('  err: ' .. (err or 'nil'))

  if res then
    return res:gsub(dummy_prefix, '')
  else
    Error.show(err)
    return
  end
end

local formulas = (function()
    local deg = "\194\176"
    local function v(name, unit, default)
      return {name, unit = unit, default = default}
    end

    local categories = {}
    categories["Resistive Circuits"] = {
      variables = {
        ['p'] = v('Power P', 'W'),
        ['r'] = v('Resistance R', 'Ohm'),
        ['u'] = v('Voltage U', 'V'),
        ['i'] = v('Current I', 'A'),
        ['t'] = v('Time t', 's'),
        ['g'] = v('Conductance G', 'siemens'),
        ['w'] = v('Work W', 'J')
      },
      formulas = {
        Formula('u=r*i',     {'u', 'r', 'i'}),
        Formula('p=u*i',     {'p', 'u', 'i'}),
        Formula('p=(u*u)/r', {'p', 'u', 'r'}),
        Formula('p=u*u*g',   {'p', 'u', 'g'}),
        Formula('p=w/t',     {'w', 'p', 't'}),
        Formula('g=1/r',     {'r', 'g'}),
        Formula('w=u*i*t',   {'w', 'u', 'i', 't'})
      }
    }

    -- Bewegungen
    categories["a=konst Bewegung"] = {
      variables = {
        ['a'] = v('Beschleunigung', 'm/_s^2'),
        ['s'] = v('Strecke', 'm'),
        ['v'] = v('Geschwindigkeit', 'm/_s'),
        ['t'] = v('Zeit', 's'),
        ['s0'] = v('Strecke 0', 'm'),
        ['v0'] = v('Geschwindigkeit 0', 'm/_s'),
        ['t0'] = v('Zeit 0', 's')
      },
      formulas = {
        -- Defaults
        Formula('t0=0_s',    {'t0'}),
        Formula('v0=0_m/_s', {'v0'}),
        Formula('s0=0_m',    {'s0'}),
        -- Formulas
        Formula('v=a*t', {'v', 'a', 't'}),
        Formula('s=a/2*t^2+v0*t0+s0', {'s', 'a', 't', 'v0', 't0', 's0'})
      }
    }

    categories["Mechanik (Kräfte)"] = {
      variables = {
        ['epot'] = v('Potentielle Energie', 'J'),
        ['ekin'] = v('Kinetische Energie', 'J'),
        ['f']  = v('Kraft F',        'N'),
        ['fn'] = v('Normalkraft Fn', 'N'),
        ['m']  = v('Masse m',        'kg'),
        ['m2'] = v('Masse 2 M',      'kg'),
        ['u']  = v('Reibungszahl u'),
        ['p']  = v('Dichte p',       'g*cm^3'),
        ['v']  = v('Volumen V',      'm^3'),
        ['pr'] = v('Druck pr',       ''),
        ['ar'] = v('Fläche A',       'm^2'),
        ['g']  = v('Fallbeschleunigung g', 'm/_s^2', '9.81'),
        ['d']  = v('Federkonstante D'),
        ['s']  = v('Federdehnung s', 'm'),
        ['a']  = v('Beschleunigung', 'm/_s^2'),
        ['h']  = v('Fallhöhe h',     'm'),
      },
      formulas = {
        Formula('f=m*a',             {'f', 'm', 'a'}),
        Formula('f=m*g',             {'f', 'm', 'g'}),
        Formula('f=u*fn',            {'f', 'u', 'fn'}),
        Formula('f=m*v^2/r',         {'f', 'm', 'v', 'r'}),
        Formula('f=d*s',             {'f', 'd', 's'}),
        Formula('f=p*v*g',           {'f', 'p', 'v', 'g'}),
        Formula('f=pr*ar',           {'f', 'pr', 'ar'}),
        Formula('f=9.81*(_m/_s^2)*(m*m2)/r^2', {'f', 'm', 'm2', 'r'}),

        Formula('epot=m*g*h',        {'epot', 'm', 'g', 'h'}),
        Formula('epot=f*h',          {'epot', 'f', 'h'}),
        Formula('ekin=1/2*d*s^2',    {'ekin', 'd', 's'}),
        Formula('ekin=1/2*m*v^2',    {'ekin', 'm', 'v'}),
        --Formula('ekin=1/2*j*w^2',    {'ekin', 'j', 'w'}),
      }
    }
    categories["Triangles"] = {
      variables = {
        ['a']     = v('Side a'),
        ['b']     = v('Side b'),
        ['c']     = v('Side c'),
        ['ha']    = v('Height on a'),
        ['hb']    = v('Height on b'),
        ['hc']    = v('Height on c'),
        ['alpha'] = v('Angle alpha'),
        ['beta']  = v('Angle beta'),
        ['gamma'] = v('Angle gamma'),
        ['p']     = v('Perimeter P'),
        ['s']     = v('Semi-Perimeter s'),
        ['area']  = v('Area A'),
        ['r']     = v('Circumradius r')
      },
      formulas = {
        Formula('alpha'..deg..'+beta'..deg..'+gamma'..deg..'=180', {'alpha', 'beta', 'gamma'}),
        -- Perimeter
        Formula('p=a+b+c', {'a', 'b', 'c', 'p'}),
        Formula('p=8*r*cos(alpha/2)*cos(beta/2)*cos(gamma/2)', {'p', 'r', 'alpha', 'beta', 'gamma'}),
        Formula('s=p/2', {'s', 'p'}),
        Formula('s=(a+b+c)/2', {'s', 'a', 'b', 'c'}),
        -- Law of sine
        Formula('sin(alpha)/a=sin(beta)/b', {'alpha', 'a', 'beta', 'b'}),
        Formula('sin(alpha)/a=sin(gamma)/c', {'alpha', 'a', 'gamma', 'c'}),
        Formula('sin(beta)/b=sin(gamma)/c', {'beta', 'b', 'gamma', 'c'}),
        -- Law of cosine
        Formula('alpha=arccos((b^2+c^2-a^2)/(2*b*c))', {'a', 'b', 'c', 'alpha'}), -- FIXME: TI solves the a^2=... version with an error
        Formula('beta=arccos((a^2+c^2-b^2)/(2*a*c))', {'a', 'b', 'c', 'beta'}),
        Formula('gamma=arccos((b^2+a^2-c^2)/(2*b*a))', {'a', 'b', 'c', 'gamma'}),
        -- Area
        Formula('area=(a*ha)/2', {'area', 'a', 'ha'}),
        Formula('area=(b*hb)/2', {'area', 'b', 'hb'}),
        Formula('area=(c*hc)/2', {'area', 'c', 'hc'}),
        Formula('area=sqrt(s*(s-a)*(s-b)*(s-c))', {'area' ,'s', 'a', 'b', 'c'}), -- Herons formula
        -- Heights
        Formula('ha=c*sin(beta)',  {'ha', 'c', 'beta'}),
        Formula('ha=b*sin(gamma)', {'ha', 'b', 'gamma'}),
        Formula('hb=a*sin(gamma)', {'hb', 'a', 'gamma'}),
        Formula('hb=c*sin(alpha)', {'hb', 'c', 'alpha'}),
        Formula('hc=b*sin(alpha)', {'hc', 'b', 'alpha'}),
        Formula('hc=a*sin(beta)',  {'hc', 'a', 'beta'}),
        -- Circumscribed Circle radius r
        Formula('r=a/(2*sin(alpha))', {'r', 'a', 'alpha'}),
        Formula('r=b/(2*sin(beta))',  {'r', 'b', 'beta'}),
        Formula('r=c/(2*sin(gamma))', {'r', 'c', 'gamma'}),
        Formula('r=(a*b*c)/(4*area)', {'r', 'a', 'b', 'c', 'area'}),
      }
    }
    -- TODO: Add formulas

    return categories
end)()
--- END: formulas.lua
