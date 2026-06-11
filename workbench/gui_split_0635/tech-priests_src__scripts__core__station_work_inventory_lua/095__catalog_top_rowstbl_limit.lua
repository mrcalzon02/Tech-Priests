-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1454-1481
local function catalog_top_rows(tbl, limit)
  local rows = {}
  for key, rec in pairs(tbl or {}) do
    local name = nil
    if type(key) == "string" then name = key end
    if not name and type(rec) == "table" then name = rec.name or rec.item_name end
    local count = 0
    if type(rec) == "table" then count = tonumber(rec.count) or tonumber(rec.amount) or 0 else count = tonumber(rec) or 0 end
    if name and name ~= "" and count > 0 then
      rows[#rows + 1] = {
        name = name,
        count = count,
        sources = type(rec) == "table" and (tonumber(rec.sources) or 0) or 0,
        owner = type(rec) == "table" and rec.owner_unit or nil
      }
    end
  end
  table.sort(rows, function(a, b)
    if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
    return tostring(a.name) < tostring(b.name)
  end)
  local out = {}
  for i = 1, math.min(limit or M.max_rows, #rows) do out[#out + 1] = rows[i] end
  return out, #rows
end

local add_table_cell_0521 -- forward for Auspex section tables

