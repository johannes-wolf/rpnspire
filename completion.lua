local t = {}

local ti_units     = require 'ti.units'
local ti_functions = require 'ti.functions'
local stats        = require 'config.stats'

local completion_stats = stats.completion
local function score_match(str)
   return completion_stats[str]
end

local function match_and_add(str, prefix, tab)
   local len = prefix:len()
   if str:find(prefix, 1) == 1 then
      table.insert(tab, { str, str:sub(len + 1), score = score_match(str) })
   end
end

function t.complete_unit(prefix, tab)
   for _, cat in pairs(ti_units.tab) do
      for _, v in ipairs(cat) do
         match_and_add(v[1], prefix, tab)
      end
   end
end

function t.complete_variable(prefix, tab)
   for _, v in ipairs(_G.var.list()) do
      match_and_add(v, prefix, tab)
   end
end

function t.complete_function(prefix, tab)
   for k, _ in pairs(ti_functions.tab) do
      match_and_add(k, prefix, tab)
   end
end

function t.complete_number(_, _)
end

function t.complete_word(prefix, tab)
   t.complete_function(prefix, tab)
   t.complete_variable(prefix, tab)
end

function t.sort_completion(tab)
   table.sort(tab, function(a, b)
      return (a.score or 0) > (b.score or 0)
   end)
   return tab
end

function t.complete_smart(prefix)
   local lexer = require 'ti.lexer'
   local ok, res = pcall(function()
      return lexer.tokenize(prefix)
   end)
   if ok and res and #res > 0 then
      local text, kind = table.unpack(res[#res])
      local tab = {}
      if t['complete_' .. kind] then
         t['complete_' .. kind](text, tab)
      end
      return t.sort_completion(tab)
   elseif prefix == '_' or prefix:find('[^%a]_$') then
      local tab = {}
      t.complete_unit('_', tab)
      return t.sort_completion(tab)
   else
      print('Error parsing prefix!')
   end
   return {}
end

function t.setup_edit(edit)
   edit.on_complete = function(_, prefix)
      return t.complete_smart(prefix)
   end
   edit.on_complete_done = function(_, title, _)
      if title and #title > 0 then
         completion_stats[title] = (completion_stats[title] or 0) + 1
      end
   end
end

return t
