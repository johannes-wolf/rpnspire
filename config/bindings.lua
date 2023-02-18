local sym = require 'ti.sym'

local function get_tab(tab, ...)
   assert(tab)
   local path = {...}
   for _, v in ipairs(path) do
      tab[v] = tab[v] or {}
      tab = tab[v]
   end
   return tab
end

-- Global leader key (shortcut prefix key)
local leader = '.'

return {
   -- Shortcut prefix key
   ---@type string
   leader = leader,

   -- Bindings for ui.edit
   edit = function(view)
      local t = get_tab(view, 'kbd', leader)
      t['left'] = function() view:set_cursor(1) end
      t['right'] = function() view:set_cursor('end') end
   end,

   -- Bindings for main-view
   main = function(ctrl, win, edit, list)
      do
         local t = get_tab(win, 'kbd', leader)
         t['u'] = function() ctrl:undo() end
         t['r'] = function() ctrl:redo() end

         t['v'] = function() ctrl:variables_interactive() end
         t['e'] = function() ctrl:edit_interactive() end
         t['m'] = function() ctrl:run_app() end

         t = win.kbd
         t['return'] = function(_) ctrl:command_palette() end
      end

      do
         local t = get_tab(edit, 'kbd', leader)
         t['='] = function(_) ctrl:push_operator('=:') end
         t['^2'] = function(_) ctrl:push_operator('1/x') end
         t[','] = function(_) ctrl:smart_append() end
         t['/'] = function(_) ctrl:explode_interactive() end
         t['l'] = function(_) ctrl:push_list() end
         t['s'] = function(_) ctrl:store_interactive() end
         t['x'] = function(_) ctrl:solve_interactive() end

         t = edit.kbd
         t['down'] = function(_) ctrl.stack:swap() end
      end

      do
         local t = get_tab(list, 'kbd')
         t['7'] = function(v) v:set_selection(1) end
         t['3'] = function(v) v:set_selection('end') end
         t['left'] = function(_) ctrl:roll_up() end
         t['right'] = function(_) ctrl:roll_down() end
         t['backspace'] = function(_) ctrl:pop(); end
         t['enter'] = function(_) ctrl:dup() end
         t['e'] = function() ctrl:edit_interactive() end
         t['c'] = function(_) edit:insert_text(ctrl:stack_sel_expr().infix, true) end
         t['r'] = function(_) edit:insert_text(ctrl:stack_sel_expr().result, true) end
         t['='] = function(_) ctrl.stack:push_infix(ctrl:stack_sel_expr().result) end
      end
   end,
}
