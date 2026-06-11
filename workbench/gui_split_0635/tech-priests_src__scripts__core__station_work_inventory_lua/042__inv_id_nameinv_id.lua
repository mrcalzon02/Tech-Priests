-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 561-565
local function inv_id_name(inv_id)
  for k, v in pairs(defines.inventory or {}) do if v == inv_id then return tostring(k) end end
  return tostring(inv_id)
end

