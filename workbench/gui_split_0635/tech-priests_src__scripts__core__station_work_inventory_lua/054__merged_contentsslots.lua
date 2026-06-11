-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 691-698
local function merged_contents(slots)
  local out = {}
  for _, slot in ipairs(slots or {}) do
    for name, count in pairs(inventory_contents(slot.inv)) do out[name] = (out[name] or 0) + count end
  end
  return out
end

