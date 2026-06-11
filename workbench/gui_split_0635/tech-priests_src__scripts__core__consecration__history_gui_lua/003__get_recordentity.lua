-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 37-45
local function get_record(entity)
  if not (entity and entity.valid) then return nil end
  if not (is_consecration_target and is_consecration_target(entity)) then return nil end
  if not get_consecration_record then return nil end
  local ok, record = pcall(get_consecration_record, entity)
  if ok then return record end
  return nil
end

