local m = {}

local function formula_get_vars(str)
   local res = {}
   for v in str:gmatch('%{%w+%}') do
      table.insert(res, v:sub(2, -2))
   end
   return res
end

local function formula_replace_vars(str, tab)
   return str and str:gsub('%{%w+%}', function(key)
      key = key:sub(2, -2)
      return tab[key] and '(' .. tab[key] .. ')' or key
   end)
end

-- Mask variables for symbolic solve/isolation
local function formula_mask_vars(str)
   return str and str:gsub('%{%w+%}', function(key)
      return '(m_' .. key:sub(2, -2) .. '_m)'
   end)
end

-- Unmask masked variables
local function formula_unmask_vars(str)
   return str and str:gsub('m_%w+_m', function(key)
      return key:sub(3, -3)
   end)
end

local function build_formula_solve_queue(want_var, set, formulas)
   local var_to_formula = {}

   if type(want_var) == 'string' then
      want_var = { want_var }
   end

   -- Insert all given arguments as pseudo formulas
   for name, value in pairs(set) do
      var_to_formula[name] = name.."=("..value..")"
   end

   -- Returns a variable name the formula is solvable for
   -- with the current set of known variables
   local function get_solvable_for(formula)
      local missing = nil
      for _, v in ipairs(formula_get_vars(formula)) do
         if not var_to_formula[v] then
            if missing then
               return nil
            end
            missing = v
         end
      end
      return missing
   end

   for _ = 1, 50 do -- Artificial search limit
      local found = false
      for _, v in ipairs(formulas) do
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
   ---@type string[][]
   local solve_queue = {}

   local function add_formula_to_queue(formula, solve_for)
      if not formula then return end

      -- Remove prev element
      for i, v in ipairs(solve_queue) do
         if v[1] == solve_for and v[2] == formula then
            table.remove(solve_queue, i)
            break
         end
      end

      -- Insert at top
      table.insert(solve_queue, 1, { solve_for, formula })

      for _, v in ipairs(formula_get_vars(formula)) do
         if v ~= solve_for then
            add_formula_to_queue(var_to_formula[v], v)
         end
      end
   end

   for _, v in ipairs(want_var) do
      print('info: adding wanted var ' .. v .. ' to queue')
      add_formula_to_queue(var_to_formula[v], v)
   end

   return solve_queue
end

function m.solve_for(var, set, formulas)
   local q = build_formula_solve_queue(var, set, formulas)
   local steps = {}
   for _, v in ipairs(q) do
      local variable, formula = v[1], v[2]

      -- Solve numeric
      local numeric = math.evalStr(string.format('nsolve(%s,%s)', formula_replace_vars(formula, set), variable))
      set[variable] = numeric

      -- Solve symbolic (for steps)
      local symbolic = formula_replace_vars(formula, {})
      if symbolic then
         table.insert(steps, { formula = symbolic, var = variable })
      end
   end
   return set, steps
end

return m
