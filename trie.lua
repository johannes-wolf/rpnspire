local trie = {}

-- Build a prefix tree (trie) from table
---@param tab table  Input table
---@return table     Prefix tree
function trie.build(tab)
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
function trie.find(str, tab, pos)
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
    return table.unpack(match)
  end
  return nil
end

return trie
