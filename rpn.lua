--[[
Copyright (c) 2022 Johannes Wolf <mail@johannes-wolf.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License version 3 as published by
the Free Software Foundation.
]]--

-- Forward declarations
local focus_view = nil
local input_ask_value = nil
local completion_catmatch = nil
local completion_fn_variables = nil
local theme_val = nil

-- Temporary mode override stack
local temp_mode = {}

-- Currently focused view
local current_focus = nil

-- Undo Scope
local Undo = {
  undo_stack = {},
  redo_stack = {}
}

-- Helper for loading user-defined lua code
---@param name string  TI-BASIC function name (rpnuser\\*)
---@return any
local function load_user_code(name)
  local ok, res = pcall(function()
    return loadstring(_G.math.eval('rpnuser\\' .. name))()
  end)

  return ok and res
end


-- Dump table to string
---@param o table
---@return string | nil
local function dump(o)
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

-- Deep copy table
---@param t table  Input table
---@return table
local function table_clone(t)
  if type(t) ~= 'table' then return t end
  local meta = getmetatable(t)
  local target = {}
  for k, v in pairs(t) do
    if type(v) == 'table' then
      target[k] = table_clone(v)
    else
      target[k] = v
    end
  end
  setmetatable(target, meta)
  return target
end

-- Copy certain table fields
---@param source table   Source table
---@param fields table   List of field names to copy
---@param target? table  Target table
---@return table
local function table_copy_fields(source, fields, target)
  target = target or {}
  for _,v in ipairs(fields) do
    if type(source[v]) == 'table' then
      target[v] = table_clone(source[v])
    else
      target[v] = source[v]
    end
  end
  return target
end

-- Join table to string
---@param self table             Self
---@param separator string       Separator string
---@param transform_fn function  Transformation function (any) : string
---@return string
function table.join_str(self, separator, transform_fn)
  if not self then return '' end

  separator = separator or ' '
  local str = ''
  for idx, item in ipairs(self) do
    if idx > 1 then
      str = str .. separator
    end
    str = str .. (transform_fn and transform_fn(item) or tostring(item))
  end
  return str
end

-- Trim quotes from string
---@param str string  Input string
---@param q? string   Quote character (defaults to ")
---@return string
function string.unquote(str, q)
  q = q or '"'
  if str:sub(1, 1) == q and
     str:sub(-1)   == q then
    return str:sub(2, -2)
  end
  return str
end

-- Returns the number of utf-8 codepoints in string
---@param str string
---@return number
function string.ulen(str)
  return select(2, str:gsub('[^\128-\193]', ''))
end

-- Draw string aligned
---@param gc table        GC
---@param text string     Text
---@param halign integer  left (<0), center (0), right (>0)
---@param valign integer  top (<0), mid (0), bottom (>0)
---@return integer x1     Left position
---@return integer x2     Right position
---@return integer y      Top position
local function draw_string_aligned(gc, text, x, y, w, h, halign, valign)
  halign = halign or -1
  valign = valign or -1

  if halign >= 0 then
    local text_w = gc:getStringWidth(text)
    if halign == 0 then
      x = x + w/2 - text_w/2
    else
      x = x + w - text_w
    end
  end

  if valign >= 0 then
    local text_h = gc:getStringHeight(text)
    if valign == 0 then
      y = y + h/2 - text_h/2
    else
      y = y + h - text_h
    end
  end

  return x, gc:drawString(text, x, y), y
end

-- Draw rect with 1px shadow
---@param gc table
local function draw_rect_shadow(gc, x, y, w, h)
  gc:drawRect(x, y, w, h)
  gc:drawRect(x + 1, y + h, w, 1)
  gc:drawRect(x + w, y + 1, 1, h)
end


-- Rectangle utility functions
Rect = {}
function Rect.is_point_in_rect(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.width and
         y >= rect.y and x <= rect.y + rect.height
end

function Rect.intersection(r, x, y, width, height)
  local top_left = {
      x = math.max(r.x, x),
      y = math.max(r.y, y)
  }
  local bottom_right = {
      x = math.min(r.x + r.width, x + width),
      y = math.min(r.y + r.height, y + height)
  }

  if bottom_right.x > top_left.x and
     bottom_right.y > top_left.y then
    return {
      x = top_left.x,
      y = top_left.y,
      width = bottom_right.x - top_left.x,
      height = bottom_right.y - top_left.y
    }
  end
  return nil
end

-- Clipboard
local Clipboard = {
  max = 5,
  items = {}
}

function Clipboard.yank(str)
  if str:ulen() == 0 then
    return
  end

  table.insert(Clipboard.items, tostring(str))
  while #Clipboard.items > Clipboard.max do
    table.remove(Clipboard.items, 1)
  end
end

function Clipboard.get(index)
  return Clipboard.items[index or #Clipboard.items] or ''
end

-- UI
UI = {}

-- Incremental search helper
---@class UI.IncSearch
UI.IncSearch = class()
UI.IncSearch.incremental_search_timeout_ms = 2000 --- Timeout for incremental searches
function UI.IncSearch.get_ms()
  return _G.timer.getMilliSecCounter()
end

function UI.IncSearch:init(on_change)
  self.str = ''
  self.last_input_ms = nil
  -- Callbacks
  self.on_change = on_change
end

function UI.IncSearch:reset()
  self.str = ''
  self.last_input_ms = nil
end

function UI.IncSearch:onClear()
  self.str = ''
  if self.on_change then
    self.on_change(self.str)
  end
end

function UI.IncSearch:onBackspace()
  self.str = ''
  if self.on_change then
    self.on_change(self.str)
  end
end

function UI.IncSearch:onCharIn(c)
  local now = UI.IncSearch.get_ms()
  if self.last_input_ms then
    if now - self.last_input_ms > UI.IncSearch.incremental_search_timeout_ms then
      self.str = ''
    end
  end

  self.str = self.str .. c
  if self.on_change then
    self.on_change(self.str)
  end

  self.last_input_ms = now
end

-- Widget base class
---@class UI.Widget
UI.Widget = class()
function UI.Widget:init(frame)
  self._frame = frame or {0, 0, 0, 0}
  self._visible = true
end

---@return number  x
---@return number  y
---@return number  width
---@return number  height
function UI.Widget:frame()
  return unpack(self._frame)
end

function UI.Widget:set_frame(x, y, w, h)
  self._frame = {x, y, w, h}
end

function UI.Widget:visible()
  return self._visible
end

function UI.Widget:invalidate()
  local x, y, w, h = self:frame()
  platform.window:invalidate(x, y, w + 1, h + 1)
end

function UI.Widget:draw(gc)
  gc:drawRect(self:frame())
end

-- Vertical row layout container
---@class UI.RowLayout
UI.RowLayout = class()
function UI.RowLayout:init()
  self.children = {}
end

-- Add child widget
---@param widget UI.Widget  Child widget to add
---@param index? number     Index at which to add the widget
---@param height? number    Size in units
---@return UI.Widget widget
function UI.RowLayout:add_widget(widget, index, height)
  index = index or #self.children
  table.insert(self.children, index, {
    widget = widget,
    height = height
  })
  return self.children[index].widget
end

-- Calculate child layout
function UI.RowLayout:layout(x, y, w, h)
  x = x or 0
  y = y or 0
  w = w or platform.window:width()
  h = h or platform.window:height()

  local dyn_height = h
  local dyn_child_count = 0
  for _, child in ipairs(self.children) do
    if child.widget:visible() then
      if child.height then
        dyn_height = dyn_height - child.height
      else
        dyn_child_count = dyn_child_count + 1
      end
    end
  end

  for _, child in ipairs(self.children) do
    if child.widget:visible() then
      local child_height = child.height or (dyn_height / dyn_child_count)
      child.widget:set_frame(x, y, w, child_height)

      y = y + child_height
    end
  end
end

-- Render layout
function UI.RowLayout:draw(gc, x, y, w, h)
  self:layout()

  for _, child in ipairs(self.children) do
    if child.widget:visible() then
      child.widget:draw(gc, x, y, w, h)
    end
  end
end

-- Bar for text
---@class UI.OmniBar : UI.Widget
UI.OmniBar = class(UI.Widget)
function UI.OmniBar:init()
  UI.Widget.init(self)
  self.text_left = nil
  self.text_right = nil
end

function UI.OmniBar:draw(gc)
  local x, y, w, h = self:frame()

  local old_f, old_s, old_size = gc:setFont('sansserif', 'r', 6)
  gc:clipRect('set', x, y, w, h)
  gc:setColorRGB(theme_val('omni_bg'))
  gc:fillRect(x, y, w, h)

  gc:setColorRGB(theme_val('omni_fg'))
  if self.text_right then
    w = draw_string_aligned(gc, self.text_right, x, y, w, h, 1, 0) - x - 2
  end

  if self.text_left then
    gc:clipRect('set', x, y, w, h)
    draw_string_aligned(gc, self.text_left, x, y, w, h, -1, 0)
  end
  gc:setFont(old_f, old_s, old_size)
end

function UI.OmniBar:visible()
  return self.text_left or self.text_right
end

function UI.OmniBar:set_text(left, right)
  self.text_left = left
  self.text_right = right
end

function UI.OmniBar.height()
  return platform.withGC(function(gc)
    gc:setFont('sansserif', 'r', 6)
    return gc:getStringHeight('A')
  end)
end

---@class UI.Menu : UI.Widget
---@field items table  List of items
---@field sel number   Selected item
UI.Menu = class(UI.Widget)
UI.Menu.current_menu = nil           --- Current root menu
UI.Menu.last_focus = nil             --- Last focused non-menu
UI.Menu.submenu_indicator_width = 8  --- Submenu indicator width (units)
UI.Menu.hmargin = 4
UI.Menu.font_size = 9
UI.Menu.item_height = nil

function UI.Menu.draw_current(gc)
  if UI.Menu.current_menu then
    UI.Menu.current_menu:draw(gc)
  end
end

function UI.Menu.close_current()
  if getmetatable(current_focus) == UI.Menu then
    current_focus:close(true)
  end
end

function UI.Menu:init(parent)
  UI.Widget.init(self)
  self.items = {}
  self.orig_items = nil
  self.sel = 1

  self.width = nil
  self.height = nil
  self.max_height = nil
  self.vscroll = 0
  self.parent = parent
  self._visible = false
  self.filtered = false
  self.isearch = UI.IncSearch(function(str)
    if not self.orig_items then
      self.orig_items = self.items
    end

    if not str or str == '' then
      self.items = self.orig_items
      self.filtered = false
      self:invalidate()
      self:calc_size(true)
      self:invalidate()
      return
    end

    -- Recursive search menu
    local function add_matches(menu)
      for _, item in ipairs(menu.orig_items or menu.items) do
        if item['submenu'] then
          add_matches(item['submenu'])
        elseif item['action'] then
          if item['title'] and item['title']:lower():find(str:lower()) then
            table.insert(self.items, item)
          end
        end
      end
    end

    self.items = {}
    self.filtered = true
    add_matches(self)
    self:select_item(1)

    self:invalidate()
    self:calc_size(true)
    self:invalidate()
  end)

  -- Lazy globals
  UI.Menu.item_height = UI.Menu.item_height or platform.withGC(function(gc)
    gc:setFont('sansserif', 'r', UI.Menu.font_size)
    return gc:getStringHeight("A")
  end)

  -- Callbacks
  self.onExec = nil --- onExec(action : any) : string
  self.onSelect = nil -- onSelect(idx : number, item : table)
end

-- Returns if the menu is filtered
---@return boolean filtered
function UI.Menu:is_filtered()
  return self.filtered
end

-- Add menu item
---@param title string   Title
---@param action? any    Value; set nil for opening a submenu
---@return UI.Menu menu  Returs self or sub-menu
function UI.Menu:add(title, action)
  if not title and not action then
    return self.parent
  end

  if not action then
    local sub = UI.Menu(self)
    table.insert(self.items, {title=title, submenu=sub})
    return sub
  else
    table.insert(self.items, {title=title, action=action})
    return self
  end
end

function UI.Menu:open_at(x, y, max_height, parent)
  if not parent then
    UI.Menu.current_menu = self
    UI.Menu.last_focus = current_focus
  else
    self.onExec = self.onExec or parent.onExec
  end

  if not self.width or not self.height then
    self:calc_size()
  end

  self.max_height = max_height

  -- If in the lower quarter of the screen, open menus to the top
  if y > platform.window:height() * 0.75 then
    y = y - self.height
  end

  local x_offset = x + self.width - platform.window:width()
  if x_offset > 0 then
    x = x - x_offset
  end

  local y_offset = y + self.height - (self.max_height or platform.window:height())
  if y_offset > 0 then
    y = y - y_offset
  end

  self.parent = parent
  self:set_frame(math.max(0, x), math.max(0, y), 0, 0)
  focus_view(self)
  self._visible = true
  self:select_item(self.sel or 1, false)
end

function UI.Menu:close(recurse)
  self._visible = false

  if self.parent then
    if recurse then
      self.parent:close(recurse)
      self.parent = nil
    else
      if current_focus == self then
        focus_view(self.parent)
      end
    end
  else
    UI.Menu.current_menu = nil
    focus_view(UI.Menu.last_focus)
  end
end

function UI.Menu:select_item(idx, exec)
  if idx == 0 then idx = 10 end
  idx = math.max(1, idx)
  if #self.items >= idx then
    self.sel = idx

    local _, y, _, h = self:frame()
    local _, item_y, _, item_h = self:item_rect(self.sel)

    if item_y < 0 then
      self.vscroll = self.vscroll + item_y
    elseif item_y + item_h > y + h then
       self.vscroll = self.vscroll + (item_y + item_h) - (y + h)
    end

    if self.onSelect then
      self.onSelect(self.sel, self.items[self.sel])
    end
    if exec then
      self:exec_item(idx)
    end
    self:invalidate()
  end
end

function UI.Menu:exec_item(idx)
  local item = self.items[idx]
  if item then
    if item['submenu'] then
      local x, y, w = self:item_rect(self.sel)
      item.submenu:open_at(x + w - 4, y + 4, nil, self)
    end

    if item['action'] then
      if self.onExec then
        if self.onExec(item['action']) ~= 'repeat' then
          self:close(true)
        end
      elseif type(item['action']) == 'function' and
             item['action']() ~= 'repeat' then
        self:close(true)
      end
    end
  end
end

function UI.Menu:onCharIn(c)
  if c:find('^%d+$') then
    self:select_item(tonumber(c), true)
  else
    self.isearch:onCharIn(c)
  end
end

function UI.Menu:onArrowUp()
  self.sel = self.sel - 1
  if self.sel <= 0 then
    self.sel = #self.items
  end
  self.isearch:reset()
  self:select_item(self.sel, false)
end

function UI.Menu:onArrowDown()
  self.sel = self.sel + 1
  if self.sel > #self.items then
    self.sel = 1
  end
  self.isearch:reset()
  self:select_item(self.sel, false)
end

function UI.Menu:onTab()
  self:onArrowDown()
end

function UI.Menu:onBackTab()
  self:onArrowUp()
end

function UI.Menu:onArrowLeft()
  if self.parent then
    self:close(false)
  end
end

function UI.Menu:onArrowRight()
  self:exec_item(self.sel or 1)
end

function UI.Menu:onEnter()
  self:onArrowRight()
end

function UI.Menu:onEscape()
  self:close(true)
end

function UI.Menu:onBackspace()
  if self.isearch.str:len() > 0 then
    self.isearch:onBackspace()
  else
    self:onEscape()
  end
end

function UI.Menu:selected_item()
  if self.sel then
    return self.items[self.sel]
  end
end

function UI.Menu:frame()
  return self._frame[1], self._frame[2],
         math.min(platform.window:width(), self.width),
         math.min(self.max_height or platform.window:height(), self.height)
end

function UI.Menu:calc_size(width_only)
  platform.withGC(function(gc)
    local max_width = 1
    gc:setFont('sansserif', 'r', UI.Menu.font_size)

    for _, item in ipairs(self.items) do
      local item_width = gc:getStringWidth(item['title'])
      if item['submenu'] then
        item_width = item_width + UI.Menu.submenu_indicator_width
      end
      max_width = math.max(max_width, item_width)
    end

    self.width = max_width + UI.Menu.hmargin * 2
    if not width_only then
      self.height = UI.Menu.item_height * #self.items
    end
  end)
end

function UI.Menu:item_rect(idx)
  local x, y, w, _ = self:frame()
  return x + UI.Menu.hmargin,
         y + (idx - 1) * UI.Menu.item_height - self.vscroll,
         w - UI.Menu.hmargin,
         UI.Menu.item_height
end

---@param gc table     GC
---@param item table   Item
---@param sel boolean  Selection state
---@param x number     X
---@param y number     Y
---@return number height
function UI.Menu:draw_item(gc, item, sel, x, y)
  local title = item['title']

  gc:setColorRGB(theme_val(self:is_filtered() and 'filter_fg' or 'fg'))
  gc:drawString(title, x, y)

  if item['submenu'] then
    local _, _, w = self:frame()
    gc:fillRect(x + w - UI.Menu.hmargin - 8, y + UI.Menu.item_height / 2 - 1, 4, 4)
  end

  return gc:getStringHeight(title)
end

function UI.Menu:draw(gc)

  if not self._visible then return end
  local x, y, w, h = self:frame()
  if h == 0 then
    return
  end

  gc:clipRect('set', x, y, w+1, h+1)
  gc:setColorRGB(theme_val('bg'))
  gc:fillRect(x, y, w, h)
  gc:setColorRGB(theme_val('border_bg'))
  draw_rect_shadow(gc, x, y, w - 1, h - 1)
  gc:setFont('sansserif', 'r', UI.Menu.font_size)

  local item_y = y - self.vscroll
  for idx, item in ipairs(self.items) do
    gc:clipRect('set', x, y, w - 1, h - 1)
    if self.sel == idx then
      gc:setColorRGB(theme_val('selection_bg'))
      gc:fillRect(x + 1, item_y + 1, w - 2, UI.Menu.item_height)
    end

    self:draw_item(gc, item, self.sel == idx, x + UI.Menu.hmargin, item_y)
    if item['submenu'] then
      item['submenu']:draw(gc)
    end

    item_y = item_y + UI.Menu.item_height
  end

  gc:clipRect('reset', x, y, w, h)
end

-- Prefix tree
Trie = {}

-- Build a prefix tree (trie) from table
---@param tab table  Input table
---@return table     Prefix tree
function Trie.build(tab)
  local trie = {}
  for key, _ in pairs(tab) do
    local root = trie
    for i=1,#key do
      local k = string.sub(key, i, i)
      root[k] = root[k] or {}
      root = root[k]
    end
    root['@LEAF@'] = true
  end
  return trie
end

-- Search for string in prefix table
---@param str string   Search string
---@param tab table    Prefix table (trie)
---@param pos? number  Position in string
function Trie.find(str, tab, pos)
  assert(str)
  assert(tab)
  local i, j = (pos or 1), (pos or 1) - 1
  local match = nil
  while tab do
    j = j+1
    tab = tab[str:sub(j, j)]
    if tab and tab['@LEAF@'] then
      match = {i, j, str:sub(i, j)}
    end
  end

  if match and match[1] then
    return unpack(match)
  end
  return nil
end

-- Theme
---@class Theme
local Theme = class()
function Theme:init(bg, fg, opts)
  self.bg = bg or 0xffffff
  self.fg = fg or 0x000000
  for k, v in pairs(opts) do
    self[k] = v
  end
end

-- Themes
local themes = {
  ['light'] = Theme(0xffffff, 0x000000, {
    row_bg         = 0xffffff,
    alt_bg         = 0xeeeeee,
    selection_bg   = 0xdfdfff,
    fringe_fg      = 0xaaaaaa,
    menu_active_bg = 0x88ff98,
    cursor_bg      = 0xee0000,
    cursor_alg_bg  = 0x0000ff,
    cursor_alt_bg  = 0x999999,
    error_bg       = 0xee0000,
    error_fg       = 0xffffff,
    border_bg      = 0x000000,
    omni_bg        = 0x222222,
    omni_fg        = 0xEEEEEE,
    filter_fg      = 0x0000FF,
  }),
  ['dark'] = Theme(0x444444, 0xffffff, {
    row_bg         = 0x444444,
    alt_bg         = 0x222222,
    selection_bg   = 0xdd0000,
    selection_fg   = 0xffffff,
    fringe_fg      = 0xaaaaaa,
    menu_active_bg = 0x999999,
    cursor_bg      = 0xee0000,
    cursor_alg_bg  = 0x0000ee,
    cursor_alt_bg  = 0x999999,
    error_bg       = 0xee0000,
    error_fg       = 0xffffff,
    border_bg      = 0x000000,
    omni_bg        = 0x222222,
    omni_fg        = 0xEEEEEE,
    filter_fg      = 0x0000FF,
  })
}

-- Global options
local options = {
  autoClose = true,        -- Auto close parentheses
  autoKillParen = true,    -- Auto kill righthand paren when killing left one
  showFringe = true,       -- Show fringe (stack number)
  showExpr = true,         -- Show stack expression (infix)
  autoPop = true,          -- Pop stack when pressing backspace
  theme = "light",         -- Well...
  cursorWidth = 2,         -- Width of the cursor
  mode = "RPN",            -- What else
  saneHexDigits = false,   -- Whether to disallow 0hfx or not (if not, 0hfx produces 0hf*x)
  smartComplete = true,    -- Try to be smart when completing
  spaceAsEnter = false,    -- Space acts as enter in RPN mode
  autoAns = true,          -- Auto insert @1 in ALG mode
  maxUndo = 20,            -- Max num of undo steps
  completionStyle = 'menu',-- Default completion style
}

-- Returns value for key of the current theme
---@param key string
---@return any
theme_val = function(key)
  local val = themes[options.theme][key]
  if not val then
    if key:find('fg$') then
      return themes[options.theme].fg or 0x000000
    elseif key:find('bg$') then
      return themes[options.theme].bg or 0xffffff
    elseif key:find('font$') then
      return {'sansserif', 'r', 11}
    end
  end
  return val
end

-- Get the current mode
---@alias Mode "RPN" | "ALG"
---@return Mode
local function get_mode()
  return (temp_mode and temp_mode[#temp_mode]) or options.mode
end

-- Override the current mode
---@param mode Mode  Mode to set
local function push_temp_mode(mode)
  temp_mode = temp_mode or {}
  table.insert(temp_mode, mode)
end

-- Pop top-most mode from mode stack
local function pop_temp_mode()
  table.remove(temp_mode)
end


local ParenPairs = {
  ['('] = {')', true},
  [')'] = {'(', false},
  ['{'] = {'}', true},
  ['}'] = {'{', false},
  ['['] = {']', true},
  [']'] = {'[', false},
  ['"'] = {'"', true},
  ["'"] = {"'", true},
}

Sym = {
  NEGATE  = "\226\136\146",
  STORE   = "→",
  ROOT    = "\226\136\154",
  NEQ     = "≠",
  LEQ     = "≤",
  GEQ     = "≥",
  LIMP    = "⇒",
  DLIMP   = "⇔",
  RAD     = "\239\128\129",
  GRAD    = "\239\129\128",
  DEGREE  = "\194\176",
  TRANSP  = "\239\128\130",
  CONVERT = "\226\150\182",
  EE      = "\239\128\128",
  POWN1   = "\239\128\133", -- ^-1
  MICRO   = "\194\181",
  INFTY   = "\226\136\158",
}

local operators = {
  --[[                 string, lvl, #, side, assoc, aggressive-assoc ]]--
  -- Parentheses
  ["#"]             = {nil,     18, 1, -1},
  --
  -- Function call
  -- [" "]             = {nil, 17, 1,  1}, -- DEGREE/MIN/SEC
  ["!"]             = {nil,     17, 1,  1},
  ["%"]             = {nil,     17, 1,  1},
  [Sym.RAD]         = {nil,     17, 1,  1},
  [Sym.GRAD]        = {nil,     17, 1,  1},
  [Sym.DEGREE]      = {nil,     17, 1,  1},
  --["_["]            = {nil,     17, 2,  1}, -- Subscript (rpnspire custom)
  ["@t"]            = {Sym.TRANSP, 17, 1, 1},
  [Sym.TRANSP]      = {nil,     17, 1,  1},
  --
  ["^"]             = {nil,     16, 2,  0, 'r', true}, -- Matching V200 RPN behavior
  --
  ["(-)"]           = {Sym.NEGATE,15,1,-1},
  [Sym.NEGATE]      = {nil,     15, 1, -1},
  --
  ["&"]             = {nil,     14, 2,  0},
  --
  ["*"]             = {nil,     13, 2,  0},
  ["/"]             = {nil,     13, 2,  0, 'l'},
  --
  ["+"]             = {nil,     12, 2,  0},
  ["-"]             = {nil,     12, 2,  0, 'l'},
  --
  ["="]             = {nil,     11, 2,  0, 'r'},
  [Sym.NEQ]         = {nil,     11, 2,  0, 'r'},
  ["/="]            = {Sym.NEQ, 11, 2,  0, 'r'},
  ["<"]             = {nil,     11, 2,  0, 'r'},
  [">"]             = {nil,     11, 2,  0, 'r'},
  [Sym.LEQ]         = {nil,     11, 2,  0, 'r'},
  ["<="]            = {Sym.LEQ, 11, 2,  0, 'r'},
  [Sym.GEQ]         = {nil,     11, 2,  0, 'r'},
  [">="]            = {Sym.GEQ, 11, 2,  0, 'r'},
  --
  ["not"]           = {"not ",  10, 1, -1},
  ["and"]           = {" and ", 10, 2,  0},
  ["or"]            = {" or ",  10, 2,  0},
  --
  ["xor"]           = {" xor ",  9, 2,  0},
  ["nor"]           = {" nor ",  9, 2,  0},
  ["nand"]          = {" nand ", 9, 2,  0},
  --
  [Sym.LIMP]        = {nil,      8, 2,  0, 'r'},
  ["=>"]            = {Sym.LIMP, 8, 2,  0, 'r'},
  --
  [Sym.DLIMP]       = {nil,      7, 2,  0, 'r'},
  ["<=>"]           = {Sym.DLIMP,7, 2,  0, 'r'},
  --
  ["|"]             = {nil,      6, 2,  0},
  --
  [Sym.STORE]       = {nil,      5, 2,  0, 'r'},
  ["=:"]            = {Sym.STORE,5, 2,  0, 'r'},
  [":="]            = {nil,      5, 2,  0, 'r'},

  [Sym.CONVERT]     = {nil, 1, 2, 0},
  ["@>"]            = {Sym.CONVERT, 1, 2,  0}
}
local operators_trie = Trie.build(operators)

-- Query operator information
---comment
---@param s string  Name of the operator
---@return string | nil  Name
---@return number        Precedence
---@return number        Arguments
---@return number        Side
---@return number        Associativity
---@return boolean       Aggressive
local function queryOperatorInfo(s)
  local tab = operators[s]
  if tab == nil then return nil end

  local str, lvl, args, side, assoc, aggro = unpack(tab)
  return (str or s), lvl, args, side, assoc, aggro
end

-- Returns the number of arguments for the nspire function `nam`.
-- Implementation is hacky, but there seems to be no clean way of
-- getting this information.
---@param nam string   Function name
---@return number | nil
local function tiGetFnArgs(nam)
  local res, err = math.evalStr('getType('..nam..')')
  if err ~= nil or res ~= '"FUNC"' then
    return nil
  end

  local argc = 0
  local arglist = nil
  for _ = 0, 10 do
    res, err = math.evalStr("string("..nam.."("..(arglist or '').."))")
    if err == nil or err == 210 then
      return argc
    elseif err == 930 then
      argc = argc + 1
    else
      return nil
    end

    if arglist then
      arglist = arglist .. ",x"
    else
      arglist = "x"
    end
  end
  return nil
end

-- n: Number of args (max)
-- min: Min number of args
-- conv: Conversion function (@>...)
local functions = {
  ["abs"]             = {n = 1},
  ["amorttbl"]        = {n = 10, min = 4},
  ["angle"]           = {n = 1},
  ["approx"]          = {n = 1},
  ["approxfraction"]  = {n = 1, min = 0, conv = true},
  ["approxrational"]  = {n = 2, min = 1},
  ["arccos"]          = {n = 1},
  ["arccosh"]         = {n = 1},
  ["arccot"]          = {n = 1},
  ["arccoth"]         = {n = 1},
  ["arccsc"]          = {n = 1},
  ["arccsch"]         = {n = 1},
  ["arclen"]          = {n = 4},
  ["arcsec"]          = {n = 1},
  ["arcsech"]         = {n = 1},
  ["arcsin"]          = {n = 1},
  ["arcsinh"]         = {n = 1},
  ["arctan"]          = {n = 1},
  ["arctanh"]         = {n = 1},
  ["augment"]         = {n = 2},
  ["avgrc"]           = {n = 3, min = 2},
  ["bal"]             = {{n = 10, min = 4},
                         {n = 2}},
  ["binomcdf"]        = {{n = 5},
                         {n = 3},
                         {n = 2}},
  ["binompdf"]        = {{n = 2},
                         {n = 3}},
  ["ceiling"]         = {n = 1},
  ["centraldiff"]     = {n = 3, min = 2},
  ["cfactor"]         = {n = 2, min = 1},
  ["char"]            = {n = 1},
  ["charpoly"]        = {n = 2},
  ["colaugment"]      = {n = 2},
  ["coldim"]          = {n = 1},
  ["colnorm"]         = {n = 1},
  ["comdenom"]        = {n = 2, min = 1},
  ["completesquare"]  = {n = 2},
  ["conj"]            = {n = 1},
  ["constructmat"]    = {n = 5},
  ["corrmat"]         = {n = 20, min = 2},
  ["cos"]             = {n = 1},
  ["cos"..Sym.POWN1]  = {n = 1},
  ["cosh"]            = {n = 1},
  ["cosh"..Sym.POWN1] = {n = 1},
  ["cot"]             = {n = 1},
  ["cot"..Sym.POWN1]  = {n = 1},
  ["coth"]            = {n = 1},
  ["coth"..Sym.POWN1] = {n = 1},
  ["count"]           = {min = 1},
  ["countif"]         = {n = 2},
  ["cpolyroots"]      = {{n = 1},
                         {n = 2}},
  ["crossp"]          = {n = 2},
  ["csc"]             = {n = 1},
  ["csc"..Sym.POWN1]  = {n = 1},
  ["csch"]            = {n = 1},
  ["csch"..Sym.POWN1] = {n = 1},
  ["csolve"]          = {{n = 2},
                         {min = 3}},
  ["cumulativesum"]   = {n = 1},
  ["czeros"]          = {n = 2},
  ["dbd"]             = {n = 2},
  ["deltalist"]       = {n = 1},
  ["deltatmpcnv"]     = {n = 2}, -- FIXME: Check n
  ["delvoid"]         = {n = 1},
  ["derivative"]      = {n = 2}, -- FIXME: Check n
  ["desolve"]         = {n = 3},
  ["det"]             = {n = 2, min = 1},
  ["diag"]            = {n = 1},
  ["dim"]             = {n = 1},
  ["domain"]          = {n = 2},
  ["dominantterm"]    = {n = 3, min = 2},
  ["dotp"]            = {n = 2},
  --["e^"]              = {n = 1},
  ["eff"]             = {n = 2},
  ["eigvc"]           = {n = 1},
  ["eigvl"]           = {n = 1},
  ["euler"]           = {n = 7, min = 6},
  ["exact"]           = {n = 2, min = 1},
  ["exp"]             = {n = 1},
  ["expand"]          = {n = 2, min = 1},
  ["expr"]            = {n = 1},
  ["factor"]          = {n = 2, min = 1},
  ["floor"]           = {n = 1},
  ["fmax"]            = {n = 4, min = 2},
  ["fmin"]            = {n = 4, min = 2},
  ["format"]          = {n = 2, min = 1},
  ["fpart"]           = {n = 1},
  ["frequency"]       = {n = 2},
  ["gcd"]             = {n = 2},
  ["geomcdf"]         = {n = 3, min = 2},
  ["geompdf"]         = {n = 2},
  ["getdenom"]        = {n = 1},
  ["getlanginfo"]     = {n = 0},
  ["getlockinfo"]     = {n = 1},
  ["getmode"]         = {n = 1},
  ["getnum"]          = {n = 1},
  ["gettype"]         = {n = 1},
  ["getvarinfo"]      = {n = 1, min = 0},
  ["identity"]        = {n = 1},
  ["iffn"]            = {n = 4, min = 2},
  ["imag"]            = {n = 1},
  ["impdif"]          = {n = 4, min = 3},
  ["instring"]        = {n = 3, min = 2},
  ["int"]             = {n = 1},
  ["integral"]        = {n = 2},
  ["intdiv"]          = {n = 2},
  ["interpolate"]     = {n = 4},
  --["invx^2"]          = {n = 1},
  --["invf"]            = {n = 1},
  ["invnorm"]         = {n = 3, min = 2},
  ["invt"]            = {n = 2},
  ["ipart"]           = {n = 1},
  ["irr"]             = {n = 3, min = 2},
  ["isprime"]         = {n = 1},
  ["isvoid"]          = {n = 1},
  ["lcm"]             = {n = 2},
  ["left"]            = {n = 2, min = 1},
  ["libshortcut"]     = {n = 3, min = 2},
  ["limit"]           = {n = 4, min = 3},
  ["lim"]             = {n = 4, min = 3, def = 4},
  ["linsolve"]        = {n = 2},
  ["ln"]              = {n = 1},
  ["log"]             = {n = 2, min = 1, def = 2},
  ["max"]             = {n = 2},
  ["mean"]            = {n = 2},
  ["median"]          = {n = 2, min = 1},
  ["mid"]             = {n = 3, min = 2},
  ["min"]             = {n = 2},
  ["mirr"]            = {n = 5, min = 4},
  ["mod"]             = {n = 2},
  ["mrow"]            = {n = 3},
  ["mrowadd"]         = {n = 4},
  ["ncr"]             = {n = 2},
  ["nderivative"]     = {n = 3, min = 2},
  ["newlist"]         = {n = 1},
  ["newmat"]          = {n = 2},
  ["nfmax"]           = {n = 4, min = 2},
  ["nfmin"]           = {n = 4, min = 2},
  ["nint"]            = {n = 4},
  ["nom"]             = {n = 2},
  ["norm"]            = {n = 1},
  ["normalline"]      = {n = 3, min = 2},
  ["normcdf"]         = {n = 4, min = 2},
  ["normpdf"]         = {n = 3, min = 1},
  ["npr"]             = {n = 2},
  ["pnv"]             = {n = 4, min = 3},
  ["nsolve"]          = {n = 4, min = 2},
  ["ord"]             = {n = 1},
  ["piecewise"]       = {min = 1},
  ["poisscdf"]        = {n = 3, min = 2},
  ["poisspdf"]        = {n = 2},
  ["polycoeffs"]      = {n = 2, min = 1},
  ["polydegree"]      = {n = 2, min = 1},
  ["polyeval"]        = {n = 2},
  ["polygcd"]         = {n = 2},
  ["polyquotient"]    = {n = 3, min = 2},
  ["polyremainder"]   = {n = 3, min = 2},
  ["polyroots"]       = {n = 2, min = 1},
  ["prodseq"]         = {n = 4}, -- FIXME: Check n
  ["product"]         = {n = 3, min = 0},
  ["propfrac"]        = {n = 2, min = 1},
  ["rand"]            = {n = 1, min = 0},
  ["randbin"]         = {n = 3, min = 2},
  ["randint"]         = {n = 3, min = 2},
  ["randmat"]         = {n = 2},
  ["randnorm"]        = {n = 3, min = 2},
  ["randsamp"]        = {n = 3, min = 2},
  ["real"]            = {n = 1},
  ["ref"]             = {n = 2, min = 1},
  ["remain"]          = {n = 2},
  ["right"]           = {n = 2, min = 1},
  ["rk23"]            = {n = 7, min = 6},
  ["root"]            = {n = 2, min = 1, def = 2},
  ["rotate"]          = {n = 2, min = 1},
  ["round"]           = {n = 2, min = 1},
  ["rowadd"]          = {n = 3},
  ["rowdim"]          = {n = 1},
  ["rownorm"]         = {n = 1},
  ["rowswap"]         = {n = 3},
  ["rref"]            = {n = 2, min = 1},
  ["sec"]             = {n = 1},
  ["sec"..Sym.POWN1]  = {n = 1},
  ["sech"]            = {n = 1},
  ["sech"..Sym.POWN1] = {n = 1},
  ["seq"]             = {n = 5, min = 4},
  ["seqgen"]          = {n = 7, min = 4},
  ["seqn"]            = {n = 4, min = 1},
  ["series"]          = {n = 4, min = 3},
  ["setmode"]         = {n = 2, min = 1},
  ["shift"]           = {n = 2, min = 1},
  ["sign"]            = {n = 1},
  ["simult"]          = {n = 3, min = 2},
  ["sin"]             = {n = 1},
  ["sin"..Sym.POWN1]  = {n = 1},
  ["sinh"]            = {n = 1},
  ["sinh"..Sym.POWN1] = {n = 1},
  ["solve"]           = {n = 2},
  ["sqrt"]            = {n = 1, pretty = Sym.ROOT},
  [Sym.ROOT]          = {n = 1},
  ["stdefpop"]        = {n = 2, min = 1},
  ["stdefsamp"]       = {n = 2, min = 1},
  ["string"]          = {n = 1},
  ["submat"]          = {n = 5, min = 1},
  ["sum"]             = {n = 3, min = 1},
  ["sumif"]           = {n = 3, min = 2},
  ["sumseq"]          = {n = 5, min = 4}, -- FIXME: Check n
  ["system"]          = {min = 1},
  ["tan"]             = {n = 1},
  ["tan"..Sym.POWN1]  = {n = 1},
  ["tangentline"]     = {n = 3, min = 2},
  ["tanh"]            = {n = 1},
  ["tanh"..Sym.POWN1] = {n = 1},
  ["taylor"]          = {n = 4, min = 3},
  ["tcdf"]            = {n = 3},
  ["tcollect"]        = {n = 1},
  ["texpand"]         = {n = 1},
  ["tmpcnv"]          = {n = 2},
  ["tpdf"]            = {n = 2},
  ["trace"]           = {n = 1},
  ["tvmfv"]           = {n = 7, min = 4},
  ["tvml"]            = {n = 7, min = 4},
  ["tvmn"]            = {n = 7, min = 4},
  ["tvmpmt"]          = {n = 7, min = 4},
  ["tvmpv"]           = {n = 7, min = 4},
  ["unitv"]           = {n = 1},
  ["varpop"]          = {n = 2, min = 1},
  ["varsamp"]         = {n = 2, min = 1},
  ["warncodes"]       = {n = 2},
  ["when"]            = {n = 4, min = 2},
  ["zeros"]           = {n = 2},
  -- Stat Functions
  ["linregmx"]        = {n = 2, statfn = true},
  ["quadreg"]         = {n = 2, statfn = true},
  ["quartreg"]        = {n = 2, statfn = true},
}

-- Returns information about the function with the name given
---@param s string             Name of the function
---@param builtinOnly boolean  If true, do not consider user defined functions
---@return table<string, number> | nil
local function functionInfo(s, builtinOnly)
  local name, argc = s:lower(), nil

  if name:find('^%d') then
    return nil
  end

  local info = functions[name]
  if info then
    if not argc then
      if #info > 1 then -- Overloaded function
        for _,v in ipairs(info) do -- Take first default
          if v.def then
            argc = v.def
            break
          end
        end
        if not argc then -- Take first overload
          argc = info[1].min or info[1].n
        end
      else
        if info.def then
          argc = info.def
        else
          argc = info.min
        end

        argc = argc or info.n
      end
    end

    return info.pretty or name, argc, info.statfn
  end

  -- User function
  if builtinOnly == false then
    argc = tiGetFnArgs(s)
    if argc ~= nil then
      return s, argc
    end
  end

  return nil
end

local errorCodes = {
  [10]  = "Function did not return a value",
  [20]  = "Test did not resolve to true or false",
  [40]  = "Argument error",
  [50]  = "Argument missmatch",
  [60]  = "Argument must be a bool or int",
  [70]  = "Argument must be a decimal",
  [90]  = "Argument must be a list",
  [100] = "Argument must be a matrix",
  [130] = "Argument must be a string",
  [140] = "Argument must be a variable name",
  [160] = "Argument must be an expression",
  [180] = "Break",
  [230] = "Dimension",
  [235] = "Dimension error",
  [250] = "Divide by zero",
  [260] = "Domain error",
  [270] = "Duplicate variable name",
  [300] = "Expected 2 or 3-element list or matrix",
  [310] = "Argument must be an equation with a single var",
  [320] = "First argument must be an equation",
  [345] = "Inconsistent units",
  [350] = "Index out of range",
  [360] = "Indirection string is not a valid var name",
  [380] = "Undefined ANS",
  [390] = "Invalid assignment",
  [400] = "Invalid assignment value",
  [410] = "Invalid command",
  [430] = "Invalid for current mode settings",
  [435] = "Invalid guess",
  [440] = "Invalid implied mulitply",
  [565] = "Invalid outside programm",
  [570] = "Invalid pathname",
  [575] = "Invalid polar complex",
  [580] = "Invalid programm reference",
  [600] = "Invalid table",
  [605] = "Invalid use of units",
  [610] = "Invalid variable name or local statement",
  [620] = "Invalid variable or function name",
  [630] = "Invalid variable reference",
  [640] = "Invalid vector syntax",
  [670] = "Low memory",
  [672] = "Resource exhaustion",
  [673] = "Resource exhaustion",
  [680] = "Missing (",
  [690] = "Missing )",
  [700] = "Missing *",
  [710] = "Missing [",
  [720] = "Missing ]",
  [750] = "Name is not a function or program",
  [780] = "No solution found",
  [800] = "Non-real result",
  [830] = "Overflow",
  [860] = "Recursion too deep",
  [870] = "Reserved name or system variable",
  [900] = "Argument error",
  [910] = "Syntax error",
  [920] = "Text ont found",
  [930] = "Too few arguments",
  [940] = "Too many arguments",
  [950] = "Too many subscripts",
  [955] = "Too many undefined variables",
  [960] = "Variable is not defined",
  -- TODO: ...
}


--[[
  Interactive Session Stack

  Capsules an coroutine for representing an interactive function.
  Only one interactive function can be active at the same time.
]]--
local interactiveStack = {}
local function interactive_get()
  for i=#interactiveStack,1,-1 do
    if interactiveStack[i] and coroutine.status(interactiveStack[i]) ~= 'dead' then
      return interactiveStack[i]
    end
    table.remove(interactiveStack, i)
  end
end

local function interactive_start(fn)
  table.insert(interactiveStack, coroutine.create(fn))
  coroutine.resume(interactive_get())
  print('info: Started interactive #' .. (#interactiveStack))
end

local function interactive_resume()
  local co = interactive_get()
  if co then
    coroutine.resume(co)
  end
end

local function interactive_yield()
  local co = interactive_get()
  if co then
    coroutine.yield(co)
  end
end

local function interactive_kill()
  table.remove(interactiveStack)
end

-- Helper function for using `input_ask_value` in an interactive session.
---@param widget UIInput     Input widget
---@param onEnter function   Callback called if the user presses enter
---@param onCancel function  Callback called if the user canceled the request
---@param onSetup function   Callback called to set up the view
local function interactive_input_ask_value(widget, onEnter, onCancel, onSetup)
  input_ask_value(widget, function(value)
    if onEnter then onEnter(value) end
    interactive_resume()
  end, function()
    if onCancel then onCancel() end
    interactive_kill()
  end, function(init_widget)
    if onSetup then onSetup(init_widget) end
  end)
  interactive_yield()
end


-- Macro
---@class Macro
---@field steps string[]
Macro = class()
function Macro:init(steps)
  self.steps = steps or {}
end

function Macro:execute()
  Undo.record_undo()

  local stackTop = StackView:size()

  local function clrbot(n)
    n = tonumber(n)
    for i=StackView:size() -n,stackTop+1,-1 do
      StackView:pop(i)
    end
  end

  local function exec_step(step)
    if step:find('^@%a+') then
      step = step:usub(2)
      local tokens = step:split(':')
      local cmd = tokens[1]

      local function numarg(n, def)
        n = n + 1
        return tokens >= n and tonumber(tokens[n]) or def
      end

      if cmd == 'clrbot' then
        -- Clear all but top n args
        clrbot(tokens[2] or 1)
      elseif cmd == 'dup' then
        StackView:dup(numarg(1, 1))
      elseif cmd == 'simp' then
        StackView:pushInfix(StackView:pop().result)
      elseif cmd == 'label' then
        if StackView:size() > 0 then
          StackView:top().label = tokens[2]
        end
      elseif cmd == 'input' then
        local prefix = tokens[2] or ''

        interactive_input_ask_value(InputView, function(value)
          StackView:pushInfix(value)
          interactive_resume()
        end, function()
          Undo.undo()
        end, function(widget)
          widget:setText('', prefix)
        end)
      end
    else
      StackView:pushInfix(step)
    end

    return true
  end

  return interactive_start(function()
    for _,v in ipairs(self.steps) do
      if not exec_step(v) then
        Undo.undo()
        break
      end
    end
    platform.window:invalidate()
  end)
end


-- Returns a list of {var, formula} to solve in order to solve for wanted variables
---@param category table      Formula category table
---@param want_var string[]   Variable name(s) [string or table]
---@param have_vars string[]  List of {var, value} pairs
---@return table<string, string>
local function build_formula_solve_queue(category, want_var, have_vars)
  local var_to_formula = {}

  if type(want_var) == 'string' then
    want_var = {want_var}
  end

  -- Insert all given arguments as pseudo formulas
  for _,v in ipairs(have_vars) do
    local name, value = unpack(v)
    var_to_formula[name:lower()] = Formula(name .. '=' .. value, {})
  end

  -- Returns a variable name the formula is solvable for
  -- with the current set of known variables
  local function get_solvable_for(formula)
    local missing = nil
    for _,v in ipairs(formula.variables) do
      if not var_to_formula[v:lower()] then
        if missing then
          return nil
        end
        missing = v:lower()
      end
    end
    return missing
  end

  for _=1,50 do -- Artificial search limit
    local found = false
    for _,v in ipairs(category.formulas) do
      local var = get_solvable_for(v)
      if var then
        var_to_formula[var] = v
        found = true
      end
    end
    if not found then
      break
    end
  end

  -- Build list of formulas that need to be solved
  local solve_queue = {}

  local function add_formula_to_queue(formula, solve_for)
    if not formula then return end

    -- Remove prev element
    for i,v in ipairs(solve_queue) do
      if v[1] == solve_for and v[2] == formula then
        table.remove(solve_queue, i)
        break
      end
    end

    -- Insert at top
    table.insert(solve_queue, 1, {solve_for, formula})

    for _,v in ipairs(formula.variables) do
      if v ~= solve_for then
        add_formula_to_queue(var_to_formula[v], v)
      end
    end
  end

  for _,v in ipairs(want_var) do
    print('info: adding wanted var ' .. v .. ' to queue')
    add_formula_to_queue(var_to_formula[v], v)
  end

  print('info: formula solve queue:')
  for idx,v in ipairs(solve_queue) do
    local solve_for, formula = unpack(v)
    print(string.format('  %02d %s', idx, solve_for ..  ' = ' .. formula:solve_symbolic(solve_for)))
  end

  return solve_queue
end

local function solve_formula_interactive(category)
  interactive_start(function()
    local var_in_use = {}
    local solve_for, solve_with = nil, {}

    local function interactive_ask_variable(prefix)
      local ret = ''

      local function complete_unset(comp_prefix)
        local candidates = {}
        for name,_ in pairs(category.variables) do
          if not var_in_use[name] then
            table.insert(candidates, name)
          end
        end

        return completion_catmatch(candidates, comp_prefix)
      end

      interactive_input_ask_value(InputView, function(value)
        if value == 'solve' or value:ulen() == 0 then
          ret = nil
        else
          ret = value
        end
      end, nil, function(widget)
        widget:setText('', prefix)
        widget.completionFun = complete_unset
      end)

      return ret
    end

    solve_for = interactive_ask_variable('Solve for:')
    if not solve_for then
      return
    end

    -- Solve for multiple
    if solve_for:find(',') then
      ---@diagnostic disable-next-line: undefined-field
      solve_for = string.split(solve_for, ',')
    else
      solve_for = {solve_for}
    end

    -- Mark as in use
    for _,v in ipairs(solve_for) do
      var_in_use[v] = true
    end

    while true do
      local set_var = interactive_ask_variable('Set [empty if done]:')
      if not set_var then
        break
      end

      local var_info = category.variables[set_var]
      interactive_input_ask_value(InputView, function(value)
        table.insert(solve_with, {set_var, value})
      end, nil, function(widget)
        -- Auto append the matching base unit for convenience
        local template = var_info.default or ''
        if var_info.unit then
          template = template .. '*_' .. var_info.unit
        end
        widget:setText(template, var_info[1] .. '=')
        widget:setCursor(0)
        --widget:selAll()
      end)

      -- Mark as set
      var_in_use[set_var] = true
    end

    local solve_queue = build_formula_solve_queue(category, solve_for, solve_with)
    if solve_queue then
      local infix_steps = {}
      for _,v in ipairs(solve_queue) do
        local var, formula = unpack(v)
        table.insert(infix_steps, {
          var = var,
          infix = tostring(formula:solve_symbolic(var):gsub('=', ':='))
        })
      end

      -- Remember user entered (non solved) variables
      local user_provided = {}
      for _, v in ipairs(solve_with) do
        user_provided[v[1]] = true
      end

      Undo.record_undo()
      for _,step in ipairs(infix_steps) do
        if step.var then
          math.evalStr('DelVar '..step.var)
        end
        if not StackView:pushInfix(step.infix) then
          Undo.undo()
          break
        end

        local var_info = category.variables[step.var]
        if var_info then
          -- Label expression with variable info and asterisk, if it is a solved expression
          StackView:top().label = var_info[1] .. ' (' .. step.var .. ')' ..
            (user_provided[step.var] and '' or '*')
        end
      end
    else
      Error.show('Can not solve')
      return
    end
  end)
end


-- Lexer for TI math expressions being as close to the original as possible
Infix = {}
function Infix.tokenize(input)
  local function operator(input, i)
    return Trie.find(input, operators_trie, i)
  end

  local function ans(input, i)
    return input:find('^(@[0-9]+)', i)
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
    return input:find('^(_[%a\128-\255]+)', i)
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
        if options.saneHexDigits and input:find('^[%a%.]', j+1) then
          return nil
        end
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
      -- Normal number
      i, j, token = input:find('^(%d*%.?%d*)', pos)

      -- '.' is not a number
      if i and (token == '' or token == '.') then i = nil end

      -- SCI notation exponent
      if i then
        local ei, ej, etoken = input:find('^('..Sym.EE..'[%-%+]?%d+)', j+1)
        if not ei then
          -- Sym.NEGATE is a multibyte char, so we can not put it into the char-class above
          ei, ej, etoken = input:find('^('..Sym.EE..Sym.NEGATE..'%d+)', j+1)
        end
        if ei then
          j, token = ej, token..etoken
        end
      end

      -- Fail if followed by additional digit or point
      if input:find('^[%d%.]', j+1) then
        return nil
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

  -- TODO: Move this elsewhere!
  local function isImplicitMultiplication(token, kind, top)
    if not top then return false end

    if kind == 'operator' or
       top[2] == 'operator' then
       return false
    end

    -- 1(...)
    if (token == '(' or token == '{') and
       (top[2] == 'number' or top[2] == 'unit' or top[2] == 'string' or top[1] == ')') then
      return true
    end

    -- 1[...]
    if token == '[' and
      (top[2] == 'number' or top[2] == 'unit') then
      return true
    end

    -- (...)1
    if kind ~= 'syntax' then
      if top[2] ~= 'syntax' or top[1] == ')' or top[1] == '}' or top[1] == ']' then
        return true
      end
    end
  end

  ---@alias TokenKind "number"|"word"|"function"|"syntax"|"operator"|"string"|"ans"|"ws"|"unit"
  ---@alias TokenPair table<string, TokenKind>
  local matcher = {
    {fn=operator,   kind='operator'},
    {fn=syntax,     kind='syntax'},
    {fn=ans,        kind='ans'},
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
          if isImplicitMultiplication(token, m.kind, tokens[#tokens]) then
            table.insert(tokens, {'*', 'operator'})
          end
          if token == '(' and #tokens > 0 and tokens[#tokens][2] == 'word' then
            tokens[#tokens][2] = 'function'
          end
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


-- Expression tree
---@class ExpressionTree
---@field root table  Root node
ExpressionTree = class()
function ExpressionTree:init(root)
  self.root = root
end

function ExpressionTree:debug_print()
  local function print_node_recursive(node, level)
    level = level or 0
    local indent = string.rep('  ', level)
    print(string.format('%s%s (%s)', indent, node.text, node.kind:sub(1, 1)))

    if node.children then
      for _, child in ipairs(node.children) do
        print_node_recursive(child, level + 1)
      end
    end
  end

  print_node_recursive(self.root)
end

-- Converts the node tree to an infix representation
---@return string infix  Infix string
function ExpressionTree:infix_string()
  local function node_to_infix(node)
    if node.kind == 'operator' then
      local name, prec, _, side, assoc, aggr_assoc = queryOperatorInfo(node.text)
      assoc = assoc == 'r' and 2 or (assoc == 'l' and 1 or 0)

      local str = nil
      for idx, operand in ipairs(node.children) do
        if str and side == 0 then str = str .. name end
        str = str or ''
        if operand.kind == 'operator' then
          local _, operand_prec = queryOperatorInfo(operand.text)
          if (operand_prec < prec) or ((aggr_assoc or idx ~= assoc) and operand_prec < prec + (assoc ~= 0 and 1 or 0)) then
            --[[
            print('DEBUG')
            print('child prec: '..operand_prec)
            print('my    prec: '..prec)
            print('my   assoc: '..assoc)
            print('my     idx: '..idx)
            ]]
            str = str .. '(' .. node_to_infix(operand) .. ')'
          else
            str = str .. node_to_infix(operand)
          end
        else
          str = str .. node_to_infix(operand)
        end
      end

      if side < 0 then str = name .. str end
      if side > 0 then str = str .. name end
      return str
    elseif node.kind == 'function' then
      return node.text .. '(' ..
        table.join_str(node.children, ',', node_to_infix) ..
        ')'
    elseif node.kind == 'stat_function' then
      return node.text .. ' ' ..
        table.join_str(node.children, ',', node_to_infix)
    elseif node.kind == 'syntax' then
      assert(node.text == '{' or node.text == '[')
      if node.text == '{' then
        return node.text ..
          table.join_str(node.children, ',', node_to_infix) ..
          ParenPairs[node.text][1]
      elseif node.text == '[' then
        return node.text ..
          table.join_str(node.children, node.matrix and '' or ',', node_to_infix) ..
          ParenPairs[node.text][1]
      end
    else
      if node.kind == 'number' and node.text:sub(1, 1) == '-' then
        return Sym.NEGATE .. node.text:sub(2)
      end
      return node.text
    end
  end

  local ok, res = pcall(function()
    return node_to_infix(self.root)
  end)

  if not ok then
    Error.show(res)
    return nil
  end

  return res
end

-- Helper function returning true if `node` is a relational operator
local function node_is_rel_operator(node)
  if node.kind == 'operator' then
    return node.text == '=' or node.text == '<' or node.text == '>' or
           node.text == '/=' or node.text == Sym.NEQ or node.text == Sym.LEQ or
           node.text == Sym.GEQ
  end
end

-- Construct a node
---@param text string
---@param kind TokenKind
---@param children table
---@return table node
function ExpressionTree.make_node(text, kind, children)
  return {text = text, kind = kind, children = children}
end

-- Construct an ExpressionTree from a list of tokens
---@param tokens table  List of tokens
function ExpressionTree.from_infix(tokens)
  assert(type(tokens) == 'table')

  local stack = {}
  local target_stack = {{}}
  local nodes = target_stack[#target_stack]

  local function begin_target(node)
    node.children = node.children or {}
    table.insert(target_stack, node.children)
    nodes = target_stack[#target_stack]
  end

  local function end_target()
    if #target_stack <= 1 then
      error('Tried popping last stack entry')
    end
    table.remove(target_stack)
    nodes = target_stack[#target_stack]
  end

  local function stack_top()
    return #stack > 0 and stack[#stack] or nil
  end

  -- Copy node from stack to result
  local function copy_stack_node()
    local node = stack_top()
    table.insert(nodes, node)
  end

  -- Push new node to result
  ---@param text string     Text value
  ---@param kind TokenKind  Kind
  ---@param argc number     Number of arguments to consume
  local function push_node(text, kind, argc)
    argc = argc or 0
    local node = ExpressionTree.make_node(text, kind, argc > 0 and {} or nil)
    for _=0, argc-1 do
      table.insert(node.children, 1, table.remove(nodes))
    end
    table.insert(nodes, node)
  end

  local function apply_stack_operator()
    assert(#stack > 0)
    local node = table.remove(stack)
    assert(node.kind == 'operator')
    local _, _, argc = queryOperatorInfo(node.text)
    push_node(node.text, node.kind, argc)
  end

  for _, token_tuple in ipairs(tokens) do
    local text, kind = unpack(token_tuple)
    if kind == 'number' or kind == 'word' or kind == 'string' or kind == 'unit' then
      push_node(text, kind)
    end

    if kind == 'ans' then
      local stack_n = tonumber(text:sub(2))
      if stack_n then
        if not Error.assertStackN(stack_n) then
          error('Too few arguments on stack')
        end
      end

      table.insert(nodes, _G.StackView.stack[#_G.StackView.stack - stack_n + 1].rpn)
    end

    if kind == 'operator' then
      local _, prec, _, _, assoc = queryOperatorInfo(text)

      while stack_top() and stack_top().kind == 'operator' do
        local _, top_prec, _, _, _ = queryOperatorInfo(stack_top().text)
        if (assoc ~= 'r' and prec <= top_prec) or
           (assoc == 'r' and prec < top_prec) then
          apply_stack_operator()
        else
          break
        end
      end

      table.insert(stack, ExpressionTree.make_node(text, kind))
    end

    if kind == 'function' then
      table.insert(stack, ExpressionTree.make_node(text, kind))
      begin_target(stack_top())
    end

    if kind == 'syntax' then
      if text == ',' then
        while stack_top().kind ~= 'syntax' do
          apply_stack_operator()
        end
      elseif text == '(' then
        table.insert(stack, ExpressionTree.make_node(text, kind))
      elseif text == '{' then
        table.insert(stack, ExpressionTree.make_node(text, kind))
        begin_target(stack_top())
      elseif text == '[' then
        -- Detect matrix row ([ inside [)
        if stack_top() and stack_top().text == '[' then
          stack_top().matrix = true -- HACK: Fix by separating lists/martices and subscripts
        end

        table.insert(stack, ExpressionTree.make_node(text, kind))
        begin_target(stack_top())
      elseif text == ')' or text == '}' or text == ']' then
        while stack_top().kind ~= 'syntax' do
          apply_stack_operator()
        end

        if stack_top().text ~= ParenPairs[text][1] then
          error('Missing ' .. ParenPairs[text][1])
        end

        if text == '}' or text == ']' then
          end_target()
          copy_stack_node()
        end
        table.remove(stack) -- Pop opening paren

        if text == ')' then
          if stack_top() and stack_top().kind == 'function' then
            end_target()
            copy_stack_node()
            table.remove(stack) -- Pop function name
          end
        end
      end
    end
  end

  while stack_top() and stack_top().kind == 'operator' do
    apply_stack_operator()
  end

  if #stack > 0 then
    error('Unprocessed tokens on stack')
  end

  if #nodes > 1 then
    error('Multiple root nodes')
  end

  return ExpressionTree(nodes[1])
end

-- Match node for a sub-expression
---@param subexpr ExpressionTree   Subexpression to match against
---@param limit? boolean           Limit to first match
---@param meta? boolean            Make words match anything
---@return table Matches           List of matches found
function ExpressionTree:find_subexpr(subexpr, limit, meta)
  local matches = {}
  local metavars = {}

  local function match_subtree_recurse(a, b)
    if b.kind == 'word' then
      if not metavars[b.text] then
        metavars[b.text] = a
        return true
      else
        return match_subtree_recurse(a, metavars[b.text])
      end
    end

    if a.kind == b.kind and a.text == b.text then
      if not a.children and not b.children then
        return true
      end

      if (a.children ~= nil) ~= (b.children ~= nil) or #a.children ~= #b.children then
        return false
      end

      for idx, child in ipairs(a.children or {}) do
        if not match_subtree_recurse(child, b.children[idx]) then
          return false
        end
      end

      return true
    end
  end

  local function find_subexpr_recurse(start, start_idx, a, b)
    if match_subtree_recurse(a, b) then
      table.insert(matches, {parent = start, index = start_idx, node = a})
      if limit then
        return true
      end
    end

    for idx, child in ipairs(a.children or {}) do
      if find_subexpr_recurse(a, idx, child, b) and limit then
        return
      end
    end
  end

  find_subexpr_recurse(nil, nil, self.root, subexpr.root or subexpr)
  if #matches > 0 then
    return matches, metavars
  end
end

-- Returns `true` if self does contain subexpr (at any level)
---@param subexpr ExpressionTree  Subexpression to search for
---@return boolean Result
function ExpressionTree:contains_subexpr(subexpr)
  return self:find_subexpr(subexpr, true)
end

-- Substitutes all word tokens that exist in `vars` with the
-- node stored in vars.
---@param vars  table  Mapping from identifier to node
function ExpressionTree:substitute_vars(vars)
  self:map_all(function(node)
    if node.kind == 'word' then
      local repl = vars[node.text]
      if repl then
        return table_clone(repl)
      end
    end
    return nil
  end)
  return self
end

-- Rewrite all occurances of `subexpr` in self with `with`, replacing all variables of `subexpr`
-- with their matched nodes.
---@param subexpr ExpressionTree  Expression to replace
---@param with    ExpressionTree  Expression to replace with
function ExpressionTree:rewrite_subexpr(subexpr, with)
  local target = self
  local matches, metavars = target:find_subexpr(subexpr, false, true)

  with = ExpressionTree(with.root or with):substitute_vars(metavars)
  for _, match in ipairs(matches or {}) do
    if match.parent then
      match.parent.children[match.index] = with.root or with
    else
      target.root = with.root or with
    end
  end
  return target
end

-- Returns the left side of the expression or the whole expression
function ExpressionTree:left()
  if node_is_rel_operator(self.root) then
    return ExpressionTree(self.root.children[1])
  else
    return self
  end
end

-- Returns the right side of the expression or the whole expression
function ExpressionTree:right()
  if node_is_rel_operator(self.root) then
    return ExpressionTree(self.root.children[2])
  end
end

-- Applies operator `op` to the expression, with arguments `arguments`.
---@param op string          Operator symbol
---@param arguments table[]  List of additional operator arguments (nodes) (besides self)
---@return ExpressionTree Self
function ExpressionTree:apply_operator(op, arguments)
  local apply_on_both_sides = {
    ['+'] = true, ['-'] = true, ['*'] = true, ['/'] = true, ['^'] = true, ['!'] = true, ['%'] = true, [Sym.NEGATE] = true
  }

  if node_is_rel_operator(self.root) and apply_on_both_sides[op] then
    self:map_level(function(node)
      return ExpressionTree(node):apply_operator(op, arguments).root
    end)
  else
    local operator = ExpressionTree.make_node(op, 'operator', table_clone(arguments))
    table.insert(operator.children, 1, self.root)
    self.root = operator
  end
  return self
end

-- Calls function for each argument at optional level `level`.
-- If the function returns a value, the visited node will be replaced by that.
---@param fn function     Callback (node, parent) : node?
---@param level? integer  Optional level
function ExpressionTree:map_level(fn, level)
  level = level or 1

  local function recursive_map_level(node, level_)
    if level_ == 1 then
      for idx, child in ipairs(node.children or {}) do
        local replace = fn(child, node)
        if replace then
          node.children[idx] = replace
        end
      end
    elseif node.children then
      for _, child in ipairs(node.children) do
        recursive_map_level(child, level_ - 1)
      end
    end
  end

  return recursive_map_level(self.root, level)
end

function ExpressionTree:map_all(fn)
  local function map_recursive(node)
    for idx, child in ipairs(node and node.children or {}) do
      local replace = fn(child, node)
      if replace then
        node.children[idx] = replace
      else
        map_recursive(child)
      end
    end
  end


  local replace = fn(self.root, nil)
  if replace then
    self.root = replace
  else
    map_recursive(self.root)
  end
  return self
end

--------------------------------------------------
--                     UI                       --
--------------------------------------------------

-- Toast Widget
UI.Toast = class(UI.Widget)
UI.Toast.font_size = 11
function UI.Toast:init(args)
  UI.Widget.init(self)
  args = args or {}
  self.location = args.location or 'top'
  self.margin = 4
  self.padding = 4
  self.text = nil
  self.style = args.style
end

function UI.Toast:frame()
  if not self.text or self.text:ulen() == 0 then
    return 0, 0, 0, 0
  end

  local x, y, w, h = 0, 0, platform.window:width(), platform.window:height()
  local textW, textH = 0, 0

  platform.withGC(function(gc)
    gc:setFont('sansserif', 'b', UI.Toast.font_size)
    textW = gc:getStringWidth(self.text)
    textH = gc:getStringHeight(self.text)
  end)

  x = x + w/2 - textW/2 - self.margin
  if self.location == 'center' then
    y = h/2 - textH/2 - self.margin -- Mid
  else
    y = self.padding -- Top location
  end

  w = textW + 2*self.margin
  h = textH + 2*self.margin

  return x, y, w, h
end

function UI.Toast:show(text)
  self:invalidate()
  self.text = text and tostring(text) or nil
  self:invalidate()
end

function UI.Toast:draw(gc)
  if not self.text then return end

  local x,y,w,h = self:frame()
  local isError = self.style == 'error'

  gc:clipRect("set", x, y, w, h)
  gc:setColorRGB(theme_val(isError and 'error_bg' or 'alt_bg'))
  gc:fillRect(x, y, w, h)
  gc:setColorRGB(theme_val('border_bg'))
  gc:drawRect(x, y, w-1, h-1)
  gc:setColorRGB(theme_val(isError and 'error_fg' or 'fg'))
  gc:setFont('sansserif', 'b', UI.Toast.font_size)
  gc:drawString(self.text, x + self.margin, y + self.margin)
  gc:clipRect("reset")
end


-- KeybindManager
---@class KeybindManager
---@field bindings table
---@field currentTab table
---@field currentSequence table
---@field onSequencechanged function
---@field onExec function
KeybindManager = class()
function KeybindManager:init()
  self.bindings = {}

  -- State
  self.currentTab = nil
  self.currentSequence = nil

  -- Callbacks
  self.onSequenceChanged = nil -- string({sequence})
  self.onExec = nil -- void(void)
end

function KeybindManager:resetSequence()
  self.currentTab = nil
  self.currentSequence = nil
  if self.onSequenceChanged then
    self.onSequenceChanged(self.currentSequence)
  end
end

function KeybindManager:setSequence(sequence, fn)
  local tab = self.bindings
  for idx, key in ipairs(sequence) do
    if idx == #sequence then break end
    if not tab[key] then
      tab[key] = {}
    end
    tab = tab[key]
  end

  tab[sequence[#sequence]] = fn
end

function KeybindManager:dispatchKey(key)
  self.currentSequence = self.currentSequence or {}
  table.insert(self.currentSequence, key)

  self.currentTab = self.currentTab or self.bindings

  if type(self.currentTab) == 'table' then
    -- Special case: Binding all number keys
    if not self.currentTab[key] then
      if key:find('^%d+$') then
        self.currentTab = self.currentTab['%d']
      else
        self.currentTab = self.currentTab[key]
      end
    else
      -- Default case
      self.currentTab = self.currentTab[key]
    end
  end

  -- Exit if not found
  if not self.currentTab then
    self:resetSequence()
    return false
  end

  -- Call binding
  if type(self.currentTab) == 'function' then
    if self.currentTab(self.currentSequence) == 'repeat' then
      self.currentTab = {[key] = self.currentTab}
    else
      self:resetSequence()
    end
    if self.onExec then
      self.onExec()
    end
    return true
  end

  -- Propagate sequence change
  if self.onSequenceChanged then
    self.onSequenceChanged(self.currentSequence)
  end

  return true
end

-- Fullscreen 9-tile menu which is navigated using the numpad
---@class UIMenu : UI.Widget
UIMenu = class(UI.Widget)
function UIMenu:init()
  UI.Widget.init(self)
  self.page = 0
  self.pageStack = {}
  self.items = {}
  self.filterString = nil
  self._visible = false
  self.parent = nil
  -- Style
  self.style = 'grid'
  -- Callbacks
  self.onSelect = nil -- void()
  self.onCancel = nil -- void()
end

function UIMenu:center(w, h)
  w = w or platform.window:width()
  h = h or platform.window:height()

  local margin = 4
  self._frame = {
    margin,
    margin,
    w - 2*margin,
    h - 2*margin
  }
end

function UIMenu:hide()
  if self.parent ~= nil then
    focus_view(self.parent)
  else
    focus_view(InputView)
  end
end

function UIMenu:present(parent, items, onSelect, onCancel)
  if parent == self then parent = nil end
  self.pageStack = {}
  self.filterString = nil
  self:pushPage(items or {})
  self.parent = parent
  self.onSelect = onSelect
  self.onCancel = onCancel
  focus_view(self)
  return self
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
  self._visible = true
end

function UIMenu:onLooseFocus()
  self._visible = false
end

function UIMenu:onTab()
  if #self.items > 9 then
    self.page = (self.page + 1) % math.floor(#self.items / 9)
    self:invalidate()
  end
end

function UIMenu:onArrowLeft()
  self:prevPage()
end

function UIMenu:onArrowRight()
  self:nextPage()
end

function UIMenu:onArrowUp()
  self:popPage()
end

function UIMenu:onArrowDown()
  self:popPage()
end

function UIMenu:onEscape()
  if #self.items ~= #self.origItems then
    self:onBackspace()
    return
  end
  if self.onCancel then self.onCancel() end
  self:hide()
end

function UIMenu:onClear()
  self.page = 0
  self.filterString = ''
  self.items = self.origItems
  self:invalidate()
end

function UIMenu:onBackspace()
  self.filterString = ''
  self.items = self.origItems
  self:invalidate()
end

function UIMenu:pushPage(page)
  if page then
    table.insert(self.pageStack, page)
    self.items = self.pageStack[#self.pageStack]
    self.origItems = self.items
    self.filterString = ''
    self:invalidate()
  end
end

function UIMenu:popPage()
  if #self.pageStack > 1 then
    table.remove(self.pageStack)
    self.items = self.pageStack[#self.pageStack]
    self.origItems = self.items
    self.filterString = ''
    self:invalidate()
  end
end

function UIMenu:onCharIn(c)
  if c:byte(1) >= 49 and c:byte(1) <= 57 then -- [1]-[9]
    local n = c:byte(1) - 49
    local row, col = 2 - math.floor(n / 3), n % 3
    local item = self.items[self.page * 9 + row * 3 + (col+1)]
    if not item then return end

    -- NOTE: The call order is _very_ important:
    --  1. Hide the menu
    --  2. Call the callback
    --  3. Execute the action
    -- Otherwise, presenting a new menu from the action sets the current pages callbacks
    --  which leads to strange behaviour.
    if type(item[2]) == "function" then
      self:hide()
      if self.onSelect then self.onSelect(item) end
      item[2]()
    elseif type(item[2]) == "table" then
      self:pushPage(item[2])
    elseif type(item[2]) == "string" then
      self:hide()
      if self.onSelect then self.onSelect(item) end
      InputView:insertText(item[2]) -- HACK
    end
  else
    self.filterString = self.filterString or ''
    if c == ' ' then
      self.filterString = self.filterString..'.*'
    elseif c:byte(1) >= 97 and c:byte(1) <= 122 then
      self.filterString = self.filterString..c:lower()
    end

    local function matchFn(title)
      if title:lower():find(self.filterString) then
        return true
      end
    end

    local filteredItems = {}
    for _,v in ipairs(self.origItems) do
      if matchFn(v[1]) then
        table.insert(filteredItems, v)
      end
    end

    self.items = filteredItems
    self:invalidate()
  end
end

function UIMenu:drawCell(gc, item, x, y, w ,h)
  local margin = 2
  x = x + margin
  y = y + margin
  w = w - 2*margin
  h = h - 2*margin

  if w < 0 or h < 0 then return end

  if item then
    gc:setColorRGB(theme_val('alt_bg'))
    gc:fillRect(x,y,w,h)
    gc:setColorRGB(theme_val('border_bg'))
    draw_rect_shadow(gc, x, y, w, h)
  else
    gc:setColorRGB(theme_val('row_bg'))
    gc:fillRect(x,y,w,h)
    gc:setColorRGB(theme_val('border_bg'))
    draw_rect_shadow(gc, x, y, w, h)
    return
  end

  gc:clipRect("set", x, y, w+1, h+1)

  local itemText = item[1] or ''
  local itemState = item.state

  local tw, th = gc:getStringWidth(itemText), gc:getStringHeight(itemText)
  local tx, ty = x + w/2 - tw/2, y + h/2 - th/2

  gc:setColorRGB(theme_val('fg'))
  gc:drawString(item[1], tx, ty)

  if itemState ~= nil then
    local iw, ih = w * 0.66, 4
    local ix, iy = x + w/2 - iw/2, y + h - ih - margin

    if itemState == true then
      gc:setColorRGB(theme_val('menu_active_bg'))
      gc:fillRect(ix,iy,iw,ih)
    end
    gc:setColorRGB(theme_val('border_bg'))
    gc:drawRect(ix, iy, iw, ih)
  end

  gc:clipRect("reset")
end

function UIMenu:_drawGrid(gc)
  local x, y, width, height = self:frame()
  local pageOffset = self.page * 9

  local cw, ch = width/3, height/3
  for row=1,3 do
    for col=1,3 do
      local cx, cy = x + cw*(col-1), y + ch*(row-1)
      self:drawCell(gc, self.items[pageOffset + (row-1)*3 + col] or nil, cx, cy, cw, ch)
    end
  end
end

function UIMenu:_drawList(gc)
  local x, y, width, height = self:frame()
  local pageOffset = self.page * 9

  local cw, ch = width, height/9
  for row=1,9 do
    local cx, cy = x, y + ch*(row-1)
    self:drawCell(gc, self.items[pageOffset + row] or nil, cx, cy, cw, ch)
  end
end

function UIMenu:draw(gc)
  if not self:visible() then
    return
  end

  gc:clipRect("set", self:frame())
  local ffamily, fstyle, fsize = gc:setFont('sansserif', 'r', 9)

  if self.style == 'grid' then
    self:_drawGrid(gc)
  else
    self:_drawList(gc)
  end

  gc:setFont(ffamily, fstyle, fsize)
  gc:clipRect("reset")
end

-- RPN stack view
---@class UIStack : UI.Widget
UIStack = class(UI.Widget)
function UIStack:init()
  UI.Widget.init(self)
  self.stack = {}
  -- View
  self.scrolly = 0
  -- Selection
  self.sel = nil
  -- Bindings
  self.kbd = KeybindManager()
  self:initBindings()
end

function UIStack:set_frame(x, y, w, h)
  UI.Widget.set_frame(self, x, y, w, h)
  self:scrollToIdx(self.sel)
end

function UIStack:initBindings()
  self.kbd.onExec = function()
    self:invalidate()
  end
  self.kbd:setSequence({"x"}, function()
    Undo.record_undo()
    self:pop(self.sel, false)
  end)
  self.kbd:setSequence({"backspace"}, function()
    Undo.record_undo()
    self:pop(self.sel, false)
    if #self.stack == 0 then
      focus_view(InputView)
    end
  end)
  self.kbd:setSequence({"clear"}, function()
    Undo.record_undo()
    self.stack = {}
    self:selectIdx()
    focus_view(InputView)
  end)
  self.kbd:setSequence({"enter"}, function()
    Undo.record_undo()
    self:push(table_clone(self.stack[self.sel]))
    self:selectIdx()
  end)
  self.kbd:setSequence({"="}, function()
    Undo.record_undo()
    self:pushExpression(ExpressionTree(self.stack[self.sel].rpn))
    self:selectIdx()
  end)
  self.kbd:setSequence({"left"}, function()
    self:roll(-1)
  end)
  self.kbd:setSequence({"right"}, function()
    self:roll(1)
  end)
  self.kbd:setSequence({"c", "left"}, function()
    InputView:setText(self.stack[self.sel].infix)
    focus_view(InputView)
  end)
  self.kbd:setSequence({"c", "right"}, function()
    InputView:setText(self.stack[self.sel].result)
    focus_view(InputView)
  end)
  self.kbd:setSequence({"i", "left"}, function()
    InputView:insertText(self.stack[self.sel].infix)
  end)
  self.kbd:setSequence({"i", "right"}, function()
    InputView:insertText(self.stack[self.sel].result)
  end)
  self.kbd:setSequence({"5"}, function()
    RichView:displayStackItem(self.sel)
  end)
  self.kbd:setSequence({"7"}, function()
    self:selectIdx(1)
  end)
  self.kbd:setSequence({"3"}, function()
    self:selectIdx(#self.stack)
  end)
end

function UIStack:evalStr(str)
  local res, err = math.evalStr(str)
  -- Ignore unknown-function errors (for allowing to define functions in RPN mode)
  if err and err == 750 then
    return str, nil
  end
  if err and err ~= 750 then
    Error.show(err)
    return nil
  end
  return res, err
end

function UIStack:size()
  return #self.stack
end

function UIStack:top()
  return #self.stack > 0 and self.stack[#self.stack] or nil
end

function UIStack:selectionOrTop()
  if current_focus == self and #self.stack then
    return self.stack[self.sel or #self.stack]
  end
  return self:top()
end

-- Push an infix expression (string) to the stack
---@param input string  Infix expression string
function UIStack:pushInfix(input)
  print("info: UIStack.pushInfix call with '"..input.."'")

  local tokens = Infix.tokenize(input)
  if not tokens then
    print("error: UIStack.pushInfix tokens is nil")
    return false
  end

  local expr = ExpressionTree.from_infix(tokens)
  if not expr then
    print("error: UIStack.pushInfix rpn is nil")
    return false
  end

  local infix = expr:infix_string()
  if not infix then
    print("error: UIStack.pushInfix infix is nil")
    return false
  end

  local res, err = self:evalStr(infix)
  if res then
    self:push({["rpn"]=expr.root, ["infix"]=infix, ["result"]=res or ("error: "..err)})
    return true
  end
  return false
end

function UIStack:pushExpression(expr)
  assert(expr)

  local infix = expr:infix_string()
  local res, err = self:evalStr(infix)
  if res then
    self:push({["rpn"]=expr.root, ["infix"]=infix, ["result"]=res or ("error: "..err)})
    return true
  end
  return false
end

function UIStack:push(item)
  if item then
    table.insert(self.stack, item)
    self:scrollToIdx()
    self:invalidate()
  else
    print("UIStack:push item is nil")
  end
end

function UIStack:swap(idx1, idx2)
  if #self.stack < 2 then return end

  idx1 = idx1 or (#self.stack - 1)
  idx2 = idx2 or #self.stack
  if idx1 <= #self.stack and idx2 <= #self.stack then
    local tmp = table_clone(self.stack[idx1])
    self.stack[idx1] = self.stack[idx2]
    self.stack[idx2] = tmp
  end
  self:invalidate()
end

-- Pop item at `idx` (or top) from the stack
-- Index 1 is at the bottom of the stack!
function UIStack:pop(idx, from_top)
  if from_top then
    idx = (#self.stack - idx + 1) or #self.stack
  else
    idx = idx or #self.stack
  end
  if idx <= 0 or idx > #self.stack then return end
  local v = table.remove(self.stack, idx)
  self:invalidate()
  return v
end

function UIStack:roll(n)
  if #self.stack < 2 then return end

  n = n or 1
  if n > 0 then
    for _ = 1, n do
      table.insert(self.stack, 1, table.remove(self.stack))
    end
  else
    for _ = 1, math.abs(n) do
      table.insert(self.stack, table.remove(self.stack, 1))
    end
  end
  self:invalidate()
end

function UIStack:dup(n)
  if #self.stack <= 0 then return end

  n = n or 1
  local idx = #self.stack - (n - 1)
  for i=1,n do
    table.insert(self.stack, table_clone(self.stack[idx + i - 1]))
  end
end

function UIStack:pick(n)
  n = n or 1
  local idx = #self.stack - (n - 1)
  table.insert(self.stack, table_clone(self.stack[idx]))
end

function UIStack:toList(n)
  if #self.stack <= 0 then return end

  if n == nil then
    n = tonumber(self:pop().result)
  end

  assert(type(n)=="number")
  assert(n >= 0)

  local new_list = ExpressionTree.make_node('{', 'syntax', {})

  local newTop = math.max(#StackView.stack - n + 1, 1)
  for _ = 1, n do
    local root = self:pop(newTop)
    if root then
      root = root.rpn
      if root.text == '{' then
        -- Join existing list
        for _, item in ipairs(root.children) do
          table.insert(new_list.children, item)
        end
      else
        table.insert(new_list.children, root)
      end
    end
  end

  return self:pushExpression(ExpressionTree(new_list))
end

function UIStack:toPostfix()
  if #self.stack <= 0 then return end
  local rpn = self:pop().rpn

  local str = ""
  for _,v in ipairs(rpn) do
    if str:len() > 0 then str = str .. " " end
    str = str .. v
  end
  str = '"' .. str .. '"'

  return self:pushExpression(ExpressionTree(ExpressionTree.make_node(str, 'string')))
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

  local x, y, w, _ = self:frame()
  for i = 1, idx-1 do
    y = y + platform.withGC(function(gc) return self:itemHeight(gc, i) end)
  end

  return x, y - self.scrolly, w, platform.withGC(function(gc) return self:itemHeight(gc, idx) end)
end

--[[ Navigation ]]--
function UIStack:selectIdx(idx)
  idx = idx or #self.stack
  self.sel = math.min(math.max(1, idx), #self.stack)
  self:scrollToIdx(self.sel)
  self:invalidate()
end

function UIStack:scrollToIdx(idx)
  idx = idx or #self.stack

  -- Get item frame
  local _, y, _, h = self:frame()
  local _, item_y, _, item_h = self:frameAtIdx(idx)
  local old_scroll = self.scrolly

  if item_y < 0 then
    self.scrolly = self.scrolly + item_y
  end

  if item_y + item_h >= y + h then
    self.scrolly = self.scrolly + (item_y + item_h) - (y + h)
  end

  if old_scroll ~= self.scrolly then
    self:invalidate()
  end
end

--[[ Events ]]--
function UIStack:onCopy()
  Clipboard.yank(self.stack[self.sel].infix)
end

function UIStack:onCut()
  Clipboard.yank(self.stack[self.sel].infix)
  self:pop(self.sel)
end

function UIStack:onArrowDown()
  if self.sel < #self.stack then
    self:selectIdx(self.sel + 1)
  else
    focus_view(InputView)
    self:scrollToIdx()
  end
end

function UIStack:onArrowUp()
  if self.sel > 1 then
    self:selectIdx(self.sel - 1)
  end
end

function UIStack:onEscape()
  self.kbd:resetSequence()
  focus_view(InputView)
end

function UIStack:onLooseFocus()
  self.kbd:resetSequence()
  self.sel = nil
end

function UIStack:onFocus()
  self.kbd:resetSequence()
  self:selectIdx()
end

function UIStack:itemHeight(gc, idx)
  -- TODO: Refactor und mit drawItem zusammen!
  local x,y,w,h = self:frame()
  local minDistance, margin = 12, 2
  local fringeSize = gc:getStringWidth("0")*math.floor(math.log10(#self.stack)+1)
  local fringeMargin = fringeSize + 3*margin
  local item = self.stack[idx]
  if not item then return 0 end
  local leftSize = {w = gc:getStringWidth(item.infix or ""), h = gc:getStringHeight(item.infix or "")}
  local rightSize = {w = gc:getStringWidth(item.result or ""), h = gc:getStringHeight(item.result or "")}

  local leftPos = {x = x + fringeMargin + margin,
                   y = 0}
  local rightPos = {x = x + w - margin - rightSize.w,
                    y = 0}

   if options.showExpr then
     if rightPos.x < leftPos.x + leftSize.w + minDistance then
       rightPos.y = leftPos.y + margin*2 + leftSize.h
     end
   end

   return rightPos.y + rightSize.h + margin
end

function UIStack:drawItem(gc, x, y, w, idx, item)
  local itemBG = {
    theme_val('row_bg'),
    theme_val('alt_bg'),
    theme_val('selection_bg')
  }

  local minDistance, margin = 12, 2

  local leftStr = item.label or item.infix or ''

  local leftSize = {w = gc:getStringWidth(leftStr or ""), h = gc:getStringHeight(leftStr or "")}
  local rightSize = {w = gc:getStringWidth(item.result or ""), h = gc:getStringHeight(item.result or "")}

  local fringeSize = gc:getStringWidth("0")*math.floor(math.log10(#self.stack)+1)
  local fringeMargin = options.showFringe and fringeSize + 3*margin or 0

  local leftPos = {x = x + fringeMargin + margin,
                   y = y}
  local rightPos = {x = x + w - margin - rightSize.w,
                    y = y}

  if rightPos.x < leftPos.x + leftSize.w + minDistance then
    rightPos.y = leftPos.y + margin*2 + leftSize.h
  end

  local itemHeight = rightPos.y - leftPos.y + rightSize.h + margin
  local isSelected = current_focus == self and self.sel ~= nil and self.sel == idx

  gc:clipRect("set", x, y, w, itemHeight)
  if isSelected then
    gc:setColorRGB(itemBG[3])
  else
    gc:setColorRGB(itemBG[(idx%2)+1])
  end

  gc:fillRect(x, y, w, itemHeight)

  -- Render fringe (stack number)
  local fringeX = 0
  if options.showFringe == true then
    gc:setColorRGB(itemBG[((idx+1)%2)+1])

    fringeX = x + fringeSize + 2*margin
    gc:drawLine(fringeX, y, fringeX, y + itemHeight)
    gc:setColorRGB(theme_val('fringe_fg'))
    gc:drawString(#self.stack - idx + 1, x + margin, y)

    gc:clipRect("set", fringeX-1, y, w, itemHeight)
  end

  -- Render expression and result
  gc:setColorRGB(theme_val(isSelected and 'selection_fg' or 'fg'))
  if not item.label then
    if options.showExpr == true then
      gc:drawString(item.infix or "", leftPos.x, leftPos.y)
      gc:drawString(item.result or "", rightPos.x, rightPos.y)
    else
      gc:drawString(item.result or "", leftPos.x, leftPos.y)
    end
  else
    local ffamily, fstyle, fsize = gc:setFont('serif', 'i', 11)
    gc:drawString(item.label, leftPos.x, leftPos.y)
    gc:setFont(ffamily, fstyle, fsize)

    gc:drawString(item.result or "", rightPos.x, rightPos.y)
  end

  -- Render overflow indicator
  if rightPos.x < fringeX + 1 then
    gc:setColorRGB(theme_val('cursor_bg'))
    gc:drawLine(fringeX, rightPos.y,
                fringeX, rightPos.y + rightSize.h)
  end

  gc:clipRect("reset")
  return itemHeight
end

function UIStack:draw(gc)
  local x, y, w, h = self:frame()
  local yoffset = y - self.scrolly

  gc:clipRect("set", x, y, w, h)

  if #self.stack == 0 and current_focus == self then
    gc:setColorRGB(theme_val('selection_bg'))
  else
    gc:setColorRGB(theme_val('bg'))
  end

  gc:fillRect(x,y,w,h)

  for idx, item in ipairs(self.stack) do
    yoffset = yoffset + self:drawItem(gc, x, yoffset, w, idx, item)
  end
  gc:clipRect("reset")
end


-- Text input widget
---@class UIInput : UI.Widget
UIInput = class(UI.Widget)
function UIInput:init(frame)
  UI.Widget.init(self, frame)
  self.text = ""
  self.cursor = {pos=0, size=0}
  self.scrollx = 0
  self.margin = 2
  -- Completion
  self.completionFun = nil   -- Current completion handler function
  self.completionIdx = nil   -- Current completion index
  self.completionList = nil  -- Current completion candidates
  self.completionMenu = nil  -- Current completion menu
  -- Prefix
  self.prefix = ""           -- Non-Editable prefix shown on the left
  -- Input
  self.inputHandler = RPNInput({
      text = function()
        return self.text
      end,
      set_text = function(text)
        self:setText(text)
      end,
      split = function()
        return self:split()
      end
  })
  self.kbd = KeybindManager()
  self:init_bindings()
  self:setText('', '')
  self:setCursor(0)
end

function UIInput.height()
  return platform.withGC(function(gc)
    gc:setFont('sansserif', 'r', 11)
    return gc:getStringHeight('A')
  end)
end

function UIInput:save_state()
  return table_copy_fields(self, {
    'text', 'prefix', 'cursor', 'scrollx', 'completionFun', 'completionIdx', 'completionList'})
end

function UIInput:restore_state(state)
  table_copy_fields(state, {
    'text', 'prefix', 'cursor', 'scrollx', 'completionFun', 'completionIdx', 'completionList'}, self)
  self:invalidate()
end

function UIInput:init_bindings()
  local function findNearestChr(chr, origin, direction)
    local byteOrigin = self.text:sub(1, origin):len()
    local pos = direction == 'left' and 1 or byteOrigin+1
    for _ = 1, self.text:len() do
      local newPos = self.text:find(chr, pos)
      if not newPos then
        return direction == 'left' and pos - 1 or nil
      end
      if direction == 'left' then
        if newPos >= pos and newPos < byteOrigin then
          pos = newPos + 1
        else
          return pos - 1
        end
      else
        return newPos - 1
      end
    end
  end

  self.kbd:setSequence({'G', '('}, function()
    local byteCursor = self.text:usub(1, self.cursor.pos):len()
    local left = findNearestChr('[%(%[%{,]', byteCursor, 'left')
    if left then
      self:setCursor(self.text:sub(1, left):ulen())
    end
  end)
  self.kbd:setSequence({'G', ')'}, function()
    local byteCursor = self.text:usub(1, self.cursor.pos + 1):len()
    local right = findNearestChr('[%)%]%},]', byteCursor, 'right')
    if right then
      self:setCursor(self.text:sub(1, right):ulen())
    end
  end)
  self.kbd:setSequence({'G', '.'}, function()
    local byteCursor = self.text:usub(1, self.cursor.pos + 1):len()
    local left = findNearestChr('[%(%[%{,]', byteCursor, 'left')
    local right = findNearestChr('[%)%]%},]', byteCursor, 'right')
    if left and right then
      self:setCursor(self.text:sub(1, left):ulen())
      self.cursor.size = self.text:sub(1, right):ulen() - self.cursor.pos
    end
  end)
  self.kbd:setSequence({'G', 'left'}, function()
    self:setCursor(0)
  end)
  self.kbd:setSequence({'G', 'right'}, function()
    self:setCursor(self.text:ulen())
  end)

  -- Special chars
  self.kbd:setSequence({'I', 'c'}, function()
    MenuView:present(InputView, {
      {'{', '{'}, {'=:', '=:'}, {'}', '}'},
      {'[', '['}, {'@>', '@>'}, {']', ']'},
      {'|', '|'}, {':=', ':='}, {'@', '@'},
    })
  end)

  -- Unit table
  self.kbd:setSequence({'I', 'u'}, function()
    local menu = UI.Menu()
    if units then
      for category, unit_pairs in pairs(units) do
        menu = menu:add(category)
        for _, unit in ipairs(unit_pairs) do
          menu:add(unit[2] or unit[1], function()
            self:insertText(unit[1])
          end)
        end
        menu = menu:add()
      end
    else
      menu:add("No Units")
    end

    self:open_menu(menu)
  end)

  -- Ans/Stack reference
  self.kbd:setSequence({'A', '%d'}, function(sequence)
    local n = tonumber(sequence[#sequence])
    if Error.assertStackN(n) then
      self:insertText('@'..sequence[#sequence])
    end
  end)

  local function eval_interactive(fn, args)
    local i = 1
    Undo.record_undo()

    local function handle_cancel()
      Undo.undo()
    end

    local function setup_arg(widget)
      local arg = args[i]
      if arg then
        widget:setText(arg.default, arg.prompt)
        widget:selAll()
      end
    end

    local function handle_arg(value)
      local arg = args[i]
      if arg then
        if value:find(',') then value = '{'..value..'}' end
        StackView:pushInfix(value)

        if i < #args then
          i = i + 1
          interactive_input_ask_value(InputView, handle_arg, handle_cancel, setup_arg)
          return
        elseif i == #args then
          if not self.inputHandler:dispatchFunction(fn) then
            handle_cancel()
          end
          self:clear()
        end
      end

      interactive_resume()
    end

    if args and #args >= 1 then
      interactive_input_ask_value(InputView, handle_arg, handle_cancel, setup_arg)
    else
      self.inputHandler:dispatchFunction(fn)
    end
  end

  ------------------------
  -- Interactive helper --
  ------------------------
  local function ia_solve()
    eval_interactive('solve', {{
      prompt = 'Solve for:', default = 'x'
    }})
  end

  local function ia_zeros()
    eval_interactive('zeros', {{
      prompt = 'Zeros for:', default = 'x'
    }})
  end

  local function ia_derivative()
    eval_interactive('derivative', {{
      prompt = 'Derivative for:', default = 'x'
    }})
  end

  local function ia_limit()
    eval_interactive('limit', {{
      prompt = 'Limit for:', default = 'x'
    }, {
      prompt = 'To:'
    }})
  end

  local function ia_seq()
    eval_interactive('seq', {{
      prompt = 'Index var:', default = 'x'
    }, {
      prompt = 'From:'
    }, {
      prompt = 'To:'
    }})
  end

  local function ia_sumseq()
    eval_interactive('sumseq', {{
      prompt = 'Summation var:', default = 'x'
    }, {
      prompt = 'From:'
    }, {
      prompt = 'To:'
    }})
  end

  local function ia_prodseq()
    eval_interactive('prodseq', {{
      prompt = 'Index var:', default = 'x'
    }, {
      prompt = 'From:'
    }, {
      prompt = 'To:'
    }})
  end

  local function ia_rewrite()
    if not StackView:top() then
      Error.show("Stack empty")
      return
    end

    local top = ExpressionTree(StackView:top().rpn)
    interactive_input_ask_value(InputView, function(search)
      interactive_input_ask_value(InputView, function(replace)
        local search_expr = ExpressionTree.from_infix(Infix.tokenize(search))
        local replace_expr = ExpressionTree.from_infix(Infix.tokenize(replace))
        if search_expr and replace_expr then
          Undo.record_undo()
          top:rewrite_subexpr(search_expr.root, replace_expr.root)
          StackView:pop()
          StackView:pushExpression(top)
        else
          Error.show("Error parsing expressions")
        end
      end, nil, function(widget)
        widget:setText('', 'Rewrite ' .. (search or '?') .. ' with:')
      end)
    end, nil, function(widget)
      widget:setText('', 'Rewrite rule:')
    end)
  end

  self.kbd:setSequence({'.', '%d'}, function(sequence)
    local n = tonumber(sequence[#sequence])
    self:insertText('.' .. n)
  end)
  self.kbd:setSequence({'.', '.'}, function()
    self:insertText('.')
  end)
  self.kbd:setSequence({'.', Sym.NEGATE}, function()
    self:insertText(Sym.INFTY)
  end)
  self.kbd:setSequence({'.', 's'}, function()
    ia_solve()
  end)
  self.kbd:setSequence({'.', 'z'}, function()
    ia_zeros()
  end)
  self.kbd:setSequence({'.', 'd'}, function()
    ia_derivative()
  end)
  self.kbd:setSequence({'.', 'l'}, function()
    ia_limit()
  end)
  self.kbd:setSequence({'.', 'q'}, function()
    ia_seq()
  end)
  self.kbd:setSequence({'.', '+'}, function()
    ia_sumseq()
  end)
  self.kbd:setSequence({'.', '*'}, function()
    ia_prodseq()
  end)
  self.kbd:setSequence({'.', 'r'}, function()
    ia_rewrite()
  end)
  self.kbd:setSequence({'.', 'x'}, function()
    eval_interactive('expand', nil)
  end)
  self.kbd:setSequence({'.', 'f'}, function()
    eval_interactive('factor', nil)
  end)
  self.kbd:setSequence({'.', '='}, function()
    StackView:dup()
    StackView:invalidate()
  end)

  self.kbd:setSequence({'ctx'}, function()
    local menu = UI.Menu()

    local iamenu = menu:add('Interactive')
    iamenu:add('Solve', ia_solve)
    iamenu:add('Zeros', ia_zeros)
    iamenu:add('Derivative', ia_derivative)
    iamenu:add('Limit', ia_limit)
    iamenu:add('Seq', ia_seq)
    iamenu:add('Summation', ia_sumseq)
    iamenu:add('Product', ia_prodseq)
    iamenu:add('Rewrite', ia_rewrite)

    self:open_menu(menu)
  end)
end

-- Reset the completion state, canceling pending completions
function UIInput:cancelCompletion()
  if self.completionIdx ~= nil then
    self.completionIdx = nil
    self.completionList = nil
    if self.completionMenu then
      self.completionMenu:close(true)
      self.completionMenu = nil
    end

    if self.cursor.size > 0 then
      self:onBackspace()
    end
    return true
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

function UIInput:current_completion_style()
  if options.completionStyle == 'menu' and
     self.completionList and
     #self.completionList > 1 then -- lower menu threshold
     return 'menu'
  end
  return 'inline'
end

function UIInput:onCompletionBegin(prefix, candidates)
  if self:current_completion_style() == 'menu' then
    local menu = UI.Menu()
    for _, suffix in ipairs(candidates) do
      menu:add(prefix .. suffix, suffix)
    end

    local old_on_escape = menu.onEscape
    menu.onEscape = function(menu_self)
      old_on_escape(menu_self)
      self:cancelCompletion()
    end

    menu.onExec = function()
      self:moveCursor(1)
    end

    menu.onSelect = function(_, item)
      self:insert_completion_candidate(item['action'])
    end

    self.completionMenu = menu
    self:open_menu(self.completionMenu)
  end
end

function UIInput:open_menu(menu)
  assert(getmetatable(menu) == UI.Menu)

  local _, y = self:frame()
  return menu:open_at(self:getCursorX(), y + 4, y + 4)
end

-- Apply completion item as selected region
function UIInput:insert_completion_candidate(suffix)
  local tail = ""
  if self.cursor.pos + self.cursor.size < #self.text then
    tail = self.text:usub(self.cursor.pos + self.cursor.size + 1)
  end

  self.text = self.text:usub(1, self.cursor.pos) ..
              suffix ..
              tail

  self.cursor.size = suffix:ulen()
  self:scrollToPos()
  self:invalidate()
end

function UIInput:nextCompletion(offset)
  if not self.completionList or #self.completionList == 0 then
    if not self.completionFun then return end

    local prefix = ''
    local left_text = self.text:usub(1, self.cursor.pos)
    local prefix_begin = left_text:find('([_%a\128-\255][%._%w\128-\255]*)$')
    if prefix_begin then
      prefix = left_text:sub(prefix_begin)
    end

    self.completionList = self.completionFun(prefix)
    if not self.completionList or #self.completionList == 0 then
      -- If prefix is a function, add parentheses
      if functionInfo(prefix, false) then
        self:_insertChar('(')
      end

      self:cancelCompletion()
      return
    end

    self.completionIdx = 1
    self:onCompletionBegin(prefix, self.completionList)
  else
    -- Apply single entry using [tab]
    if #self.completionList <= 1 then
      self:moveCursor(1)
      self:cancelCompletion()
      return
    end

    -- Advance completion index
    self.completionIdx = (self.completionIdx or 0) + (offset or 1)

    -- Reset completion list
    if self.completionIdx > #self.completionList then
      self.completionIdx = 1
    elseif self.completionIdx < 1 then
      self.completionIdx = #self.completionList
    end
  end

  if self.completionList then
    self:insert_completion_candidate(self.completionList[self.completionIdx])
  end
end

function UIInput:moveCursor(offset)
  if self.cursor.size > 0 then
    -- Jump to edge of selection
    if offset > 0 then
      offset = self.cursor.size
    end
  end

  self:setCursor(self.cursor.pos + offset)
end

function UIInput:setCursor(pos, scroll)
  local oldPos, oldSize = unpack(self.cursor)

  self.cursor.pos = math.min(math.max(0, pos or self.text:ulen()), self.text:ulen())
  self.cursor.size = 0

  scroll = scroll or true
  if scroll == true then
    self:scrollToPos()
  end

  self:cancelCompletion()

  if oldPos ~= self.cursor.pos or
     oldSize ~= self.cursor.size then
    self:invalidate()
  end
end

function UIInput:getCursorX(pos)
  local x = platform.withGC(function(gc)
    local offset = 0
    if self.prefix then
      offset = gc:getStringWidth(self.prefix) + 2*self.margin
    end
    return offset + gc:getStringWidth(string.usub(self.text, 1, pos or self.cursor.pos))
  end)
  return x
end

function UIInput:scrollToPos(pos)
  local _,_,w,_ = self:frame()
  local margin = self.margin
  local cx = self:getCursorX(pos or self.cursor.pos + self.cursor.size)
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
  StackView:swap()
end

function UIInput:onArrowUp()
  focus_view(StackView)
end

function UIInput:onEscape()
  self:cancelCompletion()
  self:setCursor()
  self:invalidate()
end

function UIInput:onLooseFocus(next)
  if next ~= self.completionMenu then
    self:cancelCompletion()
  end
end

function UIInput:onFocus()
  --self:setCursor(#self.text)
end

function UIInput:onCopy()
  Clipboard.yank(self.text)
end

function UIInput:onCut()
  Clipboard.yank(self.text)
  self:setText('')
end

function UIInput:onPaste()
  if #Clipboard.items == 0 then
    return
  end

  local ctx = UI.Menu()
  for _, item in ipairs(Clipboard.items) do
    ctx:add(item, function() self:insertText(item) end)
  end

  ctx.sel = #ctx.items
  self:open_menu(ctx)
end

function UIInput:onCharIn(c)
  self:cancelCompletion()
  if not self.inputHandler:onCharIn(c) then
    -- Inserting an operator into an empty input in ALG mode should insert '@1'
    if get_mode() == 'ALG' and options.autoAns and self.text:len() == 0 and StackView:size() > 0 then
      local name, _, args, side = queryOperatorInfo(c)
      if name and (args > 1 or (args == 1 and side == 1)) then
        c = '@1'..c
      end
    end

    if c == ' ' and get_mode() == 'RPN' and options.spaceAsEnter then
      self:onEnter()
    else
      self:_insertChar(c)
    end
  end
  self:scrollToPos()
end

-- Returns the views input text split into three parts.
---@return string left   Left side of the input
---@return string mid    Selected input
---@return string right  Right side of the input
function UIInput:split()
  return string.usub(self.text, 1, self.cursor.pos),
         string.usub(self.text, self.cursor.pos + 1, self.cursor.size + self.cursor.pos),
         string.usub(self.text, self.cursor.pos + 1 + self.cursor.size)
end

function UIInput:_insertChar(c)
  c = c or ""
  self:cancelCompletion()

  local expanded = c
  if options.autoClose == true then
    -- Add closing paren
    local matchingParen, isOpening = unpack(ParenPairs[c:usub(-1)] or {})
    if matchingParen and isOpening then
      expanded = c..matchingParen
    end

    -- Skip closing paren
    local rhsPos = self.cursor.pos + 1
    local rhs = self.text:ulen() >= rhsPos and self.text:usub(rhsPos, rhsPos) or nil
    if self.cursor.size == 0 and c == rhs then
      self:moveCursor(1)
      self:invalidate()
      return
    end
  end

  if self.cursor.pos == self.text:ulen() then
    self.text = self.text .. expanded
  else
    local left, mid, right = self:split()

    -- Kill the matching character right to the selection
    if options.autoKillParen == true and mid:ulen() == 1 then
      local matchingParen, isOpening = unpack(ParenPairs[mid] or {})
      if matchingParen and isOpening and right:usub(1, 1) == matchingParen then
        right = right:usub(2)
      end
    end

    self.text = left .. expanded .. right
  end

  self.cursor.pos = self.cursor.pos + string.ulen(c) -- c!
  self.cursor.size = 0

  self:invalidate()
end

function UIInput:onBackspace()
  if not self:cancelCompletion() then
    if options.autoPop == true and self.text:ulen() <= 0 then
      Undo.record_undo()
      StackView:pop()
      StackView:scrollToIdx()
      return
    end
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
end

function UIInput:onEnter()
  if self.text:ulen() == 0 then return end

  self.inputHandler:onEnter()

  self.tempMode = nil
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
  self.prefix = prefix or self.prefix
  self:setCursor(#self.text)
  self:cancelCompletion()
  self:invalidate()
end

function UIInput:insertText(s)
  if s then
    self:cancelCompletion()
    self:_insertChar(s)
    self:scrollToPos()
  end
end

function UIInput:selAll()
  self:cancelCompletion()
  self.cursor.pos = 0
  self.cursor.size = #self.text
  self:invalidate()
end


function UIInput:drawFrame(gc)
  local x, y, width, height = self:frame()

  gc:setColorRGB(theme_val('bg'))
  gc:fillRect(x, y, width, height)
  gc:setColorRGB(theme_val('border_bg'))
  gc:drawLine(x-1, y,
              x + width, y)
  gc:drawLine(x-1, y + height,
              x + width, y + height)
end

function UIInput:drawText(gc)
  local margin = self.margin
  local x,y,w,h = self:frame()
  local scrollx = self.scrollx
  local cursorx = math.max(gc:getStringWidth(string.usub(self.text, 1, self.cursor.pos)) or 0, 0)
  cursorx = cursorx + x + scrollx

  gc:clipRect("set", x, y, w, h)

  -- Draw prefix text
  if self.prefix and self.prefix:len() > 0 then
    local prefixWidth = gc:getStringWidth(self.prefix) + 2*margin

    --gc:setColorRGB(theme_val('alt_bg'))
    --gc:fillRect(x, y+1, prefixWidth, h-2)
    gc:setColorRGB(theme_val('fringe_fg'))
    gc:drawString(self.prefix, x + margin, y)

    x = x + prefixWidth
    cursorx = cursorx + prefixWidth
    gc:clipRect("set", x, y, w, h)
  end

  -- Draw cursor selection box
  if self.cursor.size ~= 0 then
    local selWidth = gc:getStringWidth(string.usub(self.text, self.cursor.pos+1, self.cursor.pos + self.cursor.size))
    local cursorLeft, cursorRight = math.min(cursorx, cursorx + selWidth), math.max(cursorx, cursorx + selWidth)

    gc:drawRect(cursorLeft + 1, y + 2, cursorRight - cursorLeft, h-3)
  end

  gc:setColorRGB(theme_val('fg'))
  gc:drawString(self.text, x + margin + scrollx, y)

  if current_focus == self then
    local is_alg_mode = get_mode() == 'ALG' or not self.inputHandler:isBalanced()
    gc:setColorRGB(theme_val(is_alg_mode and 'cursor_alg_bg' or 'cursor_bg'))
  else
    gc:setColorRGB(theme_val('cursor_alt_bg'))
  end
  gc:fillRect(cursorx+1, y+2, options.cursorWidth, h-3)

  gc:clipRect("reset")
end

function UIInput:draw(gc)
  self:drawFrame(gc)
  self:drawText(gc)
end


--[[
  Rich text view for displaying expressions in a 2D style.
]]--
RichText = class(UI.Widget)
function RichText:init()
  UI.Widget.init(self)
  self.view = D2Editor.newRichText()
  self.view:setReadOnly(true)
  self.view:setBorder(0)
end

function RichText:onFocus()
  self:set_frame(StackView:frame())
  self.view:move(self:frame())
    :resize(select(3, self:frame()))
    :setVisible(true)
    :setFocus(true)
  self._visible = true
end

function RichText:onLooseFocus()
  self.view:setVisible(false)
    :setFocus(false)
  self._visible = false
end

function RichText:onEscape()
  focus_view(StackView)
end

function RichText:displayStackItem(idx)
  local item = StackView.stack[idx or StackView:size()]
  if item ~= nil then
    self.view:createMathBox()
      :setExpression("\\0el {"..item.infix.."}\n=\n" ..
                     "\\0el {"..item.result.."}")
  end
  focus_view(self)
end

function RichText:displayText(text)
  self.view:setExpression(text)
  focus_view(self)
end


-- Returns a new undo-state table by copying the current stack and text input
function Undo.make_state(text)
  return {
    stack=table_clone(StackView.stack),
    input=text or InputView.text
  }
end

function Undo.record_undo(input)
  table.insert(Undo.undo_stack, Undo.make_state(input))
  if #Undo.undo_stack > options.maxUndo then
    table.remove(Undo.undo_stack, 1)
  end
  Undo.redo_stack = {}
end

function Undo.pop_undo()
  table.remove(Undo.undo_stack)
end

function Undo.apply_state(state)
  StackView.stack = state.stack
  if state.input ~= nil then
    InputView:setText(state.input)
  end
  StackView:invalidate()
end

function Undo.undo()
  if #Undo.undo_stack > 0 then
    local state = table.remove(Undo.undo_stack)
    table.insert(Undo.redo_stack, Undo.make_state())
    Undo.apply_state(state)
  end
end

function Undo.redo()
  if #Undo.redo_stack > 0 then
    local state = table.remove(Undo.redo_stack)
    table.insert(Undo.undo_stack, Undo.make_state())
    Undo.apply_state(state)
  end
end

local function clear()
  Undo.record_undo()
  StackView.stack = {}
  StackView:invalidate()
  InputView:setText("", "")
  InputView:invalidate()
  --interactiveStack = {} -- Kill _all_ interactive sessions
end


-- RPN Input Handler
---@class RPNInput
RPNInput = class()

---@param input table  Input interface
---                    Needs the following functions:
---                      text() : string
---                      split() : like text, but split into left|right cursor side
---                      set_text(string)
function RPNInput:init(input)
  assert(input)
  self.input = input
end

function RPNInput:getInput()
  return self.input.text()
  --return InputView.text -- TODO: fix view access
end

function RPNInput:setInput(str)
  self.input.set_text(str)
  --InputView:setText(str)
end

-- Returns the token left to the cursor (if any)
---@return Token token  The rightmost token (cursor)
function RPNInput:currentToken()
  local left = self.input.split()
  if left then
    local tokens = Infix.tokenize(left)
    if tokens and #tokens >= 1 then
      return tokens[#tokens]
    end
  end
end

function RPNInput:togglePrefix(prefix)
  local text = self.input.text()
  if text then
    local i, j = text:find('^[ ]*' .. prefix)
    if i then
      text = text:usub(j - 1)
    else
      text = prefix .. text
    end
    self.input.set_text(text)
  end
end

function RPNInput:isBalanced()
  local str = InputView.text
  local paren,brack,brace,dq,sq = 0,0,0,0,0
  for i = 1, InputView.cursor.pos do
    local c = str:byte(i)
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

---@return table[] nodes  Returns a list of nodes
function RPNInput:popN(num)
  local nodes = {}
  local newTop = #StackView.stack - num + 1
  for _ = 1, num do
    local root = StackView:pop(newTop).rpn
    if not root then
      error('Too few items on stack (' .. #StackView.stack .. ' of ' .. num .. ')')
    end

    if root.kind == 'operator' then
      if root.text == '=:' or root.text == Sym.STORE then
        root = root.children[1]
      elseif root.text == ':=' then
        root = root.children[2]
      end
    end

    table.insert(nodes, root)
  end
  return nodes
end

function RPNInput:dispatchInfix(str)
  if not str or str:ulen() == 0 then
    return nil
  end
  local res = StackView:pushInfix(str)
  if res then
    self:setInput('')
  end
  return res
end

function RPNInput:dispatchInput()
  local str = self:getInput()
  if str and str:ulen() > 0 then
    return self:dispatchInfix(str)
  end
  return true
end

function RPNInput:dispatchOperator(str, ignoreInput)
  local name, _, argc = queryOperatorInfo(str)
  if name then
    Undo.record_undo()
    if (not ignoreInput and not self:dispatchInput()) or
       not Error.assertStackN(argc) then
      Undo.pop_undo()
      return
    end

    local nodes = self:popN(argc)

    -- TODO: Move this elsewhere
    if nodes and #nodes == 1 then
      if nodes[1].text == str and nodes[1].kind == 'operator' then
        if name == Sym.NEGATE or name == 'not ' then
          StackView:pushExpression(ExpressionTree(nodes[1].children[1]))
          return true
        end
      end
    end

    local expr = ExpressionTree(nodes[1])
    table.remove(nodes, 1)
    StackView:pushExpression(expr:apply_operator(str, nodes))
    return true
  end
end

function RPNInput:dispatchOperatorSpecial(key)
  local tab = {
    ['^2'] = function()
      self:dispatchInput()
      StackView:pushInfix('2')
      self:dispatchOperator('^')
    end,
    ['10^'] = function()
      self:dispatchInput()
      StackView:pushInfix('10')
      StackView:swap()
      self:dispatchOperator('^')
    end
  }

  tab[key]()
end

function RPNInput:dispatchFunction(str, ignoreInput, builtinOnly)
  local name, argc, is_stat = functionInfo(str, builtinOnly)
  if name then
    Undo.record_undo()
    if (not ignoreInput and not self:dispatchInput()) or
       not Error.assertStackN(argc) then
      Undo.pop_undo()
      return
    end

    local nodes = self:popN(argc)
    local expr = ExpressionTree(ExpressionTree.make_node(name, is_stat and 'stat_function' or 'function', nodes))

    local res = StackView:pushExpression(expr)
    if is_stat then
      -- TODO: Parse result
      StackView:pushExpression(
        ExpressionTree(ExpressionTree.make_node('stat.results', 'word', {}))
      )
    end
    return res
  end
end

---@return boolean handle  Returns true if key has been handled and
---                        should not be appended to the output.
function RPNInput:onCharIn(key)
  if not key then
    return false
  end

  if get_mode() == "ALG" or not self:isBalanced() then
    return false
  end

  local function isOperator(key)
    return queryOperatorInfo(key) ~= nil
  end

  local function isOperatorSpecial(key)
    if key == '^2' or key == '10^' then return true end
  end

  local function isFunction(key)
    return functionInfo(key, true) ~= nil
  end

  local function handleNegate()
    if key == Sym.NEGATE and self:getInput():ulen() > 0 then
      self:togglePrefix(Sym.NEGATE)
      return true
    end
  end

  local function handleUnitPowerSuffix()
    if key == '^' or key == '^2' then
      local token = self:currentToken()
      if token and token[2] == 'unit' then
        return true
      end
    end
  end

  -- Remove trailing '(' from some TI keys
  if key:ulen() > 1 and key:usub(-1) == '(' then
    key = key:sub(1, -2)
  end

  -- Handle some special cases
  if handleNegate() then return true end
  if handleUnitPowerSuffix() then return false end

  if isOperator(key) then
    self:dispatchOperator(key)
  elseif isOperatorSpecial(key) then
    self:dispatchOperatorSpecial(key)
  elseif isFunction(key) then
    self:dispatchFunction(key)
  else
    return false
  end
  return true
end

function RPNInput:onEnter()
  if get_mode() == "RPN" then
    if self:dispatchFunction(self:getInput(), true, false) then
      self:setInput('')
    elseif self:dispatchOperator(self:getInput(), true) then
      self:setInput('')
    end
  end

  if self:getInput():ulen() > 0 then
    Undo.record_undo()
  end
  return self:dispatchInfix(self:getInput())
end


-- UI
local main_layout = UI.RowLayout()
StackView = main_layout:add_widget(UIStack(), 1)
InputView = main_layout:add_widget(UIInput(), 2, UIInput.height())

MenuView  = UIMenu()
RichView  = RichText()

-- Switch focus to view
---@param view UI.Widget  View to focus
focus_view = function(view)
  if view ~= nil and view ~= current_focus then
    if current_focus then
      if current_focus.onLooseFocus then
        current_focus:onLooseFocus(view)
      end
      current_focus:invalidate()
    end
    current_focus = view
    if current_focus then
      if current_focus.onFocus then
        current_focus:onFocus()
      end
      current_focus:invalidate()
    end
  end
end

-- Completion functions
completion_catmatch = function(candidates, prefix, res)
  res = res or {}
  local plen = prefix and #prefix or 0
  for _,v in ipairs(candidates or {}) do
    if plen == 0 or v:lower():sub(1, plen) == prefix then
      local m = v:sub(plen + 1)
      if #m > 0 then
        table.insert(res, m)
      end
    end
  end

  table.sort(res)
  return res
end

completion_fn_variables = function(prefix, cat)
  return completion_catmatch(var:list(), prefix, cat)
end

local completion_fn_functions_cache = nil
completion_fn_functions = function(prefix, cat)
  if not completion_fn_functions_cache then
    completion_fn_functions_cache = {}
    for k, v in pairs(functions) do
      if not v.conv then
        table.insert(completion_fn_functions_cache, k)
      end
    end
  end

  return completion_catmatch(completion_fn_functions_cache, prefix, cat)
end

local completion_fn_units_cache = nil
completion_fn_units = function(prefix, cat)
  if not completion_fn_units_cache then
    completion_fn_units_cache = {}
    for category, items in pairs(units) do
      for _, unit in ipairs(items) do
        table.insert(completion_fn_units_cache, unit[1])
      end
    end
  end

  return completion_catmatch(completion_fn_units_cache, prefix, cat)
end

InputView.completionFun = function(prefix)
  -- Semantic autocompletion
  local semantic = nil
  if options.smartComplete then
    local semanticValue, semanticKind = nil, nil

    local tokens = Infix.tokenize(InputView.text:usub(1, InputView.cursor.pos + 1 - (prefix and prefix:ulen() + 1 or 0)))
    if tokens and #tokens > 0 then
      semanticValue, semanticKind = unpack(tokens[#tokens])
      semantic = {}
    end

    if semanticValue == '@>' or semanticValue == Sym.CONVERT or semanticKind == 'number' then
      semantic['unit'] = true
    end

    if semanticValue == '@>' or semanticValue == Sym.CONVERT then
      semantic['conversion_fn'] = true
    end

    if semanticKind == 'unit' then
      semantic['conversion_op'] = true
    end

    if semanticValue ~= '@>' and semanticValue ~= Sym.CONVERT and semanticKind == 'operator'  then
      semantic['function'] = true
      semantic['variable'] = true
    end

    if not semanticValue then
      semantic = semantic or {}
      semantic['common'] = true
    end
  end

  -- Provide semantic
  if semantic then
    local candidates = {}
    if semantic['unit'] then
      candidates = completion_fn_units(prefix, candidates)
    end
    if semantic['conversion_op'] then
      candidates = completion_catmatch({'@>'}, prefix, candidates) -- TODO: Use unicode when input is ready
    end
    if semantic['conversion_fn'] then
      candidates = completion_catmatch({
        'approxFraction()',
        'Base2', 'Base10', 'Base16',
        'Decimal',
        'Grad', 'Rad'
      }, prefix, candidates)
    end
    if semantic['function'] then
      candidates = completion_fn_functions(prefix, candidates)
    end
    if semantic['variable'] then
      candidates = completion_fn_variables(prefix, candidates)
    end
    if semantic['common'] then
      --candidates = completion_catmatch(commonTab, prefix, candidates) -- TODO: Add common tab
      candidates = completion_fn_variables(prefix,
                   completion_fn_functions(prefix,
                   completion_fn_units(prefix, candidates)))
    end

    print('info: Got ' .. #candidates .. ' completion candidates for prefix ' .. prefix)
    return candidates
  end

  -- Provide all
  return completion_fn_variables(prefix,
         completion_fn_functions(prefix,
         completion_fn_units(prefix)))
end


Toast = UI.Toast()
ErrorToast = UI.Toast({location = 'center', style = 'error'})
GlobalKbd = KeybindManager()

-- After execution of any kbd command invaidate all
GlobalKbd.onExec = function()
  platform.window:invalidate()
end

-- Show the current state using a toast message
GlobalKbd.onSequenceChanged = function(sequence)
  if not sequence then
    Toast:show()
    return
  end

  local str = ''
  for idx, v in ipairs(sequence) do
    if idx > 1 then str = str..Sym.CONVERT end
    str = str .. v
  end
  Toast:show(str)
end

StackView.kbd.onSequenceChanged = GlobalKbd.onSequenceChanged
InputView.kbd.onSequenceChanged = GlobalKbd.onSequenceChanged

-- Show text as error
Error = {}
function Error.show(str, pos)
  if type(str) == 'number' then
    str = errorCodes[str] or str
  end

  ErrorToast:show(str)
  if not pos then
    InputView:selAll()
  else
    InputView:setCursor(pos)
  end
end

function Error.hide()
  ErrorToast:show()
end

function Error.assertStackN(n, pos)
  if #StackView.stack < (n or 1) then
    Error.show("Too few arguments on stack")
    if not pos then
      InputView:selAll()
    else
      InputView:setCursor(pos)
    end
    return false
  end
  return true
end

-- Ask for a value submitteds with [enter], canceled with [esc]
-- Parameters:
--   widget  The UIInput instance
--   callbackEnter   Called if the user pressed enter
--   callbackEscape  Called if the user pressed escape
--   callbackSetup   Called first with `widget` passed as parameter
input_ask_value = function(widget, callbackEnter, callbackEscape, callbackSetup)
  local state = widget:save_state()
  local onEnter = widget.onEnter
  local onEscape = widget.onEscape

  local function restore_state()
    pop_temp_mode()
    widget:restore_state(state)
    widget.onEnter = onEnter
    widget.onEscape = onEscape
  end

  push_temp_mode('ALG')
  widget:setText('', '')
  if callbackSetup then
    callbackSetup(widget)
  end

  widget.onEnter = function()
    local text = widget.text
    restore_state()
    if callbackEnter then
      callbackEnter(text)
    end
  end

  widget.onEscape = function()
    if callbackEscape then
      callbackEscape()
    end
    restore_state()
  end

  focus_view(widget)
  widget:invalidate()
end


-- Menus
local function make_formula_menu()
  if not formulas then
    return {{"No Formulas", ""}}
  end

  local category_menu = {}
  for title, category in pairs(formulas) do
    local actions_menu = {
      {"Solve for ...", function()
         solve_formula_interactive(category)
      end},
      {"Formulas ...", (function()
        local formula_list = {}
        for _,item in ipairs(category.formulas) do
          table.insert(formula_list, {item.title, item.infix})
        end
        return formula_list
      end)()},
      {"Variables ...", (function()
        local variables_list = {}
        for var,info in pairs(category.variables) do
          table.insert(variables_list, {info[1], var})
        end
        return variables_list
      end)()}
    }

    table.insert(category_menu, {title, actions_menu})
  end

  return category_menu
end

local function make_options_menu()
  local function make_bool_item(title, key)
    return {title, function() options[key] = not options[key] end, state=options[key] == true}
  end

  local function make_choice_item(title, key, choices)
    local choice_items = {}
    for k,v in pairs(choices) do
      table.insert(choice_items, {
        k, function() options[key] = v end, state=options[key] == v
      })
    end
    return {title, choice_items}
  end

  local function make_theme_menu()
    local items = {}
    for name,_ in pairs(themes) do
      table.insert(items, {
        name, function() options.theme = name end, state=options.theme == name
      })
    end
    return {'Theme ...', items}
  end

  return {
    make_bool_item('Show Fringe', 'showFringe'),
    make_bool_item('Show Infix', 'showExpr'),
    make_bool_item('Smart Parens', 'autoClose'),
    make_bool_item('Smart Kill', 'autoKillParen'),
    make_bool_item('Smart Complete', 'smartComplete'),
    make_bool_item('Auto Pop', 'autoPop'),
    make_bool_item('Auto ANS', 'autoAns'),
    make_choice_item('Completion', 'completionStyle', {['inline']='inline', ['menu']='menu'}),
    make_theme_menu()}
end


-- Called for _any_ keypress
local function on_any_key()
  Error.hide()
end

-- View list
local views = {
  Toast,
  ErrorToast,
  MenuView
}

function on.construction()
  toolpalette.enableCopy(true)
  toolpalette.enableCut(true)
  toolpalette.enablePaste(true)

  GlobalKbd:setSequence({'U'}, function()
    Undo.undo()
  end)
  GlobalKbd:setSequence({'R'}, function()
    Undo.redo()
  end)
  GlobalKbd:setSequence({'C'}, function()
    clear()
  end)

  -- Edit
  GlobalKbd:setSequence({'E'}, function()
    if StackView:size() > 0 then
      local idx = StackView.sel or StackView:size()
      focus_view(InputView)
      input_ask_value(InputView, function(expr)
        Undo.record_undo()
        StackView:pushInfix(expr)
        StackView:swap(idx, #StackView.stack)
        StackView:pop()
      end, nil, function(widget)
        widget:setText(StackView.stack[idx].infix, 'Edit #'..(#StackView.stack - idx + 1))
      end)
    end
  end)

  -- Stack
  GlobalKbd:setSequence({'S', 'd', '%d'}, function(sequence)
    -- Duplicate N items from top
    Undo.record_undo()
    StackView:dup(tonumber(sequence[#sequence]))
  end)
  GlobalKbd:setSequence({'S', 'p', '%d'}, function(sequence)
    -- Pick item at N
    Undo.record_undo()
    StackView:pick(tonumber(sequence[#sequence]))
  end)
  GlobalKbd:setSequence({'S', 'r', '%d'}, function(sequence)
    -- Roll stack N times
    Undo.record_undo()
    StackView:roll(tonumber(sequence[#sequence]))
  end)
  GlobalKbd:setSequence({'S', 'r', 'r'}, function()
    -- Roll down 1
    Undo.record_undo()
    StackView:roll(1)
    return 'repeat'
  end)
  GlobalKbd:setSequence({'S', 'x', '%d'}, function(sequence)
    -- Pop item N from top
    Undo.record_undo()
    StackView:pop(tonumber(sequence[#sequence]), true)
  end)
  GlobalKbd:setSequence({'S', 'x', 'x'}, function()
    -- Pop all items from top
    Undo.record_undo()
    StackView.stack = {}
  end)
  GlobalKbd:setSequence({'S', 'l', '%d'}, function(sequence)
    -- Transform top N items to list
    Undo.record_undo()
    StackView:toList(tonumber(sequence[#sequence]))
  end)
  GlobalKbd:setSequence({'S', 'l', 'l'}, function()
    -- Transform top 2 items to list (repeatable)
    Undo.record_undo()
    StackView:toList(2)
    return 'repeat'
  end)

  -- Variables
  GlobalKbd:setSequence({'V', 'clear'}, function()
    math.evalStr('DelVar a-z')
  end)
  GlobalKbd:setSequence({'V', 'backspace'}, function()
    input_ask_value(InputView, function(varname)
      local _, err = math.evalStr('DelVar '..varname)
      if err then
        Error.show(err)
      end
    end, nil, function(widget)
      widget:setText('', 'Delete Var:')
      widget.completionFun = completion_fn_variables
      widget:onTab()
    end)
  end)
  GlobalKbd:setSequence({'V', '='}, function()
    local item = StackView:selectionOrTop()
    local var_name, var_value = '', ''
    if item then
      var_value = item.result

      -- Guess a function signature
      local tokens = Infix.tokenize(item.result)
      if tokens then
        local args = {}
        for _, v in ipairs(tokens) do
          if v[2] == 'word' then
            table.insert(args, v[1])
          end
        end
        if #args > 0 then
          var_name = '(' .. table.concat(args, ',') .. ')'
        end
      end
    end

    input_ask_value(InputView, function(varname)
      input_ask_value(InputView, function(value)
        local res, err = math.evalStr(varname..':=('..value..')')
        if err then
          Error.show(err)
        end
      end, nil, function(widget)
        widget:setText(var_value, varname .. ':=')
        widget:selAll()
      end)
    end, nil, function(widget)
      widget:setText(var_name, 'Set Var:')
      widget:setCursor(0)
      widget.completionFun = completion_fn_variables
    end)
  end)

  -- Formula Library
  GlobalKbd:setSequence({'F'}, function()
    MenuView:present(current_focus, make_formula_menu())
  end)

  -- Mode
  GlobalKbd:setSequence({'M', 'r'}, function()
    -- Set mode to RPN
    options.mode = 'RPN'
  end)
  GlobalKbd:setSequence({'M', 'a'}, function()
    -- Set mode to ALG
    options.mode = 'ALG'
  end)
  GlobalKbd:setSequence({'M', 'm'}, function()
    -- Toggle mode
    options.mode = options.mode == 'RPN' and 'ALG' or 'RPN'
  end)

  -- Settings
  GlobalKbd:setSequence({'help', 'help'}, function()
    MenuView:present(current_focus, make_options_menu())
  end)

  -- User assignable bindings
  GlobalKbd:setSequence({'help', '%d'}, function(sequence)
    local last = tostring(sequence[#sequence])
    local res = load_user_code(string.format('key_%s()', last))
    if res then
      -- Handle special cases
      if type(res) == 'table' then
        if getmetatable(res) == UI.Menu then
          local menu = res
          menu.onExec = function(action)
            if type(action) == 'function' then
              return action()
            else
              InputView:insertText(tostring(action))
            end
          end

          InputView:open_menu(menu)
        else
          print('warning: Can not handle user returned type!')
        end
      end

      -- Handel basic values
      if type(res) == 'string' or type(res) == 'number' then
        InputView:insertText(res)
      end
    end
  end)

  focus_view(InputView)
end

function on.resize(w, h)
  MenuView:center(w, h)
  main_layout:layout(0, 0, w, h)
end

function on.copy()
  if current_focus.onCopy then
    current_focus:onCopy()
  end
end

function on.cut()
  if current_focus.onCut then
    current_focus:onCut()
  end
end

function on.paste()
  if current_focus.onPaste then
    current_focus:onPaste()
  end
end

function on.escapeKey()
  on_any_key()
  GlobalKbd:resetSequence()
  if current_focus.kbd then
    current_focus.kbd:resetSequence()
  end
  if current_focus.onEscape then
    current_focus:onEscape()
  end
end

function on.tabKey()
  on_any_key()
  if current_focus.onTab then
    current_focus:onTab()
  else
    if current_focus ~= InputView then
      UI.Menu.close_current()
      focus_view(InputView)
    end
  end
end

function on.backtabKey()
  on_any_key()
  if current_focus.onBackTab then
    current_focus:onBackTab()
  end
end

function on.returnKey()
  on_any_key()
  if GlobalKbd:dispatchKey('return') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('return') then
    return
  end

  if current_focus == InputView then
    InputView:customCompletion({
      "=:", ":=", "{}", "[]", "@>"
    })
  end
end

function on.arrowRight()
  on_any_key()
  if GlobalKbd:dispatchKey('right') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('right') then
    return
  end
  if current_focus.onArrowRight then
    current_focus:onArrowRight()
  end
end

function on.arrowLeft()
  on_any_key()
  if GlobalKbd:dispatchKey('left') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('left') then
    return
  end
  if current_focus.onArrowLeft then
    current_focus:onArrowLeft()
  end
end

function on.arrowUp()
  on_any_key()
  if GlobalKbd:dispatchKey('up') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('up') then
    return
  end
  if current_focus.onArrowUp then
    current_focus:onArrowUp()
  end
end

function on.arrowDown()
  on_any_key()
  if GlobalKbd:dispatchKey('down') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('down') then
    return
  end
  if current_focus.onArrowDown then
    current_focus:onArrowDown()
  end
end

function on.charIn(c)
  on_any_key()
  if GlobalKbd:dispatchKey(c) then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey(c) then
    return
  end

  --for i=1,#c do
  --  print(c:byte(i))
  --end

  if current_focus.onCharIn then
    current_focus:onCharIn(c)
  end
end

function on.enterKey()
  on_any_key()
  GlobalKbd:resetSequence()
  if current_focus.kbd and current_focus.kbd:dispatchKey('enter') then
    return
  end
  if current_focus.onEnter then
    current_focus:onEnter()
  end
  if current_focus.invalidate then
    current_focus:invalidate()
  end
end

function on.backspaceKey()
  on_any_key()
  if GlobalKbd:dispatchKey('backspace') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('backspace') then
    return
  end
  if current_focus.onBackspace then
    current_focus:onBackspace()
  end
end

function on.clearKey()
  on_any_key()
  if GlobalKbd:dispatchKey('clear') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('clear') then
    return
  end
  if current_focus.onClear then
    current_focus:onClear()
  end
end

function on.contextMenu()
  on_any_key()
  if GlobalKbd:dispatchKey('ctx') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('ctx') then
    return
  end
  if current_focus.onContextMenu then
    current_focus:onContextMenu()
  end
end

function on.help()
  --[[ -- TEST CODE
  RPNExpression(stack:top().rpn):split()
  Macro({'@input:f1(x)', 'f1(x):=@1',
         'f1(0)', 'derivative(f1(x),x)|x=0', '@simp', '(f1(x)-@2-@1)|x=1', '@simp',
         'string(@1)&"((x+"&string((@2/@1)/2)&")^2+"&string((@3/@1)-(((@2/@1)/2)^2))&")"', '@label:f1(x)', '@clrbot:1',
         '{zeros(derivative(f1(x),x),x)}[1,1]', '@simp', '@label:SP x=',
         'f1(@1)', '@simp', '@label:SP y=',
         'zeros(f1(x),x)', '@simp', '@label:Zeros'}):execute()
  ]]--
  on_any_key()
  if GlobalKbd:dispatchKey('help') then
    return
  end
  if current_focus.kbd and current_focus.kbd:dispatchKey('help') then
    return
  end
end

function on.paint(gc, x, y, w, h)
  local frame = {x = x, y = y, width = w, height = h}

  main_layout:draw(gc, x, y, w, h)

  for _,view in ipairs(views) do
    if Rect.intersection(frame, view:frame()) then
      view:draw(gc, frame)
    end
  end

  UI.Menu.draw_current(gc)
end

function on.save()
  return {
    ['options'] = options,
    ['stack'] = StackView.stack,
    ['input'] = InputView.text,
    ['undo'] = {Undo.undo_stack, Undo.redo_stack},
    ['clip'] = Clipboard.stack
  }
end

function on.restore(state)
  Undo.undo_stack, Undo.redo_stack = unpack(state.undo)
  StackView.stack = state['stack'] or {}
  options = state.options
  Clipboard.stack = state['clip'] or {}
  InputView:setText(state.input)
end

if platform.registerErrorHandler then
  platform.registerErrorHandler(function(line, msg)
    Error.show(string.format('Internal: %s (%d)', msg or '', line))
    return true
  end)
end
