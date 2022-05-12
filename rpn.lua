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

-- Remove quotes from `s`
function string.unquote(s)
  if s:sub(1,1) == "\"" and
     s:sub(#s) == "\"" then
    return s:sub(2, #s-1)
  end
  return s
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
    backgroundColor = 0x111111,
    borderColor = 0x888888,
  },
}

-- Global options
options = {
  autoClose = true,     -- Auto close parentheses
  autoKillParen = true, -- Auto kill righthand paren when killing left one
  showFringe = true,    -- Show fringe (stack number)
  showExpr = true,      -- Show stack expression (infix)
  theme = "light",      -- Well...
  cursorWidth = 2,      -- Width of the cursor
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

SYM_LIST   = "@LIST" -- RPN list operator
SYM_MAT    = "@MAT"  -- RPN matrix operator

operators = {
  --[[                 string, lvl, #, side ]]--
  -- Parentheses
  ["#"]             = {nil,     18, 1, -1},
  --
  -- Function call
  -- [" "]             = {nil, 17, 1,  1}, -- DEGREE/MIN/SEC
  ["!"]             = {nil,     17, 1,  1},
  ["%"]             = {nil,     17, 1,  1},
  [SYM_RAD]         = {nil,     17, 1,  1},
  -- [" "]             = {nil, 17, 1,  1}, -- SUBSCRIPT
  -- [SYM_TRANSP]      = {nil, 17, 1,  1}, -- TRANSPOSE
  --
  ["^"]             = {nil,     16, 2,  0},
  --
  ["(-)"]           = {SYM_NEGATE,15,1,-1},
  [SYM_NEGATE]      = {nil,     15, 1, -1},
  --
  ["&"]             = {nil,     14, 2,  0},
  --
  ["*"]             = {nil,     13, 2,  0},
  ["/"]             = {nil,     13, 2,  0},
  --
  ["+"]             = {nil,     12, 2,  0},
  ["-"]             = {nil,     12, 2,  0},
  --
  ["="]             = {nil,     11, 2,  0},
  [SYM_NEQ]         = {nil,     11, 2,  0},
  ["/="]            = {SYM_NEQ, 11, 2,  0},
  ["<"]             = {nil,     11, 2,  0},
  [">"]             = {nil,     11, 2,  0},
  [SYM_LEQ]         = {nil,     11, 2,  0},
  ["<="]            = {SYM_LEQ, 11, 2,  0},
  [SYM_GEQ]         = {nil,     11, 2,  0},
  [">="]            = {SYM_GEQ, 11, 2,  0},
  --
  ["not"]           = {"not ",  10, 1, -1},
  ["and"]           = {" and ", 10, 2,  0},
  ["or"]            = {" or ",  10, 2,  0},
  --
  ["xor"]           = {" xor ",  9, 2,  0},
  ["nor"]           = {" nor ",  9, 2,  0},
  ["nand"]          = {" nand ", 9, 2,  0},
  --
  [SYM_LIMP]        = {nil,      8, 2,  0},
  ["=>"]            = {SYM_LIMP, 8, 2,  0},
  --
  [SYM_DLIMP]       = {nil,      7, 2,  0},
  ["<=>"]           = {SYM_DLIMP,7, 2,  0},
  --
  ["|"]             = {nil,      6, 2,  0},
  --
  [SYM_STORE]       = {nil,      5, 2,  0},
  ["=:"]            = {SYM_STORE,5, 2,  0},
  [":="]            = {nil,      5, 2,  0}
}

-- Query operator information
function quertyOperatorInfo(s)
  local tab = operators[s]
  if tab == nil then return nil end
  
  local str, lvl, args, side = unpack(tab)
  return (str or s), lvl, args, side
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

--[[
Function info table
  str, args
--]]
function functionInfo(s, builtinOnly)
  -- TODO: THIS IMPLEMENTATION IS ONLY FOR TESTING.
  --       Replace with a table, see `operators`

  if s=="root" then return s, 2 end
  if s=="sqrt" or s==SYM_ROOT then return SYM_ROOT, 1 end
  if s=="exp"      then return s, 1 end
  if s=="abs"      then return s, 1 end
  if s=="ceiling" then return "ceiling", 1 end
  if s=="floor" then return "floor", 1 end
  if s=="int" or s=="real" then return s, 1 end
  
  -- CAS
  if s=="solve" or s=="zeros" or s=="nsolve" or s=="derivative" then
    return s, 2
  end
  -- TRIG
  if s=="sin" or s=="cos" or s=="tan" or
     s=="arcsin" or s=="arccos" or s=="arctan" or 
     s=="sin\239\128\133" or s=="cos\239\128\133" or s=="tan\239\128\133" then
    return s, 1
  end
  
  -- OTHER
  if s=="when"     then return s, 3 end
  if s=="string"   then return s, 1 end
  if s=="approx"   then return s, 1 end
  if s=="store"    then return s, 2 end
  
  if s=="seq" then return s, 4 end
  if s=="sumSeq" then return s, 4 end
  if s=="sum" then return s, 3 end
  
  if s=="left" or s=="right" then return s, 1 end
  
  -- User function
  if builtinOnly == false then
    local argc = tiGetFnArgs(s)
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
  ["tlist"]= function() stack:toList() end,

  -- History
  ["undo"] = function() popUndo(); undo() end, -- HACK: popUndo to remove the undo of the undo
  -- Weird features
  ["label"]= function() stack:label() end,
  ["killexpr"] = function() stack:killexpr() end,
  -- Macros
  ["mcall"] = function()
    -- TODO: this is a hack for testing out macros
    local n = string.unquote(stack:pop().result)
    local m = macros[n]
    if m ~= nil then
      m:exec()
    end
  end,
  
  -- Options
  ["setopt"]= function()
    local option, value = string.unquote(stack:pop().result), string.unquote(stack:pop().result)
    options[option] = value
  end
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


-- RPN Expression stack for transforming from and to infix notation
RPNExpression = class()

function RPNExpression:init(stack)
  self.stack = stack or {}
end

function RPNExpression:parseInfix(s)
  -- TODO: ...
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

function RPNExpression:_infixString(top, parentPrec)
  local sym = self.stack[top]
  if not sym then return "ERR", top end
  
  local fnStr, fnArgs = functionInfo(sym, false)
  if fnStr ~= nil then
    local out = fnStr.."("
    
    local argidx = fnArgs
    while argidx > 0 do
      local tmpOut, tmpTop = self:_infixString(top - 1, nil)
      out = out .. tmpOut .. (argidx > 1 and "," or "")
      argidx = argidx - 1
      top = tmpTop
    end
      
    return out..")", top
  end
  
  local opStr, opPrec, opArgs, opPos = quertyOperatorInfo(sym)
  if opStr ~= nil then
    local out = ""
    if opPos < 0 then
      out = opStr
    end
    
    local argidx = opArgs
    while argidx > 0 do
      local tmpStr, tmpTop = self:_infixString(top - 1, opPrec)
      if opPos == 0 then
        out = out .. (argidx == 1 and opStr or "") .. tmpStr
      else
        out = out .. (argidx > 1 and ", " or "") .. tmpStr
      end

      argidx = argidx - 1
      top = tmpTop
    end
    
    if (parentPrec ~= nil and opPrec < parentPrec) or (opPos ~= 0 and opArgs > 1) then
      out = "("..out..")"
    end

    if opPos > 0 then
      out = out .. opStr
    end

    return out, top
  elseif sym == SYM_LIST or sym == SYM_MAT then
    local argc = tonumber(self.stack[top - 1])
    assert(argc)
    top = top - 1

    local out = sym==SYM_LIST and "{" or "["

    local argidx = argc
    while argidx > 0 do
      local tmpStr, tmpTop = self:_infixString(top - 1, opPrec)
      out = out .. (argidx < argc and "," or "") .. tmpStr

      argidx = argidx - 1
      top = tmpTop
    end

    return out..(sym==SYM_LIST and "}" or "]"), top
  else
    return sym, top
  end
end

function RPNExpression:infixString()
  local str, _ = self:_infixString(#self.stack, nil)
  return str
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
  if #self.stack < 2 then
    return
  end
  
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
  local v = table.remove(self.stack, idx or #self.stack)
  self:invalidate()
  return v
end

function UIStack:roll(n)
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
  local idx = #self.stack - ((n or 1) - 1)
  for i=1,(n or 1) do
    table.insert(self.stack, clone(self.stack[idx + i - 1]))
  end
end

function UIStack:pick(n)
  local idx = #self.stack - ((n or 1) - 1)
  table.insert(self.stack, clone(self.stack[idx]))
end

function UIStack:toList(n)
  if #self.stack <= 0 then return end

  if n == nil then
    n = tonumber(self:pop().result)
  end

  assert(type(n)=="number")
  assert(n >= 0)

  local rpn = RPNExpression()
  for i=1, n do
    local arg = stack:pop(#stack.stack)
    if arg ~= nil then
      rpn:appendStack(arg.rpn)
    else
      -- TODO: Error
      rpn:push(0)
    end
  end

  rpn:push(n)
  rpn:push(SYM_LIST)

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
  gc:setColorRGB(theme[options.theme].backgroundColor)
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
  if self.completionList == nil then
    if self.completionFun == nil then return end

    local prefixSize = 0
    for i=self.cursor.pos,1,-1 do
      local b = self.text:byte(i)
      if b == nil or b < 64 then break end -- Stop at char < '@'
      prefixSize = prefixSize + 1
    end

    local prefix = "" 
    if prefixSize > 0 then
      prefix = self.text:sub(self.cursor.pos + 1 - prefixSize, self.cursor.pos)
    end

    self.completionList = self.completionFun(prefix)
    if #self.completionList == 0 then
      return
    end
    
    self.completionIdx = 1
  else
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
  
  self.text = self.text:sub(1, self.cursor.pos) .. 
              self.completionList[self.completionIdx] ..
              tail
  self.cursor.size = #self.completionList[self.completionIdx]
  self:invalidate()
  
  -- Apply single entry using [tab]
  if #self.completionList == 1 then
    self:moveCursor(1)
    self:cancelCompletion()
    return
  end
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

function UIInput:_cursorX()
  local x = platform.withGC(function(gc)
    return gc:getStringWidth(string.sub(self.text, 1, self.cursor.pos))
  end)
  
  return x
end

function UIInput:scrollToPos(pos)
  pos = pos or self.cursor.pos + self.cursor.size
  
  local _,_,w,_ = self:getFrame()
  local margin = self.margin
  local cx = self:_cursorX()
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

  if isBalanced(self.text:sub(1, self.cursor.pos)) then
    if c == " " then return end
    
    -- Remove trailing '(' inserted by some keys
    if #c > 1 and c:byte(#c) == 40 then
      c = c:sub(1, #c-1)
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
  
  local expanded = c
  if options.autoClose == true then
    if c=="("  then expanded = c..")"  end
    if c=="["  then expanded = c.."]"  end
    if c=="{"  then expanded = c.."}"  end
    if c=="\"" then expanded = c.."\"" end
    if c=="'"  then expanded = c.."'"  end
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
  if self.text:len() <= 0 then
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
  self:cancelCompletion()
end

function UIInput:onEnter()
  if self.text:len() == 0 then return end

  recordUndo(self.text)
  local c = self.text
  if dispatchFull(c) ~= true then
    --stack:pushEval(c) -- TODO: Parse ALG to RPN
    stack:push(c)
  end
  input:setText("")
  
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

function UIInput:setText(s, prefix)
  self.text = s or ""
  self.prefix = prefix or ""
  self:setCursor(#self.text)
  self:cancelCompletion()
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
  local cursorx = gc:getStringWidth(string.sub(self.text, 1, self.cursor.pos))
  cursorx = cursorx + x + self.scrollx
  
  gc:clipRect("set", x, y, w, h)
  
  if self.cursor.size ~= 0 then
    local cursor2x = gc:getStringWidth(string.sub(self.text, 1, self.cursor.pos + self.cursor.size))
    cursor2x = cursor2x + x + margin + self.scrollx
    
    local cursorLeft, cursorRight = math.min(cursorx, cursor2x), math.max(cursorx, cursor2x)
    
    gc:drawRect(cursorLeft + 1, y + 2, cursorRight - cursorLeft, h-3)
  end
  
  if self.prefix:len() > 0 then
    local prefixWidth = gc:getStringWidth(self.prefix) + margin 
  
    --gc:setColorRGB(theme[options.theme].altRowColor)
    --gc:fillRect(x, y+1, prefixWidth, h-2)
    gc:setColorRGB(theme[options.theme].fringeTextColor)
    gc:drawString(self.prefix, x + margin, y)
    
    x = x + prefixWidth
    cursorx = cursorx + prefixWidth
  end
  
  gc:setColorRGB(theme[options.theme].textColor)
  gc:drawString(self.text, x + margin + self.scrollx, y)
  
  if focus == self then
    gc:setColorRGB(theme[options.theme].cursorColor)
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
      onArrowUp = function()
        focusView(stack)
      end,
      onArrowDown = function()
        focusView(input)
      end,
      onCharIn = function(c) end,
      onBackspace = function(c) 
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

--[[ === ERROR === ]]--
function assertN(n)
  if #stack.stack < (n or 1) then
    print("Error!")
    -- TODO: Display error message .. handle errors at all
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
  input:setText("")
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
  assert(op)
  if input.text:len() > 0 and input.text ~= op then
    --stack:pushEval(input.text)
    -- TODO: We need RPN parsing here!
    stack:push(input.text)
    input:setText("")
  end
end

function dispatchOperator(op)
  local opStr, _, opArgs = quertyOperatorInfo(op)
    if opStr ~= nil then
      _dispatchPushInput(op)
      if not assertN(opArgs) then
        input:setText("")
        return false, "Argument error"
      end
  
      local rpn = RPNExpression()
      for i=1, opArgs do
        local arg = stack:pop(#stack.stack)
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
  if mode ~= "RPN" then return false end

  local fnStr, fnArgs = functionInfo(op, true)
  if fnStr ~= nil then
    _dispatchPushInput(op)
    if not assertN(fnArgs) then
      return false, "Argument error"
    end
    
    local rpn = RPNExpression()
    for i=1, fnArgs do
      local arg = stack:pop(#stack.stack)
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
  if op:sub(1,1) == "@" then
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
    
    local rpn = RPNExpression()
    for i=1, fnArgs do
      local arg = stack:pop(#stack.stack)
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
    local plen = #prefix
    for _,v in ipairs(tab) do
      if v:sub(1, plen) == prefix then
        local m = v:sub(plen + 1)
        if #m > 0 then
          table.insert(res, m)
        end
      end
    end
    return res
  end

  local varTab = var.list()

  local functionTab = {
    "solve", "nSolve", "zeros",
    "approx",
    "delvar x,y,z"
  }
  
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
  
  return catmatch(varTab, prefix,
         catmatch(functionTab, prefix,
         catmatch(unitTab, prefix)))
end

function on.construction()
  bigview = D2Editor.newRichText()

  mode = "RPN"
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

function on.tabKey()
  if focus ~= input then
    focusView(input)
  else
    input:onTab()
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
      "=:", ":=", "{", "[", "?", "!", "%", "@"
    })
  end
end

function on.arrowRight()
  focus:onArrowRight()
end

function on.arrowLeft()
  focus:onArrowLeft()
end

function on.arrowUp()
  focus:onArrowUp()
end

function on.arrowDown()
  focus:onArrowDown()
end

function on.charIn(c)
  if c == "U" then undo(); return end
  if c == "R" then redo(); return end
  if c == "C" then clear(); return end
  if c == "L" then stack:roll(); return end

  focus:onCharIn(c)
end

function on.enterKey()
  focus:onEnter()
  stack:invalidate() -- TODO: ?
  input:invalidate()
end

function on.backspaceKey()
  focus:onBackspace()
end

function on.clearKey()
  focus:onClear()
end

function on.contextMenu()
  -- FIXME: this is just a test
  if focus == stack then
    menu:present(stack, {
      {"ROLL", function() stack:roll() end},
      {"SWAP", function() stack:swap() end},
      {"Options", {
        {"Fringe", function() options.showFringe = not options.showFringe end},
        {"Calc", function() options.showExpr = not options.showExpr end},
        {"Theme", {
          {"light", function() options.theme="light" end},
          {"dark",  function() options.theme="dark" end},
        }}
      }}
    })
  elseif focus == input then
    menu:present(stack, {
      {"Units", {
        {"Mass", {
          {"kg", "_kg"}, {"g", "_g"}
        }}
      }}, {"Solve", {
        {"solve", "solve"}, {"zeros", "zeros"}
      }}
    })
  end
end

function on.paint(gc)
  stack:draw(gc)
  input:draw(gc)
  menu:draw(gc)
end
