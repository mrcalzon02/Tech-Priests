-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1361-1423
function M.describe_pair(pair)
  if not valid_pair(pair) then return { "No valid station/priest pair selected." } end
  local lines = {}
  local task_name, task = task_candidates(pair)
  local facilities = facility_records(pair)
  local transient = merged_contents(priest_transient_inventories(pair))
  local transient_rows, transient_total = sorted_items(transient, 6)
  local station_rows, station_total = sorted_items(merged_contents(M.station_sources(pair)), 8)
  local superior, juniors, peers = relation_summary(pair)
  lines[#lines+1] = "Station seal: " .. station_label(pair) .. " | rank " .. tostring(station_rank(pair))
  lines[#lines+1] = "Priest: " .. priest_label(pair) .. " | mode " .. tostring(pair.mode or "idle")
  local profile = profile_for_pair(pair)
  if profile then
    lines[#lines+1] = "Personal dossier: " .. tostring(profile.noospheric_id or noospheric_id(pair)) .. " | forge=" .. tostring(profile.forge_world or "unknown") .. " | doctrine=" .. tostring(profile.doctrine or "unknown") .. " | camp=" .. tostring(profile.doctrine_camp or "unknown")
    lines[#lines+1] = "  likes=" .. tostring(profile.like or "?") .. " | dislikes=" .. tostring(profile.dislike or "?")
    lines[#lines+1] = "  quirk=" .. tostring(profile.quirk or "?") .. " | mental=" .. tostring(profile.mental_state or "?")
    lines[#lines+1] = "  origin=" .. tostring(profile.planet_of_origin_0525 or profile.forge_world or "?") .. " type=" .. tostring(profile.origin_world_type_0525 or "?")
  lines[#lines+1] = "  status=" .. tostring(profile.current_status_0525 or profile.mental_state or "?") .. " former=" .. tostring(profile.former_assignment_0525 or "?")
  lines[#lines+1] = "  biography=" .. tostring(profile.history or "?")
    lines[#lines+1] = "  plan=" .. tostring(profile.plan or "?") .. " | goal=" .. tostring(profile.goal or "?")
    local allies, rivals, neutral = social_rows(pair, profile, 5)
    lines[#lines+1] = "  doctrine relationship chart: allies=" .. tostring(#allies) .. " rivals=" .. tostring(#rivals) .. " neutral=" .. tostring(#neutral)
    for _, row in ipairs(allies) do lines[#lines+1] = "    ally: " .. tostring(row) end
    for _, row in ipairs(rivals) do lines[#lines+1] = "    rival: " .. tostring(row) end
  end
  lines[#lines+1] = "Superior: " .. (superior and station_label(superior) or "none in chain")
  lines[#lines+1] = "Juniors: " .. tostring(#juniors) .. " | equal peers: " .. tostring(#peers)
  lines[#lines+1] = "Active request/task: " .. tostring(task_name) .. " :: " .. short_value(task)
  local mem = observe_task_state(pair, "describe")
  lines[#lines+1] = "Primitive task history: last five observed transitions; forward augury is provisional."
  for i = 1, 5 do
    local rec = mem and mem.history and mem.history[i] or nil
    lines[#lines+1] = rec and ("  -" .. tostring(i) .. " " .. tostring(rec.task_name or "?") .. " :: " .. tostring(rec.summary or "") .. " [" .. task_age_text(rec.tick) .. "]") or ("  -" .. tostring(i) .. " EMPTY HISTORY SLOT")
  end
  local projected_rows = projection_rows(pair, task_name, task, superior, juniors)
  lines[#lines+1] = "Augured next rite-slots: provisional until senior mandate, construction writ, or scheduler command overwrites them."
  for i = 1, 5 do lines[#lines+1] = "  +" .. tostring(i) .. " " .. tostring(projected_rows[i].label) .. " :: " .. tostring(projected_rows[i].basis) end
  if _G.tech_priests_0445_task_transition_describe then
    local ok_gov, gov_lines = pcall(_G.tech_priests_0445_task_transition_describe, pair)
    if ok_gov and gov_lines then
      for i, line in ipairs(gov_lines) do
        if i <= 5 then lines[#lines+1] = "Task governor: " .. tostring(line) end
      end
    end
  end
  if _G.tech_priests_0361_describe_scheduler_state then
    local ok_sched, sched_lines = pcall(_G.tech_priests_0361_describe_scheduler_state, pair)
    if ok_sched and sched_lines then
      for i, sched_line in ipairs(sched_lines) do
        if i <= 8 then lines[#lines+1] = "Scheduler: " .. tostring(sched_line) end
      end
    end
  end
  lines[#lines+1] = "Personal Martian facilities: " .. tostring(#facilities)
  for i, rec in ipairs(facilities) do if i <= 6 then lines[#lines+1] = "  " .. tostring(rec.role or "facility") .. ": " .. tostring(rec.name) .. "#" .. tostring(rec.entity and rec.entity.unit_number or "?") end end
  lines[#lines+1] = "Station-bound inventory kinds: " .. tostring(station_total)
  for _, row in ipairs(station_rows) do lines[#lines+1] = "  " .. row.name .. " x" .. tostring(row.count) end
  lines[#lines+1] = "Priest transient reliquary cargo kinds: " .. tostring(transient_total) .. " (should evacuate to station/stash)"
  for _, row in ipairs(transient_rows) do lines[#lines+1] = "  transient " .. row.name .. " x" .. tostring(row.count) end
  lines[#lines+1] = "Doctrine: craft/place/mine outputs return to station or station stash; priest inventory is not active stock."
  return lines
end

