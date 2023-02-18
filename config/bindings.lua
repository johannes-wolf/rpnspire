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
      t['left'] = { function() view:set_cursor(1) end, 'Move to beginning' }
      t['right'] = { function() view:set_cursor('end') end, 'Move to end' }
   end,

   -- Bindings for main-view
   main = function(ctrl, win, edit, list)
      do
         local t = get_tab(win, 'kbd', leader)
         t['u'] = { function() ctrl:undo() end, 'Undo' }
         t['r'] = { function() ctrl:redo() end, 'Redo' }

         t['v'] = { function() ctrl:variables_interactive() end, 'Show variables' }
         t['e'] = { function() ctrl:edit_interactive() end, 'Edit*' }
         t['m'] = { function() ctrl:run_app() end, 'Run tool' }
         t['b'] = { function() ctrl:show_bindings() end, 'Show bindings' }

         t = win.kbd
         t['return'] = { function(_) ctrl:command_palette() end, 'Command palette' }
      end

      do
         local t = get_tab(edit, 'kbd', leader)
         t['='] = { function(_) ctrl:push_operator('=:') end, '=:' }
         t['^2'] = { function(_) ctrl:push_operator('1/x') end, '1/x' }
         t[','] = { function(_) ctrl:smart_append() end, 'Smart append' }
         t['/'] = { function(_) ctrl:explode_interactive() end, 'Explode*' }
         t['l'] = { function(_) ctrl:push_list() end, 'Push list' }
         t['s'] = { function(_) ctrl:store_interactive() end, 'Store*' }
         t['x'] = { function(_) ctrl:solve_interactive() end, 'Solve*' }

         t = edit.kbd
         t['down'] = { function(_) ctrl.stack:swap() end, 'Swap' }
      end

      do
         local t = get_tab(list, 'kbd')
         t['7'] = { function(v) v:set_selection(1) end, 'Move to bottom' }
         t['3'] = { function(v) v:set_selection('end') end, 'Move to top' }
         t['left'] = { function(_) ctrl:roll_up() end, 'Roll up' }
         t['right'] = { function(_) ctrl:roll_down() end, 'Roll down' }
         t['backspace'] = { function(_) ctrl:pop(); end, 'Drop' }
         t['enter'] = { function(_) ctrl:dup() end, 'Dup' }
         t['e'] = { function() ctrl:edit_interactive() end, 'Edit*' }
         t['c'] = { function(_) edit:insert_text(ctrl:stack_sel_expr().infix, true) end, 'Copy expression' }
         t['r'] = { function(_) edit:insert_text(ctrl:stack_sel_expr().result, true) end, 'Copy result' }
         t['='] = { function(_) ctrl.stack:push_infix(ctrl:stack_sel_expr().result) end, 'Dup result' }
      end
   end,
}
