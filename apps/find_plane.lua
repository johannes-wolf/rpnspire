local apps       = require 'apps.apps'
local matrix     = require 'matrix'
local advice     = require 'advice'
local ask        = require('dialog.input').display_sync
local choice     = require('dialog.choice').display_sync
local choice     = require('dialog.choice').display_sync
local matrix_ed  = require('rpn.matrixeditor').display_sync
local expr       = require 'expressiontree'
local sym        = require 'ti.sym'

local function table_to_vec(t)
   local r = ""
   for _, v in ipairs(t) do
      r = r .. "[" .. v .. "]"
   end
   return "[" .. r .. "]"
end

local function ask_vector(title, dim)
   dim = dim or 3
   while true do
      local r = ask({title = title or 'Vector'})
      if not r then
         return nil
      end

      local v = {}
      for c in r:gmatch("([^,]+)") do
         table.insert(v, c)
      end

      if #v == dim then
         return v
      end
   end
end

local function ask_n_vectors(ctrl, names)
   local mat = matrix.new(4, 5)
   mat:set(1,1," ")
   mat:set(2,1,"x")
   mat:set(3,1,"y")
   mat:set(4,1,"z")
   mat:resize(4, 1 + #names)
   for n = 1, #names do
      mat:set(1, 1 + n, tostring(names[n]))
   end

   local function setup_dlg(dlg)
      local grid = dlg.grid
      grid:set_header(1,1)
      grid:set_selection(2,2)
      dlg.grid_resize(4, 1 + #names)
   end

   local res = matrix_ed(ctrl, mat, setup_dlg)
   if res then
      local vecs = {}
      for n = 1, #names do
         table.insert(vecs, {
             mat:get(2, n + 1),
             mat:get(3, n + 1),
             mat:get(4, n + 1),
         })
      end
      return vecs
   end
end

-- Find plane equation from 3 pts
local function run_plane_3pt(ctrl, stack)
   local a, b, c = table.unpack(ask_n_vectors(ctrl, {"a", "b", "c"}))
   local ab = math.evalStr(table_to_vec(a) .. "-" .. table_to_vec(b))
   local ac = math.evalStr(table_to_vec(a) .. "-" .. table_to_vec(c))
   local n = math.evalStr("crossp(" .. ab .. "," .. ac .. ")")
   local eq = math.evalStr("dotp(" ..n .. "," .. table_to_vec({"x", "y", "z"}) .. ")")
   local d = math.evalStr(string.format(eq .."|(x=%s and y=%s and z=%s)", a[1], a[2], a[3]))

   local res_c = eq .. " = " .. d
   local res_p = "x = " .. table_to_vec(a) .. " + s*" .. ab .. " + t*" .. ac
   local res_n = "(x - " .. table_to_vec(a) .. ") " .. sym.CDOT .. " " .. n

   local action = choice { title = 'Results', items = {
      { title = 'E: ' .. res_c, align = -1, result = 'c' },
      { title = 'E: ' .. res_p, align = -1, result = 'p' },
      { title = 'E: ' .. res_n, align = -1, result = 'n' },
      { title = 'Store...', result = 'store' },
      { title = 'Exit', result = 'done' },
   }}

   if action == 'store' then
      local sym = ask { title = 'Variable', text = 'E1' }
      if sym and #sym > 0 then
         stack:push_infix(res_c)
         stack:push_infix(sym)
         stack:push_operator('=:')
      end
   elseif action == 'c' then
      stack:push_infix(res_c)
   elseif action == 'done' then
      return
   end
end

-- Find intersection point or distance between two lines
local function run_2lines(ctrl, stack)
   local function vec_str(l)
      return string.format("[[%s,%s,%s]]", table.unpack(l))
   end

   local p1, d1, p2, d2 = table.unpack(ask_n_vectors(ctrl, {"p1", "d1", "p2", "d2"}))
   if p1 then
      local vp1, vd1 = vec_str(p1), vec_str(d1)
      local vp2, vd2 = vec_str(p2), vec_str(d2)

      local eq1 = vp1 .. "+a*".. vd1
      local eq2 = vp2 .. "+b*".. vd2

      local isection = "solve(" .. eq1 .. "=" .. eq2 .. ",a,b)"
      local parallel = "solve(" .. vd1 .. "=t*" .. vd2 .. ",t)"
      local n = math.evalStr("crossp(" .. vd1 .. "," .. vd2 .. ")")
      local n1 = math.evalStr("crossp(" .. vd1 .. "," .. n .. ")")
      local n2 = math.evalStr("crossp(" .. vd2 .. "," .. n .. ")")
      local nearest1 = string.format("%s+(dotp(%s-%s,%s)/dotp(%s,%s))*%s",
        vp1, vp2, vp1, n2, vd1, n2, vd1)
      local nearest2 = string.format("%s+(dotp(%s-%s,%s)/dotp(%s,%s))*%s",
        vp2, vp1, vp2, n1, vd2, n1, vd2)
      local distance = "norm(" .. nearest1 .. "-" .. nearest2 ..")"

      local r_isection = math.evalStr(isection)
      local r_parallel = math.evalStr(parallel)
      print(r_isection)
      print(r_parallel)

      if r_isection ~= 'false' then
         return
      else
         return
      end
   end
end

local function run_angle_2vec(stack)
   local a = table_to_vec(ask_vector("Vector a"))
   local b = table_to_vec(ask_vector("Vector b"))

   stack:push_infix("arccos(dotp(" .. a .. "," .. b .. ")/(norm(" .. a .. "*norm(" .. b ..  "))")
end

local function run_dist_2pt(stack)
   local a = table_to_vec(ask_vector("Point A"))
   local b = table_to_vec(ask_vector("Point B"))

   stack:push_infix("norm(" .. b .. "-" .. a .. ")")
end

apps.add('plane - 3pt', 'Plane - 3 Points', run_plane_3pt)
apps.add('angle - 2vec', 'Angle - 2 Vectors', run_angle_2vec)
apps.add('dist - 2pt',   'Dist. - 2 Points', run_dist_2pt)
apps.add('2line',   '2line', run_2lines)
