-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1435-1440
local function add_items(parent, title, rows, total, empty_text)
  add_label(parent, title .. " (" .. tostring(total or #rows) .. ")")
  if #rows == 0 then add_label(parent, "  " .. (empty_text or "none")); return end
  for _, row in ipairs(rows) do add_label(parent, "  [item=" .. tostring(row.name) .. "] " .. tostring(row.name) .. " x" .. tostring(row.count)) end
end

