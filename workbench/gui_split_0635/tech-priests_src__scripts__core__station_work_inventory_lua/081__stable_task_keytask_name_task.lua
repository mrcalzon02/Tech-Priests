-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1196-1201
local function stable_task_key(task_name, task)
  local text = tostring(task_name or "none") .. " :: " .. short_value(task)
  if #text > 180 then text = text:sub(1, 177) .. "..." end
  return text
end

