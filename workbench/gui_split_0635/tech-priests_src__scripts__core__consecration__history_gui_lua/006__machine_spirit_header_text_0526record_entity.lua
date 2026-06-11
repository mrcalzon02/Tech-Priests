-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 61-69
local function machine_spirit_header_text_0526(record, entity)
  local spirit = record and record.machine_spirit_0523 or {}
  local machine_id = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or ("unit#" .. tostring(record and record.unit_number or (entity and entity.valid and entity.unit_number) or "?"))
  local name = spirit.display_name or (spirit.named and "Machine" or "Unnamed Machine-Spirit")
  return tostring(name) .. " // " .. tostring(machine_id)
end

local set_label_style

