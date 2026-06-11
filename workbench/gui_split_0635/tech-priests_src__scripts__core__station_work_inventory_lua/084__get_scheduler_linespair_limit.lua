-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1227-1240
local function get_scheduler_lines(pair, limit)
  local out = {}
  if _G.tech_priests_0361_describe_scheduler_state then
    local ok, sched_lines = pcall(_G.tech_priests_0361_describe_scheduler_state, pair)
    if ok and sched_lines then
      for i, line in ipairs(sched_lines) do
        if i > (limit or 5) then break end
        out[#out + 1] = tostring(line)
      end
    end
  end
  return out
end

