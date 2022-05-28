--[[
Copyright (c) 2022 Johannes Wolf <mail@johannes-wolf.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License version 3 as published by
the Free Software Foundation.
]]--

-- luacheck: ignore on

-- Forward declarations
local input_ask_value = nil
local completion_catmatch = nil
local completion_fn_variables = nil
local temp_mode = {} -- Temporary mode override


-- Returns the height of string `s`
local function getStringHeight(s)
  return platform.withGC(function(gc) return gc:getStringHeight(s or "A") end)
end

-- Dump table `o` to string
local function dump(o)
   if type(o) == "table" then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Deep copy a table
local function table_clone(t)
    if type(t) ~= 'table' then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then
            target[k] = table_clone(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
    return target
end

-- Copy certain table fields
local function table_copy_fields(source, fields, target)
  target = target or {}
  for _,v in ipairs(fields) do
    if type(source[v]) == 'table' then
      target[v] = table_clone(source[v])
    else
      target[v] = source[v]
    end
  end
  return target
end

-- Remove quotes from `str`
function string.unquote(str)
  if str:sub(1, 1) == '"' and
     str:sub(-1)   == '"' then
    return str:sub(2, -2)
  end
  return str
end

function string.ulen(str)
  return select(2, str:gsub('[^\128-\193]', ''))
end


-- Rectangle utility functions
Rect = {}
function Rect.is_point_in_rect(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.width and
         y >= rect.y and x <= rect.y + rect.height
end

function Rect.intersection(r, x, y, width, height)
  local top_left = {
      x = math.max(r.x, x),
      y = math.max(r.y, y)
  }
  local bottom_right = {
      x = math.min(r.x + r.width, x + width),
      y = math.min(r.y + r.height, y + height)
  }

  if bottom_right.x > top_left.x and
     bottom_right.y > top_left.y then
    return {
      x = top_left.x,
      y = top_left.y,
      width = bottom_right.x - top_left.x,
      height = bottom_right.y - top_left.y
    }
  end
  return nil
end


-- Prefix
Trie = {}

-- Build a prefix tree from `tab` keys
function Trie.build(tab)
  local trie = {}
  for key, _ in pairs(tab) do
    local root = trie
    for i=1,#key do
      local k = string.sub(key, i, i)
      root[k] = root[k] or {}
      root = root[k]
    end
    root['@LEAF@'] = true
  end
  return trie
end

function Trie.find(str, tab, pos)
  assert(str)
  assert(tab)
  local i, j = (pos or 1), (pos or 1) - 1
  local match = nil
  while tab do
    j = j+1
    tab = tab[str:sub(j, j)]
    if tab and tab['@LEAF@'] then
      match = {i, j, str:sub(i, j)}
    end
  end

  if match and match[1] then
    return unpack(match)
  end
  return nil
end

-- Themes
local theme = {
  ["light"] = {
    rowColor = 0xFFFFFF,
    altRowColor = 0xEEEEEE,
    selectionColor = 0xDFDFFF,
    fringeTextColor = 0xAAAAAA,
    menuActiveColor = 0x88FF98,
    textColor = 0,
    cursorColor = 0xEE0000,
    cursorColorAlg = 0x0000FF,
    cursorColorAlt = 0x999999,
    backgroundColor = 0xFFFFFF,
    borderColor = 0,
    errorBackgroundColor = 0xEE0000,
    errorTextColor = 0xffffff,
  },
  ["nordlike"] = {
    rowColor = 0x2e3440,
    altRowColor = 0x323844,
    selectionColor = 0x636c7e,
    menuActiveColor = 0x636c7e,
    fringeTextColor = 0x4c566a,
    textColor = 0xd8dee9,
    cursorColor = 0xd8dee9,
    cursorColorAlg = 0x0000FF,
    cursorColorAlt = 0x777777,
    backgroundColor = 0x2e3440,
    borderColor = 0x1b2232,
    errorBackgroundColor = 0xbf616a,
    errorTextColor = 0xd8dee9,
  },
  ["dark"] = {
    rowColor = 0x444444,
    altRowColor = 0x222222,
    selectionColor = 0xEE0000,
    menuActiveColor = 0x00EE00,
    fringeTextColor = 0xAAAAAA,
    textColor = 0xFFFFFF,
    cursorColor = 0xEE0000,
    cursorColorAlg = 0xEE00EE,
    cursorColorAlt = 0x999999,
    backgroundColor = 0x111111,
    borderColor = 0x888888,
    errorBackgroundColor = 0x0000ff,
    errorTextColor = 0x000000,
  },
}

-- Global options
local options = {
  autoClose = true,      -- Auto close parentheses
  autoKillParen = true,  -- Auto kill righthand paren when killing left one
  showFringe = true,     -- Show fringe (stack number)
  showExpr = true,       -- Show stack expression (infix)
  autoPop = true,        -- Pop stack when pressing backspace
  theme = "light",       -- Well...
  cursorWidth = 2,       -- Width of the cursor
  mode = "RPN",          -- What else
  saneHexDigits = false, -- Whether to disallow 0hfx or not (if not, 0hfx produces 0hf*x)
  smartComplete = true,  -- Try to be smart when completing
  spaceAsEnter = false,  -- Space acts as enter in RPN mode
  autoAns = true,        -- Auto insert @1 in ALG mode
  maxUndo = 20,          -- Max num of undo steps
}

-- Get the current mode
local function get_mode()
  return (temp_mode and temp_mode[#temp_mode]) or options.mode
end

-- Oveeride the current mode
local function push_temp_mode(mode)
  temp_mode = temp_mode or {}
  table.insert(temp_mode, mode)
end

local function pop_temp_mode()
  table.remove(temp_mode, #temp_mode)
end


local ParenPairs = {
  ['('] = {')', true},
  [')'] = {'(', false},
  ['{'] = {'}', true},
  ['}'] = {'{', false},
  ['['] = {']', true},
  [']'] = {'[', false},
  ['"'] = {'"', true},
  ["'"] = {"'", true},
}

Sym = {
  NEGATE  = "\226\136\146",
  STORE   = "→",
  ROOT    = "\226\136\154",
  NEQ     = "≠",
  LEQ     = "≤",
  GEQ     = "≥",
  LIMP    = "⇒",
  DLIMP   = "⇔",
  RAD     = "∠",
  TRANSP  = "",
  DEGREE  = "\194\176",
  CONVERT = "\226\150\182",
  EE      = "\239\128\128",
  POWN1   = "\239\128\133", -- ^-1
}

local operators = {
  --[[                 string, lvl, #, side, assoc, aggressive-assoc ]]--
  -- Parentheses
  ["#"]             = {nil,     18, 1, -1},
  --
  -- Function call
  -- [" "]             = {nil, 17, 1,  1}, -- DEGREE/MIN/SEC
  ["!"]             = {nil,     17, 1,  1},
  ["%"]             = {nil,     17, 1,  1},
  [Sym.RAD]         = {nil,     17, 1,  1},
  -- [" "]             = {nil, 17, 1,  1}, -- SUBSCRIPT
  ["@t"]            = {Sym.TRANSP, 17, 1, 1},
  [Sym.TRANSP]      = {nil,     17, 1,  1},
  --
  ["^"]             = {nil,     16, 2,  0, 'r', true}, -- Matching V200 RPN behavior
  --
  ["(-)"]           = {Sym.NEGATE,15,1,-1},
  [Sym.NEGATE]      = {nil,     15, 1, -1},
  --
  ["&"]             = {nil,     14, 2,  0},
  --
  ["*"]             = {nil,     13, 2,  0},
  ["/"]             = {nil,     13, 2,  0, 'l'},
  --
  ["+"]             = {nil,     12, 2,  0},
  ["-"]             = {nil,     12, 2,  0, 'l'},
  --
  ["="]             = {nil,     11, 2,  0, 'r'},
  [Sym.NEQ]         = {nil,     11, 2,  0, 'r'},
  ["/="]            = {Sym.NEQ, 11, 2,  0, 'r'},
  ["<"]             = {nil,     11, 2,  0, 'r'},
  [">"]             = {nil,     11, 2,  0, 'r'},
  [Sym.LEQ]         = {nil,     11, 2,  0, 'r'},
  ["<="]            = {Sym.LEQ, 11, 2,  0, 'r'},
  [Sym.GEQ]         = {nil,     11, 2,  0, 'r'},
  [">="]            = {Sym.GEQ, 11, 2,  0, 'r'},
  --
  ["not"]           = {"not ",  10, 1, -1},
  ["and"]           = {" and ", 10, 2,  0},
  ["or"]            = {" or ",  10, 2,  0},
  --
  ["xor"]           = {" xor ",  9, 2,  0},
  ["nor"]           = {" nor ",  9, 2,  0},
  ["nand"]          = {" nand ", 9, 2,  0},
  --
  [Sym.LIMP]        = {nil,      8, 2,  0, 'r'},
  ["=>"]            = {Sym.LIMP, 8, 2,  0, 'r'},
  --
  [Sym.DLIMP]       = {nil,      7, 2,  0, 'r'},
  ["<=>"]           = {Sym.DLIMP,7, 2,  0, 'r'},
  --
  ["|"]             = {nil,      6, 2,  0},
  --
  [Sym.STORE]       = {nil,      5, 2,  0, 'r'},
  ["=:"]            = {Sym.STORE,5, 2,  0, 'r'},
  [":="]            = {nil,      5, 2,  0, 'r'},
  
  [Sym.CONVERT]     = {nil, 1, 2, 0},
  ["@>"]            = {Sym.CONVERT, 1, 2,  0}
}
local operators_trie = Trie.build(operators)

-- Query operator information
local function queryOperatorInfo(s)
  local tab = operators[s]
  if tab == nil then return nil end
  
  local str, lvl, args, side, assoc, aggro = unpack(tab)
  return (str or s), lvl, args, side, assoc, aggro
end

-- Returns the number of arguments for the nspire function `nam`.
-- Implementation is hacky, but there seems to be no clean way of
-- getting this information.
local function tiGetFnArgs(nam)
  local res, err = math.evalStr("getType("..nam..")")
  if err ~= nil or res ~= "\"FUNC\"" then
    return nil
  end

  local argc = 0
  local arglist = ""
  for i=0,10 do
    res, err = math.evalStr("string("..nam.."("..arglist.."))")
    if err == nil or err == 210 then
      return argc
    elseif err == 930 then
      argc = argc + 1
    else
      return nil
    end
    
    if arglist:len() > 0 then
      arglist = arglist .. ",x"
    else
      arglist = arglist .. "x"
    end
  end
  return nil
end

-- n: Number of args (max)
-- min: Min number of args
-- conv: Conversion function (@>...)
local functions = {
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
  ["cos"..Sym.POWN1]  = {n = 1},
  ["cosh"]            = {n = 1},
  ["cosh"..Sym.POWN1] = {n = 1},
  ["cot"]             = {n = 1},
  ["cot"..Sym.POWN1]  = {n = 1},
  ["coth"]            = {n = 1},
  ["coth"..Sym.POWN1] = {n = 1},
  ["count"]           = {min = 1},
  ["countif"]         = {n = 2},
  ["cpolyroots"]      = {{n = 1},
                         {n = 2}},
  ["crossp"]          = {n = 2},
  ["csc"]             = {n = 1},
  ["csc"..Sym.POWN1]  = {n = 1},
  ["csch"]            = {n = 1},
  ["csch"..Sym.POWN1] = {n = 1},
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
  ["sec"..Sym.POWN1]  = {n = 1},
  ["sech"]            = {n = 1},
  ["sech"..Sym.POWN1] = {n = 1},
  ["seq"]             = {n = 5, min = 4},
  ["seqgen"]          = {n = 7, min = 4},
  ["seqn"]            = {n = 4, min = 1},
  ["series"]          = {n = 4, min = 3},
  ["setmode"]         = {n = 2, min = 1},
  ["shift"]           = {n = 2, min = 1},
  ["sign"]            = {n = 1},
  ["simult"]          = {n = 3, min = 2},
  ["sin"]             = {n = 1},
  ["sin"..Sym.POWN1]  = {n = 1},
  ["sinh"]            = {n = 1},
  ["sinh"..Sym.POWN1] = {n = 1},
  ["solve"]           = {n = 2},
  ["sqrt"]            = {n = 1, pretty = Sym.ROOT},
  [Sym.ROOT]          = {n = 1},
  ["stdefpop"]        = {n = 2, min = 1},
  ["stdefsamp"]       = {n = 2, min = 1},
  ["string"]          = {n = 1},
  ["submat"]          = {n = 5, min = 1},
  ["sum"]             = {n = 3, min = 1},
  ["sumif"]           = {n = 3, min = 2},
  ["sumseq"]          = {n = 5, min = 4}, -- FIXME: Check n
  ["system"]          = {min = 1},
  ["tan"]             = {n = 1},
  ["tan"..Sym.POWN1]  = {n = 1},
  ["tangentline"]     = {n = 3, min = 2},
  ["tanh"]            = {n = 1},
  ["tanh"..Sym.POWN1] = {n = 1},
  ["taylor"]          = {n = 4, min = 3},
  ["tcdf"]            = {n = 3},
  ["tcollect"]        = {n = 1},
  ["texpand"]         = {n = 1},
  ["tmpcnv"]          = {n = 2},
  ["deltatmpcnv"]     = {n = 2},
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
}

--[[
Function info table
  str, args
--]]
local function functionInfo(s, builtinOnly)
  local name, argc = s:lower(), nil
  
  if name:find('^%d') then
    return nil
  end
  
  local info = functions[name]
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

    return info.pretty or name, argc
  end

  -- User function
  if builtinOnly == false then
    argc = tiGetFnArgs(s)
    if argc ~= nil then
      return s, argc
    end  
  end
  
  return nil
end

local errorCodes = {
  [10]  = "Function did not return a value",
  [20]  = "Test did not resolve to true or false",
  [40]  = "Argument error",
  [50]  = "Argument missmatch",
  [60]  = "Argument must be a bool or int",
  [70]  = "Argument must be a decimal",
  [90]  = "Argument must be a list",
  [100] = "Argument must be a matrix",
  [130] = "Argument must be a string",
  [140] = "Argument must be a variable name",
  [160] = "Argument must be an expression",
  [180] = "Break",
  [230] = "Dimension",
  [235] = "Dimension error",
  [250] = "Divide by zero",
  [260] = "Domain error",
  [270] = "Duplicate variable name",
  [300] = "Expected 2 or 3-element list or matrix",
  [310] = "Argument must be an equation with a single var",
  [320] = "First argument must be an equation",
  [345] = "Inconsistent units",
  [350] = "Index out of range",
  [360] = "Indirection string is not a valid var name",
  [380] = "Undefined ANS",
  [390] = "Invalid assignment",
  [400] = "Invalid assignment value",
  [410] = "Invalid command",
  [430] = "Invalid for current mode settings",
  [435] = "Invalid guess",
  [440] = "Invalid implied mulitply",
  [565] = "Invalid outside programm",
  [570] = "Invalid pathname",
  [575] = "Invalid polar complex",
  [580] = "Invalid programm reference",
  [600] = "Invalid table",
  [605] = "Invalid use of units",
  [610] = "Invalid variable name or local statement",
  [620] = "Invalid variable or function name",
  [630] = "Invalid variable reference",
  [640] = "Invalid vector syntax",
  [670] = "Low memory",
  [672] = "Resource exhaustion",
  [673] = "Resource exhaustion",
  [680] = "Missing (",
  [690] = "Missing )",
  [700] = "Missing *",
  [710] = "Missing [",
  [720] = "Missing ]",
  [750] = "Name is not a function or program",
  [780] = "No solution found",
  [800] = "Non-real result",
  [830] = "Overflow",
  [860] = "Recursion too deep",
  [870] = "Reserved name or system variable",
  [900] = "Argument error",
  [910] = "Syntax error",
  [920] = "Text ont found",
  [930] = "Too few arguments",
  [940] = "Too many arguments",
  [950] = "Too many subscripts",
  [955] = "Too many undefined variables",
  [960] = "Variable is not defined",
  -- TODO: ...
}


--[[
  Interactive Session Stack

  Capsules an coroutine for representing an interactive function.
  Only one interactive function can be active at the same time.
]]--
local interactiveStack = {}
local function interactive_get()
  for i=#interactiveStack,1,-1 do
    if interactiveStack[i] and coroutine.status(interactiveStack[i]) ~= 'dead' then
      return interactiveStack[i]
    end
    table.remove(interactiveStack, i)
  end
end

local function interactive_start(fn)
  table.insert(interactiveStack, coroutine.create(fn))
  coroutine.resume(interactive_get())
  print('info: Started interactive #' .. (#interactiveStack))
end

local function interactive_resume()
  local co = interactive_get()
  if co then
    coroutine.resume(co)
  end
end

local function interactive_yield()
  local co = interactive_get()
  if co then
    coroutine.yield(co)
  end
end

local function interactive_kill()
  table.remove(interactiveStack, #interactiveStack)
end

--[[
  Helper function for using `input_ask_value` in an interactive session.
--]]--
local function interactive_input_ask_value(widget, onEnter, onCancel, onSetup)
  input_ask_value(widget, function(value)
    if onEnter then onEnter(value) end
    interactive_resume()
  end, function()
    if onCancel then onCancel() end
    interactive_kill()
  end, function(widget)
    if onSetup then onSetup(widget) end
  end)
  interactive_yield()
end


-- Macro
Macro = class()
function Macro:init(steps)
  self.steps = steps or {}
end

function Macro:execute()
  recordUndo()
  
  local stackTop = stack:size()
  
  local function clrbot(n)
    n = tonumber(n)
    for i=stack:size() -n,stackTop+1,-1 do
      stack:pop(i)
    end
  end
    
  local function exec_step(step)
    if step:find('^@%a+') then
      step = step:usub(2)
      local tokens = step:split(':')
      local cmd = tokens[1]
      
      local function numarg(n, def)
        n = n + 1
        return tokens >= n and tonumber(tokens[n]) or def
      end
      
      if cmd == 'clrbot' then
        -- Clear all but top n args
        clrbot(tokens[2] or 1)
      elseif cmd == 'dup' then
        stack:dup(numarg(1, 1))
      elseif cmd == 'simp' then
        stack:pushInfix(stack:pop().result)
      elseif cmd == 'label' then
        if stack:size() > 0 then
          stack:top().label = tokens[2]
        end
      elseif cmd == 'input' then
        local prefix = tokens[2] or ''
        
        interactive_input_ask_value(input, function(value)
          stack:pushInfix(value)
          interactive_resume()
        end, function()
          undo()
        end, function(widget)
          widget:setText('', prefix)
        end)
      end
    else
      stack:pushInfix(step)
    end
    
    return true
  end
  
  return interactive_start(function()
    for _,v in ipairs(self.steps) do
      if not exec_step(v) then
        undo()
        break
      end
    end
    platform.window:invalidate()
  end)
end


--[[

]]--
Formula = class()
function Formula:init(infix, variables)
  self.title = infix -- TODO: Provide helpful names
  self.infix = infix
  self.variables = variables
end

function Formula:variables()
  local res = {}
  for k,_ in pairs(self.variables) do
    table.insert(res, k)
  end

  return res
end

function Formula:solve_symbolic(for_var)
  local dummy_prefix = 'dummysolvesym_'
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
  end
end

local formulas = (function()
  local function v(name, unit)
    return {name, unit = unit}
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
  categories["Triangles"] = {
    variables = {
      ['a']     = v('Side a'),
      ['b']     = v('Side b'),
      ['c']     = v('Side c'),
      ['ha']    = v('Height on a'),
      ['hb']    = v('Height on a'),
      ['hc']    = v('Height on a'),
      ['alpha'] = v('Angle alpha'),
      ['beta']  = v('Angle beta'),
      ['gamma'] = v('Angle gamma'),
      ['p']     = v('Perimeter P'),
      ['s']     = v('Semi-Perimeter s'),
      ['area']  = v('Area A'),
      ['r']     = v('Circumradius r')
    },
    formulas = {
      Formula('alpha'..Sym.DEGREE..'+beta'..Sym.DEGREE..'+gamma'..Sym.DEGREE..'=180', {'alpha', 'beta', 'gamma'}),
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
      Formula('r=a/(2*sin(alpha)',  {'r', 'a', 'alpha'}),
      Formula('r=b/(2*sin(beta)',   {'r', 'b', 'beta'}),
      Formula('r=c/(2*sin(gamma)',  {'r', 'c', 'gamma'}),
      Formula('r=(a*b*c)/(4*area)', {'r', 'a', 'b', 'c', 'area'}),
    }
  }
  -- TODO: Add formulas

  return categories
end)()

-- Returns a list of {var, formula} to solve in order to solve for `want_var`.
-- Parameters
--   category   Formula category table
--   want_var   Variable name(s) [string or table]
--   have_vars  List of {var, value} pairs
function build_formula_solve_queue(category, want_var, have_vars)
  local formulas, variables = category.formulas, category.variables
  local var_to_formula = {}
  
  if type(want_var) == 'string' then
    want_var = {want_var}
  end

  -- Insert all given arguments as pseudo formulas
  for _,v in ipairs(have_vars) do
    local name, value = unpack(v)
    var_to_formula[name:lower()] = Formula(name .. '=' .. value, {})
  end

  -- Returns a variable name the formula is solvable for
  -- with the current set of known variables
  local function get_solvable_for(formula)
    local missing = nil
    for _,v in ipairs(formula.variables) do
      if not var_to_formula[v:lower()] then
        if missing then
          return nil
        end
        missing = v:lower()
      end
    end
    return missing
  end
  
  for i=1,50 do -- Artificial search limit
    local found = false
    for _,v in ipairs(formulas) do
      local var = get_solvable_for(v)
      if var then
        var_to_formula[var] = v
        found = true
      end
    end
    if not found then
      break
    end
  end

  -- Build list of formulas that need to be solved
  local solve_queue = {}

  local function add_formula_to_queue(formula, solve_for)
    if not formula then return end 

    -- Remove prev element
    for i,v in ipairs(solve_queue) do
      if v[1] == solve_for and v[2] == formula then
        table.remove(solve_queue, i)
        break
      end
    end

    -- Insert at top
    table.insert(solve_queue, 1, {solve_for, formula})
    
    for _,v in ipairs(formula.variables) do
      if v ~= solve_for then
        add_formula_to_queue(var_to_formula[v], v)
      end
    end
  end

  for _,v in ipairs(want_var) do
    print('info: adding wanted var ' .. v .. ' to queue')
    add_formula_to_queue(var_to_formula[v], v)
  end

  print('info: formula solve queue:')
  for idx,v in ipairs(solve_queue) do
    local solve_for, formula = unpack(v)
    print(string.format('  %02d %s', idx, solve_for ..  ' = ' .. formula:solve_symbolic(solve_for)))
  end

  return solve_queue
end

local function solve_formula_interactive(category)
  interactive_start(function()
    local var_in_use = {}
    local solve_for, solve_with = nil, {}
    
    local function interactive_ask_variable_menu(prefix)
      prefix = prefix or ''
      local ret = nil
    
      local var_menu = {}
      for name,info in pairs(category.variables) do
        if not var_in_use[name] then
          table.insert(var_menu, {
            prefix .. info[1], function()
              ret = name
              interactive_resume()
            end
          })
        end
      end
      table.insert(var_menu, {
        'Solve [esc]', function()
          ret = nil
          interactive_resume()
        end
      })
      
      menu:present(focus, var_menu, nil, function()
        interactive_resume()
      end)
      
      interactive_yield()
      return ret
    end
    
    local function interactive_ask_variable(prefix)
      local ret = ''
      
      local function complete_unset(prefix)
        local candidates = {}
        for name,_ in pairs(category.variables) do
          if not var_in_use[name] then
            table.insert(candidates, name)
          end
        end
        
        return completion_catmatch(candidates, prefix)
      end
    
      interactive_input_ask_value(input, function(value)
        if value == 'solve' or value:ulen() == 0 then
          ret = nil
        else
          ret = value
        end
      end, nil, function(widget)
        widget:setText('', prefix)
        widget.completionFun = complete_unset
      end)
      
      return ret
    end
    
    solve_for = interactive_ask_variable('Solve for:')
    if not solve_for then
      return
    end
    
    -- Solve for multiple
    if solve_for:find(',') then
      solve_for = string.split(solve_for, ',')
    else
      solve_for = {solve_for}
    end
    
    -- Mark as in use
    for _,v in ipairs(solve_for) do
      var_in_use[solve_for] = true
    end

    while not empty_input do
      local set_var = interactive_ask_variable('Set [empty if done]:')
      if not set_var then
        break
      end

      local var_info = category.variables[set_var]
      interactive_input_ask_value(input, function(value)
        table.insert(solve_with, {set_var, value})
      end, function()
        canceled = true
      end, function(widget)
        -- Auto append the matching base unit for convenience
        local template = ''
        if var_info.unit then
          template = '*_' .. var_info.unit
        end
        widget:setText(template, var_info[1] .. '=')
        widget:setCursor(0)
        --widget:selAll()
      end)
      
      -- Mark as set
      var_in_use[set_var] = true
    end
    
    local solve_queue = build_formula_solve_queue(category, solve_for, solve_with)
    if solve_queue then
      local infix_steps = {}
      for _,v in ipairs(solve_queue) do
        local var, formula = unpack(v)
        table.insert(infix_steps, {
          var = var,
          infix = tostring(formula:solve_symbolic(var):gsub('=', ':='))
        })
      end
      
      recordUndo()
      for _,step in ipairs(infix_steps) do
        if not stack:pushInfix(step.infix) then
          undo()
          break
        end
        
        local var_info = category.variables[step.var]
        if var_info then
          stack:top().label = string.format('%s (%s)', var_info[1], stack:top().infix)
        end
      end
    else
      Error.show('Can not solve')
    end
  end)
end


-- Lexer for TI math expressions being as close to the original as possible
Infix = {}
function Infix.tokenize(input)
  local function operator(input, i)
    return Trie.find(input, operators_trie, i)
  end
  
  local function ans(input, i)
    return input:find('^(@[0-9]+)', i)
  end
  
  local function syntax(input, i)
    return input:find('^([(){}[%],])', i)
  end

  local function word(input, i)
    local li, lj, ltoken = input:find('^([%a\128-\255][_%w\128-\255]*%.[%a\128-\255][_%w\128-\255]*)', i)
    if not li then
      return input:find('^([%a\128-\255][_%w\128-\255]*)', i)
    end
    return li, lj, ltoken
  end

  local function unit(input, i)
    return input:find('^(_[%a\128-\255]+)', i)
  end

  local function number(input, pos)
    -- Binary or hexadecimal number
    local i, j, prefix = input:find('^0([bh])', pos)
    if i then
      if prefix == "b" then
        i, j, token = input:find('^([10]+)', j+1)
      elseif prefix == "h" then
        i, j, token = input:find('^([%x]+)', j+1)

        -- Non standard behaviour
        if options.saneHexDigits and input:find('^[%a%.]', j+1) then
          return nil
        end
      else
        return
      end
      if token then
        token = "0"..prefix..token
      end

      -- Fail if followed by additional digit or point
      if input:find('^[%d%.]', j+1) then
        return nil
      end
    else
      -- Normal number
      i, j, token = input:find('^(%d*%.?%d*)', pos)
      
      -- '.' is not a number
      if i and (token == '' or token == '.') then i = nil end
      
      -- SCI notation exponent
      if i then
        local ei, ej, etoken = input:find('^('..Sym.EE..'[%-%+]?%d+)', j+1)
        if not ei then
          -- Sym.NEGATE is a multibyte char, so we can not put it into the char-class above
          ei, ej, etoken = input:find('^('..Sym.EE..Sym.NEGATE..'%d+)', j+1)
        end
        if ei then
          j, token = ej, token..etoken
        end
      end

      -- Fail if followed by additional digit or point
      if input:find('^[%d%.]', j+1) then
        return nil
      end
    end

    return i, j, token
  end

  local function str(input, i)
    if input:sub(i, i) == '"' then
      local j = input:find('"', i+1)
      if j then
        return i, j, input:sub(i, j)
      end
    end
  end

  local function whitespace(input, i)
    return input:find('^%s+', i)
  end

  local function isImplicitMultiplication(token, kind, top)
    if not top then return false end
    
    if kind == 'operator' or
       top[2] == 'operator' then
       return false
    end
    
    -- 1(...)
    if (token == '(' or token == '{' or token == '[') and
       (top[2] == 'number' or top[2] == 'unit' or top[2] == 'string' or top[1] == ')') then
      return true
    end
    
    -- (...)1
    if kind ~= 'syntax' then
      if top[2] ~= 'syntax' or top[1] == ')' or top[1] == '}' or top[1] == ']' then
        return true
      end
    end
  end

  local matcher = {
    {fn=operator,   kind='operator'},
    {fn=syntax,     kind='syntax'},
    {fn=ans,        kind='ans'},
    {fn=number,     kind='number'},
    {fn=unit,       kind='unit'},
    {fn=word,       kind='word'},
    {fn=str,        kind='string'},
    {fn=whitespace, kind='ws'},
  }

  local tokens = {}
 
  local pos = 1
  while pos <= #input do
    local oldPos = pos
    for _,m in ipairs(matcher) do
      local i, j, token = m.fn(input, pos)
      if i then
        if token then
          if isImplicitMultiplication(token, m.kind, tokens[#tokens]) then
            table.insert(tokens, {'*', 'operator'})
          end
          if token == '(' and #tokens > 0 and tokens[#tokens][2] == 'word' then
            tokens[#tokens][2] = 'function'
          end
          table.insert(tokens, {token, m.kind})
        end
        pos = j+1
        break
      end
    end
    
    if pos <= oldPos then
      print("error: Infix.tokenize no match at "..pos.." '"..input:usub(pos).."' ("..input:byte(pos)..")")
      return nil, pos
    end
  end

  return tokens
end


-- RPN Expression stack for transforming from and to infix notation
RPNExpression = class()

function RPNExpression:init(stack)
  self.stack = stack or {}
end

function RPNExpression:fromInfix(tokens)
  if not tokens then
    self.stack = {}
    return nil
  end

  local stack, result = {}, {}

  -- Forward declarations
  local beginFunction = nil
  local beginList = nil
  local beginMatrix = nil

  -- State
  local listLevel = 0
  local matrixLevel = 0

  local idx = 1
  local function next()
    local token = idx <= #tokens and tokens[idx] or nil
    idx = idx + 1
    return token
  end

  local function testTop(kind)
    return #stack > 0 and stack[#stack][2] == kind or nil
  end
  
  local function popTop()
    table.insert(result, table.remove(stack, #stack))
  end
  
  local function popUntil(value)
    while #stack > 0 do
      if stack[#stack][1] == value then
        return true
      end
      table.insert(result, table.remove(stack, #stack))
    end
    return false
  end

  local function handleOperator(sym)
    local _, prec, _, _, assoc = queryOperatorInfo(sym)

    while testTop('operator') do
      local topName, top_prec, _, _, _ = queryOperatorInfo(stack[#stack][1])
      if (assoc ~= 'r' and prec <= top_prec) or
         (assoc == 'r' and prec < top_prec) then
        popTop()
      else
        break
      end
    end
    table.insert(stack, {sym, 'operator'})
  end
  
  local function handleAns(sym)
    local n = tonumber(sym:sub(2))
    if n then
      if not Error.assertStackN(n) then
        return
      end
      
      local rpn = _G.stack.stack[#_G.stack.stack - n + 1].rpn
      for _,v in ipairs(rpn) do
        table.insert(result, v)
      end
    end
  end

  local function handleDefault(value, kind)
    assert(value)
    assert(kind)

    if kind == 'number' or kind == 'word' or kind == 'unit' or kind == 'string' then
      table.insert(result, {value, kind})
    elseif kind == 'function' then
      beginFunction(value)
    elseif kind == 'syntax' and value == '(' then
      table.insert(stack, {value, kind})
    elseif kind == 'syntax' and value == ')' then
      if popUntil('(') then
        table.remove(stack, #stack)
      else
        print("error: RPNExpression.fromInfix missing '('")
      end
    elseif kind == 'syntax' and value == '{' then
      table.insert(stack, {value, kind})
      listLevel = listLevel + 1
      if not beginList() then return end
      listLevel = listLevel - 1
    elseif kind == 'syntax' and value == '[' then
      table.insert(stack, {value, kind})
      matrixLevel = matrixLevel + 1
      if not beginMatrix() then return end
      matrixLevel = matrixLevel - 1
    elseif kind == 'operator' then
      handleOperator(value)
    elseif kind == 'ans' then
      handleAns(value)
    else
      return false
    end

    return true
  end

  beginFunction = function(name)
    local argc = nil
    local parenLevel = 0
    for token in next do
      local value, kind = token[1], token[2]
      if value == ',' then
        if argc then
          argc = argc + 1
        else
          print("error: RPNExpression.fromInfix expected '('")
        end
        if not popUntil('(') then
          print("error: RPNExpression.fromInfix missing '('")
          return
        end
      elseif value == ')' and parenLevel == 1 then
        if popUntil('(') then
          table.remove(stack, #stack)
          table.insert(result, {tostring(argc or 0), 'number'})
          table.insert(result, {name, 'function'})
          return
        else
          print("error: RPNExpression.fromInfix missing '('")
          return
        end
      else
        -- Begin argument count at first non '(' token
        if value ~= '(' and not argc then
          argc = 1
        end
        if value == '(' then
          parenLevel = parenLevel + 1
        elseif value == ')' then
          parenLevel = parenLevel - 1
        end
        handleDefault(value, kind)
      end
    end
  end

  beginList = function()
    if listLevel > 1 then
      print("error: RPNExpression.fromInfix Nested lists are not allowed")
      return
    end

    local argc = nil
    for token in next do
      local value, kind = token[1], token[2]
      if value == ',' then
        if argc then
          argc = argc + 1
        else
          print("error: RPNExpression.fromInfix expected '{'")
        end
        if not popUntil('{') then
          print("error: RPNExpression.fromInfix missing '{'")
          return
        end
      elseif value == '}' then
        if popUntil('{') then
          table.remove(stack, #stack)
          table.insert(result, {tostring(argc or 0), 'number'})
          table.insert(result, {'}', 'syntax'})
          return
        else
          print("error: RPNExpression.fromInfix missing '{'")
          return
        end
      else
        -- Begin argument count at first non '(' token
        if value ~= '{' and not argc then
          argc = 1
        end
        handleDefault(value, kind)
      end
    end
  end

  beginMatrix = function()
    if matrixLevel > 1 then
      print("error: RPNExpression.fromInfix nested matrices are not allowed")
      return
    end

    local rows, cols = 0, 1
    local curCol = 0
    for token in next do
      local value, kind = token[1], token[2]
      if value == ',' then
        if rows <= 1 then
          cols = cols + 1
        else
          curCol = curCol + 1
          if curCol > cols then
            print("error: RPNExpression.fromInfix different column count")
            return
          end
        end
        
        if not popUntil('[') then
          print("error: RPNExpression.fromInfix missing '['")
          return
        end
      elseif value == '[' then
        curCol = 1
        rows = rows + 1
        if not popUntil('[') then
          print("error: RPNExpression.fromInfix missing '['")
          return
        end
        --handleDefault(value, kind)
      elseif value == ']' then
        if rows == 0 then rows = 1 end
        if popUntil('[') then
          if curCol == 0 then
            table.remove(stack, #stack)
            table.insert(result, {tostring(cols), 'number'})
            table.insert(result, {tostring(rows), 'number'})
            table.insert(result, {']', 'syntax'})
            return
          end
        else
          print("error: RPNExpression.fromInfix missing '['")
          return
        end
        curCol = 0
      else
        handleDefault(value, kind)
      end
    end
  end

  for token in next do
    handleDefault(token[1], token[2])
  end

  while #stack > 0 do
    if stack[#stack][1] == '(' then
      print("error: RPNExpression.fromInfix paren missmatch")
      return nil
    end
    popTop()
  end

  self.stack = result
  return self.stack
end

function RPNExpression:_isReverseOp(value, kind)
  if kind == 'operator' then
    if self.stack[#self.stack][1] == value then
      return value == Sym.NEGATE or value == "(-)" or
             value == "not" or value == "not "
    end 
  end
  return false
end

function RPNExpression:pop()
  return table.remove(self.stack, #self.stack)
end

function RPNExpression:pushOperator(name)
  assert(name)
  self:push({name, 'operator'})
end

function RPNExpression:pushFunctionCall(name, argc)
  assert(name and argc)
  self:push({tostring(argc), 'number'})
  self:push({name, 'function'})
end

function RPNExpression:push(item)
  local value, kind = nil, nil
  if type(item) == 'table' then
    value, kind = unpack(item)
  elseif type(item) == 'string' then
    local tokens = Infix.tokenize(item)
    if not tokens or #tokens < 1 then
      Error.show("Could not parse input")
    end
    value, kind = unpack(tokens[1])
  end
  
  if self:_isReverseOp(value, kind) then
    -- Remove double negation/not
    self:pop()
  else
    table.insert(self.stack, {value, kind})
  end
end


function RPNExpression:appendStack(o)
  for _, item in ipairs(o) do
    table.insert(self.stack, item)
  end
end

function RPNExpression:infixString()
  local stack = {}

  local function pushOperator(name, prec, argc, pos, assoc, aggrassoc)
    local assoc = assoc == "r" and 2 or (assoc == "l" and 1 or 0)
 
    local args = {}
    for i=1,argc do
      local item = table.remove(stack, #stack)
      table.insert(args, item)
    end
    
    local str = ""
    for i,v in ipairs(args) do
      if pos == 0 and str:len() > 0 then str = name .. str end

      if v.prec and ((v.prec < prec) or ((aggrassoc or i == assoc) and v.prec < prec + (assoc ~= 0 and 1 or 0))) then
        str = "(" .. v.expr .. ")" .. str
      else
        str = v.expr .. str
      end
    end
    if pos < 0 then str = name .. str end
    if pos > 0 then str = str .. name end
    
    table.insert(stack, {expr=str, prec=prec})
  end
  
  local function pushFunction(name)
    if not stack or #stack < 1 then
      return Error.show("Missing function argument size")
    end
  
    argc = tonumber(table.remove(stack, #stack).expr)
    assert(argc)

    local args = {}
    for i=1,argc do
      local item = table.remove(stack, #stack)
      table.insert(args, 1, item)
    end
    
    local str = ""
    for _,v in ipairs(args) do
      if str:len() > 0 then str = str .. ',' end
      str = str .. v.expr
    end
    str = name .. "(" .. str .. ")"
    
    table.insert(stack, {expr=str, prec=99})
  end

  local function pushList()
    if not stack or #stack < 1 then
      return Error.show("Missing list length")
    end
      
    local length = tonumber(table.remove(stack, #stack).expr)
    assert(length)

    local str = ""
    while length > 0 do
      str = table.remove(stack, #stack).expr .. str
      if length > 1 then str = "," .. str end
      length = length - 1
    end
    str = "{" .. str .. "}"

    table.insert(stack, {expr=str, prec=99})
  end

  local function pushMatrix()
    local rows = tonumber(table.remove(stack, #stack).expr)
    local cols = tonumber(table.remove(stack, #stack).expr)
    assert(rows and rows >= 1)
    assert(cols and cols >= 1)
    
    local str = ""
    for row=rows,1,-1 do
      local colStr = ''
      for col=cols,1,-1 do
        colStr = table.remove(stack, #stack).expr .. colStr
        if col > 1 then colStr = "," .. colStr end
      end
      str = '['.. colStr .. ']'..str
    end
    
    if rows > 1 then
      str = "[" .. str .. "]"
    end
 
    table.insert(stack, {expr=str, prec=99})
  end
  
  local function push(value, kind)
    if value == '}' then
      return pushList()
    elseif value == ']' then
      return pushMatrix()
    end

    if kind == 'operator' then
      local opname, opprec, opargc, oppos, opassoc, opaggrassoc = queryOperatorInfo(value)
      assert(opname)
      return pushOperator(opname, opprec, opargc, oppos, opassoc, opaggrassoc)
    end
    
    if kind == 'function' then
      local fname = functionInfo(value, false)
      return pushFunction(fname or value)
    end
    
    return table.insert(stack, {expr=value})
  end
  
  for _,v in ipairs(self.stack) do
    push(unpack(v))
  end
  
  local infix = nil
  for _,v in ipairs(stack) do
    infix = (infix or '') .. v.expr
  end 
  
  return infix
end

--------------------------------------------------
--                     UI                       --
--------------------------------------------------

Widgets = {}

-- Widget Base Class
Widgets.Base = class()
function Widgets.Base:invalidate()
end

function Widgets.Base:draw(gc)
end

-- Toast Widget
Widgets.Toast = class(Widgets.Base)
function Widgets.Toast:init(options)
  options = options or {}
  self.location = options.location or 'top'
  self.margin = 4
  self.padding = 4
  self.text = nil
  self.style = options.style
end

function Widgets.Toast:invalidate()
  platform.window:invalidate(self:getFrame())
end

function Widgets.Toast:getFrame()
  if not self.text or self.text:ulen() == 0 then
    return 0, 0, 0, 0
  end

  local x, y, w, h = 0, 0, platform.window:width(), platform.window:height()
  local textW, textH = 0, 0
  
  platform.withGC(function(gc)
    textW = gc:getStringWidth(self.text)
    textH = gc:getStringHeight(self.text)
  end)
  
  x = x + w/2 - textW/2 - self.margin
  if self.location == 'center' then
    y = h/2 - textH/2 - self.margin -- Mid
  else
    y = self.padding -- Top location
  end
  
  w = textW + 2*self.margin
  h = textH + 2*self.margin

  return x, y, w, h
end

function Widgets.Toast:show(text)
  self:invalidate()
  self.text = text and tostring(text) or nil
  self:invalidate()
end

function Widgets.Toast:draw(gc)
  if not self.text then return end

  local x,y,w,h = self:getFrame()
  local isError = self.style == 'error'

  gc:clipRect("set", x, y, w, h)
  gc:setColorRGB(theme[options.theme][isError and 'errorBackgroundColor' or 'altRowColor'])
  gc:fillRect(x, y, w, h)
  gc:setColorRGB(theme[options.theme].borderColor)
  gc:drawRect(x, y, w-1, h-1)
  gc:setColorRGB(theme[options.theme][isError and 'errorTextColor' or 'textColor'])
  gc:drawString(self.text, x + self.margin, y + self.margin)
  gc:clipRect("reset")
end


-- KeybindManager
KeybindManager = class()
function KeybindManager:init()
  self.bindings = {}
  
  -- State 
  self.currentTab = nil
  self.currentSequence = nil

  -- Callbacks
  self.onSequenceChanged = nil -- string({sequence})
  self.onExec = nil -- void(void)
end

function KeybindManager:resetSequence()
  self.currentTab = nil
  self.currentSequence = nil
  if self.onSequenceChanged then
    self.onSequenceChanged(self.currentSequence)
  end
end

function KeybindManager:setSequence(sequence, fn)
  local tab = self.bindings
  for idx, key in ipairs(sequence) do
    if idx == #sequence then break end
    if not tab[key] then
      tab[key] = {}
    end
    tab = tab[key]
  end
  
  tab[sequence[#sequence]] = fn
end

function KeybindManager:dispatchKey(key)
  self.currentSequence = self.currentSequence or {}
  table.insert(self.currentSequence, key)
  
  self.currentTab = self.currentTab or self.bindings

  if type(self.currentTab) == 'table' then
    -- Special case: Binding all number keys
    if not self.currentTab[key] then
      if key:find('^%d+$') then
        self.currentTab = self.currentTab['%d']
      else
        self.currentTab = self.currentTab[key]
      end
    else
      -- Default case
      self.currentTab = self.currentTab[key]
    end
  end

  -- Exit if not found
  if not self.currentTab then
    self:resetSequence()
    return false
  end

  -- Call binding
  if type(self.currentTab) == 'function' then
    if self.currentTab(self.currentSequence) == 'repeat' then
      self.currentTab = {[key] = self.currentTab}
    else
      self:resetSequence()
    end
    if self.onExec then
      self.onExec()
    end
    return true
  end

  -- Propagate sequence change
  if self.onSequenceChanged then
    self.onSequenceChanged(self.currentSequence)
  end

  return true
end

-- Fullscreen 9-tile menu which is navigated using the numpad
UIMenu = class(Widgets.Base)
function UIMenu:init()
  self.frame = {width=0, height=0, x=0, y=0}
  self.page = 0
  self.pageStack = {}
  self.items = {}
  self.filterString = nil
  self.visible = false
  self.parent = nil
  -- Style
  self.style = 'grid'
  -- Callbacks
  self.onSelect = nil -- void()
  self.onCancel = nil -- void()
end

function UIMenu:center(w, h)
  w = w or platform.window:width()
  h = h or platform.window:height()
  
  local margin = 4
  self.frame.x = margin
  self.frame.y = margin
  self.frame.width = w - 2*margin
  self.frame.height = h - 2*margin
end

function UIMenu:getFrame()
  return self.frame.x, self.frame.y, self.frame.width, self.frame.height
end

function UIMenu:invalidate()
  platform.window:invalidate(self:getFrame())
end

function UIMenu:hide()
  if self.parent ~= nil then
    focusView(self.parent)
  else
    focusView(input)
  end
end

function UIMenu:present(parent, items, onSelect, onCancel)
  if parent == self then parent = nil end
  self.pageStack = {}
  self.filterString = nil
  self:pushPage(items or {})
  self.parent = parent
  self.onSelect = onSelect
  self.onCancel = onCancel
  focusView(self)
  return self
end

function UIMenu:numPages()
  return math.floor(#self.items / 9) + 1
end

function UIMenu:prevPage()
  self.page = self.page - 1
  if self.page < 0 then
    self.page = self:numPages() - 1
  end
  self:invalidate()
end

function UIMenu:nextPage()
  self.page = self.page + 1
  if self.page >= self:numPages() then
    self.page = 0
  end
  self:invalidate()
end

function UIMenu:onFocus()
  self.visible = true
end

function UIMenu:onLooseFocus()
  self.visible = false
end

function UIMenu:onTab()
  if #items > 9 then
    self.page = (self.page + 1) % math.floor(#items / 9)
    self:invalidate()
  end
end

function UIMenu:onArrowLeft()
  self:prevPage()
end

function UIMenu:onArrowRight()
  self:nextPage()
end

function UIMenu:onArrowUp()
  self:popPage()
end

function UIMenu:onArrowDown()
  self:popPage()
end

function UIMenu:onEscape()
  if #self.items ~= #self.origItems then
    self:onBackspace()
    return
  end
  if self.onCancel then self.onCancel() end
  self:hide()
end

function UIMenu:onClear()
  self.page = 0
  self.filterString = ''
  self.items = self.origItems
  self:invalidate()
end

function UIMenu:onBackspace()
  self.filterString = ''
  self.items = self.origItems
  self:invalidate()
end

function UIMenu:pushPage(page)
  if page then
    table.insert(self.pageStack, page)
    self.items = self.pageStack[#self.pageStack]
    self.origItems = self.items
    self.filterString = ''
    self:invalidate()
  end
end

function UIMenu:popPage()
  if #self.pageStack > 1 then
    table.remove(self.pageStack, #self.pageStack)
    self.items = self.pageStack[#self.pageStack]
    self.origItems = self.items
    self.filterString = ''
    self:invalidate()
  end
end

function UIMenu:onCharIn(c)
  if c:byte(1) >= 49 and c:byte(1) <= 57 then -- [1]-[9]
    local n = c:byte(1) - 49
    local row, col = 2 - math.floor(n / 3), n % 3
    local item = self.items[self.page * 9 + row * 3 + (col+1)]
    if not item then return end
    
    -- NOTE: The call order is _very_ important:
    --  1. Hide the menu
    --  2. Call the callback
    --  3. Execute the action
    -- Otherwise, presenting a new menu from the action sets the current pages callbacks
    --  which leads to strange behaviour.
    if type(item[2]) == "function" then
      self:hide()
      if self.onSelect then self.onSelect(item) end
      item[2]()  
    elseif type(item[2]) == "table" then
      self:pushPage(item[2])
    elseif type(item[2]) == "string" then
      self:hide()
      if self.onSelect then self.onSelect(item) end
      input:insertText(item[2]) -- HACK
    end
  else
    self.filterString = self.filterString or ''
    if c == ' ' then
      self.filterString = self.filterString..'.*'
    elseif c:byte(1) >= 97 and c:byte(1) <= 122 then
      self.filterString = self.filterString..c:lower()
    end
    
    local function matchFn(title)
      if title:lower():find(self.filterString) then
        return true
      end
    end
    
    local filteredItems = {}
    for _,v in ipairs(self.origItems) do
      if matchFn(v[1]) then
        table.insert(filteredItems, v)
      end
    end
    
    self.items = filteredItems
    self:invalidate()
  end
end

function UIMenu:drawCell(gc, item, x, y, w ,h)
  local margin = 1
  x = x + margin
  y = y + margin
  w = w - 2*margin
  h = h - 2*margin

  if w < 0 or h < 0 then return end

  if item then
    gc:setColorRGB(theme[options.theme].altRowColor)
    gc:fillRect(x,y,w,h)
    gc:setColorRGB(theme[options.theme].borderColor)
    gc:drawRect(x,y,w,h)
  else
    gc:setColorRGB(theme[options.theme].rowColor)
    gc:fillRect(x,y,w,h)
    gc:setColorRGB(theme[options.theme].borderColor)
    gc:drawRect(x,y,w,h)
    return
  end

  gc:clipRect("set", x, y, w+1, h+1)

  local itemText = item[1] or ''
  local itemState = item.state

  local tw, th = gc:getStringWidth(itemText), gc:getStringHeight(itemText)
  local tx, ty = x + w/2 - tw/2, y + h/2 - th/2
  
  gc:setColorRGB(theme[options.theme].textColor)
  gc:drawString(item[1], tx, ty)
  
  if itemState ~= nil then 
    local iw, ih = w * 0.66, 4
    local ix, iy = x + w/2 - iw/2, y + h - ih - margin

    if itemState == true then
      gc:setColorRGB(theme[options.theme].menuActiveColor)
      gc:fillRect(ix,iy,iw,ih)
    end
    gc:setColorRGB(theme[options.theme].borderColor)
    gc:drawRect(ix, iy, iw, ih)
  end
  
  gc:clipRect("reset")
end

function UIMenu:_drawGrid(gc)
  local pageOffset = self.page * 9
  
  local cw, ch = self.frame.width/3, self.frame.height/3
  for row=1,3 do
    for col=1,3 do
      local cx, cy = self.frame.x + cw*(col-1), self.frame.y + ch*(row-1)
      self:drawCell(gc, self.items[pageOffset + (row-1)*3 + col] or nil, cx, cy, cw, ch)
    end
  end
end

function UIMenu:_drawList(gc)
  local pageOffset = self.page * 9
  
  local cw, ch = self.frame.width, self.frame.height/9
  for row=1,9 do
    local cx, cy = self.frame.x, self.frame.y + ch*(row-1)
    self:drawCell(gc, self.items[pageOffset + row] or nil, cx, cy, cw, ch)
  end
end

function UIMenu:draw(gc)
  if not self.visible then return end

  gc:clipRect("set", self:getFrame())
  local ffamily, fstyle, fsize = gc:setFont('sansserif', 'r', 9)
  
  if self.style == 'grid' then
    self:_drawGrid(gc)
  else
    self:_drawList(gc)
  end
  
  gc:setFont(ffamily, fstyle, fsize)
  gc:clipRect("reset")
end

-- RPN stack view
UIStack = class(Widgets.Base)
function UIStack:init()
  self.stack = {}
  -- View
  self.frame = {x=0, y=0, width=0, height=0}
  self.scrolly = 0
  -- Selection
  self.sel = nil
  -- Bindings
  self.kbd = KeybindManager()
  self:initBindings()
end

function UIStack:initBindings()
  self.kbd.onExec = function()
    self:invalidate()
  end
  self.kbd:setSequence({"x"}, function()
    recordUndo()
    self:pop(self.sel, false)
  end)
  self.kbd:setSequence({"backspace"}, function()
    recordUndo()
    self:pop(self.sel, false)
    if #self.stack == 0 then
      focusView(input)
    end
  end)
  self.kbd:setSequence({"clear"}, function()
    recordUndo()
    self.stack = {}
    self:selectIdx()
    focusView(input)
  end)
  self.kbd:setSequence({"enter"}, function()
    recordUndo()
    self:push(table_clone(self.stack[self.sel]))
    self:selectIdx()
  end)
  self.kbd:setSequence({"="}, function()
    recordUndo()
    self:pushRPNExpression(RPNExpression(self.stack[self.sel].rpn))
    self:selectIdx()
  end)
  self.kbd:setSequence({"left"}, function()
    self:roll(-1)
  end)
  self.kbd:setSequence({"right"}, function()
    self:roll(1)
  end)
  self.kbd:setSequence({"c", "left"}, function()
    input:setText(self.stack[self.sel].infix)
    focusView(input)
  end)
  self.kbd:setSequence({"c", "right"}, function()
    input:setText(self.stack[self.sel].result)
    focusView(input)
  end)
  self.kbd:setSequence({"i", "left"}, function()
    input:insertText(self.stack[self.sel].infix)
  end)
  self.kbd:setSequence({"i", "right"}, function()
    input:insertText(self.stack[self.sel].result)
  end)
  self.kbd:setSequence({"5"}, function()
    bigv:displayStackItem(self.sel)
  end)
  self.kbd:setSequence({"7"}, function()
    self:selectIdx(1)
  end)
  self.kbd:setSequence({"3"}, function()
    self:selectIdx(#self.stack)
  end)
end

function UIStack:getFrame()
  return self.frame.x, self.frame.y, self.frame.width, self.frame.height
end

function UIStack:invalidate()
  platform.window:invalidate()
end

function UIStack:evalStr(str)
  local res, err = math.evalStr(str)
  -- Ignore unknown-function errors (for allowing to define functions in RPN mode)
  if err and err ~= 750 then
    Error.show(err)
    return nil
  end
  return res, err
end

function UIStack:size()
  return #self.stack
end

function UIStack:top()
  return #self.stack > 0 and self.stack[#self.stack] or nil
end

function UIStack:pushInfix(input)
  print("info: UIStack.pushInfix call with '"..input.."'")

  local tokens = Infix.tokenize(input)
  if not tokens then
    print("error: UIStack.pushInfix tokens is nil")
    return false
  end

  local rpn = RPNExpression()
  local stack = rpn:fromInfix(tokens)
  if not stack then
    print("error: UIStack.pushInfix rpn is nil")
    return false
  end

  local infix = rpn:infixString()
  if not infix then
    print("error: UIStack.pushInfix infix is nil")
    return false
  end
  
  local res, err = self:evalStr(infix)
  if res then
    self:push({["rpn"]=stack, ["infix"]=infix, ["result"]=res or ("error: "..err)})
    return true
  end
  return false
end

function UIStack:pushRPNExpression(item)
  local infix = item:infixString()
  local res, err = self:evalStr(infix)
  if res then
    self:push({["rpn"]=item.stack, ["infix"]=infix, ["result"]=res or ("error: "..err)})
    return true
  end
  return false
end

function UIStack:push(item)
  if item then
    table.insert(self.stack, item)
    self:scrollToIdx()
    self:invalidate()
  else
    print("UIStack:push item is nil")
  end
end

function UIStack:swap(idx1, idx2)
  if #self.stack < 2 then return end
  
  idx1 = idx1 or (#self.stack - 1)
  idx2 = idx2 or #self.stack
  if idx1 <= #self.stack and idx2 <= #self.stack then
    local tmp = table_clone(self.stack[idx1])
    self.stack[idx1] = self.stack[idx2]
    self.stack[idx2] = tmp
  end
  self:invalidate()
end

-- Pop item at `idx` (or top) from the stack
-- Index 1 is at the bottom of the stack!
function UIStack:pop(idx, from_top)
  if from_top then
    idx = (#self.stack - idx + 1) or #self.stack
  else
    idx = idx or #self.stack
  end
  if idx <= 0 or idx > #self.stack then return end
  local v = table.remove(self.stack, idx)
  self:invalidate()
  return v
end

function UIStack:roll(n)
  if #self.stack < 2 then return end

  n = n or 1
  if n > 0 then
    for i=1,n do
      table.insert(self.stack, 1, table.remove(self.stack, #self.stack))
    end
  else
    for i=1,math.abs(n) do
      table.insert(self.stack, table.remove(self.stack, 1))
    end
  end
  self:invalidate()
end

function UIStack:dup(n)
  if #self.stack <= 0 then return end

  n = n or 1
  local idx = #self.stack - (n - 1)
  for i=1,n do
    table.insert(self.stack, table_clone(self.stack[idx + i - 1]))
  end
end

function UIStack:pick(n)
  n = n or 1
  local idx = #self.stack - (n - 1)
  table.insert(self.stack, table_clone(self.stack[idx]))
end

function UIStack:toList(n)
  if #self.stack <= 0 then return end

  if n == nil then
    n = tonumber(self:pop().result)
  end

  assert(type(n)=="number")
  assert(n >= 0)

  local newList = {
    rpn = RPNExpression(),
    n = 0
  }

  function newList:join(rpn)
    if rpn and rpn[#rpn][1] == '}' then
      table.remove(rpn, #rpn)

      local size = tonumber(table.remove(rpn, #rpn)[1])
      assert(size)

      self.rpn:appendStack(rpn)
      self.n = self.n + size
      return true
    end
  end

  function newList:add(rpn)
    if not self:join(rpn) then
      self.rpn:appendStack(rpn)
      self.n = self.n + 1
    end
  end

  function newList:finalize()
    self.rpn:push({tostring(self.n), 'number'})
    self.rpn:push('}')
  end

  local newTop = math.max(#stack.stack - n + 1, 1)
  for i=1,n do
    local arg = self:pop(newTop)
    if arg then
      newList:add(RPNExpression():fromInfix(Infix.tokenize(arg.result)))
    end
  end
  
  newList:finalize()

  self:pushRPNExpression(newList.rpn)
end

function UIStack:toPostfix()
  if #self.stack <= 0 then return end
  local rpn = self:pop().rpn
  
  local str = ""
  for _,v in ipairs(rpn) do
    if str:len() > 0 then str = str .. " " end
    str = str .. v
  end
  str = '"' .. str .. '"'
  
  local rpn = RPNExpression()
  rpn:push(str)
  self:pushRPNExpression(rpn)
end

function UIStack:label(text)
  text = text or self:pop().result
  self.stack[#self.stack].infix = text
end

function UIStack:killexpr()
  if self.stack[#self.stack].result then
    self.stack[#self.stack].infix = self.stack[#self.stack].result
  end
end

--[[ UI helper ]]--
function UIStack:frameAtIdx(idx)
  idx = idx or #self.stack
  
  local x,y,w,h = 0,0,0,0
  local fx,_,fw,_ = self:getFrame()
  
  for i=1,idx-1 do
    y = y + platform.withGC(function(gc) return self:itemHeight(gc, i) end)
  end
  h = platform.withGC(function(gc) return self:itemHeight(gc, idx) end)
  
  return fx,y,fw,h
end

--[[ Navigation ]]--
function UIStack:selectIdx(idx)
  idx = idx or #self.stack
  self.sel = math.min(math.max(1, idx), #self.stack)
  self:scrollToIdx(idx)
  self:invalidate()
end

function UIStack:scrollToIdx(idx)
  idx = idx or #self.stack

  -- Get item frame
  local _,itemY,_,itemHeight = self:frameAtIdx(idx)
  local top, bottom = itemY, itemY + itemHeight
  local sy = self.scrolly
  local _,_,_,h = self:getFrame()
  
  if top + sy < 0 then
    sy = 0 - top
  end
  if bottom + sy > h then
    sy = 0 - bottom + h
  end
  
  if sy ~= self.scrolly then
    self.scrolly = sy
    self:invalidate()
  end
end

--[[ Events ]]--
function UIStack:onArrowDown()
  if self.sel < #self.stack then
    self:selectIdx(self.sel + 1)
  else
    focusView(input)
    self:scrollToIdx()
  end
end

function UIStack:onArrowUp()
  if self.sel > 1 then
    self:selectIdx(self.sel - 1)
  end
end

function UIStack:onEscape()
  self.kbd:resetSequence()
  focusView(input)
end

function UIStack:onLooseFocus()
  self.kbd:resetSequence()
  self.sel = nil
end

function UIStack:onFocus()
  self.kbd:resetSequence()
  self:selectIdx()
end

function UIStack:itemHeight(gc, idx)
  -- TODO: Refactor und mit drawItem zusammen!
  local x,y,w,h = self:getFrame()
  local minDistance, margin = 12, 2
  local fringeSize = gc:getStringWidth("0")*math.floor(math.log10(#self.stack)+1)
  local fringeMargin = fringeSize + 3*margin
  local item = self.stack[idx]
  if not item then return 0 end
  local leftSize = {w = gc:getStringWidth(item.infix or ""), h = gc:getStringHeight(item.infix or "")}
  local rightSize = {w = gc:getStringWidth(item.result or ""), h = gc:getStringHeight(item.result or "")}
  
  local leftPos = {x = x + fringeMargin + margin,
                   y = y}
  local rightPos = {x = x + w - margin - rightSize.w,
                    y = y}
    
   if options.showExpr then
     if rightPos.x < leftPos.x + leftSize.w + minDistance then
       rightPos.y = leftPos.y + margin*2 + leftSize.h
     end
   end
    
   return rightPos.y - leftPos.y + rightSize.h + margin
end

function UIStack:drawItem(gc, x, y, w, idx, item)
  local itemBG = {theme[options.theme].rowColor,
                  theme[options.theme].altRowColor,
                  theme[options.theme].selectionColor}
  local minDistance, margin = 12, 2
  
  local leftStr = item.label or item.infix or ''
  
  local leftSize = {w = gc:getStringWidth(leftStr or ""), h = gc:getStringHeight(leftStr or "")}
  local rightSize = {w = gc:getStringWidth(item.result or ""), h = gc:getStringHeight(item.result or "")}
  
  local fringeSize = gc:getStringWidth("0")*math.floor(math.log10(#self.stack)+1)
  local fringeMargin = options.showFringe and fringeSize + 3*margin or 0
  
  local leftPos = {x = x + fringeMargin + margin,
                   y = y}
  local rightPos = {x = x + w - margin - rightSize.w,
                    y = y}
  
  if rightPos.x < leftPos.x + leftSize.w + minDistance then
    rightPos.y = leftPos.y + margin*2 + leftSize.h
  end
  
  local itemHeight = rightPos.y - leftPos.y + rightSize.h + margin
  
  gc:clipRect("set", x, y, w, itemHeight)
  if focus == self and self.sel ~= nil and self.sel == idx then
    gc:setColorRGB(itemBG[3])
  else
    gc:setColorRGB(itemBG[(idx%2)+1])
  end
  
  gc:fillRect(x, y, w, itemHeight)
  
  -- Render fringe (stack number)
  local fringeX = 0
  if options.showFringe == true then
    gc:setColorRGB(itemBG[((idx+1)%2)+1])
    
    fringeX = x + fringeSize + 2*margin
    gc:drawLine(fringeX, y, fringeX, y + itemHeight)
    gc:setColorRGB(theme[options.theme].fringeTextColor)
    gc:drawString(#self.stack - idx + 1, x + margin, y)
    
    gc:clipRect("set", fringeX-1, y, w, itemHeight)
  end
  
  -- Render expression and result
  gc:setColorRGB(theme[options.theme].textColor)
  if not item.label then
    if options.showExpr == true then
      gc:drawString(item.infix or "", leftPos.x, leftPos.y)
      gc:drawString(item.result or "", rightPos.x, rightPos.y)
    else
      gc:drawString(item.result or "", leftPos.x, leftPos.y)
    end
  else
    local ffamily, fstyle, fsize = gc:setFont('serif', 'i', 11)
    gc:drawString(item.label, leftPos.x, leftPos.y)
    gc:setFont(ffamily, fstyle, fsize)
    
    gc:drawString(item.result or "", rightPos.x, rightPos.y)
  end
  
  -- Render overflow indicator
  if rightPos.x < fringeX + 1 then
    gc:setColorRGB(theme[options.theme].cursorColor)
    gc:drawLine(fringeX, rightPos.y,
                fringeX, rightPos.y + rightSize.h)
  end
  
  gc:clipRect("reset")
  return itemHeight
end

function UIStack:draw(gc)
  local x,y,w,h = self:getFrame()
  local yoffset = y + self.scrolly
  
  gc:clipRect("set", x, y, w, h)
  
  if #self.stack == 0 and focus == self then
    gc:setColorRGB(theme[options.theme].selectionColor)
  else
    gc:setColorRGB(theme[options.theme].backgroundColor)
  end
   
  gc:fillRect(x,y,w,h)
 
  for idx, item in ipairs(self.stack) do
    yoffset = yoffset + self:drawItem(gc, x, yoffset, w, idx, item)
  end
  gc:clipRect("reset")
end


-- Text input widget
UIInput = class(Widgets.Base)
function UIInput:init(frame)
  self.frame = frame or {x=0, y=0, width=0, height=0}
  self.text = ""
  self.cursor = {pos=string.len(self.text), size=0}
  self.scrollx = 0
  self.margin = 2
  -- Completion
  self.completionFun = nil   -- Current completion handler function
  self.completionIdx = nil   -- Current completion index
  self.completionList = nil  -- Current completion candidates
  -- Prefix
  self.prefix = ""           -- Non-Editable prefix shown on the left
  -- Input
  self.inputHandler = RPNInput()
  self.kbd = KeybindManager()
  self:init_bindings()
end

function UIInput:save_state()
  return table_copy_fields(self, {
    'text', 'prefix', 'cursor', 'scrollx', 'completionFun', 'completionIdx', 'completionList'})
end

function UIInput:restore_state(state)
  table_copy_fields(state, {
    'text', 'prefix', 'cursor', 'scrollx', 'completionFun', 'completionIdx', 'completionList'}, self)
  self:invalidate()
end


function UIInput:init_bindings()
  local function findNearestChr(chr, origin, direction)
    local byteOrigin = self.text:sub(1, origin):len()
    local pos = direction == 'left' and 1 or byteOrigin+1
    for i=1,self.text:len() do
      local newPos = self.text:find(chr, pos)
      if not newPos then
        return direction == 'left' and pos - 1 or nil
      end
      if direction == 'left' then
        if newPos >= pos and newPos < byteOrigin then
          pos = newPos + 1
        else 
          return pos - 1
        end
      else
        return newPos - 1
      end
    end
  end
  
  self.kbd:setSequence({'G', '('}, function()
    local byteCursor = self.text:usub(1, self.cursor.pos):len()
    local left = findNearestChr('[%(%[%{,]', byteCursor, 'left')
    if left then
      self:setCursor(self.text:sub(1, left):ulen())
    end
  end)
  self.kbd:setSequence({'G', ')'}, function()
    local byteCursor = self.text:usub(1, self.cursor.pos + 1):len()
    local right = findNearestChr('[%)%]%},]', byteCursor, 'right')
    if right then
      self:setCursor(self.text:sub(1, right):ulen())
    end
  end)
  self.kbd:setSequence({'G', '.'}, function()
    local byteCursor = self.text:usub(1, self.cursor.pos + 1):len()
    local left = findNearestChr('[%(%[%{,]', byteCursor, 'left')
    local right = findNearestChr('[%)%]%},]', byteCursor, 'right')
    if left and right then
      self:setCursor(self.text:sub(1, left):ulen())
      self.cursor.size = self.text:sub(1, right):ulen() - self.cursor.pos
    end
  end)
  self.kbd:setSequence({'G', 'left'}, function()
    self:setCursor(0)
  end)
  self.kbd:setSequence({'G', 'right'}, function()
    self:setCursor(self.text:ulen())
  end)
  
  -- Special chars
  self.kbd:setSequence({'I'}, function(sequence)
    menu:present(input, {
      {'{', '{'}, {'=:', '=:'}, {'}', '}'},
      {'[', '['}, {'@>', '@>'}, {']', ']'},
      {'|', '|'}, {':=', ':='}, {'@', '@'},
    })
  end)
  
  -- Ans/Stack reference
  self.kbd:setSequence({'A', '%d'}, function(sequence)
    local n = tonumber(sequence[#sequence])
    if Error.assertStackN(n) then
      self:insertText('@'..sequence[#sequence])
    end
  end)
end

function UIInput:invalidate()
  platform.window:invalidate(self:getFrame())
end

-- Reset the completion state, canceling pending completions
function UIInput:cancelCompletion()
  if self.completionIdx ~= nil then
    self.completionIdx = nil
    self.completionList = nil
  
    if self.cursor.size > 0 then
      self:onBackspace()
    end
  end
end

-- Starts a completion with the given list
-- No prefix matching takes place 
function UIInput:customCompletion(tab)
  if not self.completionIdx then
    self.completionIdx = #tab
    self.completionList = tab
  end
  self:nextCompletion()
end

function UIInput:nextCompletion(offset)
  if not self.completionList then
    if not self.completionFun then return end

    local prefixSize = 0
    do
      local prevb = 0xff
      -- FIXME: This does not work with unicode chars!
      for i=self.cursor.pos,1,-1 do
        local b = self.text:byte(i)
        if b >= 65 and prevb < 65 then break end
        if b == nil or b < 64 then break end -- Stop at char < '@'
        prefixSize = prefixSize + 1
        prevb = b
      end
    end

    local prefix = "" 
    if prefixSize > 0 then
      prefix = self.text:sub(self.cursor.pos + 1 - prefixSize, self.cursor.pos)
    end

    self.completionList = self.completionFun(prefix)
    if not self.completionList or #self.completionList == 0 then
      return
    end
    
    self.completionIdx = 1
  else
    -- Apply single entry using [tab]
    if #self.completionList == 1 then
      self:moveCursor(1)
      self:cancelCompletion()
      return
    end
   
    -- Advance completion index
    self.completionIdx = (self.completionIdx or 0) + (offset or 1)
    
    -- Reset completion list
    if self.completionIdx > #self.completionList then
      self.completionIdx = 1
    elseif self.completionIdx < 1 then
      self.completionIdx = #self.completionList
    end
  end
  
  local tail = ""
  if self.cursor.pos + self.cursor.size < #self.text then
    tail = self.text:usub(self.cursor.pos + self.cursor.size + 1)
  end
  
  if not self.completionList[self.completionIdx] then return end
  
  self.text = self.text:usub(1, self.cursor.pos) .. 
              self.completionList[self.completionIdx] ..
              tail

  self.cursor.size = self.completionList[self.completionIdx]:ulen()
  self:scrollToPos()
  self:invalidate()
end

function UIInput:moveCursor(offset)
  if self.cursor.size > 0 then
    -- Jump to edge of selection
    if offset > 0 then
      offset = self.cursor.size
    end
  end
  
  self:setCursor(self.cursor.pos + offset)
end

function UIInput:setCursor(pos, scroll)
  local oldPos, oldSize = unpack(self.cursor)
  
  self.cursor.pos = math.min(math.max(0, pos or self.text:ulen()), self.text:ulen())
  self.cursor.size = 0
  
  scroll = scroll or true
  if scroll == true then
    self:scrollToPos()
  end
  
  self:cancelCompletion()
  
  if oldPos ~= self.cursor.pos or
     oldSize ~= self.cursor.size then
    self:invalidate()
  end
end

function UIInput:getCursorX(pos)
  local x = platform.withGC(function(gc)
    local offset = 0
    if self.prefix then
      offset = gc:getStringWidth(self.prefix) + 2*self.margin
    end
    return offset + gc:getStringWidth(string.usub(self.text, 1, pos or self.cursor.pos))
  end)
  return x
end

function UIInput:scrollToPos(pos)
  local _,_,w,_ = self:getFrame()
  local margin = self.margin
  local cx = self:getCursorX(pos or self.cursor.pos + self.cursor.size)
  local sx = self.scrollx
  
  if cx + sx > w - margin then
    sx = w - cx - margin
  elseif cx + sx < w / 2 then
    sx = math.max(0, -cx)
  end
  
  if sx ~= self.scrollx then
    self.scrollx = sx
    self:invalidate()
  end
end

function UIInput:onArrowLeft()
  self:moveCursor(-1)
  self:scrollToPos()
  self:invalidate()
end

function UIInput:onArrowRight()
  self:moveCursor(1)
  self:scrollToPos()
  self:invalidate()
end

function UIInput:onArrowDown()
  stack:swap()
end

function UIInput:onArrowUp()
  focusView(stack)
end

function UIInput:onEscape()
  self:cancelCompletion()
  self:setCursor()
  self:invalidate()
end

function UIInput:onLooseFocus()
  self:cancelCompletion()
end

function UIInput:onFocus()
  --self:setCursor(#self.text)
end

function UIInput:onCharIn(c)
  self:cancelCompletion()
  if not self.inputHandler:onCharIn(c) then
    -- Inserting an operator into an empty input in ALG mode should insert '@1'
    if get_mode() == 'ALG' and options.autoAns and self.text:len() == 0 and stack:size() > 0 then
      local name, _, args, side = queryOperatorInfo(c)
      if name and (args > 1 or (args == 1 and side == 1)) then
        c = '@1'..c
      end 
    end
    
    if c == ' ' and get_mode() == 'RPN' and options.spaceAsEnter then
      self:onEnter()
    else
      self:_insertChar(c)
    end
  end
  self:scrollToPos()
end

function UIInput:_insertChar(c)
  c = c or ""
  self:cancelCompletion()
  
  local expanded = c
  if options.autoClose == true then
    -- Add closing paren
    local matchingParen, isOpening = unpack(ParenPairs[c:usub(-1)] or {})
    if matchingParen and isOpening then
      expanded = c..matchingParen
    end
    
    -- Skip closing paren
    local rhsPos = self.cursor.pos + 1
    local rhs = self.text:ulen() >= rhsPos and self.text:usub(rhsPos, rhsPos) or nil
    if self.cursor.size == 0 and c == rhs then
      self:moveCursor(1)
      self:invalidate()
      return
    end
  end
  
  if self.cursor.pos == self.text:ulen() then
    self.text = self.text .. expanded
  else
    local left, mid, right = string.usub(self.text, 1, self.cursor.pos),
                             string.usub(self.text, self.cursor.pos + 1, self.cursor.size + self.cursor.pos),
                             string.usub(self.text, self.cursor.pos + 1 + self.cursor.size)

    -- Kill the matching character right to the selection
    if options.autoKillParen == true and mid:ulen() == 1 then
      local matchingParen, isOpening = unpack(ParenPairs[mid] or {})
      if matchingParen and isOpening and right:usub(1, 1) == matchingParen then
        right = right:usub(2)
      end
    end
    
    self.text = left .. expanded .. right
  end
  
  self.cursor.pos = self.cursor.pos + string.ulen(c) -- c!
  self.cursor.size = 0
  
  self:invalidate()
end

function UIInput:onBackspace()
  self:cancelCompletion()
  if options.autoPop == true and self.text:ulen() <= 0 then
    recordUndo()
    stack:pop()
    stack:scrollToIdx()
    return
  end
  
  if self.cursor.size > 0 then
    self:_insertChar("")
    self.cursor.size = 0
  elseif self.cursor.pos > 0 then
    self.cursor.size = 1
    self.cursor.pos = math.max(0, self.cursor.pos - 1)
    self:onBackspace()
  end
  self:scrollToPos()
end

function UIInput:onEnter()
  if self.text:ulen() == 0 then return end

  self.inputHandler:onEnter()
  
  self.tempMode = nil
end

function UIInput:onTab()
  self:nextCompletion()
end

function UIInput:onClear()
  if self.cursor.pos < #self.text then
    self.cursor.size = #self.text - self.cursor.pos
    self:_insertChar("")
    self:scrollToPos()
    self:cancelCompletion()
  else
    self:clear()
  end
end

function UIInput:clear()
  self.text = ""
  -- Do not change the prefix!
  self:setCursor(0)
  self:cancelCompletion()
  self:invalidate()
end

function UIInput:setText(s, prefix)
  self.text = s or ""
  self.prefix = prefix or ""
  self:setCursor(#self.text)
  self:cancelCompletion()
  self:invalidate()
end

function UIInput:insertText(s)
  if s then
    self:cancelCompletion()
    self:_insertChar(s)
  end
end

function UIInput:selAll()
  self:cancelCompletion()
  self.cursor.pos = 0
  self.cursor.size = #self.text
  self:invalidate()
end

function UIInput:getFrame()
  return self.frame.x, self.frame.y, self.frame.width, self.frame.height
end

function UIInput:drawFrame(gc)
  gc:setColorRGB(theme[options.theme].backgroundColor)
  gc:fillRect(self:getFrame())
  gc:setColorRGB(theme[options.theme].borderColor)
  gc:drawLine(self.frame.x-1, self.frame.y,
              self.frame.x + self.frame.width, self.frame.y)
  gc:drawLine(self.frame.x-1, self.frame.y + self.frame.height,
              self.frame.x + self.frame.width, self.frame.y + self.frame.height)
end

function UIInput:drawText(gc)
  local margin = self.margin
  local x,y,w,h = self:getFrame()
  local scrollx = self.scrollx
  local cursorx = math.max(gc:getStringWidth(string.usub(self.text, 1, self.cursor.pos)) or 0, 0)
  cursorx = cursorx + x + scrollx
  
  gc:clipRect("set", x, y, w, h)
  
  -- Draw prefix text
  if self.prefix and self.prefix:len() > 0 then
    local prefixWidth = gc:getStringWidth(self.prefix) + 2*margin

    --gc:setColorRGB(theme[options.theme].altRowColor)
    --gc:fillRect(x, y+1, prefixWidth, h-2)
    gc:setColorRGB(theme[options.theme].fringeTextColor)
    gc:drawString(self.prefix, x + margin, y)
    
    x = x + prefixWidth
    cursorx = cursorx + prefixWidth
    gc:clipRect("set", x, y, w, h)
  end
  
  -- Draw cursor selection box  
  if self.cursor.size ~= 0 then
    local selWidth = gc:getStringWidth(string.usub(self.text, self.cursor.pos+1, self.cursor.pos + self.cursor.size))
    local cursorLeft, cursorRight = math.min(cursorx, cursorx + selWidth), math.max(cursorx, cursorx + selWidth)

    gc:drawRect(cursorLeft + 1, y + 2, cursorRight - cursorLeft, h-3)
  end
  
  gc:setColorRGB(theme[options.theme].textColor)
  gc:drawString(self.text, x + margin + scrollx, y)
  
  if focus == self then
    gc:setColorRGB(get_mode() == "RPN" and 
        theme[options.theme].cursorColor or
        theme[options.theme].cursorColorAlg)
  else
    gc:setColorRGB(theme[options.theme].cursorColorAlt)
  end
  gc:fillRect(cursorx+1, y+2, options.cursorWidth, h-3)
  
  gc:clipRect("reset")
end

function UIInput:draw(gc)
  self:drawFrame(gc)
  self:drawText(gc)
end


--[[
  Rich text view for displaying expressions in a 2D style.
]]--
RichText = class(Widgets.Base)
function RichText:init()
  self.view = D2Editor.newRichText()
  self.view:setReadOnly(true)
  self.view:setBorder(0)
end

function RichText:onFocus()
  self.view:move(stack.frame.x, stack.frame.y)
    :resize(stack.frame.width, stack.frame.height)
    :setVisible(true)
    :setFocus(true)
end

function RichText:onLooseFocus()
  self.view:setVisible(false)
    :setFocus(false)
end

function RichText:onEscape()
  focusView(stack)
end

function RichText:displayStackItem(idx)
  local item = stack.stack[idx or stack:size()]
  if item ~= nil then
    self.view:createMathBox()
      :setExpression("\\0el {"..item.infix.."}\n=\n" ..
                     "\\0el {"..item.result.."}")
  end
  focusView(self)
end

function RichText:displayText(text)
  self.view:setExpression(text)
  focusView(self)
end


--[[ === UNDO/REDO === ]]--
local UndoStack, RedoStack = {}, {}

-- Returns a new undo-state table by copying the current stack and text input
local function makeUndoState(text)
  return {
    stack=table_clone(stack.stack),
    input=text or input.text
  }
end

function recordUndo(input)
  table.insert(UndoStack, makeUndoState(input))
  if #UndoStack > options.maxUndo then
    table.remove(UndoStack, 1)
  end
  RedoStack = {}
end

function popUndo()
  table.remove(UndoStack, #UndoStack)
end

local function applyUndo(state)
  stack.stack = state.stack
  if state.input ~= nil then
    input:setText(state.input)
  end
  stack:invalidate()
end

function clear()
  recordUndo()
  stack.stack = {}
  stack:invalidate()
  input:setText("", "")
  input:invalidate()
  interactiveStack = {} -- Kill _all_ interactive sessions
end

function undo()
  if #UndoStack > 0 then
    local state = table.remove(UndoStack, #UndoStack)
    table.insert(RedoStack, makeUndoState())
    applyUndo(state)
  end
end

function redo()
  if #RedoStack > 0 then
    local state = table.remove(RedoStack, #RedoStack)
    table.insert(UndoStack, makeUndoState())
    applyUndo(state)
  end
end


RPNInput = class()
function RPNInput:getInput()
  return input.text
end

function RPNInput:setInput(str)
  input:setText(str)
end

function RPNInput:isBalanced()
  local str = input.text
  local paren,brack,brace,dq,sq = 0,0,0,0,0
  for i=1,input.cursor.pos do
    local c = str:byte(i)
    if c==40  then paren = paren+1 end -- (
    if c==41  then paren = paren-1 end -- )
    if c==91  then brack = brack+1 end -- [
    if c==93  then brack = brack-1 end -- ]
    if c==123 then brace = brace+1 end -- {
    if c==125 then brace = brace-1 end -- }
    if c==34  then dq = dq + 1 end     -- "
    if c==39  then sq = sq + 1 end     -- '
  end
  return paren == 0 and brack == 0 and brace == 0 and dq % 2 == 0 and sq % 2 == 0
end

function RPNInput:popN(num)
  local newTop = #stack.stack - num + 1
  local rpn = RPNExpression()
  for i=1,num do
    rpn:appendStack(stack:pop(newTop).rpn)
  end
  return rpn
end

function RPNInput:dispatchInfix(str)
  if not str or str:ulen() == 0 then
    return nil
  end
  local res = stack:pushInfix(str)
  if res then
    self:setInput('')
  end
  return res
end

function RPNInput:dispatchInput()
  local str = self:getInput()
  if str and str:ulen() > 0 then
    return self:dispatchInfix(str)
  end
  return true
end

function RPNInput:dispatchOperator(str, ignoreInput)
  local name, _, argc = queryOperatorInfo(str)
  if name then
    recordUndo()
    if (not ignoreInput and not self:dispatchInput()) or
       not Error.assertStackN(argc) then
      popUndo()
      return
    end

    local rpn = self:popN(argc)
    rpn:pushOperator(name)
    
    stack:pushRPNExpression(rpn)
    return true
  end
end

function RPNInput:dispatchOperatorSpecial(key)
  local tab = {
    ['^2'] = function()
      self:dispatchInput()
      stack:pushInfix('2')
      self:dispatchOperator('^')
    end,
    ['10^'] = function()
      self:dispatchInput()
      stack:pushInfix('10')
      stack:swap() 
      self:dispatchOperator('^')
    end
  }
  
  tab[key]()
end

function RPNInput:dispatchFunction(str, ignoreInput, builtinOnly)
  local name, argc = functionInfo(str, builtinOnly)
  if name then
    recordUndo()
    if (not ignoreInput and not self:dispatchInput()) or
       not Error.assertStackN(argc) then
      popUndo()
      return
    end

    local rpn = self:popN(argc)
    rpn:pushFunctionCall(name, argc)
    
    stack:pushRPNExpression(rpn)
    return true
  end
end

function RPNInput:onCharIn(key)
  if not key then
    return false
  end

  if get_mode() == "ALG" or not self:isBalanced() then
    return false
  end

  local function isOperator(key)
    return queryOperatorInfo(key) ~= nil
  end

  local function isOperatorSpecial(key)
    if key == '^2' or key == '10^' then return true end
  end

  local function isFunction(key)
    return functionInfo(key, true) ~= nil
  end
  
  -- Remove trailing '(' from some TI keys
  if key:ulen() > 1 and key:usub(-1) == '(' then
    key = key:sub(1, -2)
  end

  if isOperator(key) then
    self:dispatchOperator(key)
  elseif isOperatorSpecial(key) then
    self:dispatchOperatorSpecial(key)
  elseif isFunction(key) then
    self:dispatchFunction(key)
  else
    return false
  end
  return true
end

function RPNInput:onEnter()
  if get_mode() == "RPN" then
    if self:dispatchFunction(self:getInput(), true, false) then
      self:setInput('')
    elseif self:dispatchOperator(self:getInput(), true) then
      self:setInput('')
    end
  end
  
  if self:getInput():ulen() > 0 then
    recordUndo()
  end
  return self:dispatchInfix(self:getInput())
end


-- UI
input = UIInput()
stack = UIStack()
menu  = UIMenu()
bigv  = RichText()
focus = input

function focusView(v)
  if v ~= nil and v ~= focus then
    if focus.onLooseFocus then
      focus:onLooseFocus()
    end
    focus:invalidate()
    focus = v
    if focus.onFocus then
      focus:onFocus()
    end
    focus:invalidate()
  end
end

-- Completion functions
completion_catmatch = function(candidates, prefix, res)
  res = res or {}
  local plen = prefix and #prefix or 0
  for _,v in ipairs(candidates or {}) do
    if plen == 0 or v:lower():sub(1, plen) == prefix then
      local m = v:sub(plen + 1)
      if #m > 0 then
        table.insert(res, m)
      end
    end
  end
  
  table.sort(res)
  return res
end

completion_fn_variables = function(prefix)
  return completion_catmatch(var:list(), prefix)
end

input.completionFun = function(prefix)
  -- Semantic autocompletion
  local semantic = nil
  if options.smartComplete then
    local semanticValue, semanticKind = nil, nil

    local tokens = Infix.tokenize(input.text:usub(1, input.cursor.pos + 1 - (prefix and prefix:ulen() + 1 or 0)))
    if tokens and #tokens > 0 then
      semanticValue, semanticKind = unpack(tokens[#tokens])
      semantic = {}
    end

    if semanticValue == '@>' or semanticValue == Sym.CONVERT or semanticKind == 'number' then
      semantic['unit'] = true
    end 
    
    if semanticValue == '@>' or semanticValue == Sym.CONVERT then
      semantic['conversion_fn'] = true
    end
    
    if semanticKind == 'unit' then
      semantic['conversion_op'] = true
    end
    
    if semanticValue ~= '@>' and semanticValue ~= Sym.CONVERT and semanticKind == 'operator'  then
      semantic['function'] = true
      semantic['variable'] = true
    end
    
    if not semanticValue then
      semantic = semantic or {}
      semantic['common'] = true
    end
  end

  local functionTab = {}
  for k,v in pairs(functions) do
    if not v.conv then
      table.insert(functionTab, k)
    end
  end

  -- TODO: Complete the unit table
  --       Maybe move units to a grouped menu
  local unitTab = {
    "_m",                                   -- Length
    "_kph","_m/_s",                         -- Speed
    "_m/_s^2",                              -- Accelleration
    "_s","_min","_hr","_day","_week","_yr", -- Time
    "_N",                                   -- Force
    "_J",                                   -- Energy
    "_W",                                   -- Power
    "_bar",                                 -- Pressure
    "_A","_mA","_kA",                       -- Current
    "_V","_mV","_kV",                       -- Potential
    "_ohm",                                 -- Resistance
    "_g","_c"                               -- Constants
  }

  -- Provide semantic
  if semantic then 
    local candidates = {}
    if semantic['unit'] then
      candidates = completion_catmatch(unitTab, prefix, candidates)
    end
    if semantic['conversion_op'] then
      candidates = completion_catmatch({'@>'}, prefix, candidates) -- TODO: Use unicode when input is ready
    end
    if semantic['conversion_fn'] then
      candidates = completion_catmatch({
        'approxFraction()',
        'Base2', 'Base10', 'Base16',
        'Decimal',
        'Grad', 'Rad'
      }, prefix, candidates)
    end
    if semantic['function'] then
      candidates = completion_catmatch(functionTab, prefix, candidates)
    end
    if semantic['variable'] then
      candidates = completion_catmatchtch(var.list(), prefix, candidates)
    end
    if semantic['common'] then
      candidates = completion_catmatch(commonTab, prefix, candidates) -- TODO: Add common tab
      candidates = completion_catmatch(var.list(), prefix,
                   completion_catmatch(functionTab, prefix,
                   completion_catmatch(unitTab, prefix, candidates)))
    end

    return candidates
  end

  -- Provide all
  return completion_catmatch(var.list(), prefix,
         completion_catmatch(functionTab, prefix,
         completion_catmatch(unitTab, prefix)))
end


Toast = Widgets.Toast()
ErrorToast = Widgets.Toast({location = 'center', style = 'error'})
GlobalKbd = KeybindManager()

-- After execution of any kbd command invaidate all
GlobalKbd.onExec = function()
  platform.window:invalidate()
end

-- Show the current state using a toast message
GlobalKbd.onSequenceChanged = function(sequence)
  if not sequence then
    Toast:show()
    return
  end

  local str = ''
  for idx, v in ipairs(sequence) do
    if idx > 1 then str = str..Sym.CONVERT end
    str = str .. v
  end
  Toast:show(str)
end

stack.kbd.onSequenceChanged = GlobalKbd.onSequenceChanged
input.kbd.onSequenceChanged = GlobalKbd.onSequenceChanged

-- Show text as error
Error = {}
function Error.show(str, pos)
  if type(str) == 'number' then
    str = errorCodes[str] or str
  end
  
  ErrorToast:show(str)
  if not pos then
    input:selAll()
  else
    input:setCursor(pos)
  end
end

function Error.hide()
  ErrorToast:show()
end

function Error.assertStackN(n, pos)
  if #stack.stack < (n or 1) then
    Error.show("Too few arguments on stack")
    if not pos then
      input:selAll()
    else
      input:setCursor(pos)
    end
    return false
  end
  return true
end

-- Ask for a value submitteds with [enter], canceled with [esc]
-- Parameters:
--   widget  The UIInput instance
--   callbackEnter   Called if the user pressed enter
--   callbackEscape  Called if the user pressed escape
--   callbackSetup   Called first with `widget` passed as parameter
input_ask_value = function(widget, callbackEnter, callbackEscape, callbackSetup)
  local state = widget:save_state()
  local onEnter = widget.onEnter
  local onEscape = widget.onEscape
  
  local function restore_state()
    pop_temp_mode()
    widget:restore_state(state)
    widget.onEnter = onEnter
    widget.onEscape = onEscape
  end
  
  push_temp_mode('ALG')
  widget:setText('', '')
  if callbackSetup then
    callbackSetup(widget)
  end
  
  widget.onEnter = function()
    local text = widget.text
    restore_state()
    if callbackEnter then
      enterRes = callbackEnter(text)
    end
  end
  
  widget.onEscape = function()
    if callbackEscape then 
      callbackEscape()
    end
    restore_state()
  end
  
  widget:invalidate()
end


-- Menus
local function make_formula_menu()
  local category_menu = {}
  for title,category in pairs(formulas) do
    local actions_menu = {
      {"Solve for ...", function()
         solve_formula_interactive(category)
      end},
      {"Formulas ...", (function()
        local formula_list = {}
        for _,item in ipairs(category.formulas) do
          table.insert(formula_list, {item.title, item.infix})
        end
        return formula_list
      end)()},
      {"Variables ...", (function()
        local variables_list = {}
        for var,info in pairs(category.variables) do
          table.insert(variables_list, {info[1], var})
        end
        return variables_list
      end)}
    }

    table.insert(category_menu, {title, actions_menu})
  end
  
  return category_menu
end

local function make_options_menu()
  local function make_bool_item(title, key)
    return {title, function() options[key] = not options[key] end, state=options[key] == true}
  end

  local function make_choice_item(title, key, choices)
    local choice_items = {}
    for k,v in pairs(choices) do
      table.insert(choice_items, {
        k, function() options[key] = v end, state=options[key] == v
      })
    end
    return {title, choice_items}
  end

  local function make_theme_menu()
    local items = {}
    for name,_ in pairs(theme) do
      table.insert(items, {
        name, function() options.theme = name end, state=options.theme == name
      })
    end
    return {'Theme ...', items}
  end

  return {
    make_bool_item('Show Fringe', 'showFringe'),
    make_bool_item('Show Infix', 'showExpr'),
    make_bool_item('Smart Parens', 'autoClose'),
    make_bool_item('Smart Kill', 'autoKillParen'),
    make_bool_item('Smart Complete', 'smartComplete'),
    make_bool_item('Auto Pop', 'autoPop'),
    make_bool_item('Auto ANS', 'autoAns'),
    make_theme_menu()}
end


-- Called for _any_ keypress
function on_any_key()
  Error.hide()
end

-- View list
local views = {
  stack,
  input,
  Toast,
  ErrorToast,
  menu
}

function on.construction()
  toolpalette.register({
    {"Stack",
      {"DUP 2",  function() stack:dup(2) end},
      {"SWAP",   function() stack:swap() end},
      {"PICK 2", function() stack:pick(2) end},
      {"ROLL 3", function() stack:roll(3) end},
      {"DEL",    function() stack:pop() end},
      {"UNDO",   function() undo() end},
      {Sym.CONVERT.."List", function() stack:toList() end},
    },
    {"Clear",
      {"Clear A-Z", function() math.evalStr("ClearAZ") end},
    },
    {"Options",
      {"Show...", function() menu:present(focus, make_options_menu()) end}
    }
  })
  
  GlobalKbd:setSequence({'U'}, function(sequence)
    undo()
  end)
  GlobalKbd:setSequence({'R'}, function(sequence)
    redo()
  end)
  GlobalKbd:setSequence({'C'}, function(sequence)
    clear()
  end)

  -- Edit
  GlobalKbd:setSequence({'E'}, function(sequence)
    if stack:size() > 0 then
      local idx = stack.sel or stack:size()
      focusView(input)
      input_ask_value(input, function(expr)
        recordUndo()
        stack:pushInfix(expr)
        stack:swap(idx, #stack.stack)
        stack:pop()
      end, nil, function(widget)
        widget:setText(stack.stack[idx].infix, 'Edit #'..(#stack.stack - idx + 1))
      end)
    end
  end)

  -- Stack
  GlobalKbd:setSequence({'S', 'd', '%d'}, function(sequence)
    -- Duplicate N items from top
    recordUndo()
    stack:dup(tonumber(sequence[#sequence]))
  end)
  GlobalKbd:setSequence({'S', 'p', '%d'}, function(sequence)
    -- Pick item at N
    recordUndo()
    stack:pick(tonumber(sequence[#sequence]))
  end)
  GlobalKbd:setSequence({'S', 'r', '%d'}, function(sequence)
    -- Roll stack N times
    recordUndo()
    stack:roll(tonumber(sequence[#sequence]))
  end)
  GlobalKbd:setSequence({'S', 'r', 'r'}, function(sequence)
    -- Roll down 1
    recordUndo()
    stack:roll(1)
    return 'repeat'
  end)
  GlobalKbd:setSequence({'S', 'x', '%d'}, function(sequence)
    -- Pop item N from top
    recordUndo()
    stack:pop(tonumber(sequence[#sequence]), true)
  end)
  GlobalKbd:setSequence({'S', 'x', 'x'}, function(sequence)
    -- Pop all items from top
    recordUndo()
    stack.stack = {}
  end)
  GlobalKbd:setSequence({'S', 'l', '%d'}, function(sequence)
    -- Transform top N items to list
    recordUndo()
    stack:toList(tonumber(sequence[#sequence]))
  end)
  GlobalKbd:setSequence({'S', 'l', 'l'}, function(sequence)
    -- Transform top 2 items to list (repeatable)
    recordUndo()
    stack:toList(2)
    return 'repeat'
  end)

  -- Variables
  GlobalKbd:setSequence({'V', 'clear'}, function()
      math.evalStr('DelVar a-z')
  end)
  GlobalKbd:setSequence({'V', 'backspace'}, function()
    input_ask_value(input, function(varname)
      local res, err = math.evalStr('DelVar '..varname)
      if err then
        Error.show(err)
      end
    end, nil, function(widget)
      widget:setText('', 'Delete Var:')
      widget.completionFun = completion_fn_variables
    end)
  end)
  GlobalKbd:setSequence({'V', '='}, function()
    input_ask_value(input, function(varname)
      input_ask_value(input, function(value)
        local res, err = math.evalStr(varname..':=('..value..')')
        if err then
          Error.show(err)
        end
      end, nil, function(widget)
        local text = ''
        if #stack.stack > 0 then
          text = stack.stack[#stack.stack].result
        end
        widget:setText(text, varname..':=')
        widget:selAll()
      end)
    end, nil, function(widget)
      widget:setText('', 'Set Var:')
      widget.completionFun = completion_fn_variables
    end)
  end)

  -- Formula Library
  GlobalKbd:setSequence({'F'}, function(sequence)
    menu:present(focus, make_formula_menu())
  end)

  -- Mode
  GlobalKbd:setSequence({'M', 'r'}, function(sequence)
    -- Set mode to RPN
    options.mode = 'RPN'
  end)
  GlobalKbd:setSequence({'M', 'a'}, function(sequence)
    -- Set mode to ALG
    options.mode = 'ALG'
  end)
  GlobalKbd:setSequence({'M', 'm'}, function(sequence)
    -- Toggle mode
    options.mode = options.mode == 'RPN' and 'ALG' or 'RPN'
  end)

  focusView(input)
end

function on.resize(w, h)
  local inputHeight = getStringHeight()

  stack.frame = {
    x = 0,
    y = 0,
    width = w,
    height = h - inputHeight
  }
  input.frame = {
    x = 0,
    y = h - inputHeight,
    width = w,
    height = inputHeight
  }

  menu:center(stack.frame.width,
              stack.frame.height)
end

function on.escapeKey()
  on_any_key()
  GlobalKbd:resetSequence()
  if focus.kbd then
    focus.kbd:resetSequence()
  end
  if focus.onEscape then
    focus:onEscape()
  end
end

function on.tabKey()
  on_any_key()
  if focus ~= input then
    focusView(input)
  else
    input:onTab()
  end
end

function on.backtabKey()
  on_any_key()
  if focus.onBackTab then
    focus:onBackTab()
  end
end

function on.returnKey()
  on_any_key()
  if GlobalKbd:dispatchKey('return') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('return') then
    return
  end

  if focus == input then
    input:customCompletion({
      "=:", ":=", "{}", "[]", "@>"
    })
  end
end

function on.arrowRight()
  on_any_key()
  if GlobalKbd:dispatchKey('right') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('right') then
    return
  end
  if focus.onArrowRight then
    focus:onArrowRight()
  end
end

function on.arrowLeft()
  on_any_key()
  if GlobalKbd:dispatchKey('left') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('left') then
    return
  end
  if focus.onArrowLeft then
    focus:onArrowLeft()
  end
end

function on.arrowUp()
  on_any_key()
  if GlobalKbd:dispatchKey('up') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('up') then
    return
  end
  if focus.onArrowUp then
    focus:onArrowUp()
  end
end

function on.arrowDown()
  on_any_key()
  if GlobalKbd:dispatchKey('down') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('down') then
    return
  end
  if focus.onArrowDown then
    focus:onArrowDown()
  end
end

function on.charIn(c)
  on_any_key()
  if GlobalKbd:dispatchKey(c) then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey(c) then
    return
  end

  --for i=1,#c do
  --  print(c:byte(i))
  --end
  
  if focus.onCharIn then
    focus:onCharIn(c)
  end
end

function on.enterKey()
  on_any_key()
  GlobalKbd:resetSequence()
  if focus.kbd and focus.kbd:dispatchKey('enter') then
    return
  end
  if focus.onEnter then
    focus:onEnter()
  end
  if focus.invalidate then
    focus:invalidate()
  end
end

function on.backspaceKey()
  on_any_key()
  if GlobalKbd:dispatchKey('backspace') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('backspace') then
    return
  end
  if focus.onBackspace then
    focus:onBackspace()
  end
end

function on.clearKey()
  on_any_key()
  if GlobalKbd:dispatchKey('clear') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('clear') then
    return
  end
  if focus.onClear then
    focus:onClear()
  end
end

function on.contextMenu()
  on_any_key()
  if GlobalKbd:dispatchKey('ctx') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('ctx') then
    return
  end
  if focus.onContextMenu then
    focus:onContextMenu()
  end
end

function on.help()
  --[[ -- TEST CODE
  Macro({'@input:f1(x)', 'f1(x):=@1',
         'f1(0)', 'derivative(f1(x),x)|x=0', '@simp', '(f1(x)-@2-@1)|x=1', '@simp',
         'string(@1)&"((x+"&string((@2/@1)/2)&")^2+"&string((@3/@1)-(((@2/@1)/2)^2))&")"', '@label:f1(x)', '@clrbot:1',
         '{zeros(derivative(f1(x),x),x)}[1,1]', '@simp', '@label:SP x=',
         'f1(@1)', '@simp', '@label:SP y=',
         'zeros(f1(x),x)', '@simp', '@label:Zeros'}):execute()
  ]]--
  on_any_key()
  if GlobalKbd:dispatchKey('help') then
    return
  end
  if focus.kbd and focus.kbd:dispatchKey('help') then
    return
  end
end

function on.paint(gc, x, y, w, h)
  local frame = {x = x, y = y, width = w, height = h}

  for _,view in ipairs(views) do
    if Rect.intersection(frame, view:getFrame()) then
      view:draw(gc, frame)
    end
  end
end

function on.save()
  return {
    ['options'] = options,
    ['stack'] = stack.stack,
    ['input'] = input.text,
    ['undo'] = {UndoStack, RedoStack}
  }
end

function on.restore(state)
  UndoStack, RedoStack = unpack(state.undo)
  stack.stack = state.stack
  options = state.options
  input:setText(state.input)
end
