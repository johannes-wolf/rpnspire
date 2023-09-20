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

      t = get_tab(view, 'kbd', leader, 'g')
      t['a'] = { function() view:insert_text(sym.alpha, false) end, 'greek alpha' }
      t['b'] = { function() view:insert_text(sym.beta, false) end, 'greek beta' }
      t['c'] = { function() view:insert_text(sym.gamma, false) end, 'greek gamma' }
      t['d'] = { function() view:insert_text(sym.delta, false) end, 'greek delta' }
      t['w'] = { function() view:insert_text(sym.omega, false) end, 'greek omega' }
      t['s'] = { function() view:insert_text(sym.sigma, false) end, 'greek sigma' }
      t['p'] = { function() view:insert_text(sym.phi, false) end, 'greek phi' }
   end,

   matrixeditor = function(dialog, grid, edit)
      local t = get_tab(grid, 'kbd', leader)
      t['left'] = { function() grid:set_selection(nil, 1) end, 'First column' }
      t['right'] = { function() grid:set_selection(nil, 'end') end, 'Last column' }
      t['up'] = { function() grid:set_selection(1, nil) end, 'First row' }
      t['down'] = { function() grid:set_selection('end', nil) end, 'Last row' }
      t['t'] = function() dialog.matrix_transpose() end

      t = grid.kbd
      t['='] = function() dialog.eval_cell() end
      t['tab'] = function() dialog.next_cell('right') end

      -- Hardcoded (see matrixeditor)
      -- edit: [,] at end of input: Submit cell and move right
   end,

   -- Bindings for main-view
   main = function(ctrl, win, edit, list)
      do
         local t = get_tab(win, 'kbd', leader)
         t['u'] = { function() ctrl:undo() end, 'Undo' }
         t['r'] = { function() ctrl:redo() end, 'Redo' }

         t['v'] = { function() ctrl:variables_interactive() end, 'Show variables' }
         t['e'] = { function() ctrl:edit_interactive() end, 'Edit*' }
         t['a'] = { function() ctrl:run_app() end, 'Run app' }
         t['b'] = { function() ctrl:show_bindings() end, 'Show bindings' }
         t['m'] = { function() ctrl:matrix_writer() end, 'Matrix writer' }

         t = win.kbd
         t['return'] = { function(_) ctrl:command_palette() end, 'Command palette' }
      end

      do
         local t = get_tab(edit, 'kbd', leader)
         t['='] = { function(_) ctrl:push_operator('=:') end, '=:' }
         t['+'] = { function(_) ctrl:push_operator('.+') end, '.+' }
         t['-'] = { function(_) ctrl:push_operator('.-') end, '.-' }
         t['*'] = { function(_) ctrl:push_operator('.*') end, '.*' }
         t['/'] = { function(_) ctrl:push_operator('./') end, './' }
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
