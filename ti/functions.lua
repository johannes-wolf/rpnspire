local sym = require 'ti.sym'
local t = {}

-- n: Number of args (max)
-- min: Min number of args
-- conv: Conversion function (@>...)
t.tab = {
  ["abs"]             = {n = 1},
  ["amorttbl"]        = {n = 10, min = 4},
  ["angle"]           = {n = 1},
  ["approx"]          = {n = 1},
  ["approxfraction"]  = {n = 1, min = 0, conv = true},
  ["approxrational"]  = {n = 2, min = 1},
  ["arccos"]          = {n = 1},
  ["arccosh"]         = {n = 1},
  ["arccot"]          = {n = 1},
  ["arccoth"]         = {n = 1},
  ["arccsc"]          = {n = 1},
  ["arccsch"]         = {n = 1},
  ["arclen"]          = {n = 4},
  ["arcsec"]          = {n = 1},
  ["arcsech"]         = {n = 1},
  ["arcsin"]          = {n = 1},
  ["arcsinh"]         = {n = 1},
  ["arctan"]          = {n = 1},
  ["arctanh"]         = {n = 1},
  ["augment"]         = {n = 2},
  ["avgrc"]           = {n = 3, min = 2},
  ["bal"]             = {{n = 10, min = 4},
                         {n = 2}},
  ["binomcdf"]        = {{n = 5},
                         {n = 3},
                         {n = 2}},
  ["binompdf"]        = {{n = 2},
                         {n = 3}},
  ["ceiling"]         = {n = 1},
  ["centraldiff"]     = {n = 3, min = 2},
  ["cfactor"]         = {n = 2, min = 1},
  ["char"]            = {n = 1},
  ["charpoly"]        = {n = 2},
  ["colaugment"]      = {n = 2},
  ["coldim"]          = {n = 1},
  ["colnorm"]         = {n = 1},
  ["comdenom"]        = {n = 2, min = 1},
  ["completesquare"]  = {n = 2},
  ["conj"]            = {n = 1},
  ["constructmat"]    = {n = 5},
  ["corrmat"]         = {n = 20, min = 2},
  ["cos"]             = {n = 1},
  ["cos"..sym.POWN1]  = {n = 1},
  ["cosh"]            = {n = 1},
  ["cosh"..sym.POWN1] = {n = 1},
  ["cot"]             = {n = 1},
  ["cot"..sym.POWN1]  = {n = 1},
  ["coth"]            = {n = 1},
  ["coth"..sym.POWN1] = {n = 1},
  ["count"]           = {min = 1},
  ["countif"]         = {n = 2},
  ["cpolyroots"]      = {{n = 1},
                         {n = 2}},
  ["crossp"]          = {n = 2},
  ["csc"]             = {n = 1},
  ["csc"..sym.POWN1]  = {n = 1},
  ["csch"]            = {n = 1},
  ["csch"..sym.POWN1] = {n = 1},
  ["csolve"]          = {{n = 2},
                         {min = 3}},
  ["cumulativesum"]   = {n = 1},
  ["czeros"]          = {n = 2},
  ["dbd"]             = {n = 2},
  ["deltalist"]       = {n = 1},
  ["deltatmpcnv"]     = {n = 2}, -- FIXME: Check n
  ["delvoid"]         = {n = 1},
  ["derivative"]      = {n = 2}, -- FIXME: Check n
  ["desolve"]         = {n = 3},
  ["det"]             = {n = 2, min = 1},
  ["diag"]            = {n = 1},
  ["dim"]             = {n = 1},
  ["domain"]          = {n = 2},
  ["dominantterm"]    = {n = 3, min = 2},
  ["dotp"]            = {n = 2},
  --["e^"]              = {n = 1},
  ["eff"]             = {n = 2},
  ["eigvc"]           = {n = 1},
  ["eigvl"]           = {n = 1},
  ["euler"]           = {n = 7, min = 6},
  ["exact"]           = {n = 2, min = 1},
  ["exp"]             = {n = 1},
  ["expand"]          = {n = 2, min = 1},
  ["expr"]            = {n = 1},
  ["factor"]          = {n = 2, min = 1},
  ["floor"]           = {n = 1},
  ["fmax"]            = {n = 4, min = 2},
  ["fmin"]            = {n = 4, min = 2},
  ["format"]          = {n = 2, min = 1},
  ["fpart"]           = {n = 1},
  ["frequency"]       = {n = 2},
  ["gcd"]             = {n = 2},
  ["geomcdf"]         = {n = 3, min = 2},
  ["geompdf"]         = {n = 2},
  ["getdenom"]        = {n = 1},
  ["getlanginfo"]     = {n = 0},
  ["getlockinfo"]     = {n = 1},
  ["getmode"]         = {n = 1},
  ["getnum"]          = {n = 1},
  ["gettype"]         = {n = 1},
  ["getvarinfo"]      = {n = 1, min = 0},
  ["identity"]        = {n = 1},
  ["iffn"]            = {n = 4, min = 2},
  ["imag"]            = {n = 1},
  ["impdif"]          = {n = 4, min = 3},
  ["instring"]        = {n = 3, min = 2},
  ["int"]             = {n = 1},
  ["integral"]        = {n = 2},
  ["intdiv"]          = {n = 2},
  ["interpolate"]     = {n = 4},
  --["invx^2"]          = {n = 1},
  --["invf"]            = {n = 1},
  ["invnorm"]         = {n = 3, min = 2},
  ["invt"]            = {n = 2},
  ["ipart"]           = {n = 1},
  ["irr"]             = {n = 3, min = 2},
  ["isprime"]         = {n = 1},
  ["isvoid"]          = {n = 1},
  ["lcm"]             = {n = 2},
  ["left"]            = {n = 2, min = 1},
  ["libshortcut"]     = {n = 3, min = 2},
  ["limit"]           = {n = 4, min = 3},
  ["lim"]             = {n = 4, min = 3, def = 4},
  ["linsolve"]        = {n = 2},
  ["ln"]              = {n = 1},
  ["log"]             = {n = 2, min = 1, def = 2},
  ["max"]             = {n = 2},
  ["mean"]            = {n = 2},
  ["median"]          = {n = 2, min = 1},
  ["mid"]             = {n = 3, min = 2},
  ["min"]             = {n = 2},
  ["mirr"]            = {n = 5, min = 4},
  ["mod"]             = {n = 2},
  ["mrow"]            = {n = 3},
  ["mrowadd"]         = {n = 4},
  ["ncr"]             = {n = 2},
  ["nderivative"]     = {n = 3, min = 2},
  ["newlist"]         = {n = 1},
  ["newmat"]          = {n = 2},
  ["nfmax"]           = {n = 4, min = 2},
  ["nfmin"]           = {n = 4, min = 2},
  ["nint"]            = {n = 4},
  ["nom"]             = {n = 2},
  ["norm"]            = {n = 1},
  ["normalline"]      = {n = 3, min = 2},
  ["normcdf"]         = {n = 4, min = 2},
  ["normpdf"]         = {n = 3, min = 1},
  ["npr"]             = {n = 2},
  ["pnv"]             = {n = 4, min = 3},
  ["nsolve"]          = {n = 4, min = 2},
  ["ord"]             = {n = 1},
  ["piecewise"]       = {min = 1},
  ["poisscdf"]        = {n = 3, min = 2},
  ["poisspdf"]        = {n = 2},
  ["polycoeffs"]      = {n = 2, min = 1},
  ["polydegree"]      = {n = 2, min = 1},
  ["polyeval"]        = {n = 2},
  ["polygcd"]         = {n = 2},
  ["polyquotient"]    = {n = 3, min = 2},
  ["polyremainder"]   = {n = 3, min = 2},
  ["polyroots"]       = {n = 2, min = 1},
  ["prodseq"]         = {n = 4}, -- FIXME: Check n
  ["product"]         = {n = 3, min = 0},
  ["propfrac"]        = {n = 2, min = 1},
  ["rand"]            = {n = 1, min = 0},
  ["randbin"]         = {n = 3, min = 2},
  ["randint"]         = {n = 3, min = 2},
  ["randmat"]         = {n = 2},
  ["randnorm"]        = {n = 3, min = 2},
  ["randsamp"]        = {n = 3, min = 2},
  ["real"]            = {n = 1},
  ["ref"]             = {n = 2, min = 1},
  ["remain"]          = {n = 2},
  ["right"]           = {n = 2, min = 1},
  ["rk23"]            = {n = 7, min = 6},
  ["root"]            = {n = 2, min = 1, def = 2},
  ["rotate"]          = {n = 2, min = 1},
  ["round"]           = {n = 2, min = 1},
  ["rowadd"]          = {n = 3},
  ["rowdim"]          = {n = 1},
  ["rownorm"]         = {n = 1},
  ["rowswap"]         = {n = 3},
  ["rref"]            = {n = 2, min = 1},
  ["sec"]             = {n = 1},
  ["sec"..sym.POWN1]  = {n = 1},
  ["sech"]            = {n = 1},
  ["sech"..sym.POWN1] = {n = 1},
  ["seq"]             = {n = 5, min = 4},
  ["seqgen"]          = {n = 7, min = 4},
  ["seqn"]            = {n = 4, min = 1},
  ["series"]          = {n = 4, min = 3},
  ["setmode"]         = {n = 2, min = 1},
  ["shift"]           = {n = 2, min = 1},
  ["sign"]            = {n = 1},
  ["simult"]          = {n = 3, min = 2},
  ["sin"]             = {n = 1},
  ["sin"..sym.POWN1]  = {n = 1},
  ["sinh"]            = {n = 1},
  ["sinh"..sym.POWN1] = {n = 1},
  ["solve"]           = {n = 2},
  ["sqrt"]            = {n = 1, pretty = sym.ROOT},
  [sym.ROOT]          = {n = 1},
  ["stdefpop"]        = {n = 2, min = 1},
  ["stdefsamp"]       = {n = 2, min = 1},
  ["string"]          = {n = 1},
  ["submat"]          = {n = 5, min = 1},
  ["sum"]             = {n = 3, min = 1},
  ["sumif"]           = {n = 3, min = 2},
  ["sumseq"]          = {n = 5, min = 4}, -- FIXME: Check n
  ["system"]          = {min = 1},
  ["tan"]             = {n = 1},
  ["tan"..sym.POWN1]  = {n = 1},
  ["tangentline"]     = {n = 3, min = 2},
  ["tanh"]            = {n = 1},
  ["tanh"..sym.POWN1] = {n = 1},
  ["taylor"]          = {n = 4, min = 3},
  ["tcdf"]            = {n = 3},
  ["tcollect"]        = {n = 1},
  ["texpand"]         = {n = 1},
  ["tmpcnv"]          = {n = 2},
  ["tpdf"]            = {n = 2},
  ["trace"]           = {n = 1},
  ["tvmfv"]           = {n = 7, min = 4},
  ["tvml"]            = {n = 7, min = 4},
  ["tvmn"]            = {n = 7, min = 4},
  ["tvmpmt"]          = {n = 7, min = 4},
  ["tvmpv"]           = {n = 7, min = 4},
  ["unitv"]           = {n = 1},
  ["varpop"]          = {n = 2, min = 1},
  ["varsamp"]         = {n = 2, min = 1},
  ["warncodes"]       = {n = 2},
  ["when"]            = {n = 4, min = 2},
  ["zeros"]           = {n = 2},
  -- Stat Functions
  ["linregmx"]        = {n = 2, statfn = true},
  ["quadreg"]         = {n = 2, statfn = true},
  ["quartreg"]        = {n = 2, statfn = true},
}

-- Returns the number of arguments for the nspire function `nam`.
-- Implementation is hacky, but there seems to be no clean way of
-- getting this information.
---@param nam string   Function name
---@return number | nil
local function tiGetFnArgs(nam)
  local res, err = math.evalStr('getType('..nam..')')
  if err ~= nil or res ~= '"FUNC"' then
    return nil
  end

  local argc = 0
  local arglist = nil
  for _ = 0, 10 do
    res, err = math.evalStr("string("..nam.."("..(arglist or '').."))")
    if err == nil or err == 210 then
      return argc
    elseif err == 930 then
      argc = argc + 1
    else
      return nil
    end

    if arglist then
      arglist = arglist .. ",x"
    else
      arglist = "x"
    end
  end
  return nil
end

function t.query_info(str, builtin_only)
  local name, argc = str:lower(), nil

  if name:find('^%d') then
    return nil
  end

  local info = t.tab[name]
  if info then
    if not argc then
      if #info > 1 then -- Overloaded function
        for _,v in ipairs(info) do -- Take first default
          if v.def then
            argc = v.def
            break
          end
        end
        if not argc then -- Take first overload
          argc = info[1].min or info[1].n
        end
      else
        if info.def then
          argc = info.def
        else
          argc = info.min
        end

        argc = argc or info.n
      end
    end

    return info.pretty or name, argc, info.statfn
  end

  -- User function
  if builtin_only == false then
    argc = tiGetFnArgs(str)
    if argc ~= nil then
      return str, argc
    end
  end

  return nil
end

return t
