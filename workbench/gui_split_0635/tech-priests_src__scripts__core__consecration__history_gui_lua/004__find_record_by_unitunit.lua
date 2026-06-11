-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 46-55
local function find_record_by_unit(unit)
  unit = tonumber(unit)
  if not unit then return nil end
  if ensure_storage then pcall(ensure_storage) end
  local machines = storage and storage.tech_priests and storage.tech_priests.consecration and storage.tech_priests.consecration.machines or nil
  local record = machines and machines[unit] or nil
  if record and record.entity and record.entity.valid then return record end
  return nil
end

