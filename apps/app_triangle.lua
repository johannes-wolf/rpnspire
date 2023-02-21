local apps       = require 'apps.apps'
local ask        = require('dialog.input').display_sync
local choice     = require('dialog.choice').display_sync
local formsolver = require 'apps.formsolver'

local vars_default = {
   { 'Side a', 'a' },
   { 'Side b', 'b' },
   { 'Side c', 'c' },
   { 'Alpha', 'alpha' },
   { 'Beta', 'beta' },
   { 'Gamma', 'gamma' },
   { 'Perimeter', 'p' },
   { 'Area', 'area' },
}

local vars_full = {
   { 'Side a', 'a' },
   { 'Side b', 'b' },
   { 'Side c', 'c' },
   { 'Alpha', 'alpha' },
   { 'Beta', 'beta' },
   { 'Gamma', 'gamma' },
   { 'Perimeter', 'p' },
   { 'Semiperimeter', 's' },
   { 'Area', 'area' },
   { 'Height a', 'ha' },
   { 'Height b', 'hb' },
   { 'Height c', 'hc' },
   { 'Median a', 'ma' },
   { 'Median b', 'mb' },
   { 'Median c', 'mc' },
   { 'Inradius', 'inrad' },
   { 'Circumradius', 'circumrad' },
}

local function run_triangle(stack)
   local vars = vars_default
   local formulas = {
      -- Law of sine
      '{a}/sin({alpha})={b}/sin({beta})',
      '{b}/sin({beta})={c}/sin({gamma})',
      '{c}/sin({gamma})={a}/sin({alpha})',
      -- Law of cosine
      '{a}^2={b}^2+{c}^2-2*{b}*{c}*cos({alpha})',
      '{b}^2={a}^2+{c}^2-2*{a}*{c}*cos({beta})',
      '{c}^2={a}^2+{b}^2-2*{a}*{b}*cos({gamma})',
      -- Perimeter
      '{p}={a}+{b}+{c}',
      '{s}={p}/2',
      -- Area
      '{area}=1/2*{a}*{b}*sin({gamma})',
      '{area}=1/2*{b}*{c}*sin({alpha})',
      '{area}=1/2*{c}*{a}*sin({beta})',
      '{area}=sqrt({s}*({s}-{a})*({s}-{b})*({s}-{c}))',
      -- Height
      '{ha}=2*{area}/{a}',
      '{hb}=2*{area}/{b}',
      '{hc}=2*{area}/{c}',
      -- Median
      '{ma}=sqrt((2*{b}^2+2*{c}^2-{a}^2)/4)',
      '{mb}=sqrt((2*{c}^2+2*{a}^2-{b}^2)/4)',
      '{mc}=sqrt((2*{a}^2+2*{b}^2-{c}^2)/4)',
      -- Inradius
      '{inrad}={area}/{s}',
      -- Circumradius
      '{circumrad}={a}/(2*sin({alpha}))',
      '{circumrad}={b}/(2*sin({beta}))',
      '{circumrad}={c}/(2*sin({gamma}))',
   }

   local mode = math.getEvalSettings()[2][1]
   if mode == 'Radian' then
      table.insert(formulas, '{alpha}+{beta}+{gamma}=pi')
   else
      table.insert(formulas, '{alpha}+{beta}+{gamma}=180')
   end

   local set = {}

   local sel = 1 -- Dialog selection index
   while true do
      local actions = {}
      for _, v in ipairs(vars) do
         local name, var = v[1], v[2]
         table.insert(actions, { name, set[var] or '', result = var })
      end

      --table.insert(actions, {'Set ABC...', '', result = 'points'})
      if vars == vars_default then
         table.insert(actions, { 'Show all...', '', result = 'full' })
      end
      table.insert(actions, { 'Solve...', '', result = 'done' })

      local action
      action, sel = choice { title = 'Triangle', items = actions, selection = sel }
      if not action then return end
      if action == 'done' then
         break
      elseif action == 'full' then
         vars = vars_full
      elseif action then
         set[action] = ask { title = 'Set ' .. action, text = set[action] or '' }
      end
   end

   local unsolved = {}
   for _, k in ipairs(vars) do
      k = k[2]
      if not set[k] then
         table.insert(unsolved, k)
      end
   end

   -- Solve all unsolved variables
   local steps
   set, steps = formsolver.solve_for(unsolved, set, formulas)

   sel = 1
   while true do
      local actions = {}
      for _, v in ipairs(vars) do
         local name, var = v[1], v[2]
         table.insert(actions, { name, set[var] or '?', result = var })
      end

      table.insert(actions, { 'Steps...', '', result = 'explain' })
      table.insert(actions, { 'Done...', '[esc]', result = 'done' })

      local action
      action, sel = choice { title = 'Result', items = actions, selection = sel }
      if not action then return end
      if action == 'done' then
         break
      elseif action == 'explain' then
         local step_items = {}
         for _, v in ipairs(steps) do
            table.insert(step_items, { title = v.formula..' for '..v.var, result = v.formula })
         end

         while true do
            action = choice { title = 'Steps', items = step_items }
            if not action then break end
            stack:push_infix(action)
         end
      elseif action ~= nil then
         stack:push_infix(set[action])
         stack:push_infix(action)
         stack:push_rstore()
      end
   end
end

apps.add('triangle', 'Triangle solver', run_triangle)
