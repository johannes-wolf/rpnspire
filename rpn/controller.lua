local ui         = require 'ui'
local stack      = require 'rpn.stack'
local operators  = require 'ti.operators'
local expr       = require 'expressiontree'
local functions  = require 'ti.functions'
local sym        = require 'ti.sym'
local errtab     = require 'ti.error'
local config     = require 'config.config'
local bindings   = require 'config.bindings'
local dlg_input  = require 'dialog.input'
local dlg_list   = require 'dialog.list'
local dlg_error  = require 'dialog.error'
local completion = require 'completion'
local apps       = require 'apps.apps'
local lexer      = require 'ti.lexer'

require 'apps.app_trassierung'

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
      }
   }, meta)
end

function meta:initialize()
   self.list.font_size = config.stack_font_size

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
      ui.set_focus(self.list)
   end

   local orig_on_backspace = self.edit.on_backspace
   self.edit.on_backspace = function(view)
      if view.text:len() == 0 then
         self.stack:pop()
      else
         orig_on_backspace(view)
      end
   end

   local orig_insert_text = self.edit.insert_text
   self.edit.insert_text = function(view, text, sel)
      if view:is_cursor_at_end() then
         self:safe_call(function()
            if not self:handle_char(text) then
               orig_insert_text(view, text, sel)
            end
         end)
         return
      end
      orig_insert_text(view, text, sel)
   end

   local orig_on_char = self.edit.on_char
   self.edit.on_char = function(view, c)
      -- Filter leading space
      if view.cursor <= 1 and c == ' ' then
         return
      end

      self:safe_call(function()
         if not self:handle_char(c) then
            orig_on_char(view, c)
         end
      end)
   end

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
   self.edit.kbd:set_seq({ '.', ',' }, function()
      self:record_undo()
      self:handle_char('AUTOJOIN')
   end)

   self.edit.kbd:set_seq({ '.', '/' }, function()
      self:record_undo()
      self:handle_char('AUTOSPLIT')
   end)

   if bindings.main then
      bindings.main(self, self.window, self.edit, self.list)
   end
end

function meta:init_bindings(view, tab)
   view.kbd = view.kbd or ui.keybindings()
   for k, v in pairs(tab or {}) do
      local action, args = k, {}
      if type(k) == 'table' then
         action = k[1]
         args = { table.unpack(k, 2) }
      end

      assert(actions[action])
      if type(v) == 'table' then
         view.kbd:set_seq(v, function() (actions[action])(self, table.unpack(args)) end)
      else
         view.kbd:set_seq({ v }, function() (actions[action])(self, table.unpack(args)) end)
      end
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

   self.list.row_update = function(this, row, data)
      row._infix.text = data.label or data.infix or ''
      row._result.text = data.result or ''
   end

   self.list.row_constructor = function(this, data)
      local padding = 2
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

local function is_operator_store(c)
   return c == ':=' or c == '=:' or c == sym.STORE
end

local function is_operator(c)
   return operators.query_info(c) or c == '^2' or c == '10^'
end

local function is_operator_rpn(c)
   return c == 'AUTOJOIN' or c == 'AUTOSPLIT'
end

local function is_function(c)
   return functions.query_info(c, true) and true
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
      local is_negative = self.edit.text:find(sym.NEGATE) == 1
      if is_negative then
         self.edit.text = self.edit.text:usub(2)
         self.edit.cursor = self.edit.cursor - 1
      else
         self.edit.text = sym.NEGATE .. self.edit.text
         self.edit.cursor = self.edit.cursor + 1
      end
      return true
   end

   -- Remove trailing '(' some keys append
   if c:ulen() > 1 and c:usub(-1) == '(' then
      c = c:usub(1, -2)
   end

   -- TODO: Move special operator handling to rpn_stack
   if is_operator_store(c) then
      self:dispatch_operator_store(c)
   elseif is_operator(c) then
      self:dispatch_operator(c)
   elseif is_operator_rpn(c) then
      self:dispatch_operator_rpn(c)
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

function meta:dispatch_operator_rpn(c)
   if c == 'AUTOJOIN' then
      self:dispatch()

      local args = self.stack:pop_n(2)
      local first, second = args[1], args[2]

      if first.kind == 'syntax' or second.kind == 'syntax' then
         local text, all_args = nil, {}
         if first.text == '[' or first.text == '{' then
            text = first.text
            for _, v in ipairs(first.children or {}) do table.insert(all_args, v) end
         else
            table.insert(all_args, first)
         end

         if second.text == '[' or second.text == '{' then
            text = second.text
            for _, v in ipairs(second.children or {}) do table.insert(all_args, v) end
         else
            table.insert(all_args, second)
         end

         if text then
            first = expr.node(text, 'syntax', all_args)
         end
      else
         first = expr.node('[', 'syntax', args)
      end

      self.stack:push_expr(first)
   elseif c == 'AUTOSPLIT' then
      self:dispatch()

      local flat = {}
      local function flatten_args(node, kind, text)
         if node.kind == kind and node.text == text and node.children and #node.children > 0 then
            for _, v in ipairs(node.children) do
               if not flatten_args(v, kind, text) then
                  table.insert(flat, v)
               end
            end
            return true
         end
         return false
      end

      local first = self.stack:top().rpn
      if first.children and #first.children > 0 then
         self.stack:pop()
         flatten_args(first, first.kind, first.text)
         for _, v in ipairs(flat) do
            self.stack:push_expr(v)
         end
      end

   end
end

function meta:dispatch_operator_store(c)
   if self:dispatch_operator(c) then
      if config.store_mode == 'pop' then
         self.stack:pop()
      elseif config.store_mode == 'replace' then
         local node = self.stack:pop()
         node = node and node.rpn
         if not node then return false end

         local var_node
         if node.text == ':=' then
            var_node = node.children[1]
         else
            var_node = node.children[2]
         end
         self.stack:push_expr(var_node)
      end
      return true
   end
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
      stack = table_clone(self.stack.stack),
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
   self.stack.stack = state.stack
   self.stack:on_change()
   if state.input ~= nil then
      self.edit:set_text(state.input)
   end
end

-- Undo last to last recorded state
function meta:undo()
   if #self._undo.undo_stack > 0 then
      local state = table.remove(self._undo.undo_stack)
      table.insert(self._undo.redo_stack, self:undo_make_state())
      self:undo_apply_state(state)
   end
end

-- Redo last undone operation
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

function meta:swap()
   self:record_undo()
   self.stack:swap()
end

function meta:dup()
   self:record_undo()
   self.stack:dup(self:stack_get_sel())
end

function meta:pop()
   self:record_undo()
   self.stack:pop(self:stack_get_sel())
end

function meta:roll_up()
   self:record_undo()
   self.stack:roll(-1)
end

function meta:roll_down()
   self:record_undo()
   self.stack:roll(1)
end

-- Get token ranges
---@param edit      ui.edit
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

function meta:copy()
   local expr = self:stack_sel_expr()
   if expr then
      self.edit:insert_text(expr.infix, true)
   end
end

function meta:copy_result()
   local expr = self:stack_sel_expr()
   if expr then
      self.edit:insert_text(expr.result, true)
   end
end

function meta:edit_interactive()
   local expr = self:stack_sel_expr()
   if expr then
      local dlg = dlg_input.display()
      dlg.label.text = string.format("Edit ...")
      dlg.edit:insert_text(expr.infix, true)
      completion.setup_edit(dlg.edit)
      dlg.on_done = function(text)
         if text:len() > 0 then
            self:record_undo()
            expr.infix = text
            self.stack:reeval_infix(expr)
         end
      end
   end
end

function meta:solve_interactive()
   if not self.stack:top() then return end

   local dlg = dlg_input.display(string.format("Solve %s for ...", self.stack:top().infix or '?'))
   dlg.edit:insert_text('{x}', false)
   dlg.edit:set_cursor(2, 1)
   dlg.on_done = function(text)
      if text:len() > 0 then
         self:record_undo()
         self.stack:push_infix(text)
         self:dispatch_function('solve', true, false)
      end
   end
end

function meta:store_interactive()
   if not self.stack:top() then return end

   local dlg = dlg_input.display(string.format("Store %s to ...", self.stack:top().infix or '?'))
   dlg.edit.on_complete = function(_, _)
      local list = {}
      if var then list = var:list() end
      for n = 1, 9 do
         table.insert(list, string.format('f%d(x)', n))
      end
      return list
   end
   dlg.on_done = function(text)
      if text:len() > 0 then
         self:record_undo()
         self.stack:push_infix(text)
         self:handle_char('=:')
      end
   end
end

function meta:clear_all_vars()
   for _, v in ipairs(var.list()) do
      math.evalStr(string.format("delvar %s", v))
   end
end

function meta:variables_interactive()
   local dlg = dlg_list.display('Variables', {}, 'string')
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

function meta:run_app(name)
   if name then
      if apps.tab[name] then
         apps.tab[name](self.stack)
         return
      end
   end

   local items = {}
   for _, v in ipairs(apps.tab) do
      table.insert(items, { title = v.title, fn = v.fn })
   end

   local dlg = dlg_list.display('Apps', items, 'simple')
   dlg.on_done = function(item)
      if item then
         self:record_undo()
         item.fn(self.stack)
      end
   end
end

function meta:push_list(n)
   self:record_undo()
   if self.stack:top() then
      self.stack:push_expr(expr.node('{', 'syntax', self.stack:pop_n(n or 1)))
   else
      self.stack:push_expr(expr.node('{', 'syntax', {}))
   end
end

-- Push operator
---@param operator string
function meta:push_operator(operator)
   self:handle_char(operator)
end

-- Show global command palette
function meta:command_palette()
   print('TODO')
end

return t
