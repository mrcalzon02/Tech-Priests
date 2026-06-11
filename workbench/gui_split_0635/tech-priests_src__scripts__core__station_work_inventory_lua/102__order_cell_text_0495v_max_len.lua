-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1595-1601
local function order_cell_text_0495(v, max_len)
  local text = tostring(v or "—")
  max_len = max_len or 36
  if #text > max_len then return text:sub(1, max_len - 1) .. "…" end
  return text
end

