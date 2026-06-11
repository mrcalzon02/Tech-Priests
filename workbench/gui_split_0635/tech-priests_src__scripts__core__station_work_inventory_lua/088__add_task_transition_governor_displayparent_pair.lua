-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1301-1314
local function add_task_transition_governor_display(parent, pair)
  add_label(parent, "Task transition / emotion-state governor")
  if _G.tech_priests_0445_task_transition_describe then
    local ok, lines = pcall(_G.tech_priests_0445_task_transition_describe, pair)
    if ok and lines then
      for i, line in ipairs(lines) do
        if i <= 7 then add_label(parent, "  " .. tostring(line)) end
      end
      return
    end
  end
  add_label(parent, "  governor not installed yet; fallback status uses primitive task memory only")
end

