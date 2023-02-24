local sym = require 'ti.sym'
local t = {}

t.tab = {
  --[[                 string, lvl, #, side, assoc, aggressive-assoc ]]--
  -- Parentheses
  ["#"]             = {nil,     18, 1, -1},
  --
  -- Function call
  -- [" "]             = {nil, 17, 1,  1}, -- DEGREE/MIN/SEC
  ["!"]             = {nil,     17, 1,  1},
  ["%"]             = {nil,     17, 1,  1},
  [sym.RAD]         = {nil,     17, 1,  1},
  [sym.GRAD]        = {nil,     17, 1,  1},
  [sym.DEGREE]      = {nil,     17, 1,  1},
  --["_["]            = {nil,     17, 2,  1}, -- Subscript (rpnspire custom)
  ["@t"]            = {sym.TRANSP, 17, 1, 1},
  [sym.TRANSP]      = {nil,     17, 1,  1},
  --
  ["^"]             = {nil,     16, 2,  0, 'r', true}, -- Matching V200 RPN behavior
  [".^"]            = {nil,     16, 2,  0, 'r', true},
  --
  ["(-)"]           = {sym.NEGATE,15,1,-1},
  [sym.NEGATE]      = {nil,     15, 1, -1},
  --
  ["&"]             = {nil,     14, 2,  0},
  --
  ["*"]             = {nil,     13, 2,  0},
  [".*"]            = {nil,     13, 2,  0},
  ["/"]             = {nil,     13, 2,  0, 'l'},
  ["./"]            = {nil,     13, 2,  0},
  --
  ["+"]             = {nil,     12, 2,  0},
  [".+"]            = {nil,     12, 2,  0},
  ["-"]             = {nil,     12, 2,  0, 'l'},
  [".-"]            = {nil,     12, 2,  0, 'l'},
  --
  ["="]             = {nil,     11, 2,  0, 'r'},
  [sym.NEQ]         = {nil,     11, 2,  0, 'r'},
  ["/="]            = {sym.NEQ, 11, 2,  0, 'r'},
  ["<"]             = {nil,     11, 2,  0, 'r'},
  [">"]             = {nil,     11, 2,  0, 'r'},
  [sym.LEQ]         = {nil,     11, 2,  0, 'r'},
  ["<="]            = {sym.LEQ, 11, 2,  0, 'r'},
  [sym.GEQ]         = {nil,     11, 2,  0, 'r'},
  [">="]            = {sym.GEQ, 11, 2,  0, 'r'},
  --
  ["not"]           = {"not ",  11, 1, -1},
  ["and"]           = {" and ", 10, 2,  0},
  ["or"]            = {" or ",  10, 2,  0},
  --
  ["xor"]           = {" xor ",  9, 2,  0},
  ["nor"]           = {" nor ",  9, 2,  0},
  ["nand"]          = {" nand ", 9, 2,  0},
  --
  [sym.LIMP]        = {nil,      8, 2,  0, 'r'},
  ["=>"]            = {sym.LIMP, 8, 2,  0, 'r'},
  --
  [sym.DLIMP]       = {nil,      7, 2,  0, 'r'},
  ["<=>"]           = {sym.DLIMP,7, 2,  0, 'r'},
  --
  ["|"]             = {nil,      6, 2,  0},
  --
  [sym.STORE]       = {nil,      5, 2,  0, 'r'},
  ["=:"]            = {sym.STORE,5, 2,  0, 'r'},
  [":="]            = {nil,      5, 2,  0, 'r'},

  [sym.CONVERT]     = {nil, 1, 2, 0},
  ["@>"]            = {sym.CONVERT, 1, 2,  0}
}

function t.query_info(str)
  local tab = t.tab[str]
  if tab == nil then return nil end
  local alt, lvl, args, side, assoc, aggro = table.unpack(tab)
  return (alt or str), lvl, args, side or 0, assoc, aggro
end

return t
