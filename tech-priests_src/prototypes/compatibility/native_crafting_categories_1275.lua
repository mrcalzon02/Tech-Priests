-- Build a prototype capability list only from actual native recipe categories.
-- This is for the emergency assembler; no arbitrary categories or fake recipes.
return function(registered, desired)
  assert(type(registered) == "table", "Factorio recipe-category registry unavailable")
  assert(type(desired) == "table", "desired workshop categories required")
  local categories, seen = {}, {}
  for _, name in ipairs(desired) do
    if type(name) == "string" and registered[name] and not seen[name] then
      categories[#categories + 1] = name
      seen[name] = true
    end
  end
  assert(#categories > 0, "native registry provides no emergency assembler category")
  return categories
end
