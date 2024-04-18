local trie = require 'trie'
local operators = require 'ti.operators'
local sym = require 'ti.sym'

local lexer = {}

function lexer.tokenize(input)
  lexer.operators_trie = lexer.operators_trie or trie.build(operators.tab)

  local function operator(input, i)
    local i, j, token = trie.find(input, lexer.operators_trie, i)
    if i and j > i then
      -- Discard matches followed by a letter!
      if input:find('^([a-zA-Z])', j) then
        return nil, nil, nil
      end
    end
    return i, j, token
  end

  local function syntax(input, i)
    return input:find('^([(){}[%],])', i)
  end

  local function word(input, i)
    local li, lj, ltoken = input:find('^([%a\128-\255][_%w\128-\255]*[%.\\][%a\128-\255][_%w\128-\255]*)', i)
    if not li then
      return input:find('^([%a\128-\255][_%w\128-\255]*)', i)
    end
    return li, lj, ltoken
  end

  local function unit(input, i)
    return input:find('^(_[%a\128-\255][%w\128-\255]*)', i)
  end

  local function number(input, pos)
    -- Binary or hexadecimal number
    local i, j, prefix = input:find('^0([bh])', pos)
    local token = nil
    if i then
      if prefix == "b" then
        i, j, token = input:find('^([10]+)', j+1)
      elseif prefix == "h" then
        i, j, token = input:find('^([%x]+)', j+1)

        -- Non standard behaviour
        --if options.saneHexDigits and input:find('^[%a%.]', j+1) then
        --  return nil
        --end
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
      -- Integer part
      i, j, token = input:find('^(%d*)', pos)

      -- Optional real part
      local ri, rj, rtoken = input:find('^(%.%d+)', j and j+1 or pos)
      if ri then
         i = i or ri
         j = rj
         token = (token or '')..rtoken
      end

      if not i then return end

      -- '.' is not a number
      if i and (token == '' or token == '.') then i = nil end

      -- SCI notation exponent
      if i then
        local ei, ej, etoken = input:find('^('..sym.EE..'[%-%+]?%d+)', j+1)
        if not ei then
          -- sym.NEGATE is a multibyte char, so we can not put it into the char-class above
          ei, ej, etoken = input:find('^('..sym.EE..sym.NEGATE..'%d+)', j+1)
        end
        if ei then
          j, token = ej, token..etoken
        end
        if input:find('^%.%d+', j+1) then
           return nil
        end
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

  ---@alias TokenKind "number"|"word"|"function"|"syntax"|"operator"|"string"|"ans"|"ws"|"unit"
  ---@alias TokenPair table<string, TokenKind>
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
          if token == '(' and #tokens > 0 and tokens[#tokens][2] == 'word' then
            tokens[#tokens][2] = 'function'
          end

          --table.insert(tokens, {token, m.kind, location = {i, j}})
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

return lexer
