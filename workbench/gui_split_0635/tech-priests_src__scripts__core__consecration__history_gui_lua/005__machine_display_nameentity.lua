-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 56-60
local function machine_display_name(entity)
  if not (entity and entity.valid) then return "unknown-machine" end
  return entity.localised_name or entity.name or "machine"
end

