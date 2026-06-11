-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1569-1581
local function order_age_text_0521(order)
  if type(order) ~= "table" then return "—" end
  local created = order.created_tick or order.tick or order.submitted_tick or order.first_seen_tick
  local seen = order.last_seen_tick or order.activated_tick or order.promoted_tick or order.updated_tick
  local lease = order.lease_until_0512 or order.retain_until_0476 or order.hold_until_0512
  local parts = {}
  if created then parts[#parts+1] = "age " .. tick_age_0521(created) end
  if seen then parts[#parts+1] = "seen " .. tick_age_0521(seen) end
  if lease then parts[#parts+1] = "lease " .. tostring(math.max(0, math.ceil((tonumber(lease) - now()) / 60))) .. "s" end
  if #parts == 0 then return "—" end
  return table.concat(parts, " | ")
end

