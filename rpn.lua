--[[
Copyright (c) 2022 Johannes Wolf <mail@johannes-wolf.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License version 3 as published by
the Free Software Foundation.
]]--

-- Returns the height of string `s`
function getStringHeight(s)
  return platform.withGC(function(gc) return gc:getStringHeight(s or "A") end)
end

-- Dump table `o` to string
function dump(o)
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
function clone(t)
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
  while tab do
    j = j+1
    tab = tab[str:sub(j, j)]
    if tab and tab['@LEAF@'] then 
      return i, j, str:sub(i, j)
    end
  end
  return nil
end

-- Themes
theme = {
  ["light"] = {
    rowColor = 0xFFFFFF,
    altRowColor = 0xEEEEEE,
    selectionColor = 0xDFDFFF,
    fringeTextColor = 0xAAAAAA,
    textColor = 0,
    cursorColor = 0xFF0000,
    cursorColorAlg = 0x0000FF,
    backgroundColor = 0xFFFFFF,
    borderColor = 0,
  },
  ["dark"] = {
    rowColor = 0x444444,
    altRowColor = 0x222222,
    selectionColor = 0xFF0000,
    fringeTextColor = 0xAAAAAA,
    textColor = 0xFFFFFF,
    cursorColor = 0xFF0000,
    cursorColorAlg = 0xFF00FF,
    backgroundColor = 0x111111,
    borderColor = 0x888888,
  },
}

-- Global options
options = {
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
}


ASCII_LPAREN = 40   -- (
ASCII_RPAREN = 41   -- )
ASCII_LBRACK = 91   -- [
ASCII_RBRACK = 93   -- ]
ASCII_LBRACE = 123  -- {
ASCII_RBRACE = 125  -- }
ASCII_DQUOTE = 34   -- "
ASCII_SQUOTE = 39   -- '

SYM_NEGATE = "\226\136\146"
SYM_STORE  = "→"
SYM_ROOT   = "\226\136\154"
SYM_NEQ    = "≠"
SYM_LEQ    = "≤"
SYM_GEQ    = "≥"
SYM_LIMP   = "⇒"
SYM_DLIMP  = "⇔"
SYM_RAD    = "∠"
SYM_TRANSP = ""
SYM_DEGREE = "\194\176"
SYM_CONVERT= "\226\150\182"
SYM_EE     = "\239\128\128"
SYM_POWN1  = "\239\128\133" -- ^-1

operators = {
  --[[                 string, lvl, #, side, assoc, aggressive-assoc ]]--
  -- Parentheses
  ["#"]             = {nil,     18, 1, -1},
  --
  -- Function call
  -- [" "]             = {nil, 17, 1,  1}, -- DEGREE/MIN/SEC
  ["!"]             = {nil,     17, 1,  1},
  ["%"]             = {nil,     17, 1,  1},
  [SYM_RAD]         = {nil,     17, 1,  1},
  -- [" "]             = {nil, 17, 1,  1}, -- SUBSCRIPT
  ["@t"]            = {SYM_TRANSP, 17, 1, 1},
  [SYM_TRANSP]      = {nil,     17, 1,  1},
  --
  ["^"]             = {nil,     16, 2,  0, 'r', true}, -- Matching V200 RPN behavior
  --
  ["(-)"]           = {SYM_NEGATE,15,1,-1},
  [SYM_NEGATE]      = {nil,     15, 1, -1},
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
  [SYM_NEQ]         = {nil,     11, 2,  0, 'r'},
  ["/="]            = {SYM_NEQ, 11, 2,  0, 'r'},
  ["<"]             = {nil,     11, 2,  0, 'r'},
  [">"]             = {nil,     11, 2,  0, 'r'},
  [SYM_LEQ]         = {nil,     11, 2,  0, 'r'},
  ["<="]            = {SYM_LEQ, 11, 2,  0, 'r'},
  [SYM_GEQ]         = {nil,     11, 2,  0, 'r'},
  [">="]            = {SYM_GEQ, 11, 2,  0, 'r'},
  --
  ["not"]           = {"not ",  10, 1, -1},
  ["and"]           = {" and ", 10, 2,  0},
  ["or"]            = {" or ",  10, 2,  0},
  --
  ["xor"]           = {" xor ",  9, 2,  0},
  ["nor"]           = {" nor ",  9, 2,  0},
  ["nand"]          = {" nand ", 9, 2,  0},
  --
  [SYM_LIMP]        = {nil,      8, 2,  0, 'r'},
  ["=>"]            = {SYM_LIMP, 8, 2,  0, 'r'},
  --
  [SYM_DLIMP]       = {nil,      7, 2,  0, 'r'},
  ["<=>"]           = {SYM_DLIMP,7, 2,  0, 'r'},
  --
  ["|"]             = {nil,      6, 2,  0},
  --
  [SYM_STORE]       = {nil,      5, 2,  0, 'r'},
  ["=:"]            = {SYM_STORE,5, 2,  0, 'r'},
  [":="]            = {nil,      5, 2,  0, 'r'},
  
  [SYM_CONVERT]     = {nil, 1, 2, 0},
  ["@>"]            = {SYM_CONVERT, 1, 2,  0}
}
operators_trie = Trie.build(operators)

-- Query operator information
function queryOperatorInfo(s)
  local tab = operators[s]
  if tab == nil then return nil end
  
  local str, lvl, args, side, assoc, aggro = unpack(tab)
  return (str or s), lvl, args, side, assoc, aggro
end

-- Returns the number of arguments for the nspire function `nam`.
-- Implementation is hacky, but there seems to be no clean way of
-- getting this information.
function tiGetFnArgs(nam)
  local res, err = math.evalStr("getType("..nam..")")
  if err ~= nil or res ~= "\"FUNC\"" then
    return nil
  end

  local argc = 0
  local arglist = ""
  for i=0,10 do
    res, err = math.evalStr("string("..nam.."("..arglist.."))")
    if err == nil then
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
functions = {
  ["abs"]             = {n = 1},
  ["amortTbl"]        = {n = 10, min = 4},
  ["angle"]           = {n = 1},
  ["approx"]          = {n = 1},
  ["approxFraction"]  = {n = 1, min = 0, conv = true},
  ["approxRational"]  = {n = 2, min = 1},
  ["arccos"]          = {n = 1},
  ["arccosh"]         = {n = 1},
  ["arccot"]          = {n = 1},
  ["arccoth"]         = {n = 1},
  ["arccsc"]          = {n = 1},
  ["arccsch"]         = {n = 1},
  ["arcLen"]          = {n = 4},
  ["arcsec"]          = {n = 1},
  ["arcsech"]         = {n = 1},
  ["arcsin"]          = {n = 1},
  ["arcsinh"]         = {n = 1},
  ["arctan"]          = {n = 1},
  ["arctanh"]         = {n = 1},
  ["augment"]         = {n = 2},
  ["avgRC"]           = {n = 3, min = 2},
  ["bal"]             = {{n = 10, min = 4},
                         {n = 2}},
  ["binomCdf"]        = {{n = 5},
                         {n = 3},
                         {n = 2}},
  ["binomPdf"]        = {{n = 2},
                         {n = 3}},
  ["ceiling"]         = {n = 1},
  ["centralDiff"]     = {n = 3, min = 2},
  ["cFactor"]         = {n = 2, min = 1},
  ["char"]            = {n = 1},
  ["charPoly"]        = {n = 2},
  ["colAugment"]      = {n = 2},
  ["colDim"]          = {n = 1},
  ["colNorm"]         = {n = 1},
  ["comDenom"]        = {n = 2, min = 1},
  ["completeSquare"]  = {n = 2},
  ["conj"]            = {n = 1},
  ["constructMat"]    = {n = 5},
  ["corrMat"]         = {n = 20, min = 2},
  ["cos"]             = {n = 1},
  ["cos"..SYM_POWN1]  = {n = 1},
  ["cosh"]            = {n = 1},
  ["cosh"..SYM_POWN1] = {n = 1},
  ["cot"]             = {n = 1},
  ["cot"..SYM_POWN1]  = {n = 1},
  ["coth"]            = {n = 1},
  ["coth"..SYM_POWN1] = {n = 1},
  ["count"]           = {min = 1},
  ["countif"]         = {n = 2},
  ["cPolyRoots"]      = {{n = 1},
                         {n = 2}},
  ["crossP"]          = {n = 2},
  ["csc"]             = {n = 1},
  ["csc"..SYM_POWN1]  = {n = 1},
  ["csch"]            = {n = 1},
  ["csch"..SYM_POWN1] = {n = 1},
  ["cSolve"]          = {{n = 2},
                         {min = 3}},
  ["cumulativeSum"]   = {n = 1},
  ["cZeros"]          = {n = 2},
  ["dbd"]             = {n = 2},
  ["deltaList"]       = {n = 1},
  ["deltaTmpCnv"]     = {n = 2}, -- FIXME: Check n
  ["delVoid"]         = {n = 1},
  ["derivative"]      = {n = 2}, -- FIXME: Check n
  ["deSolve"]         = {n = 3},
  ["det"]             = {n = 2, min = 1},
  ["diag"]            = {n = 1},
  ["dim"]             = {n = 1},
  ["domain"]          = {n = 2},
  ["dominantTerm"]    = {n = 3, min = 2},
  ["dotP"]            = {n = 2},
  --["e^"]              = {n = 1},
  ["eff"]             = {n = 2},
  ["eigVc"]           = {n = 1},
  ["eigVl"]           = {n = 1},
  ["euler"]           = {n = 7, min = 6},
  ["exact"]           = {n = 2, min = 1},
  ["exp"]             = {n = 1},
  ["expand"]          = {n = 2, min = 1},
  ["expr"]            = {n = 1},
  ["factor"]          = {n = 2, min = 1},
  ["floor"]           = {n = 1},
  ["fMax"]            = {n = 4, min = 2},
  ["fMin"]            = {n = 4, min = 2},
  ["format"]          = {n = 2, min = 1},
  ["fPart"]           = {n = 1},
  ["frequency"]       = {n = 2},
  ["gcd"]             = {n = 2},
  ["geomCdf"]         = {n = 3, min = 2},
  ["geomPdf"]         = {n = 2},
  ["getDenom"]        = {n = 1},
  ["getLangInfo"]     = {n = 0},
  ["getLockInfo"]     = {n = 1},
  ["getMode"]         = {n = 1},
  ["getNum"]          = {n = 1},
  ["getType"]         = {n = 1},
  ["getVarInfo"]      = {n = 1, min = 0},
  ["identity"]        = {n = 1},
  ["ifFn"]            = {n = 4, min = 2},
  ["imag"]            = {n = 1},
  ["impDif"]          = {n = 4, min = 3},
  ["inString"]        = {n = 3, min = 2},
  ["int"]             = {n = 1},
  ["integral"]        = {n = 2},
  ["intDiv"]          = {n = 2},
  ["interpolate"]     = {n = 4},
  --["invX^2"]          = {n = 1},
  --["invF"]            = {n = 1},
  ["invNorm"]         = {n = 3, min = 2},
  ["invt"]            = {n = 2},
  ["iPart"]           = {n = 1},
  ["irr"]             = {n = 3, min = 2},
  ["isPrime"]         = {n = 1},
  ["isVoid"]          = {n = 1},
  ["lcm"]             = {n = 2},
  ["left"]            = {n = 2, min = 1},
  ["libShortcut"]     = {n = 3, min = 2},
  ["limit"]           = {n = 4, min = 3},
  ["lim"]             = {n = 4, min = 3},
  ["linSolve"]        = {n = 2},
  ["ln"]              = {n = 1},
  ["log"]             = {n = 2, min = 1},
  ["max"]             = {n = 2},
  ["mean"]            = {n = 2},
  ["median"]          = {n = 2, min = 1},
  ["mid"]             = {n = 3, min = 2},
  ["min"]             = {n = 2},
  ["mirr"]            = {n = 5, min = 4},
  ["mod"]             = {n = 2},
  ["mRow"]            = {n = 3},
  ["mRowAdd"]         = {n = 4},
  ["nCr"]             = {n = 2},
  ["nDerivative"]     = {n = 3, min = 2},
  ["newList"]         = {n = 1},
  ["newMat"]          = {n = 2},
  ["nfMax"]           = {n = 4, min = 2},
  ["nfMin"]           = {n = 4, min = 2},
  ["nInt"]            = {n = 4},
  ["nom"]             = {n = 2},
  ["norm"]            = {n = 1},
  ["normalLine"]      = {n = 3, min = 2},
  ["normCdf"]         = {n = 4, min = 2},
  ["normPdf"]         = {n = 3, min = 1},
  ["nPr"]             = {n = 2},
  ["pnv"]             = {n = 4, min = 3},
  ["nSolve"]          = {n = 4, min = 2},
  ["ord"]             = {n = 1},
  ["piecewise"]       = {min = 1},
  ["poissCdf"]        = {n = 3, min = 2},
  ["poissPdf"]        = {n = 2},
  ["polyCoeffs"]      = {n = 2, min = 1},
  ["polyDegree"]      = {n = 2, min = 1},
  ["polyEval"]        = {n = 2},
  ["polyGcd"]         = {n = 2},
  ["polyQuotient"]    = {n = 3, min = 2},
  ["polyRemainder"]   = {n = 3, min = 2},
  ["polyRoots"]       = {n = 2, min = 1},
  ["prodSeq"]         = {n = 4}, -- FIXME: Check n
  ["product"]         = {n = 3, min = 0},
  ["propFrac"]        = {n = 2, min = 1},
  ["rand"]            = {n = 1, min = 0},
  ["randBin"]         = {n = 3, min = 2},
  ["randInt"]         = {n = 3, min = 2},
  ["randMat"]         = {n = 2},
  ["randNorm"]        = {n = 3, min = 2},
  ["randSamp"]        = {n = 3, min = 2},
  ["real"]            = {n = 1},
  ["ref"]             = {n = 2, min = 1},
  ["remain"]          = {n = 2},
  ["right"]           = {n = 2, min = 1},
  ["rk23"]            = {n = 7, min = 6},
  ["root"]            = {n = 2, min = 1},
  ["rotate"]          = {n = 2, min = 1},
  ["round"]           = {n = 2, min = 1},
  ["rowAdd"]          = {n = 3},
  ["rowDim"]          = {n = 1},
  ["rowNorm"]         = {n = 1},
  ["rowSwap"]         = {n = 3},
  ["rref"]            = {n = 2, min = 1},
  ["sec"]             = {n = 1},
  ["sec"..SYM_POWN1]  = {n = 1},
  ["sech"]            = {n = 1},
  ["sech"..SYM_POWN1] = {n = 1},
  ["seq"]             = {n = 5, min = 4},
  ["seqGen"]          = {n = 7, min = 4},
  ["seqn"]            = {n = 4, min = 1},
  ["series"]          = {n = 4, min = 3},
  ["setMode"]         = {n = 2, min = 1},
  ["shift"]           = {n = 2, min = 1},
  ["sign"]            = {n = 1},
  ["simult"]          = {n = 3, min = 2},
  ["sin"]             = {n = 1},
  ["sin"..SYM_POWN1]  = {n = 1},
  ["sinh"]            = {n = 1},
  ["sinh"..SYM_POWN1] = {n = 1},
  ["solve"]           = {n = 2},
  ["sqrt"]            = {n = 1, pretty = SYM_ROOT},
  [SYM_ROOT]          = {n = 1},
  ["stDefPop"]        = {n = 2, min = 1},
  ["stDefSamp"]       = {n = 2, min = 1},
  ["string"]          = {n = 1},
  ["subMat"]          = {n = 5, min = 1},
  ["sum"]             = {n = 3, min = 1},
  ["sumIf"]           = {n = 3, min = 2},
  ["sumSeq"]          = {n = 5, min = 4}, -- FIXME: Check n
  ["system"]          = {min = 1},
  ["tan"]             = {n = 1},
  ["tan"..SYM_POWN1]  = {n = 1},
  ["tangentLine"]     = {n = 3, min = 2},
  ["tanh"]            = {n = 1},
  ["tanh"..SYM_POWN1] = {n = 1},
  ["taylor"]          = {n = 4, min = 3},
  ["tCdf"]            = {n = 3},
  ["tCollect"]        = {n = 1},
  ["tExpand"]         = {n = 1},
  ["tmpCnv"]          = {n = 2},
  ["deltaTmpCnv"]     = {n = 2},
  ["tPdf"]            = {n = 2},
  ["trace"]           = {n = 1},
  ["tvmFV"]           = {n = 7, min = 4},
  ["tvml"]            = {n = 7, min = 4},
  ["tvmN"]            = {n = 7, min = 4},
  ["tvmPmt"]          = {n = 7, min = 4},
  ["tvmPV"]           = {n = 7, min = 4},
  ["unitV"]           = {n = 1},
  ["varPop"]          = {n = 2, min = 1},
  ["varSamp"]         = {n = 2, min = 1},
  ["warnCodes"]       = {n = 2},
  ["when"]            = {n = 4, min = 2},
  ["zeros"]           = {n = 2},
}

--[[
Function info table
  str, args
--]]
function functionInfo(s, builtinOnly)
  local name, argc = s, nil
  
  if s:find('^%d') then
    return nil
  end
  
  local argcBegin = s:find('%d+$')
  if argcBegin and argcBegin > 1 then
    argc = tonumber(s:sub(argcBegin))
    name = name:sub(1, argcBegin-1)
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


--[[
RPN specific functions
--]]
rpnFunctions = {
  ["swap"] = function() stack:swap() end,
  ["roll"] = function() stack:roll() end,
  ["dup"]  = function() stack:dup() end,
  ["dup2"] = function() stack:dup(2) end,
  ["dup3"] = function() stack:dup(3) end,
  ["pick"] = function() stack:pick(1) end,
  ["pick2"]= function() stack:pick(2) end,
  ["pick3"]= function() stack:pick(3) end,
  ["del"]  = function() stack:pop() end,
  ["tolist"]= function() stack:toList() end,
  ["rpn"]  = function() options.mode = "RPN" end,
  ["alg"]  = function() options.mode = "ALG" end,
  ["clearaz"] = function() math.evalStr("clearaz") end,
  -- History
  ["undo"] = function() popUndo(); undo() end, -- HACK: popUndo to remove the undo of the undo
  -- Weird features
  ["label"]= function() stack:label() end,
  ["killexpr"] = function() stack:killexpr() end,
  -- Debugging
  ["postfix"]  = function() stack:toPostfix() end,
  -- Macros
  ["mcall"] = function()
    -- TODO: this is a hack for testing out macros
    local n = string.unquote(stack:pop().result)
    local m = macros[n]
    if m ~= nil then
      m:exec()
    end
  end,
}

--[[ MACRO ]]--
currentMacro = nil -- Currently or last active macro coroutine

-- A macro is a list of actions to execute with some special function available
Macro = class()

function Macro:init(s)
  self.steps = s or {}
end

function Macro:exec()
  currentMacro = coroutine.create(function()
    for _,s in ipairs(self.steps) do
      if type(s)=="function" then
        s()
      elseif s:sub(1,2) == "?>" then -- Ask for input
        input:setText("", s:sub(3))
        coroutine.yield()
      elseif s:sub(1,2) == "?:" then -- Provide custom completion
        local prefix = s:sub(3,s:find(">"))
        local items = string.split(s:sub(s:find(">")+1),":")
        input:setText("", prefix)
        input:customCompletion(items)
        coroutine.yield()
      elseif not dispatchFull(s) then
        stack:push(s)
      end
    end
  end)
end

-- Global macro list
macros = {
  ["genqf"]  = Macro{"?>a:", "x", "?>x", SYM_NEGATE, "+", "2", "^", "?>y", "@pick3", "/", "+", "*"},
  ["seq"]    = Macro{"?>f(x)", "x", "?>start:", "?>end:", "seq"},
  ["sumSeq"] = Macro{"?>f(x)", "x", "?>x:", "?>end:", "sumSeq"},
}

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
    local li, lj, ltoken = input:find('^(%a[_%w]*%.%a[_%w]*)', i)
    if not li then
      return input:find('^(%a[_%w]*)', i)
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
        local ei, ej, etoken = input:find('^('..SYM_EE..'[%-%+]?%d+)', j+1)
        if not ei then
          -- SYM_NEGATE is a multibyte char, so we can not put it into the char-class above
          ei, ej, etoken = input:find('^('..SYM_EE..SYM_NEGATE..'%d+)', j+1)
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
    {fn=unit,       kind='unit'},
    {fn=number,     kind='number'},
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
      print("error: Infix.tokenize no match at "..pos.." '"..input:sub(pos).."'")
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
    local argc = 0
    for token in next do
      local value, kind = token[1], token[2]
      if value == ',' then
        argc = argc + 1
        if not popUntil('(') then
          print("error: RPNExpression.fromInfix missing '('")
          return
        end
      elseif value == ')' then
        if popUntil('(') then
          table.remove(stack, #stack)
          table.insert(result, {name, 'function'})
          return
        else
          print("error: RPNExpression.fromInfix missing '('")
          return
        end
      else
        if argc == 0 then argc = 1 end
        handleDefault(value, kind)
      end
    end
  end

  beginList = function()
    if listLevel > 1 then
      print("error: RPNExpression.fromInfix Nested lists are not allowed")
      return
    end

    local argc = 0
    for token in next do
      local value, kind = token[1], token[2]
      if value == ',' then
        argc = argc + 1
        if not popUntil('{') then
          print("error: RPNExpression.fromInfix missing '{'")
          return
        end
      elseif value == '}' then
        if popUntil('{') then
          table.remove(stack, #stack)
          table.insert(result, {tostring(argc), 'number'})
          table.insert(result, {'}', 'syntax'})
          return
        else
          print("error: RPNExpression.fromInfix missing '{'")
          return
        end
      else
        if argc == 0 then argc = 1 end
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

  self.stack = {}
  for _,v in ipairs(result) do
    table.insert(self.stack, v[1])
  end

  return self.stack
end

function RPNExpression:_isReverseOp(sym)
  if self.stack[#self.stack] == sym then
    return sym == SYM_NEGATE or sym == "(-)" or
           sym == "not" or sym == "not "
  end 
  return false
end

function RPNExpression:pop()
  return table.remove(self.stack, #self.stack)
end

function RPNExpression:push(sym)
  if self:_isReverseOp(sym) == true then
    -- Remove double negation/not
    self:pop()
  else
    table.insert(self.stack, sym)
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
  
  local function pushFunction(name, argc)
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
  
  local function push(str)
    if str == '}' then
      return pushList()
    end

    local opname, opprec, opargc, oppos, opassoc, opaggrassoc = queryOperatorInfo(str)
    if opname then
      return pushOperator(opname, opprec, opargc, oppos, opassoc, opaggrassoc)
    end
    
    local fname, fargc = functionInfo(str, false)
    if fname then
      return pushFunction(fname, fargc)
    end
    
    return table.insert(stack, {expr=str})
  end
  
  for _,v in ipairs(self.stack) do
    push(v)
  end
  
  return #stack > 0 and stack[#stack].expr or nil
end


-- Fullscreen 9-tile menu which is navigated using the numpad
UIMenu = class()

function UIMenu:init()
  self.frame = {width=0, height=0, x=0, y=0}
  self.items = {}
  self.page = 0
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
  self.items = items or {}
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
end

function UIMenu:onArrowDown()
end

function UIMenu:onEscape()
  self:hide()
end

function UIMenu:onClear()
  self.page = 0
  self:invalidate()
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
      self.items = item[2]
      self:invalidate()
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
UIStack = class()

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
  
  local res, err = math.evalStr(infix)
  self:push({["rpn"]=stack, ["infix"]=infix, ["result"]=res or ("error: "..err)})
  return true
end

function UIStack:pushEval(item)
  local infix = item:infixString()
  local res, err = math.evalStr(infix)
  self:push({["rpn"]=item.stack, ["infix"]=infix, ["result"]=res or ("error: "..err)})
end

function UIStack:push(item)
  if type(item) ~= "table" then
    local rpn = RPNExpression{item}
    local infix = rpn:infixString()
    local res, err = math.evalStr(infix)
    item = {["rpn"]=rpn.stack, ["infix"]=infix, ["result"]=res or ("error: "..err)}
  end
  if item ~= nil then
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

function UIStack:pop(idx)
  idx = idx or #self.stack
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
  
  rpn:push(tostring(n))
  rpn:push('}')

  self:pushEval(rpn)
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
  self:pushEval(rpn)
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
    --gc:setPen("thin", "dashed")
    
    fringeX = x + fringeSize + 2*margin
    gc:drawLine(fringeX, y, fringeX, y + itemHeight)
    gc:setColorRGB(theme[options.theme].fringeTextColor)
    gc:drawString(#self.stack - idx + 1, x + margin, y)
    gc:setPen()
    
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
UIInput = class()

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
    tail = self.text:sub(self.cursor.pos + self.cursor.size + 1)
  end
  
  if not self.completionList[self.completionIdx] then return end
  
  self.text = self.text:sub(1, self.cursor.pos) .. 
              self.completionList[self.completionIdx] ..
              tail

  self.cursor.size = #self.completionList[self.completionIdx]
  self:scrollToPos()
  self:invalidate()
end

function UIInput:moveCursor(offset)
  if self.cursor.size > 0 then
    if offset > 0 then
      offset = self.cursor.size
    end
  end
  self:setCursor(self.cursor.pos + offset)
end

function UIInput:setCursor(pos, scroll)
  self.cursor.pos = math.min(math.max(0, pos), self.text:len())
  self.cursor.size = 0
  
  scroll = scroll or true
  if scroll == true then
    self:scrollToPos()
  end
  
  self:cancelCompletion()
end

function UIInput:getCursorX(pos)
  local x = platform.withGC(function(gc)
    local offset = 0
    if self.prefix then
      offset = gc:getStringWidth(self.prefix) + 2*self.margin
    end
    return offset + gc:getStringWidth(string.sub(self.text, 1, pos or self.cursor.pos))
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

  if self:getMode() == "RPN" and isBalanced(self.text:sub(1, self.cursor.pos)) then
    if c == " " then return end
    
    -- Remove trailing '(' inserted by some keys
    if c:len() > 1 and c:sub(-1) == '(' then
      c = c:sub(1, -2)
    end 
    
    recordUndo()
    if not dispatchImmediate(c) then
      popUndo()
      self:_insertChar(c)
    end
  else
    self:_insertChar(c)
  end
  self:scrollToPos()
end

function UIInput:_insertChar(c)
  c = c or ""
  self:cancelCompletion()
  
  local expanded = c
  if options.autoClose == true then
    if c=="("  then expanded = c..")"  end
    if c=="["  then expanded = c.."]"  end
    if c=="{"  then expanded = c.."}"  end
    if c=="\"" then expanded = c.."\"" end
    if c=="'"  then expanded = c.."'"  end
    
    local rhsPos = self.cursor.pos + 1
    local rhs = #self.text >= rhsPos and self.text:byte(rhsPos) or 0
    if self.cursor.size == 0 and
       c==")" and rhs == ASCII_RPAREN or
       c=="]" and rhs == ASCII_RBRACK or
       c=="}" and rhs == ASCII_RBRACE or
       c=='"' and rhs == ASCII_DQUOTE or
       c=="'" and rhs == ASCII_SQUOTE then
      self:moveCursor(1)
      self:invalidate()
      return
    end
  end
  
  if self.cursor.pos == self.text:len() then
    self.text = self.text .. expanded
  else
    local left, mid, right = string.sub(self.text, 1, self.cursor.pos),
                             string.sub(self.text, self.cursor.pos+1, self.cursor.size+self.cursor.pos),
                             string.sub(self.text, self.cursor.pos+1+self.cursor.size)

    -- Kill the matching character right to the selection
    if options.autoKillParen == true and mid:len() == 1 then   
      if (mid:byte(1) == ASCII_LPAREN and right:byte(1) == ASCII_RPAREN) or
         (mid:byte(1) == ASCII_LBRACK and right:byte(1) == ASCII_RBRACK) or
         (mid:byte(1) == ASCII_LBRACE and right:byte(1) == ASCII_RBRACE) or
         (mid:byte(1) == ASCII_DQUOTE and right:byte(1) == ASCII_DQUOTE) or
         (mid:byte(1) == ASCII_SQUOTE and right:byte(1) == ASCII_SQUOTE) then
        right = right:sub(2)
      end
    end
    self.text = left .. expanded .. right
  end
  self.cursor.pos = self.cursor.pos + string.len(c) -- c!
  self.cursor.size = 0
  
  self:invalidate()
end

function UIInput:onBackspace()
  self:cancelCompletion()
  if options.autoPop == true and self.text:len() <= 0 then
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
  if self.text:len() == 0 then return end

  recordUndo(self.text)
  local c = self.text
  if self:getMode() ~= "RPN" or not dispatchFull(c) then
    -- Since dispatchFull is not called in ALG mode,
    -- we need this special check here.
    if c == "@rpn" then
      options.mode = "RPN"
      input:setText()
      popUndo()
      return
    end 
 
    if stack:pushInfix(c) then
      input:setText("")
    else
      popUndo()
      input:selAll()
      return
    end
  else
    input:setText("")
  end
  
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
  local cursorx = gc:getStringWidth(string.sub(self.text, 1, self.cursor.pos))
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
    local selWidth = gc:getStringWidth(string.sub(self.text, self.cursor.pos+1, self.cursor.pos + self.cursor.size))
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
      onEscape = function() end,
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

--[[ === ERROR === ]]--
function assertN(n)
  if #stack.stack < (n or 1) then
    print("Error!")
    -- TODO: Display error message .. handle errors at all
    input:selAll()
    return false
  end
  return true
end

--[[ === UNDO/REDO === ]]--
undoStack, redoStack = {}, {}

-- Returns a new undo-state table by copying the current stack and text input
function makeUndoState(text)
  return {
    stack=clone(stack.stack),
    input=text or input.text
  }
end

function recordUndo(input)
  table.insert(undoStack, makeUndoState(input))
  redoStack = {}
end

function popUndo()
  table.remove(undoStack, #undoStack)
end

function applyUndo(state)
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
  if #undoStack > 0 then
    local state = table.remove(undoStack, #undoStack)
    table.insert(redoStack, makeUndoState())
    applyUndo(state)
  end
end

function redo()
  if #redoStack > 0 then
    local state = table.remove(redoStack, #redoStack)
    table.insert(undoStack, makeUndoState())
    applyUndo(state)
  end
end

-- Returns true if `s` parentheses and quotes are balanced
function isBalanced(s)
  local paren,brack,brace,dq,sq = 0,0,0,0,0
  for i = 1, #s do
    c = s:byte(i)
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

--[[ === EVALUATION == ]]--
function _dispatchPushInput(op)
  if input.text:len() > 0 and input.text ~= op then
    stack:pushInfix(input.text)
    input:setText("")
  end
end

function _dispatchOperatorSpecial(op)
  if op == "^2" then
    _dispatchPushInput(op)
    stack:push("2")
    return "^"
  elseif op == "10^" then
    _dispatchPushInput(op)
    stack:push("10")
    stack:swap()
    return "^"
  end
  
  return op
end

function dispatchOperator(op)
  -- Special case for nspire keys that input operators with arguments
  op = _dispatchOperatorSpecial(op)
  
  local opStr, _, opArgs = queryOperatorInfo(op)
    if opStr ~= nil then
      _dispatchPushInput(op)
      if not assertN(opArgs) then
        return false, "Argument error"
      end
  
      local newTop = #stack.stack - opArgs + 1
      local rpn = RPNExpression()
      for i=1,opArgs do
        local arg = stack:pop(newTop)
        rpn:appendStack(arg.rpn)
      end
      
      rpn:push(op)
  
      local infix = rpn:infixString()
      local res, err = math.evalStr(infix)
      stack:push({rpn=rpn.stack, infix=infix, result=res or ("error: "..err)})
  
      return true
    end
    
    return false
end

function dispatchImmediate(op)
  if input.text:sub(-2) == '@' then
    return false
  end

  local fnStr, fnArgs = functionInfo(op, true)
  if fnStr ~= nil then
    _dispatchPushInput(op)
    if not assertN(fnArgs) then
      return false, "Argument error"
    end
    
    local newTop = #stack.stack - fnArgs + 1
    local rpn = RPNExpression()
    for i=1,fnArgs do
      local arg = stack:pop(newTop)
      rpn:appendStack(arg.rpn)
    end
      
    rpn:push(fnStr)
      
    local infix = rpn:infixString()
    local res, err = math.evalStr(infix)
    stack:push({rpn=rpn.stack, infix=infix, result=res or ("error: "..err)})
    
    return true
  end

  return dispatchOperator(op)
end

function dispatchFull(op)
  -- Call internal function
  if op:find('^@%w') then
    local fnStr = op:sub(2)
    local fn = rpnFunctions[fnStr]
    if fn ~= nil then
      fn()
      return true
    elseif fnStr:len() > 0 then
      -- Display error
      return false
    end
  end
  
  -- Call function
  local fnStr, fnArgs = functionInfo(op, false)
  if fnStr ~= nil then
    if not assertN(fnArgs) then
      return false, "Argument error"
    end
    
    local newTop = #stack.stack - fnArgs + 1
    local rpn = RPNExpression()
    for i=1, fnArgs do
      local arg = stack:pop(newTop)
      rpn:appendStack(arg.rpn)
    end
      
    rpn:push(fnStr)
      
    local infix = rpn:infixString()
    local res, err = math.evalStr(infix)
    stack:push({rpn=rpn.stack, infix=infix, result=res or ("error: "..err)})
    
    return true
  end

  -- Call operator
  return dispatchOperator(op)
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
    return res
  end

  -- Semantic autocompletion
  local semantic = nil
  if options.smartComplete then
    local tokens, semanticValue, semanticKind = nil, nil, nil

    -- BUG: If cursor is not at end, this is wrong!!!
    tokens = Infix.tokenize(input.text:sub(1, #input.text - (prefix and prefix:ulen() or 0)))
    if tokens and #tokens > 0 then
      semanticValue, semanticKind = unpack(tokens[#tokens])
      semantic = {}
    end

    if semanticValue == '@>' or semanticValue == SYM_CONVERT or semanticKind == 'number' then
      semantic['unit'] = true
    end 
    
    if semanticValue == '@>' or semanticValue == SYM_CONVERT then
      semantic['conversion_fn'] = true
    end
    
    if semanticKind == 'unit' then
      semantic['conversion_op'] = true
    end
    
    if semanticValue ~= '@>' and semanticValue ~= SYM_CONVERT and semanticKind == 'operator'  then
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
  
  local macroTab = (function ()
    local r = {}
    for k,_ in ipairs(macros) do
      --table.insert(r, ""..k) -- TODO: How to call macros?
    end
  end)()

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
      {SYM_CONVERT.."List", function() stack:toList() end},
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
  if focus.onEscape then
    focus:onEscape()
  end
end

function on.tabKey()
  if focus ~= input then
    focusView(input)
  else
    input:onTab()
  end
end

function on.backtabKey()
  if focus.onBackTab then
    focus:onBackTab()
  end
end

function on.returnKey()
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
  if focus.onArrowRight then
    focus:onArrowRight()
  end
end

function on.arrowLeft()
  if focus.onArrowLeft then
    focus:onArrowLeft()
  end
end

function on.arrowUp()
  if focus.onArrowUp then
    focus:onArrowUp()
  end
end

function on.arrowDown()
  if focus.onArrowDown then
    focus:onArrowDown()
  end
end

function on.charIn(c)
  if c == "U" then undo(); return end
  if c == "R" then redo(); return end
  if c == "C" then clear(); return end
  if c == "L" then stack:roll(); return end
  if c == "T" then input:onCharIn("@"); return end
  if c == "E" then
    if #stack.stack > 0 then
      focusView(input)
      input:setTempMode("ALG")
      input:setText(stack:pop().infix, "Edit")
      return
    end
  end

  --for i=1,#c do
  --  print(c:byte(i))
  --end
  
  if focus.onCharIn then
    focus:onCharIn(c)
  end
end

function on.enterKey()
  focus:onEnter()
  stack:invalidate() -- TODO: ?
  input:invalidate()
end

function on.backspaceKey()
  if focus.onBackspace then
    focus:onBackspace()
  end
end

function on.clearKey()
  if focus.onClear then
    focus:onClear()
  end
end

function on.contextMenu()
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
  menu:draw(gc)
end
