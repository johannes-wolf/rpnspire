local fn = {}

function fn.map(list, f)
    local t = {}
    for k, v in pairs(list) do
        t[k] = f(v)
    end
    return t
end

function fn.imap(list, f)
    local t = {}
    for i, v in ipairs(list) do
        t[i] = f(v)
    end
    return t
end

return fn