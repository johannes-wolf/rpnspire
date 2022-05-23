--[[
Copyright (c) 2022 Johannes Wolf <mail@johannes-wolf.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License version 3 as published by
the Free Software Foundation.
]]--

-- luacheck: ignore on

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
local function clone(t)
    if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            target[k] = clone(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
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
    textColor = 0,
    cursorColor = 0xEE0000,
    cursorColorAlg = 0x0000FF,
    backgroundColor = 0xFFFFFF,
    borderColor = 0,
    errorBackgroundColor = 0xEE0000,
    errorTextColor = 0xffffff,
  },
  ["dark"] = {
    rowColor = 0x444444,
    altRowColor = 0x222222,
    selectionColor = 0xEE0000,
    fringeTextColor = 0xAAAAAA,
    textColor = 0xFFFFFF,
    cursorColor = 0xEE0000,
    cursorColorAlg = 0xEE00EE,
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
  maxUndo = 20,          -- Max num of undo steps
}

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

--[[ MACRO ]]--
local currentMacro = nil -- Currently or last active macro coroutine

-- A macro is a list of actions to execute with some special function available
Macro = class()

function Macro:init(s)
  self.steps = s or {}
end

function Macro:exec()
  currentMacro = coroutine.create(function()
    for _,s in ipairs(self.steps) do
      -- TODO: Implement
    end
  end)
end


-- Lexer for TI math expressions being as close to the original as possible
Infix = {}
function Infix.tokenize(input)
  local function operator(input, i)
    return Trie.find(input, operators_trie, i)
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
    return input:find('^(_%a+)', i)
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

    local rows, cols = 0, 0
    for token in next do
      local value, kind = token[1], token[2]
      if value == ',' then
        cols = cols + 1
        if not popUntil('[') then
          print("error: RPNExpression.fromInfix missing '['")
          return
        end
      elseif value == '[' then
        rows = rows + 1
        if not popUntil('[') then
          print("error: RPNExpression.fromInfix missing '['")
          return
        end
        --handleDefault(value, kind)
      elseif value == ']' then
        if popUntil('[') then
          table.remove(stack, #stack)
          --table.insert(result, {tostring(argc), 'number'})
          --table.insert(result, {']', 'syntax'})
          return
        else
          print("error: RPNExpression.fromInfix missing '['")
          return
        end
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
    while rows > 0 do
      str = str .. "["
      for col=cols,0,-1 do
        str = table.remove(stack, #stack).expr .. str
        if col > 1 then str = "," .. str end
        rows = rows - 1
      end
      str = str .. "]"
    end
    str = "[" .. str .. "]"

    table.insert(stack, {expr=str, prec=99})
  end
  
  local function push(value, kind)
    if value == '}' then
      return pushList()
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
  
  return #stack > 0 and stack[#stack].expr or nil
end


Widgets = {}

-- Widget Base Class
Widgets.Base = class()

-- Fullscreen 9-tile menu which is navigated using the numpad
UIMenu = class(Widgets.Base)
function UIMenu:init()
  self.frame = {width=0, height=0, x=0, y=0}
  self.page = 0
  self.pageStack = {}
  self.items = {}
  self.visible = false
  self.parent = nil
end

function UIMenu:center(w, h)
  w = w or platform.window:width()
  h = h or platform.window:height()
  
  local margin = 8
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
  end
end

function UIMenu:present(parent, items)
  self.pageStack = {}
  self:pushPage(items or {})
  self.parent = parent
  focusView(self)
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
  self:invalidate()
end

function UIMenu:onLooseFocus()
  self.visible = false
  self:invalidate()
end

function UIMenu:onTab()
  if #items > 9 then
    self.page = (self.page + 1) % math.floor(#items / 9)
    self:invalidate()
  end
end

function UIMenu:onEnter()
  self:hide()
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
  self:hide()
end

function UIMenu:onClear()
  self.page = 0
  self:invalidate()
end

function UIMenu:pushPage(page)
  if page then
    table.insert(self.pageStack, page)
    self.items = self.pageStack[#self.pageStack]
    self:invalidate()
  end
end

function UIMenu:popPage()
  if #self.pageStack > 1 then
    table.remove(self.pageStack, #self.pageStack)
    self.items = self.pageStack[#self.pageStack]
    self:invalidate()
  end
end

function UIMenu:onCharIn(c)
  if c:byte(1) >= 49 and c:byte(1) <= 57 then -- [1]-[9]
    local n = c:byte(1) - 49
    local row, col = 2 - math.floor(n / 3), n % 3
    local item = self.items[self.page * 9 + row * 3 + (col+1)]
    if not item then return end
    
    if type(item[2]) == "function" then
      item[2]()
      focusView(self.parent)
    elseif type(item[2]) == "table" then
      self:pushPage(item[2])
    elseif type(item[2]) == "string" then
      input:onCharIn(item[2]) -- TODO
      focusView(input)
    end
  end
end

function UIMenu:drawCell(gc, item, x, y, w ,h)
  local margin = 4
  x = x + margin
  y = y + margin
  w = w - 2*margin
  h = h - 2*margin

  if w < 0 or h < 0 then return end
  gc:clipRect("set", x-1, y-1, w+2, h+2)

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

  local tw, th = gc:getStringWidth(item[1]), gc:getStringHeight(item[1])
  local tx, ty = x + w/2 - tw/2, y + h/2 - th/2
  
  gc:setColorRGB(theme[options.theme].textColor)
  gc:drawString(item[1], tx, ty)
end

function UIMenu:draw(gc)
  if not self.visible then return end

  gc:clipRect("set", self:getFrame())
  
  local pageOffset = self.page * 9
  
  local cw, ch = self.frame.width/3, self.frame.height/3
  for row=1,3 do
    for col=1,3 do
      local cx, cy = self.frame.x + cw*(col-1), self.frame.y + ch*(row-1)
      self:drawCell(gc, self.items[pageOffset + (row-1)*3 + col] or nil, cx, cy, cw, ch)
    end
  end
  
  gc:clipRect("reset")
end

-- RPN stack view
UIStack = class(Widgets.Base)
function UIStack:init()
  self.stack = {}
  self.frame = {x=0, y=0, width=0, height=0}
  self.scrolly = 0
  self.sel = 0
  return o
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
  assert(item)
  if item then
    table.insert(self.stack, item)
    self:scrollToIdx()
    self:invalidate()
  end
end

function UIStack:swap(idx1, idx2)
  if #self.stack < 2 then return end
  
  idx1 = idx1 or (#self.stack - 1)
  idx2 = idx2 or #self.stack
  if idx1 <= #self.stack and idx2 <= #self.stack then
    local tmp = clone(self.stack[idx1])
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
    table.insert(self.stack, clone(self.stack[idx + i - 1]))
  end
end

function UIStack:pick(n)
  n = n or 1
  local idx = #self.stack - (n - 1)
  table.insert(self.stack, clone(self.stack[idx]))
end

function UIStack:toList(n)
  if #self.stack <= 0 then return end

  if n == nil then
    n = tonumber(self:pop().result)
  end

  assert(type(n)=="number")
  assert(n >= 0)

  local newTop = math.max(#stack.stack - n + 1, 1)
  local rpn = RPNExpression()
  for i=1,n do
    local arg = stack:pop(newTop)
    if arg then
      rpn:appendStack(arg.rpn)
    else
      n = n - 1
    end
  end
  
  rpn:push({tostring(n), 'number'})
  rpn:push('}')

  self:pushRPNExpression(rpn)
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
function UIStack:onArrowLeft()
  self:roll(-1)
end

function UIStack:onArrowRight()
  self:roll(1)
end

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

function UIStack:onLooseFocus()
  self:invalidate()
end

function UIStack:onFocus()
  self:selectIdx()
end

function UIStack:onEnter()
  if self.sel > 0 then
    self:onCharIn("d")
    self.sel = #self.stack
  end
end

function UIStack:onBackspace()
  self:onCharIn("x")
end

function UIStack:onClear()
  recordUndo()
  self.stack = {}
  self:selectIdx()
  focusView(input)
end

function UIStack:onCharIn(c)
  if c == "x" then
    recordUndo()
    table.remove(self.stack, self.sel)
    if #self.stack == 0 then
      focusView(input)
    end
  elseif c == "d" then
    recordUndo()
    self:push(clone(self.stack[self.sel]))
  elseif c == "r" then
    recordUndo()
    self:push(self.stack[self.sel].result)
  elseif c == "=" then
    recordUndo()
    local rpn = RPNExpression(self.stack[self.sel].rpn)
    local infix = rpn:infixString()
    local res, err = math.evalStr(infix)
    self:push({rpn=rpn, infix=infix, result=res or ("error: "..err)})
  elseif c == "c" then
    input:setText(self.stack[self.sel].result)
  elseif c == "s" then
    if self.sel > 1 then
      self:swap(self.sel, self.sel - 1)
    end
  elseif c == "7" then
    self:selectIdx(1)
  elseif c == "3" then
    self:selectIdx(#self.stack)
  elseif c == "5" then
    showBigView(true, self.sel)
  end
  
  -- Fix selection if out of bounds
  if self.sel > #self.stack then
    self.sel = #self.stack
  end
  self:invalidate()
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
  
  local leftSize = {w = gc:getStringWidth(item.infix or ""), h = gc:getStringHeight(item.infix or "")}
  local rightSize = {w = gc:getStringWidth(item.result or ""), h = gc:getStringHeight(item.result or "")}
  
  local fringeSize = gc:getStringWidth("0")*math.floor(math.log10(#self.stack)+1)
  local fringeMargin = options.showFringe and fringeSize + 3*margin or 0
  
  local leftPos = {x = x + fringeMargin + margin,
                   y = y}
  local rightPos = {x = x + w - margin - rightSize.w,
                    y = y}
  
  if options.showExpr then
    if rightPos.x < leftPos.x + leftSize.w + minDistance then
      rightPos.y = leftPos.y + margin*2 + leftSize.h
    end
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
  if options.showExpr == true then
    gc:drawString(item.infix or "", leftPos.x, leftPos.y)
    gc:drawString(item.result or "", rightPos.x, rightPos.y)
  else
    gc:drawString(item.result or "", leftPos.x, leftPos.y)
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
  -- Mode
  self.tempMode = nil
  -- Input
  self.inputHandler = RPNInput()
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
  
  self.cursor.pos = math.min(math.max(0, pos), self.text:ulen())
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

function UIInput:onLooseFocus()
  self:cancelCompletion()
  self:invalidate()
end

function UIInput:onFocus()
  self:setCursor(#self.text)
  self:invalidate()
end

function UIInput:onCharIn(c)
  self:cancelCompletion()
  if not self.inputHandler:onCharIn(c) then
    self:_insertChar(c)
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
  if currentMacro ~= nil then
    coroutine.resume(currentMacro)
  end
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

function UIInput:setTempMode(mode)
  self.tempMode = mode or options.mode
  self:invalidate()
end

function UIInput:getMode()
  return self.tempMode or options.mode
end

function UIInput:setText(s, prefix)
  self.text = s or ""
  self.prefix = prefix or ""
  self:setCursor(#self.text)
  self:cancelCompletion()
  self:invalidate()
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
  local cursorx = gc:getStringWidth(string.usub(self.text, 1, self.cursor.pos))
  cursorx = cursorx + x + scrollx
  
  gc:clipRect("set", x, y, w, h)
  
  -- Draw prefix text
  if self.prefix:len() > 0 then
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
    gc:setColorRGB(self:getMode() == "RPN" and 
        theme[options.theme].cursorColor or
        theme[options.theme].cursorColorAlg)
    gc:fillRect(cursorx+1, y+2, options.cursorWidth, h-3)
  end
  
  gc:clipRect("reset")
end

function UIInput:draw(gc)
  self:drawFrame(gc)
  self:drawText(gc)
end


--[[ === BIG UI === ]]--
-- TODO: Refactor
function showBigView(show, idx)
  if show == true then
    focusView({
      onArrowRight = function() end,
      onArrowLeft = function() end,
      onArrowUp = function() end,
      onArrowDown = function() end,
      onCharIn = function(c) end,
      onBackspace = function(c) 
        focusView(input)
      end,
      onEscape = function() 
        focusView(input)
      end,
      onFocus = function()
        local margin = 8
        bigview:setBorder(2)
        bigview:setBorderColor(theme[options.theme].borderColor)
        bigview:move(margin, margin)
        bigview:resize(platform.window:width() - 2*margin, platform.window:height() - 2*margin)
        bigview:setVisible(show == true)
        bigview:setReadOnly(true)
      end,
      onLooseFocus = function()
        bigview:setVisible(false)
      end,
      onEnter = function()
        focusView(input)
      end,
      onClear = function()
      end
    })
    local item = stack.stack[idx or #stack.stack]
    if item ~= nil then
      bigview:createMathBox():setExpression("\\0el {"..item.infix.." = "..item.result.."}")
    else
      bigview:setExpression(":-(")
    end
  else
    focusView(stack)
  end
end


--[[ === UNDO/REDO === ]]--
local UndoStack, RedoStack = {}, {}

-- Returns a new undo-state table by copying the current stack and text input
local function makeUndoState(text)
  return {
    stack=clone(stack.stack),
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
  input:setTempMode()
  input:invalidate()
  currentMacro = nil
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

function RPNInput:dispatchFunction(str, ignoreInput)
  local name, argc = functionInfo(str)
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

  if options.mode == "ALG" or not self:isBalanced() then
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
  if options.mode == "RPN" then
    if self:dispatchFunction(self:getInput(), true) then
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
focus = input

function focusView(v)
  if v ~= nil and v ~= focus then
    focus:onLooseFocus()
    focus = v
    focus:onFocus()
  end
end

input.completionFun = function(prefix)
  local catmatch = function(tab, prefix, res)
    res = res or {}
    local plen = prefix and #prefix or 0
    for _,v in ipairs(tab or {}) do
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
      candidates = catmatch(unitTab, prefix, candidates)
    end
    if semantic['conversion_op'] then
      candidates = catmatch({'@>'}, prefix, candidates) -- TODO: Use unicode when input is ready
    end
    if semantic['conversion_fn'] then
      candidates = catmatch({
        'approxFraction()',
        'Base2', 'Base10', 'Base16',
        'Decimal',
        'Grad', 'Rad'
      }, prefix, candidates)
    end
    if semantic['function'] then
      candidates = catmatch(functionTab, prefix, candidates)
    end
    if semantic['variable'] then
      candidates = catmatch(var.list(), prefix, candidates)
    end
    if semantic['common'] then
      candidates = catmatch(commonTab, prefix, candidates) -- TODO: Add common tab
      candidates = catmatch(var.list(), prefix,
                   catmatch(functionTab, prefix,
                   catmatch(unitTab, prefix, candidates)))
    end

    return candidates
  end

  -- Provide all
  return catmatch(var.list(), prefix,
         catmatch(functionTab, prefix,
         catmatch(unitTab, prefix)))
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
  self.onSequenceChanged = nil -- void({sequence})
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

  -- Exit if not found
  if not self.currentTab then
    self:resetSequence()
    return false
  end

  -- Call binding
  if type(self.currentTab) == 'function' then
    self.currentTab(self.currentSequence)
    self:resetSequence()
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


-- Called for _any_ keypress
function onAnyKey()
  Error.hide()
end

function on.construction()
  bigview = D2Editor.newRichText() -- TODO: Refactor to custom view

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
    {"Settings",
      {"Light theme", function() options.theme = "light" end},
      {"Dark theme",  function() options.theme = "dark" end},
      {"Toggle fringe", function() options.showFringe = not options.showFringe end},
      {"Toggle calculation", function() options.showExpr = not options.showExpr end},
      {"Toggle smart parens", function() options.autoClose = not options.autoClose; options.autoKillParen = options.autoClose end},
      {"Toggle smart complete", function() options.smartComplete = not options.smartComplete end},
    }
  })
  
  GlobalKbd:setSequence({'I'}, function(sequence)
    menu:present(input, {
      {'{', '{'}, {'=:', '=:'}, {'}', '}'},
      {'[', '['}, {'@>', '@>'}, {']', ']'},
      {'<', '<'}, {':=', ':='}, {'>', '>'},
    })
  end)
  GlobalKbd:setSequence({'U'}, function(sequence)
    undo()
  end)
  GlobalKbd:setSequence({'R'}, function(sequence)
    redo()
  end)
  GlobalKbd:setSequence({'C'}, function(sequence)
    clear()
  end)
  GlobalKbd:setSequence({'E'}, function(sequence)
    if #stack.stack >= 1 then
      input:setTempMode("ALG")
      input:setText(stack:pop().infix, "Edit")
    end
  end)
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
  GlobalKbd:setSequence({'M', 'r'}, function(sequence)
    -- Set mode to RPN
    options.mode = 'RPN'
  end)
  GlobalKbd:setSequence({'M', 'a'}, function(sequence)
    -- Set mode to ALG
    options.mode = 'ALG'
  end)
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
  onAnyKey()
  GlobalKbd:resetSequence()
  
  if focus.onEscape then
    focus:onEscape()
  end
end

function on.tabKey()
  onAnyKey()
  if focus ~= input then
    focusView(input)
  else
    input:onTab()
  end
end

function on.backtabKey()
  onAnyKey()
  if focus.onBackTab then
    focus:onBackTab()
  end
end

function on.returnKey()
  onAnyKey()
  if GlobalKbd:dispatchKey('return') then
    return
  end

  if focus == input then
    --menu:present(input, {
    --  {"→", "=:"}, {":=", ":="}, {"@"},
    --  {"{", "{"},  {"}", "}"}, {"\""},
    --  {"[", "["},  {"]", "]"}, {"'", "'"}
    --})
    input:customCompletion({
      "=:", ":=", "{}", "[]", "@>"
    })
  end
end

function on.arrowRight()
  onAnyKey()
  if GlobalKbd:dispatchKey('right') then
    return
  end
  if focus.onArrowRight then
    focus:onArrowRight()
  end
end

function on.arrowLeft()
  onAnyKey()
  if GlobalKbd:dispatchKey('left') then
    return
  end
  if focus.onArrowLeft then
    focus:onArrowLeft()
  end
end

function on.arrowUp()
  onAnyKey()
  if GlobalKbd:dispatchKey('up') then
    return
  end
  if focus.onArrowUp then
    focus:onArrowUp()
  end
end

function on.arrowDown()
  onAnyKey()
  if GlobalKbd:dispatchKey('down') then
    return
  end
  if focus.onArrowDown then
    focus:onArrowDown()
  end
end

function on.charIn(c)
  onAnyKey()
  if GlobalKbd:dispatchKey(c) then
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
  onAnyKey()
  GlobalKbd:resetSequence()
  focus:onEnter()
  stack:invalidate() -- TODO: ?
  input:invalidate()
end

function on.backspaceKey()
  onAnyKey()
  GlobalKbd:resetSequence()
  if focus.onBackspace then
    focus:onBackspace()
  end
end

function on.clearKey()
  onAnyKey()
  if GlobalKbd:dispatchKey('clear') then
    return
  end
  if focus.onClear then
    focus:onClear()
  end
end

function on.contextMenu()
  onAnyKey()
  if GlobalKbd:dispatchKey('ctx') then
    return
  end
  if focus.onContextMenu then
    focus:onContextMenu()
  end

  -- FIXME: this is just a test
  if focus == stack then
    menu:present(stack, {
      {"Options", {
        {"Fringe", function() options.showFringe = not options.showFringe end},
        {"Calc", function() options.showExpr = not options.showExpr end},
        {"Complete", {
          {"Smart", function() options.smartComplete = true end},
          {"Prefix", function() options.smartComplete = false end},
        }},
        {"Theme", {
          {"light", function() options.theme="light" end},
          {"dark",  function() options.theme="dark" end},
        }}
      }},
      {"Clear A-Z", function() math.evalStr("ClearAZ") end},
    })
  elseif focus == input then
    menu:present(input, {
      {"Const", {
        {"g", "_g"}, {"c", "_c"},
      }},
      {"Units", {
        {"Length", {
          {"m", "_m"}
        }},
        {"Mass", {
          {"kg", "_kg"}
        }}
      }},
      {"CAS", {
        {"solve", "solve"}, {"zeros", "zeros"}
      }}, 
      {options.mode == "RPN" and "ALG" or "RPN", function() options.mode = options.mode == "RPN" and "ALG" or "RPN" end},
    })
  end
end

function on.paint(gc)
  stack:draw(gc)
  input:draw(gc)
  Toast:draw(gc)
  ErrorToast:draw(gc)
  menu:draw(gc)
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
