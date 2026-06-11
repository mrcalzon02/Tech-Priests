-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1824-1830
local function command_node_priest_signal_0521(p)
  if not p then return "no node" end
  if valid(p.priest) then return tostring(p.priest.name) .. "#" .. tostring(p.priest.unit_number or "?") end
  if p.last_valid_priest_unit_0495 then return "lost; last#" .. tostring(p.last_valid_priest_unit_0495) end
  return "priest-signal-lost"
end

