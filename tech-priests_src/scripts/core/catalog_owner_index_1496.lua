-- Transient reverse lookup for station-owned resource keys.
-- Rebuild from saved canonical ownership after Lua load; never persist the index.
local M = {}
local indexed_source = nil
local by_owner = nil

function M.for_root(root)
  local source = assert(root and root.owned_resources, "catalog ownership unavailable")
  if indexed_source ~= source or by_owner == nil then
    local built = {}
    for key, owner in pairs(source) do
      if owner ~= nil then
        local keys = built[owner]
        if not keys then keys = {}; built[owner] = keys end
        keys[key] = true
      end
    end
    indexed_source, by_owner = source, built
    if root.stats then
      root.stats.owner_index_rebuilds_1496 =
        (root.stats.owner_index_rebuilds_1496 or 0) + 1
    end
  end
  return by_owner
end

function M.assign(root, key, owner)
  if key == nil or owner == nil then return false end
  local grouped = M.for_root(root)
  local previous = root.owned_resources[key]
  if previous ~= nil and previous ~= owner then
    local old = grouped[previous]
    if old then
      old[key] = nil
      if next(old) == nil then grouped[previous] = nil end
    end
  end
  root.owned_resources[key] = owner
  local keys = grouped[owner]
  if not keys then keys = {}; grouped[owner] = keys end
  keys[key] = true
  return previous ~= owner
end

function M.release(root, key)
  if key == nil then return false end
  local grouped = M.for_root(root)
  local owner = root.owned_resources[key]
  if owner == nil then return false end
  root.owned_resources[key] = nil
  local keys = grouped[owner]
  if keys then
    keys[key] = nil
    if next(keys) == nil then grouped[owner] = nil end
  end
  return true
end

function M.release_station(root, owner, on_release)
  local grouped = M.for_root(root)
  local keys = grouped[owner]
  if not keys then return 0 end
  local released = 0
  for key in pairs(keys) do
    if root.owned_resources[key] == owner then
      root.owned_resources[key] = nil
      if on_release then on_release(key) end
      released = released + 1
    end
  end
  grouped[owner] = nil
  return released
end

return M
