-- Cache immutable entity keys once per expanded catalog lookup.
-- Does not persist LuaObjects or change the original string-key ordering.
local M = {}
function M.sort(entities, key_for)
  if type(entities) ~= "table" then return entities end
  local keys = {}
  for _,entity in ipairs(entities) do
    keys[entity] = tostring(key_for(entity) or "")
  end
  table.sort(entities, function(a,b) return keys[a] < keys[b] end)
  return entities
end
return M
