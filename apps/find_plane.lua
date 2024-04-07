local apps       = require 'apps.apps'
local ask        = require('dialog.input').display_sync
local choice     = require('dialog.choice').display_sync
local expr       = require 'expressiontree'

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

local function run_plane_3pt(stack)
   local pts = {}
   for i = 1, 3 do
      local pt = ask_vector("Point " .. tostring(i))
      if not pt then
         return
      end
      table.insert(pts, pt)
   end

   local a, b, c = pts[1], pts[2], pts[3]
   local ab = math.evalStr(table_to_vec(a) .. "-" .. table_to_vec(b))
   local ac = math.evalStr(table_to_vec(a) .. "-" .. table_to_vec(c))
   local n = math.evalStr("crossp(" .. ab .. "," .. ac .. ")")
   local eq = math.evalStr("dotp(" ..n .. "," .. table_to_vec({"x", "y", "z"}) .. ")")
   local d = math.evalStr(string.format(eq .."|(x=%s and y=%s and z=%s)", a[1], a[2], a[3]))
   stack:push_infix(eq .. "=" .. d)
end

apps.add('plane - 3pt', 'Plane - 3 Points', run_plane_3pt)
