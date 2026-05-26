-- scripts/core/subordinate_scheduler.lua
-- Tech Priests 0.1.323 subordinate-aware assignment layer.
--
-- This is a conservative hierarchy pass.  It does not replace the old task-force
-- system; it teaches an assigned intermediate/senior to fan out ingredient writs
-- to lower-ranked subordinate priests when it has queue capacity.  If no valid
-- subordinate exists, the assigned priest continues doing the work itself.

local Sub = {}
Sub.version = "0.1.323"
Sub.storage_key = "tech_priests_subordinate_scheduler_0323"
Sub.queue_limit = 2
Sub.assignment_cooldown = 60 * 8
Sub.job_timeout = 60 * 90
Sub.max_distance_multiplier = 1.50

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function g(name) return rawget(_G, name) end
local function fn(name) local f = g(name); if type(f) == "function" then return f end; return nil end
local function key(pair) return pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or nil end

function Sub.ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Sub.storage_key] = storage.tech_priests[Sub.storage_key] or { version = Sub.version, enabled = true, stats = {} }
  local root = storage.tech_priests[Sub.storage_key]
  root.version = Sub.version
  root.stats = root.stats or {}
  return root
end

function Sub.rank(pair)
  local f = fn("tech_priests_get_pair_tier_rank") or fn("tech_priests_pair_rank_value_0188")
  if f then local ok, value = pcall(f, pair); if ok and tonumber(value) then return tonumber(value) end end
  local tier = pair and pair.tier or pair and pair.station and pair.station.valid and pair.station.name or "junior"
  if tostring(tier):find("senior") then return 3 end
  if tostring(tier):find("intermediate") then return 2 end
  return 1
end

function Sub.queue(pair)
  if not pair then return nil end
  pair.subordinate_queue_0323 = pair.subordinate_queue_0323 or { active = false, jobs = {}, count = 0, limit = Sub.queue_limit }
  local q = pair.subordinate_queue_0323
  q.limit = q.limit or Sub.queue_limit
  q.jobs = q.jobs or {}
  local count = 0
  for id, job in pairs(q.jobs) do
    if not job or job.status == "done" or job.status == "expired" or (job.timeout_tick and now() > job.timeout_tick) then
      q.jobs[id] = nil
    else
      count = count + 1
    end
  end
  q.count = count
  q.active = count > 0
  return q
end

function Sub.has_capacity(pair)
  local q = Sub.queue(pair)
  return q and (q.count or 0) < (q.limit or Sub.queue_limit)
end

function Sub.distance_sq(a, b)
  if not (a and b and valid(a.station) and valid(b.station)) then return 999999999 end
  local dx = a.station.position.x - b.station.position.x
  local dy = a.station.position.y - b.station.position.y
  return dx * dx + dy * dy
end

function Sub.is_subordinate_available(lead_pair, candidate)
  if not (lead_pair and candidate and candidate ~= lead_pair and valid(lead_pair.station) and valid(candidate.station) and valid(candidate.priest)) then return false end
  if candidate.station.force ~= lead_pair.station.force or candidate.station.surface ~= lead_pair.station.surface then return false end
  if Sub.rank(candidate) >= Sub.rank(lead_pair) then return false end
  if candidate.dead or candidate.recalling or candidate.deploying then return false end
  if candidate.emergency_assist_job_0187 or candidate.emergency_craft or candidate.scavenge or candidate.inventory_scan then return false end
  if candidate.repair_target or candidate.consecration_target or candidate.combat_target then return false end
  local radius = 20
  local rf = fn("refresh_pair_radius")
  if rf then local ok, r = pcall(rf, lead_pair); if ok and tonumber(r) then radius = tonumber(r) end end
  local allowed = radius * Sub.max_distance_multiplier
  return Sub.distance_sq(lead_pair, candidate) <= allowed * allowed
end

function Sub.find_subordinates(pair, limit)
  local result = {}
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return result end
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if Sub.is_subordinate_available(pair, other) then result[#result + 1] = { pair = other, dist = Sub.distance_sq(pair, other), rank = Sub.rank(other) } end
  end
  table.sort(result, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.dist < b.dist
  end)
  while #result > (limit or Sub.queue_limit) do table.remove(result) end
  return result
end

function Sub.missing_components(pair, item_name, count)
  local recipe_missing = fn("tech_priests_recipe_missing_components_0188") or fn("tech_priests_missing_task_force_components_0187")
  if recipe_missing then
    local ok, result = pcall(recipe_missing, pair, item_name, count or 1)
    if ok and type(result) == "table" then return result end
  end
  if item_name then return { { name = item_name, count = math.max(1, count or 1) } } end
  return {}
end

function Sub.make_job_id(lead_pair, child_pair, item_name)
  return tostring(now()) .. ":0323:" .. tostring(key(lead_pair)) .. ":" .. tostring(key(child_pair)) .. ":" .. tostring(item_name)
end

function Sub.snippet(pair, text)
  if _G.tech_priests_emit_overhead_status_0473 then
    return _G.tech_priests_emit_overhead_status_0473(pair, text, {r=1,g=0.78,b=0.22,a=0.95}, 60 * 4, 0.62, "subordinate-scheduler")
  end
  local f = fn("tech_priests_task_force_snippet_0187") or fn("tech_priests_task_force_snippet_0188")
  if f then pcall(f, pair, text); return end
  if valid(pair and pair.priest) and rendering and rendering.draw_text then
    pcall(function() rendering.draw_text({ text = text, target = pair.priest, target_offset = {0,-2.4}, surface = pair.priest.surface, color = {r=1,g=0.78,b=0.22,a=0.95}, scale=0.65, alignment="center", time_to_live=60*4 }) end)
  end
end

function Sub.assign_child(parent_pair, child_pair, item_name, count, parent_job)
  local job_id = Sub.make_job_id(parent_pair, child_pair, item_name)
  local job = {
    id = job_id,
    lead_station_unit = key(parent_pair),
    assistant_station_unit = key(child_pair),
    item_name = item_name,
    count = math.max(1, count or 1),
    parent_item = parent_job and parent_job.item_name or item_name,
    role = "subordinate-ingredient",
    subordinate_doctrine_0323 = true,
    parent_writ_id_0323 = parent_job and parent_job.id or nil,
    assigned_tick = now(),
    timeout_tick = now() + Sub.job_timeout,
    status = "assigned"
  }
  child_pair.emergency_assist_job_0187 = job
  child_pair.emergency_assist_op_0187 = {
    enabled = true,
    site = fn("tech_priests_find_emergency_operation_site_0184") and select(2, pcall(fn("tech_priests_find_emergency_operation_site_0184"), child_pair)) or nil,
    next_tick = 0,
    phase = "subordinate-assist-0323",
    parent_lead_station_unit = key(parent_pair)
  }
  local q = Sub.queue(parent_pair)
  q.jobs[job_id] = job
  q.count = (q.count or 0) + 1
  q.active = true
  parent_pair.subordinate_queue_not_full_0323 = (q.count or 0) < (q.limit or Sub.queue_limit)
  Sub.snippet(parent_pair, "[item=" .. tostring(item_name) .. "] subordinate writ issued " .. tostring(q.count) .. "/" .. tostring(q.limit))
  Sub.snippet(child_pair, "[item=" .. tostring(item_name) .. "] subordinate writ accepted. Acquire and return.")
  return true
end

function Sub.maybe_delegate_from_assigned_pair(pair)
  local root = Sub.ensure_root()
  if not root.enabled then return false end
  if not (pair and valid(pair.station) and valid(pair.priest)) then return false end
  if Sub.rank(pair) < 2 then return false end
  local job = pair.emergency_assist_job_0187
  if not (job and job.item_name and (not job.timeout_tick or now() <= job.timeout_tick)) then return false end
  local q = Sub.queue(pair)
  if (q.count or 0) >= (q.limit or Sub.queue_limit) then
    pair.subordinate_queue_not_full_0323 = false
    return false
  end
  if q.last_parent_item == job.item_name and now() < (q.next_assignment_tick or 0) then return false end
  q.last_parent_item = job.item_name
  q.next_assignment_tick = now() + Sub.assignment_cooldown
  local missing = Sub.missing_components(pair, job.item_name, job.count or 1)
  if #missing == 0 then return false end
  local assistants = Sub.find_subordinates(pair, (q.limit or Sub.queue_limit) - (q.count or 0))
  if #assistants == 0 then
    pair.subordinate_queue_not_full_0323 = false
    pair.subordinate_queue_full_reason_0323 = "no lower-rank idle subordinate"
    Sub.snippet(pair, "[item=" .. tostring(job.item_name) .. "] no subordinate queue; completing writ personally")
    return false
  end
  local assigned = 0
  for _, miss in pairs(missing) do
    if (q.count or 0) >= (q.limit or Sub.queue_limit) then break end
    local slot = assistants[assigned + 1]
    if slot and slot.pair and miss.name then
      if Sub.assign_child(pair, slot.pair, miss.name, miss.count or 1, job) then assigned = assigned + 1 end
    end
  end
  if assigned > 0 then
    root.stats.delegated = (root.stats.delegated or 0) + assigned
    pair.mode = pair.mode or "subordinate-delegation"
    return true
  end
  return false
end

function Sub.install()
  if type(rawget(_G, "tech_priests_service_task_force_assist_job_0187")) == "function" and rawget(_G, "TECH_PRIESTS_0323_PRE_SERVICE_ASSIST_JOB") == nil then
    _G.TECH_PRIESTS_0323_PRE_SERVICE_ASSIST_JOB = _G.tech_priests_service_task_force_assist_job_0187
    _G.tech_priests_service_task_force_assist_job_0187 = function(pair)
      pcall(function() Sub.maybe_delegate_from_assigned_pair(pair) end)
      return _G.TECH_PRIESTS_0323_PRE_SERVICE_ASSIST_JOB(pair)
    end
  end
  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-subordinates-0323", "Tech Priests: inspect/toggle subordinate-aware assignment. Usage: /tp-subordinates-0323 status|enable|disable", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        local parameter = tostring(event and event.parameter or "status")
        local root = Sub.ensure_root()
        if parameter == "enable" then root.enabled = true elseif parameter == "disable" then root.enabled = false end
        if player and player.valid then player.print("[Tech Priests 0.1.323] subordinate scheduler=" .. tostring(root.enabled) .. " delegated=" .. tostring(root.stats.delegated or 0)) end
      end)
    end)
  end
  return true
end

return Sub
