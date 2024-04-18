local choice = require('dialog.choice').display_sync
local ask    = require('dialog.input').display_sync

local t = {}

local function prepare_vars(vars)
    local new = {}
    for k, v in pairs(vars) do
        if type(v) ~= "table" then
            new[k] = {value = tostring(v)}
        else
            new[k] = v
        end

        local item = new[k]
        item.kind = item.kind or "text"     
        item.options = item.options
        item.value = item.value or "0"
    end
    return new
end

function t.ask_vars(vars, title)
    title = title or "Variables"
    vars = prepare_vars(vars)

    -- Result table
    local r = {}
    for k, v in pairs(vars) do
        r[k] = r[k] or v.value
    end

    -- Ask for a single value
    local function ask_value(key)
        local is_choice = vars[key].options ~= nil
        if is_choice then
            local items = {}
            for _, v in ipairs(vars[key].options) do
                if type(v) == "table" then
                    table.insert(items, {title = v.title, result = v.result or v.title})
                else
                    table.insert(items, {title = tostring(v), result = tostring(v)})
                end
            end
        
            return choice{
                title = key .. "...",
                items = items,
            } or r[key]
        else
            return ask{
                title = key .. "...",
                text = r[key] or "",
            } or r[key]
        end
    end

    while true do
        local items = {}
        for k, v in pairs(vars) do
            table.insert(items, {title = string.format("%s = %s", k, tostring(r[k])), result = k, align = -1})
        end
        table.insert(items, {title = "Done", result = "DONE", align = 0})

        local action = choice{
            title = title,
            items = items,
        }
        if action == "DONE" then
            break
        else
            r[action] = ask_value(action)
        end
    end

    return r
end

return t