local ui         = require 'ui.shared'
local expr       = require 'expressiontree'
local lexer      = require 'ti.lexer'
local matrix     = require 'matrix'
local show_error = require('dialog.error').display
local completion = require 'completion'
local ask        = require 'dialog.input'
local advice     = require 'advice'
local bindings   = require 'config.bindings'

local t = {}

-- Display matrix editor modal
---@param ctrl rpn_controller
---@param init? expr # Matrix
---@param rows? expr # Matrix
---@param cols? expr # Matrix
---@return matrix_dialog
function t.display(ctrl, init)
   local dlg = {
      on_done = function() end,
      on_cancel = function() end
   }

   local data = init

   local window = ui.container(ui.rel { left = 10, right = 10, top = 10, bottom = 10 })
   window.style = '2D'

   local label = ui.label(ui.rel { left = 0, height = 20, width = 30, bottom = 0 })
   window:add_child(label)

   local edit = ui.edit(ui.rel { left = 30, bottom = 0, right = 0, height = 20 })
   completion.setup_edit(edit)
   window:add_child(edit)

   local grid = ui.list(ui.rel { left = 0, right = 0, top = 0, bottom = 20 })
   grid.style = 'grid'
   grid.column_size = 50
   window:add_child(grid)

   if bindings.matrixeditor then
      bindings.matrixeditor(dlg, grid, edit)
   end

   function dlg.matrix_resize(rows, cols)
      rows = math.min(rows, 99)
      cols = math.min(cols, 99)

      local grid_m, grid_n =
         math.max(grid.items_len, rows),
         math.max(#grid.columns, cols)

      data:resize(rows, cols)
      dlg.grid_resize(grid_m, grid_n)
      grid:set_selection('end', 'end')
   end

   -- Action: Resize matrix
   ---@param rows?  number
   ---@param cols?  number
   function dlg.grid_resize(rows, cols)
      rows = rows or grid.items_len
      cols = cols or #grid.columns

      local new_columns = {}
      for i = 1, cols do
         table.insert(new_columns, {
            index = i,
            size = grid.column_size,
         })
      end

      grid.items_len = rows
      grid.columns = new_columns
      grid.children = {}
      grid.items = data
      grid:update_rows()
   end

   -- Action: Transpose
   function dlg.matrix_transpose()
      data:transpose()
      dlg.grid_resize()
   end

   -- Action: Clear matrix values
   function dlg.matrix_clear()
      data:clear()
      grid:update_rows()
   end

   -- Action: Set grid column size
   ---@param size number|'-'|'+'|'*'|'='
   function dlg.set_column_size(size)
      if size == '*' then
         grid.column_size = '*'
      elseif size == '=' then
         grid.column_size = grid:frame().width / #grid.columns
      else
         if grid.column_size == '*' then
            grid.column_size = 50
         end
         if size == '-' then
            size = grid.column_size - 10
         elseif size == '+' then
            size = grid.column_size + 10
         end
         grid.column_size = math.min(math.max(10, size), 260)
      end

      for _, column in ipairs(grid.columns) do
         column.size = grid.column_size
      end
      grid:layout_children()
   end

   -- Action: Push matrix to stack
   function dlg.push_to_stack()
      ctrl.stack:push_expr(data:to_expr())
   end

   -- Action: Push matrix as list
   function dlg.push_list_to_stack()
      ctrl.stack:push_expr(data:to_list())
   end

   -- Action: Push matrix as system
   function dlg.push_system_to_stack()
      local e = data:to_list()
      e.kind = expr.FUNCTION
      e.text = 'system'
      ctrl.stack:push_expr(e)
   end

   -- Action: Push matrix as piecewise
   function dlg.push_piecewise_to_stack()
      local e = data:to_list()
      e.kind = expr.FUNCTION
      e.text = 'piecewise'
      ctrl.stack:push_expr(e)
   end

   -- Action: Push matrix as function
   function dlg.push_any_to_stack()
      local e = data:to_list()
      e.kind = expr.FUNCTION
      local ask_dlg = ask.display { title = 'Function name', text = 'system' }
      function ask_dlg.on_done(text)
         if text:len() > 0 then
            e.text = text
            ctrl.stack:push_expr(e)
         end
      end
   end

   -- Action: Store interactive
   function dlg.store_interactive()
      ctrl.stack:push_expr(data:to_expr())
      ctrl:store_interactive('pop')
   end

   -- Action: Evaluate cell
   function dlg.eval_cell()
      local m, n = grid:get_selection()
      local value = data:get(m, n)
      if type(value) == 'string' then
         local result, err = math.evalStr(value)
         if result then
            data:set(m, n, result)
            grid:update_rows()
         end
      end
   end

   -- Action: Move to next cell
   ---@param direction 'right'|'down'
   function dlg.next_cell(direction)
      local m, n = data:size()
      local row, col = grid:get_selection()

      if direction == 'right' then
         if col == n and n > 1 and m > 1 then
            row = row + 1
            col = 1
         else
            col = col + 1
         end
      elseif direction == 'down' then
         if row == m and m > 1 and n > 1 then
            row = 1
            col = col + 1
         else
            row = row + 1
         end
      end

      grid:set_selection(row, col)
   end

   function grid:cell_update(cell, column, row)
      local data = row and row[column.index]
      cell.text = data or ''
   end

   function grid:cell_constructor(column, row)
      local label = ui.label()
      local data = row and row[column.index]
      label.text = data or ''
      label.align = 1
      return label
   end

   local session = ui.push_modal(window)
   ui.set_focus(grid)

   function grid:on_escape()
      ui.pop_modal(session)
      dlg.on_cancel()
   end

   local function update_selection()
      local row, col = grid:get_selection()
      label.text = string.format('%d,%d', row or 1, col or 1)

      local value = data:get(row, col)
      edit:set_text(value and tostring(value) or '', true)
   end

   function grid:on_clear()
      dlg.matrix_clear()
   end

   function grid:on_enter_key()
      ui.pop_modal(session)
      dlg.on_done(data)
   end

   function grid:on_char(c)
      ui.set_focus(edit)
      ui.on_event('char', c)
   end

   function grid:has_focus()
      return ui.get_focus() == self or edit:has_focus()
   end

   function grid:on_selection()
      update_selection()
   end

   grid.set_selection = advice.arguments(grid.set_selection,
       function(self, row, col)
          local rows, cols = data:size()
          if row == 'end' then
             row = rows
          end
          if col == 'end' then
             col = cols
          end
          return self, row, col
       end)

   function grid:on_return()
      self:on_ctx()
   end

   function grid:on_ctx()
      function action_resize()
         coroutine.wrap(function()
            local rows, cols = data:size()

            rows = tonumber(ask.display_sync { title = 'Rows', text = tostring(rows) })
            if not rows then return end
            cols = tonumber(ask.display_sync { title = 'Columns', text = tostring(cols) })
            if not cols then return end

            dlg.matrix_resize(rows, cols)
         end)()
      end

      function action_grid()
         coroutine.wrap(function()
            local rows = tonumber(ask.display_sync { title = 'Grid Rows', text = '10' })
            if not rows then return end
            local cols = tonumber(ask.display_sync { title = 'Grid Columns', text = '10' })
            if not cols then return end

            dlg.grid_resize(rows, cols)
         end)()
      end

      function action_col_size()
         coroutine.wrap(function()
            local size = ask.display_sync { title = 'Column Size', text = tostring(grid.column_size) }
            if not size then return end

            dlg.set_column_size(size)
         end)()
      end

      local items = {
         { title = 'Resize...', action = action_resize },
         { title = 'Grid...', action = action_grid },
         { title = 'Transpose', action = dlg.matrix_transpose },
         { title = 'Store matrix...', action = dlg.store_interactive },
         { title = 'Push matrix', action = dlg.push_to_stack },
         { title = 'Push list', action = dlg.push_list_to_stack },
         { title = 'Push eqsystem', action = dlg.push_system_to_stack },
         { title = 'Push piecewise', action = dlg.push_piecewise_to_stack },
         { title = 'Push as...', action = dlg.push_any_to_stack },
         { title = 'Clear', action = dlg.matrix_clear },
         { title = 'Columns...', action = action_col_size },
      }

      ui.menu.menu_at_point(grid, items)
   end

   -- Edit
   local function apply_edit()
      local row, col = grid.sel, grid.col

      local ok, res = pcall(function()
         local tokens = lexer.tokenize(edit.text)
         if not tokens then error({ desc = 'Tokenizing input' }) end

         local e = expr.from_infix(tokens)
         if not e then error({ desc = 'Parsing input' }) end

         return e:infix_string()
      end)

      if ok and res then
         data:set(row, col, res)
         data:fill(nil, nil, '0', false)

         grid:update_rows()
         ui.set_focus(grid)
         return true
      else
         show_error('Error', res.desc or res)
      end
   end

   function edit:on_char(c)
      if self:is_cursor_at_end() and c == ',' then
         if apply_edit() then
            dlg.next_cell('right')
         end
         return
      end

      return ui.edit.on_char(self, c)
   end

   function edit:on_enter_key()
      if apply_edit() then
         dlg.next_cell('down')
      end
   end

   function edit:on_escape()
      ui.set_focus(grid)
      update_selection()
   end

   -- Initialize empty matrix
   if not data then
      data = matrix.new()
   end

   dlg.grid_resize(math.max(6, data.m),
                   math.max(6, data.n))
   update_selection()

   return dlg
end

return t
