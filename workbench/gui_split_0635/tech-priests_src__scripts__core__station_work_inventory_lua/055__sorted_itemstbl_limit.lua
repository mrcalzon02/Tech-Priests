-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 699-706
local function sorted_items(tbl, limit)
  local rows = {}
  for name, count in pairs(tbl or {}) do if (count or 0) > 0 then rows[#rows+1] = { name = name, count = count } end end
  table.sort(rows, function(a,b) if a.count ~= b.count then return a.count > b.count end; return a.name < b.name end)
  local out = {}; for i = 1, math.min(limit or M.max_rows, #rows) do out[#out+1] = rows[i] end
  return out, #rows
end

