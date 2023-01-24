local sym = require 'ti.sym'
return {
   -- Shortcut prefix key
   ---@type string
   leader = '.',

   -- Bindings for ui.edit
   edit = function(edit)
      edit:bind('left',  function(self) self:set_cursor(1) end)
      edit:bind('right', function(self) self:set_cursor('end') end)
   end,

   -- Bindings for main-view
   main = function(ctrl, win, edit, list)
      assert(ctrl)
      edit:bind('u', function(_) ctrl:undo() end)
      edit:bind('r', function(_) ctrl:redo() end)
      edit:bind('v', function(_) ctrl:variables_interactive() end)
      edit:bind('e', function(_) ctrl:edit_interactive() end)
      edit:bind('=', function(_) ctrl:push_operator('=:') end)
      edit:bind('s', function(_) ctrl:store_interactive() end)
      edit:bind('x', function(_) ctrl:solve_interactive() end)
      edit:bind('m', function(_) ctrl:run_app() end)
      edit:bind('l', function(_) ctrl:push_list() end)
      edit:bind('^2', function(_) ctrl:push_operator('1/x') end)
      edit:bind_raw('down', function(_) ctrl.stack:swap() end)
      edit:bind_raw('return', function(_) ctrl:command_palette() end)

      list:bind('u', function(_) ctrl:undo() end)
      list:bind('r', function(_) ctrl:redo() end)
      list:bind_raw('7', function(v) v:set_selection(1) end)
      list:bind_raw('3', function(v) v:set_selection('end') end)
      list:bind_raw('left', function(_) ctrl:roll_up() end)
      list:bind_raw('right', function(_) ctrl:roll_down() end)
      list:bind_raw('backspace', function(_) ctrl:pop(); print('pop') end)
      list:bind_raw('enter', function(_) ctrl:dup() end)
      list:bind_raw('c', function(_) edit:insert_text(ctrl:stack_sel_expr().infix, true) end)
      list:bind_raw('r', function(_) edit:insert_text(ctrl:stack_sel_expr().result, true) end)
      list:bind_raw('=', function(_) ctrl.stack:push_infix(ctrl:stack_sel_expr().result) end)
      list:bind_raw('e', function(_) ctrl:edit_interactive() end)
      list:bind_raw('return', function(_) ctrl:command_palette() end)
   end,
}
