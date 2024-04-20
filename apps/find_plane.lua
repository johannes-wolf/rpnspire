local apps       = require 'apps.apps'
local matrix     = require 'matrix'
local advice     = require 'advice'
local ask        = require('dialog.input').display_sync
local choice     = require('dialog.choice').display_sync
local choice     = require('dialog.choice').display_sync
local matrix_ed  = require('rpn.matrixeditor').display_sync
local expr       = require 'expressiontree'
local sym        = require 'ti.sym'
local fn = require 'fn'

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

local function ask_n_vectors(ctrl, names, dim)
   local elems = {"x", "y", "z", "w"}
   local mat = matrix.new(4, 5)
   dim = dim or 3
   mat:set(1,1," ")
   for i = 1, dim do
      mat:set(1 + i,1, elems[i])
   end
   mat:resize(4, 1 + #names)
   for n = 1, #names do
      mat:set(1, 1 + n, tostring(names[n]))
   end

   local function setup_dlg(dlg)
      local grid = dlg.grid
      grid:set_header(1,1)
      grid:set_selection(2,2)
      dlg.grid_resize(1 + dim, 1 + #names)
   end

   local res = matrix_ed(ctrl, mat, setup_dlg)
   if res then
      local vecs = {}
      for n = 1, #names do
         local v = {}
         for i = 1, dim do
            table.insert(v, mat:get(1 + i, n + 1))
         end
         table.insert(vecs, v)
      end
      return vecs
   end
end

-- Find line-point distance
local function run_line_point(ctrl)
   local a, n, p = table.unpack(fn.imap(ask_n_vectors(ctrl, {"a", "n", "p"}), table_to_vec))
   if a and p then
      local n = math.evalStr("(" .. n .. "/norm(" .. n .. "))")
      local eq = a .. "+t*".. n
      local isection = "solve(" .. eq .. "=" .. p .. ",t)"
      local rvec = string.format("(%s-%s)-dotp(%s-%s,%s)*%s", p, a, p, a, n, n)
      local distance = "norm(" .. rvec .. ")"
      local proj = string.format("%s+dotp(%s-%s,%s)*%s", a, p, a, n, n)

      -- Results
      local r_isection = math.evalStr(isection)
      if r_isection == "false" then
         r_isection = nil
      end
      local r_distance = math.evalStr(distance)
      local r_rvec = math.evalStr(rvec)
      local r_proj = math.evalStr(proj)

      -- Collect results
      local r = {}
      if r_isection then
         table.insert(r, { title = 'Point on line', result = '*' })
         table.insert(r, { title = 't: ' .. r_isection, result = r_isection, align = -1 })
      else
         table.insert(r, { title = 'Point not on line', result = '*' })
         table.insert(r, { title = 'Shortest distance: ' .. r_distance, result = r_distance, align = -1 })
         table.insert(r, { title = 'Vector p to x: ' .. r_rvec, result = r_rvec, align = -1})
         table.insert(r, { title = 'Projection on x: ' .. r_proj, result = r_proj, align = -1 })
      end

      -- Show results
      table.insert(r, { title = 'Done', result = 'done' })
      while true do
         local action = choice {
            title = 'Results',
            items = r,
         }
         if action == 'done' then
            break
         elseif action then
            ctrl:push_infix(tostring(action))
         end
      end
   end
end

-- Find intersection point or distance between two lines
local function run_line_line(ctrl)
   local p1, d1, p2, d2 = table.unpack(fn.imap(ask_n_vectors(ctrl, {"p1", "d1", "p2", "d2"}), table_to_vec))
   if p1 and p2 then
      local eq1 = p1 .. "+a*".. d1
      local eq2 = p2 .. "+b*".. d2
      local isection = "solve(" .. eq1 .. "=" .. eq2 .. ",a,b)"
      local parallel = "solve(" .. d1 .. "=t*" .. d2 .. ",t)"
      local n = "crossp(" .. d1 .. "," .. d2 .. ")"
      local n1 = "crossp(" .. d1 .. "," .. n .. ")"
      local n2 = "crossp(" .. d2 .. "," .. n .. ")"
      local nearest1 = string.format("%s+(dotp(%s-%s,%s)/dotp(%s,%s))*%s",
        p1, p2, p1, n2, d1, n2, d1)
      local nearest2 = string.format("%s+(dotp(%s-%s,%s)/dotp(%s,%s))*%s",
        p2, p1, p2, n1, d2, n1, d2)
      local distance = "norm(" .. nearest1 .. "-" .. nearest2 ..")"
      local angle = "arccos(abs(dotp(" .. d1 .. "," .. d2 .. "))/(norm(" .. d1 .. ")*norm(" .. d2 .. ")))"

      -- Results
      local r = {}
      local r_isection = math.evalStr(isection)
      if r_isection == 'false' then
         r_isection = nil
      end
      local r_parallel = math.evalStr(parallel)
      if r_parallel == 'false' then
         r_parallel = nil
      end

      local r_c1 = math.evalStr(nearest1)
      local r_c2 = math.evalStr(nearest2)
      local r_dist = math.evalStr(distance)
      
      -- Collect results
      if r_isection then
         local r_angle = math.evalStr(angle)

         table.insert(r, { title = 'Intersecting lines', result = '*' })
         table.insert(r, { title = 'Intersection: ' .. r_c1, result = r_c1, align = -1 })
         table.insert(r, { title = 'Angle: ' .. r_angle, result = r_angle, align = -1 })
      elseif r_parallel then
         table.insert(r, { title = 'Parallel lines', result = '*' })
         table.insert(r, { title = 'Distance: ' .. r_dist, result = r_dist, align = -1 })
      else
         table.insert(r, { title = 'Skew lines', result = '*' })
         table.insert(r, { title = 'Distance: ' .. r_dist, result = r_dist, align = -1 })
         table.insert(r, { title = 'Nearest point on a: ' .. r_c1, result = r_c1, align = -1 })
         table.insert(r, { title = 'Nearest point on b: ' .. r_c2, result = r_c2, align = -1 })
      end

      -- Show results
      table.insert(r, { title = 'Done', result = 'done' })
      while true do
         local action = choice {
            title = 'Results',
            items = r,
         }
         if action == 'done' then
            break
         elseif action then
            ctrl:push_infix(tostring(action))
         end
      end
   end
end

-- Find intersection point between line and plane
local function run_line_plane(ctrl)
   local p0, n, l0, l = table.unpack(fn.imap(ask_n_vectors(ctrl, {"p0", "n", "l0", "ln"}), table_to_vec))
   if p0 and l0 then
      local parallel = "dotp(" .. n .. "," .. l .. ")=0"
      local angle = "arcsin(abs(dotp(" .. n .. "," .. l .. "))/(norm(" .. n .. ")*norm(" .. l .. ")))"
      local d = string.format("dotp((%s-%s),%s)/dotp(%s,%s)", p0, l0, n, l, n)
      local dist = string.format("dotp((%s-%s),%s)/dotp(%s,%s)", p0, l0, n, n, n)

      -- Results
      local r = {}
      local r_parallel = math.evalStr(parallel) == 'true'
      
      -- Collect results
      if not r_parallel then
         local r_d = math.evalStr(d)
         local r_angle = math.evalStr(angle)
         local r_pt = math.evalStr(l0 .. "+" .. l .. "*" .. d)

         table.insert(r, { title = 'Intersecting lines', result = '*' })
         table.insert(r, { title = 'Intersection: ' .. r_pt, result = r_pt, align = -1 })
         table.insert(r, { title = 'Angle: ' .. r_angle, result = r_angle, align = -1 })
      else
         local r_dist = math.evalStr(dist)
         local r_in_plane = math.evalStr("dotp(" .. p0  .. "-" .. l0 .. "," .. n .. ")=0") == 'true'

         if r_in_plane then
            table.insert(r, { title = 'Parallel (in plane)', result = '*' })
            table.insert(r, { title = 'Reason: (p0 - l0) * n = 0', result = '*', align = -1 })
         else
            table.insert(r, { title = 'Parallel', result = '*' })
            table.insert(r, { title = 'Distance: ' .. r_dist, result = r_dist, align = -1 })
         end
      end

      -- Show results
      table.insert(r, { title = 'Done', result = 'done' })
      while true do
         local action = choice {
            title = 'Results',
            items = r,
         }
         if action == 'done' then
            break
         elseif action then
            ctrl:push_infix(tostring(action))
         end
      end
   end
end

local function run_angle_2vec(ctrl, stack)
   local a, b = table.unpack(fn.imap(ask_n_vectors(ctrl, {"a", "b"}), table_to_vec))
   stack:push_infix("arccos(dotp(" .. a .. "," .. b .. ")/(norm(" .. a .. ")*norm(" .. b ..  "))")
end

local function run_dist_2pt(ctrl, stack)
   local a, b = table.unpack(fn.imap(ask_n_vectors(ctrl, {"a", "b"}), table_to_vec))
   stack:push_infix("norm(" .. b .. "-" .. a .. ")")
end

local function run_convert_plane(ctrl)
   local from
   while not from do
      from = choice {
         title = 'Input format',
         items = {
            { title = 'Points (a,b,c)', result = 'points' },
            { title = 'Vector ((x-p)*n=0)', result = 'vector' },
            { title = 'Equation (x+y+z=d)', result = 'equation' },
            { title = 'Cancel', result = 'done' }
         }
      }
      if from == 'done' then return end
   end

   local p0, n

   if from == "points" then
      local a, b, c = table.unpack(ask_n_vectors(ctrl, { "a", "b", "c" }))
      if a and b and c then
         local ab = table_to_vec(b) .. "-" .. table_to_vec(a)
         local ac = table_to_vec(c) .. "-" .. table_to_vec(a)

         p0 = table_to_vec(a)
         n = "crossp(" .. ab .. "," .. ac .. ")"
      end
   elseif from == "vector" then
      p0, n = table.unpack(fn.imap(ask_n_vectors(ctrl, { "p0", "n" }), table_to_vec))
   elseif from == "equation" then
      a, b, c, d = table.unpack(fn.imap(ask_n_vectors(ctrl, { "ax", "by", "cz", "d" }, 1), function(l) return l[1] end))

      p0 = {}
      local i = 1
      for k, v in pairs({x = a, y = b, z = c}) do
         local is_set = math.evalStr(v .. "=0") == 'false'
         if is_set then
            p0[i] = d .. "/" .. v
         else
            p0[i] = "0"
         end
      end

      if #p0 > 0 then
         p0 = table_to_vec(p0)
         n = table_to_vec({a, b, c})
      else
         error("Invalid plane coefficients")
      end
   end

   local r_eq = math.evalStr("dotp([[x][y][z]]," .. n .. ")") .. "=" .. math.evalStr("dotp(" .. p0 .. "," .. n .. ")")
   local r_vector = string.format("dotp((x-%s), %s)", p0, n)
   local r_vector_norm = string.format("dotp((x-%s), %s)", p0, math.evalStr(n .. "/norm(" .. n .. ")"))

   while true do
      local action = choice {
         title = "Resutl",
         items = {
            { title = r_eq, result = r_eq },
            { title = r_vector, result = r_vector },
            { title = r_vector_norm, result = r_vector_norm },
            { title = 'Done', result = 'done' },
         }
      }
      if action == 'done' then
         break
      elseif action then
         ctrl:push_infix(action)
      end
   end
end

apps.add('AnaGeo: line-point', 'line-point', run_line_point)
apps.add('AnaGeo: line-line',  'line-line',  run_line_line)
apps.add('AnaGeo: line-plane', 'line-plane', run_line_plane)
apps.add('AnaGeo: convert plane', 'convert plane', run_convert_plane)
