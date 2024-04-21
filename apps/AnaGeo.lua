local apps       = require 'apps.apps'
local matrix     = require 'matrix'
local advice     = require 'advice'
local ask        = require('dialog.input').display_sync
local choice     = require('dialog.choice').display_sync
local matrix_ed  = require('rpn.matrixeditor').display_sync
local expr       = require 'expressiontree'
local sym        = require 'ti.sym'
local fn         = require 'fn'

-- Eval formatted string
local function E(fmt, ...)
   return math.evalStr(string.format(fmt, ...))
end

-- Show results as cohice
local function show_results(ctrl, items)
   table.insert(items, { title = 'Done', result = 'done', align = 0 })

   local action
   while not action do
      action = choice({title = 'Results', items = items})
      if action == 'done' then
         break
      elseif type(action) == 'function' then
         action = action(ctrl)
      end
      if action ~= '*' then
         ctrl:push_infix(action)
         action = nil
      end
   end
   return action
end

-- Convert lua table to nspire column vector [[x][y]...]
local function table_to_vec(t)
   local r = ""
   for _, v in ipairs(t) do
      r = r .. "[" .. v .. "]"
   end
   return "[" .. r .. "]"
end

-- Ask for a list of n vectors of dimension dim using the matrix editor
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
         table.insert(r, { title = "Details...", result = "" })
      else
         table.insert(r, { title = 'Point not on line', result = '*' })
         table.insert(r, { title = 'Shortest distance: ' .. r_distance, result = r_distance, align = -1 })
         table.insert(r, { title = 'Vector p to x: ' .. r_rvec, result = r_rvec, align = -1})
         table.insert(r, { title = 'Projection on x: ' .. r_proj, result = r_proj, align = -1 })
      end

      -- Show results
      show_results(ctrl, r)
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
      local distance = "abs(norm(" .. nearest1 .. "-" .. nearest2 .."))"
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
      show_results(ctrl, r)
   end
end

-- Find intersection point between line and plane
local function run_line_plane(ctrl)
   local p0, n, l0, l = table.unpack(fn.imap(ask_n_vectors(ctrl, {"p0", "n", "l0", "ln"}), table_to_vec))
   if p0 and l0 then
      local parallel = "dotp(" .. n .. "," .. l .. ")=0"
      local angle = "arcsin(abs(dotp(" .. n .. "," .. l .. "))/(norm(" .. n .. ")*norm(" .. l .. ")))"
      local d = string.format("dotp((%s-%s),%s)/dotp(%s,%s)", p0, l0, n, l, n)
      local dist = string.format("abs(dotp((%s-%s),%s))/dotp(%s,%s)", p0, l0, n, n, n)

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
      show_results(ctrl, r)
   end
end

local function run_plane_point(ctrl)
   local p0, n, p = table.unpack(fn.imap(ask_n_vectors(ctrl, {"p0", "n", "p"}), table_to_vec))
   if p0 and n and p then
      local signed_dist = E("dotp((%s-%s),%s)/dotp(%s,%s)", p0, p, n, n, n)
      local abs_dist = E("abs(%s)", signed_dist)
      local point = E("%s+%s*%s", p, signed_dist, n)

      -- Results
      local r = {}

      table.insert(r, { title = 'Distance: ' .. abs_dist, result = abs_dist })
      table.insert(r, { title = 'Signed distance: ' .. signed_dist, result = signed_dist })
      table.insert(r, { title = 'Point on plane: ' .. point, result = point })

      -- Show results
      show_results(ctrl, r)
   end
end

local function run_plane_plane(ctrl)
   local p0, n0, p1, n1 = table.unpack(fn.imap(ask_n_vectors(ctrl, {"p0", "n0", "p1", "n1"}), table_to_vec))
   if p0 and p1 then
      local is_parallel = E("norm(crossp(%s,%s))=0", n0, n1)
      print(is_parallel)
      is_parallel = is_parallel == "true"

      -- Results
      local r = {}

      if not is_parallel then
         local angle = E("arccos(abs(dotp(%s,%s))/abs(norm(%s)*norm(%s)))", n0, n1, n0, n1)
         table.insert(r, { title = 'Angle: ' .. angle, result = angle })
         --table.insert(r, { title = 'Intersection: ' .. intersection, result = intersection })
      else
         local dist = E("abs(dotp((%s-%s),%s))/dotp(%s,%s)", p0, p1, n0, n0, n0)
         table.insert(r, { title = 'Distance: ' .. dist, result = dist })
      end

      show_results(ctrl, r)
   end
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

   show_results(ctrl, {
      { title = r_eq, result = r_eq, align = -1 },
      { title = r_vector, result = r_vector, align = -1 },
      { title = r_vector_norm, result = r_vector_norm, align = -1 },
   })
end

apps.add('AnaGeo: line-point',    'l-pt', run_line_point)
apps.add('AnaGeo: line-line',     'l-l',  run_line_line)
apps.add('AnaGeo: line-plane',    'l-pl', run_line_plane)
apps.add('AnaGeo: plane-point',   'pl-pt', run_plane_point)
apps.add('AnaGeo: plane-plane',   'pl-pl', run_plane_plane)
apps.add('AnaGeo: convert plane', 'cnv-pl', run_convert_plane)
