local ui           = require 'ui'
local stack        = require 'rpn.stack'
local operators    = require 'ti.operators'
local expr         = require 'expressiontree'
local functions    = require 'ti.functions'
local sym          = require 'ti.sym'
local errtab       = require 'ti.error'
local config       = require 'config.config'
local bindings     = require 'config.bindings'
local ask          = require('dialog.input').display
local dlg_list     = require 'dialog.list'
local dlg_error    = require 'dialog.error'
local dlg_filter   = require 'dialog.filterlist'
local completion   = require 'completion'
local apps         = require 'apps.apps'
local lexer        = require 'ti.lexer'
local matrixeditor = require 'rpn.matrixeditor'
local advice       = require 'advice'

require 'apps.init'

local t = {}

---@class rpn_controller
---@field mode    'rpn'|'alg'
---@field window  ui.view
---@field edit    ui.edit
---@field list    ui.list
---@field stack   rpn_stack
---@field _undo   table<string, table>
local meta = {}
meta.__index = meta

local cmds = {}
local function cmd(name, fn_name)
   table.insert(cmds, { title = name, fn = function(target)
      meta[fn_name](target)
   end })
end

---@param edit_view ui.edit
---@param list_view ui.list
function t.new(window, edit_view, list_view)
   return setmetatable({
      mode = 'rpn',
      window = window,
      edit = edit_view,
      list = list_view,
      stack = stack.new(),
      _undo = {
         undo_stack = {},
         redo_stack = {},
      },
   }, meta)
end

function meta:initialize()
   self.list.font_size = config.stack_font_size
   self.list.style = 'list'
   self.list.columns = {{ size = '*' }}

   self:poison_edit()
   self:poison_list()

   self.stack.on_change = function(this, _)
      self.list.items = this.stack
      self.list:update_rows()
      if ui.get_focus() ~= self.list then
         self.list:scroll_to_item('end')
      end
   end

   completion.setup_edit(self.edit)
end

function meta:poison_edit()
   self.edit.on_up = function(view)
      self.list:set_selection('end')
      if #self.stack.stack > 0 then
         ui.set_focus(self.list)
      end
   end

   self.edit.on_backspace = advice.around(self.edit.on_backspace,
       function(fn, view)
          if view.text:len() == 0 then
             self.stack:pop()
          else
             fn(view)
          end
   end)

   self.edit.insert_text = advice.around(self.edit.insert_text,
       function(fn, view, text, sel)
          if view:is_cursor_at_end() then
             self:safe_call(function()
                if not self:handle_char(text) then
                   fn(view, text, sel)
                end
             end)
             return
          end
          fn(view, text, sel)
      end)

   self.edit.on_char = advice.around(self.edit.on_char,
       function(fn, view, c)
          -- Filter leading space
          if view.cursor <= 1 and c == ' ' then
             return
          end

          self:safe_call(function()
             if not self:handle_char(c) then
                fn(view, c)
             end
          end)
      end)

   self.edit.on_enter_key = function(view)
      if view.text:ulen() > 0 then
         self:safe_call(function()
            self:record_undo()
            if self.mode == 'rpn' then
               if self:dispatch_function(view.text, true, false) or
                   self:dispatch_operator(view.text) then
                  view:set_text('')
               end
            end

            if view.text:ulen() > 0 then
               self.stack:push_infix(view.text)
               view:set_text('')
            end
         end)
      else
         self.stack:dup()
      end
   end

   if bindings.main then
      bindings.main(self, self.window, self.edit, self.list)
   end
end

function meta:poison_list()
   local orig_on_down = self.list.on_down
   self.list.on_down = function(view)
      if view.sel == #view.items then
         ui.set_focus(self.edit)
      else
         orig_on_down(view)
      end
   end

   self.list.on_escape = function(_)
      ui.set_focus(self.edit)
   end

   self.list.on_tab = function(_)
      ui.set_focus(self.edit)
   end

   self.list.cell_update = function(this, cell, column, data)
      cell._infix.text = data.label or data.infix or ''
      cell._result.text = data.result or ''
   end

   self.list.cell_constructor = function(this, column, data)
      local padding = ui.style.padding
      local row = ui.container()
      row.style = 'none'

      local infix = ui.label()
      infix.font_size = this.font_size
      infix.align = -1
      infix.text = data.label or data.infix or ''
      infix.layout = ui.rel { left = padding, right = 0, top = padding, height = '50%' }

      local result = ui.label()
      result.font_size = this.font_size
      result.align = 1
      result.text = data.result or ''
      result.layout = ui.rel { left = 0, right = padding, bottom = padding, height = '50%' }

      row._infix = infix
      row._result = result
      row:add_child(infix)
      row:add_child(result)
      return row
   end

   self.list.row_match = nil
   self.list.row_size = 2 * (ui.GC.a_height(self.list.font_size or 11))
end

function meta:safe_call(fn)
   local ok, err = pcall(fn)
   if ok then return err end

   self:display_error(err)
end

function meta:display_error(msg)
   if type(msg) == 'table' then
      msg = msg.code and errtab[msg.code] or msg.desc
   end

   local dlg = dlg_error.display('Error', msg or '?')
   dlg.on_cancel = function()
      self:undo()
   end
end

local function is_operator(c)
   return operators.query_info(c) or c == '^2' or c == '10^' or c == '1/x'
end

local function is_function(c)
   return functions.query_info(c, true) and true
end

-- Togle +/- of input string
--   '123'  -> '-123'
--   '1EE2' -> '1EE-2'
---@param str string
---@return string
local function toggle_sign(str)
   assert(str)

   local n
   str, n = str:gsub(sym.EE .. sym.NEGATE, sym.EE, 1)
   if n == 0 then
      str, n = str:gsub(sym.EE .. '%-', sym.EE, 1)
   end
   if n == 0 then
      str, n = str:gsub(sym.EE .. '%+?', sym.EE .. sym.NEGATE, 1)
   end

   if n > 0 then
      return str
   end

   str, n = str:gsub('^' .. sym.NEGATE, '', 1)
   if n == 0 then
      str, n = str:gsub('^%-', '', 1)
   end
   if n == 0 then
      str, n = str:gsub('^%+?', sym.NEGATE, 1)
   end
   return str
end

-- Toggle input sign +/-
function meta:negate_input()
   local text = toggle_sign(self.edit.text or '')
   local cursor = self.edit.text:ulen() - self.edit.cursor
   self.edit:set_text(text)
   self.edit:set_cursor(self.edit.text:ulen() - cursor)
   return true
end

function meta:handle_char(c)
   if self.mode ~= 'rpn' then
      return false
   end

   -- If cursor is not at end, default to alg input
   if not self.edit:is_cursor_at_end() then
      return false
   end

   -- Toggle negative sign for non empty input
   if self.edit.text:ulen() > 0 and c == sym.NEGATE then
      self:negate_input()
      return true
   end

   -- Remove trailing '(' some keys append
   if c:ulen() > 1 and c:usub(-1) == '(' then
      c = c:usub(1, -2)
   end

   if is_operator(c) then
      self:dispatch_operator(c)
   elseif is_function(c) then
      self:dispatch_function(c, false, true)
   else
      return false
   end

   self.edit:set_text('')
   return true
end

function meta:dispatch()
   if self.edit.text:ulen() > 0 and not is_operator(self.edit.text) then
      self.stack:push_infix(self.edit.text)
      self.edit:set_text('')
      return true
   end
   return false
end

function meta:undo_transaction(fn, ...)
   self:record_undo()
   local ok, res = pcall(fn, ...)
   if not ok then
      self:undo()
      error(res)
   end
   return res
end

function meta:dispatch_operator(c)
   return self:undo_transaction(function()
      self:dispatch()
      return self.stack:push_operator(c)
   end)
end

function meta:dispatch_function(str, ignore_input, builtin_only)
   return self:undo_transaction(function()
      if not ignore_input then
         self:dispatch()
      end
      return self.stack:push_function(str, nil, builtin_only)
   end)
end

function meta:validate_stack_n(n)
   if #self.stack.stack < n then
      error({ desc = string.format('too few items on stack. want %d', n) })
      return false
   end
   return true
end

-- Undo

-- Snapshot current state
---@return table
function meta:undo_make_state(text)
   return {
      stack = self.stack:clone(),
      input = text or self.edit.text,
   }
end

-- Record current state as undo state
---@param input string?  Optional input field string
function meta:record_undo(input)
   table.insert(self._undo.undo_stack, self:undo_make_state(input))
   if #self._undo.undo_stack > 10 then
      table.remove(self._undo.undo_stack, 1)
   end
   self._undo.redo_stack = {}
end

-- Pop undo state
function meta:pop_undo()
   table.remove(self._undo.undo_stack)
end

-- Apply undo state
---@param state table
function meta:undo_apply_state(state)
   self.stack = state.stack
   self.stack:on_change()
   if state.input ~= nil then
      self.edit:set_text(state.input)
   end
end

-- Undo last to last recorded state
cmd('Undo', 'undo')
function meta:undo()
   if #self._undo.undo_stack > 0 then
      local state = table.remove(self._undo.undo_stack)
      table.insert(self._undo.redo_stack, self:undo_make_state())
      self:undo_apply_state(state)
   end
end

-- Redo last undone operation
cmd('Redo', 'redo')
function meta:redo()
   if #self._undo.redo_stack > 0 then
      local state = table.remove(self._undo.redo_stack)
      table.insert(self._undo.undo_stack, self:undo_make_state())
      self:undo_apply_state(state)
   end
end

-- Actions
function meta:stack_get_sel()
   if ui.get_focus() == self.list then
      return self.list.sel
   end
   return nil
end

function meta:stack_sel_expr()
   if ui.get_focus() == self.list then
      return self.list.items[self.list.sel]
   end
   return self.stack:top()
end

cmd('Swap', 'swap')
function meta:swap()
   self:record_undo()
   self.stack:swap()
end

cmd('Dup', 'dup')
function meta:dup()
   self:record_undo()
   self.stack:dup(self:stack_get_sel())
end

cmd('Drop', 'pop')
function meta:pop()
   self:record_undo()
   self.stack:pop(self:stack_get_sel())
end

cmd('Roll -1', 'roll_up')
function meta:roll_up(n)
   self:record_undo()
   self.stack:roll(n and (-n) or -1)
end

cmd('Roll 1', 'roll_down')
function meta:roll_down(n)
   self:record_undo()
   self.stack:roll(n or 1)
end

-- Get token ranges
---@param edit ui.edit
local function get_token_ranges(edit)
   local ok, tokens = pcall(function()
      local text = edit.text
      return lexer.tokenize(text)
   end)
   if ok and tokens then
      local pos = {}
      for _, v in ipairs(tokens) do
         table.insert(pos, { left = v.location[1], right = v.location[2] })
      end
      return pos
   end
end

local function edit_select_next_token(edit, direction)
   local ranges = get_token_ranges(edit)
   for idx, v in ipairs(ranges) do
      if edit.cursor <= v.right or idx == #ranges then
         if edit.cursor > v.left then
            edit:set_cursor(v.left, v.right - v.left + 1)
            return
         elseif edit.cursor == v.left then
            if direction == 'left' and idx > 1 then
               v = ranges[idx - 1]
               edit:set_cursor(v.left, v.right - v.left + 1)
            elseif direction == 'right' and idx < #ranges then
               v = ranges[idx + 1]
               edit:set_cursor(v.left, v.right - v.left + 1)
            end
            return
         end
      end
   end
end

cmd('Copy expression', 'copy')
function meta:copy()
   local e = self:stack_sel_expr()
   if e then
      self.edit:insert_text(e.infix, true)
   end
end

cmd('Copy result', 'copy_result')
function meta:copy_result()
   local item = self:stack_sel_expr()
   if item then
      self.edit:insert_text(item.result, true)
   end
end

cmd('Edit list', 'edit_list_interactive')
function meta:edit_list_interactive(stack_item, cols)
   local matrix = require 'matrix'

   stack_item = stack_item or self:stack_sel_expr()
   if not stack_item then return end

   local mat = matrix.new():from_list(stack_item.rpn, cols or 1)
   local dlg = matrixeditor.display(self, mat)
   dlg.grid_resize(mat.m + 10, cols)
   dlg.set_column_size('=')
   function dlg.on_done(mat)
      self:safe_call(function()
         stack_item.rpn.children = mat:to_list().children
         stack_item:eval(self.stack)
      end)
   end
end

cmd('Edit matrix', 'edit_matrix_interactive')
function meta:edit_matrix_interactive(stack_item)
   local matrix = require 'matrix'

   stack_item = stack_item or self:stack_sel_expr()
   if not stack_item then return end

   local dlg = matrixeditor.display(self, matrix.new():from_expr(stack_item.rpn))
   function dlg.on_done(mat)
      self:safe_call(function()
         stack_item.rpn = mat:to_expr()
         stack_item:eval(self.stack)
      end)
   end
end

cmd('Edit', 'edit_interactive')
function meta:edit_interactive()
   local item = self:stack_sel_expr()
   if item then
      if config.edit_use_matrix_editor then
         if item.rpn:isa(expr.MATRIX) then
            return self:edit_matrix_interactive(item)
         elseif item.rpn:isa(expr.LIST) then
            return self:edit_list_interactive(item, 1)
         elseif item.rpn:isa(expr.FUNCTION, 'system') then
            return self:edit_list_interactive(item, 1)
         elseif item.rpn:isa(expr.FUNCTION, 'piecewise') then
            return self:edit_list_interactive(item, 2)
         end
      end

      local dlg = ask { title = 'Edit', text = item.infix or '' }
      completion.setup_edit(dlg.edit)
      dlg.on_done = function(text)
         if text:len() > 0 then
            self:record_undo()
            item.infix = text
            self.stack:reeval_infix(item)
         end
      end
   end
end

cmd('Solve', 'solve_interactive')
function meta:solve_interactive()
   if not self.stack:top() then return end

   local dlg = ask { title = string.format("Solve %s for ...", self.stack:top().infix or '?'), text = '{x}' }
   dlg.edit:set_cursor(2, 1)
   dlg.on_done = function(text)
      if text:len() > 0 then
         self:record_undo()
         self.stack:push_infix(text)
         self:dispatch_function('solve', true, false)
      end
   end
end

cmd('Explode', 'explode_interactive')
function meta:explode_interactive()
   if not self.stack:top() then return end

   local text = self.stack:top().infix
   local dlg = ask { title = string.format("Explode %s to ...", text or '?') }

   dlg.on_done = function(text)
      if text:len() > 0 then
         self.stack:explode_result_to(text)
      else
         self.stack:explode_result()
      end
   end
end

cmd('Smart append', 'smart_append')
function meta:smart_append()
   self:record_undo()
   self:dispatch()
   self.stack:smart_append()
end

cmd('Store', 'store_interactive')
---@param mode? 'pop'|'replace' # Config store mode override
function meta:store_interactive(mode)
   if not self.stack:top() then return end

   local dlg = ask { title = string.format("Store %s to ...", self.stack:top().infix or '?') }
   completion.setup_edit_store(dlg.edit)
   dlg.on_done = function(text)
      if text:len() > 0 then
         self:record_undo()
         self.stack:push_infix(text)
         self.stack:push_rstore(mode)
      end
   end
end

cmd('Clear variables', 'clear_all_vars')
function meta:clear_all_vars()
   for _, v in ipairs(var.list()) do
      math.evalStr(string.format("delvar %s", v))
   end
end

cmd('Show variables', 'variables_interactive')
function meta:variables_interactive()
   local dlg = dlg_list.display{ title = 'Variables', items = {} }
   local function load_data()
      dlg.list.items = var.list()
      dlg.list:update_rows()
   end

   load_data()

   dlg.list.on_clear = function(_)
      actions.clear_all_vars(self)
      load_data()
   end
   dlg.list.on_backspace = function(list)
      local item = list:get_item()
      if item then
         math.evalStr('delvar ' .. item)
         load_data()
      end
   end
   dlg.on_done = function(item)
      if item then
         self.edit:insert_text(item, true)
      end
   end
end

cmd('Run tool', 'run_app')
function meta:run_app(name)
   if name then
      if apps.tab[name] then
         apps.tab[name](self.stack)
         return
      end
   end

   local function apply_filter(text)
      text = text or ''
      text = text:gsub('.', function(c) return '.*' .. c end)

      local items = {}
      for _, v in ipairs(apps.tab) do
         if v.title:find(text) or (v.description and v.description:find(text)) then
            table.insert(items, { v.title, v.description or '', fn = v.fn })
         end
      end
      return items
   end

   local dlg = dlg_filter.display({ title = 'Apps' }, apply_filter)
   dlg.on_done = function(item)
      if item then
         self:record_undo()
         item.fn(self.stack)
      end
   end
end

cmd('Push matrix', 'push_list')
function meta:push_list(n)
   self:record_undo()
   self.stack:push_container(expr.LIST, n or 1)
end

cmd('Push matrix', 'push_matrix')
function meta:push_matrix(n)
   self:record_undo()
   self.stack:push_container(expr.MATRIX, n or 1)
end

-- Push operator
---@param operator string
function meta:push_operator(operator)
   self:handle_char(operator)
end

-- Do [+/-]
cmd('+/-', 'negate')
function meta:negate()
   self:record_undo()
   self:handle_char(sym.NEGATE)
end

-- Clear stack
cmd('Clear stack', 'clear_stack')
function meta:clear_stack()
   self:record_undo()
   self.stack.stack = {}
   self.list:set_selection(1)
   self.list:update_rows()
end

-- Show expresison and result using TI math view
cmd('Show expression', 'interactive_show')
function meta:interactive_show()
   local top = self:stack_sel_expr()
   if not top then return end

   local wnd = ui.container(ui.rel { left = 10, right = 10, top = 10, bottom = 10 })
   wnd.style = '2D'

   local editor = ui.richedit(ui.rel{ left = 1, right = 1, top = 1, bottom = 1})
   editor:set_expression("\\0el {" .. top.infix .. "}\n=\n" ..
                         "\\0el {" .. top.result .. "}")
   wnd:add_child(editor)

   local session = ui.push_modal(wnd)
   ui.set_focus(editor)

   function editor:on_escape()
      ui.pop_modal(session)
   end
end

-- Show global command palette
function meta:command_palette()
   local function apply_filter(text)
      text = text or ''
      text = text:gsub('.', function(c) return '.*' .. c end)

      local items = {}
      for _, cmd in ipairs(cmds) do
         if cmd.title:lower():find(text) then
            table.insert(items, cmd)
         end
      end
      return items
   end

   local dlg = dlg_filter.display({ title = 'Command' }, apply_filter)
   function dlg.on_done(data)
      self:safe_call(function()
         data.fn(self)
      end)
   end
end

cmd('Show bindings', 'show_bindings')
function meta:show_bindings()
   local items = {}

   local function collect_bindings(prefix, tab)
      local function join_binding_path(path, tab)
         for k, v in pairs(tab) do
            if type(v) == 'table' and not v[1] then
               join_binding_path(path .. ' [' .. k .. ']', v)
            elseif type(v) == 'table' and v[1] then
               table.insert(items, { tostring(path .. ' [' .. k .. ']'), v[2] or '?' })
            end
         end
      end

      if tab then
         join_binding_path(prefix .. ': ', tab.kbd)
      end
   end

   collect_bindings('All', self.window)
   collect_bindings('Edit', self.edit)
   collect_bindings('Stack', self.list)
   -- TODO: How show bindings of other views not existing yet? 

   local dlg = dlg_list.display{ title = 'Bindings', items = items }
   function dlg.on_done(item)
      return true
   end
end

cmd('Matrix writer', 'matrix_writer')
function meta:matrix_writer()
   local dlg = matrixeditor.display(self, nil)
   function dlg.on_done(mat)
      self:safe_call(function()
         self.stack:push_expr(mat:to_expr())
      end)
   end
end

return t
