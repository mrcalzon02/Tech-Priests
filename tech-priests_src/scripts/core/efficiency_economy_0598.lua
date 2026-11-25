-- Tech Priests 0.1.598: cooperative parallelization standards/economy shim.
-- This is not true multithreading. Factorio runtime Lua is deterministic and
-- single-threaded. The practical equivalent is cooperative parallelization:
-- spread non-critical service routes across ticks and categories so hundreds of
-- priests do not wake every background helper at once.

local M = { version = "0.1.598", storage_key = "efficiency_economy_0598" }
-- The registry already consults this governor, but callbacks INSIDE the
-- central broker previously bypassed it. Bound background polling at every
-- population, including the first four priests, without throttling movement.
M.broker_callback_budget = 4
M.broker_phase_ticks = 120

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if not r then
    r = { version = M.version, enabled = true, stats = {}, buckets = {}, last_report_tick = 0 }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  r.stats = r.stats or {}
  r.buckets = r.buckets or {}
  if r.enabled == nil then r.enabled = true end
  return r
end

local function inc(key, n)
  local r = root()
  r.stats[key] = (r.stats[key] or 0) + (n or 1)
end

local function pair_count(r)
  r = r or root()
  local tick = game and game.tick or 0
  if r.cached_pair_count ~= nil
      and tick < (tonumber(r.next_pair_scan_tick) or 0) then
    return r.cached_pair_count
  end
  local tp = storage and storage.tech_priests
  local map = tp and tp.pairs_by_station
  local n = 0
  if type(map) == "table" then
    for _, pair in pairs(map) do
      if pair and ((pair.station and pair.station.valid) or (pair.priest and pair.priest.valid)) then
        n = n + 1
        if n > 500 then break end
      end
    end
  end
  r.cached_pair_count = n
  -- The empty -> first-station transition must not wait through a long TTL.
  r.next_pair_scan_tick = tick + (n == 0 and 5 or 60)
  return n
end

local critical_categories = {
  lifecycle = true,
  dispatcher = true,
  combat = true,
  movement = true,
  recovery = true,
  safety = true,
  acquisition = true,
  crafting = true,
  construction = true,
  repair = true,
  consecration = true,
  inventory = true,
  authority = true,
}

local background_categories = {
  diagnostics = true,
  visual = true,
  visuals = true,
  gui = true,
  audio = true,
  chatter = true,
  conversation = true,
  scheduler = true,
  doctrine = true,
  background = true,
}

local function stable_hash(text)
  text = tostring(text or "")
  local h = 0
  for i = 1, #text do
    h = (h * 33 + string.byte(text, i)) % 9973
  end
  return h
end

local broker_background_categories = {
  construction=true, diagnostics=true, discovery=true, inventory=true,
  logistics=true, ["machine-logistics"]=true, maintenance=true,
  planning=true, readiness=true, ["runtime-cleanup"]=true,
  scheduler=true, visual=true, visuals=true, gui=true, audio=true,
  chatter=true, conversation=true, background=true, doctrine=true,
}

local function broker_background(service)
  -- These services advance active work despite their broad historical labels:
  -- queue progression, original-priest expansion, and inventory custody.
  return service.name ~= "order_queue_0469"
    and service.name ~= "station-starvation-first-junior-0922"
    and service.name ~= "inventory_steward_0357"
    and broker_background_categories[service.category] == true
end

function M.broker_plan(services, event, cadence)
  local r = root()
  if r.enabled == false then return nil end
  local tick = event and event.tick or (game and game.tick) or 0
  local step = math.max(1, tonumber(cadence) or 5)
  r.broker_deadlines = r.broker_deadlines or {}
  local admitted, due = {}, 0
  for _, service in ipairs(services) do
    if service.enabled ~= false and broker_background(service) then
      admitted[service.name] = false
      if not service.tech_priests_0598_broker_initialized then
        local saved = r.broker_deadlines[service.name]
        if saved and saved.interval == service.interval
            and tonumber(saved.next_due_tick) then
          service.next_due_tick = saved.next_due_tick
        elseif (tonumber(service.next_due_tick) or 0) == 0 then
          -- Reuse the governor's deterministic phasing. The existing first
          -- station spread may already have supplied a deadline; retain it.
          local slots = math.max(1, math.ceil(
            math.min(service.interval, M.broker_phase_ticks) / step))
          service.next_due_tick = tick + (stable_hash(service.name) % slots) * step
        end
        service.tech_priests_0598_broker_initialized = true
        r.broker_deadlines[service.name] = {
          interval=service.interval, next_due_tick=service.next_due_tick,
        }
      end
      if tick >= (tonumber(service.next_due_tick) or 0) then due = due + 1 end
    end
  end
  -- Round-robin admission prevents a frequently due high-priority poll from
  -- starving another poll. The broker still executes admitted callbacks in
  -- its canonical priority order, and deferred callbacks keep their deadline.
  local count, used = #services, 0
  local cursor = math.max(0, math.floor(tonumber(r.broker_cursor) or 0))
  for offset = 1, count do
    local index = ((cursor + offset - 1) % count) + 1
    local service = services[index]
    if admitted[service.name] == false
        and tick >= (tonumber(service.next_due_tick) or 0)
        and used < M.broker_callback_budget then
      admitted[service.name] = true
      used = used + 1
      r.broker_cursor = index
    end
  end
  r.stats.broker_background_admitted = (r.stats.broker_background_admitted or 0) + used
  r.stats.broker_background_deferred = (r.stats.broker_background_deferred or 0) + due - used
  r.stats.broker_background_peak = math.max(r.stats.broker_background_peak or 0, used)
  return admitted
end

function M.broker_ran(service)
  if not broker_background(service) then return end
  local r = root()
  r.broker_deadlines = r.broker_deadlines or {}
  r.broker_deadlines[service.name] = {
    interval=service.interval, next_due_tick=service.next_due_tick,
  }
end

local function window_for_load(n)
  if n <= 0 then return 1 end
  if n < 10 then return 2 end
  if n < 40 then return 4 end
  if n < 100 then return 6 end
  if n < 250 then return 10 end
  return 15
end

function M.route_budget(entry, event, cadence)
  local r = root()
  if type(entry) ~= "table" then return true end
  -- The 0594 wrapper checks this flag only for the CURRENT route dispatch.
  entry.tech_priests_0598_budgeted = false
  if not r.enabled then return true end
  local category = string.lower(tostring(entry.category or ""))
  if critical_categories[category] then return true end
  if not background_categories[category] then return true end

  local count = pair_count(r)
  if count <= 0 then
    -- Dormant gate should already catch the fully idle case, but keep this
    -- secondary defense cheap and explicit for old raw handlers.
    inc("skipped_no_pairs")
    return false
  end

  local window = window_for_load(count)
  if window <= 1 then return true end
  entry.tech_priests_0598_budgeted = true
  local key = entry.tech_priests_0598_pulse_key
  if not key then
    key = tostring(entry.id or (tostring(entry.owner or "legacy") .. ":" .. tostring(entry.route or category)))
      .. ":" .. tostring(cadence or entry.tick or "")
    entry.tech_priests_0598_pulse_key = key
  end
  local pulse = (tonumber(r.buckets[key]) or 0) + 1
  r.buckets[key] = pulse
  local phase = entry.tech_priests_0598_phase
  if phase == nil then
    phase = stable_hash(key)
    entry.tech_priests_0598_phase = phase
  end
  if ((pulse + phase) % window) ~= 0 then
    inc("deferred_" .. category)
    return false
  end
  inc("allowed_" .. category)
  return true
end

function M.install()
  root()
  _G.tech_priests_route_budget_0598 = function(entry, event, cadence)
    return M.route_budget(entry, event, cadence)
  end
  _G.tech_priests_broker_plan_0598 = M.broker_plan
  _G.tech_priests_broker_ran_0598 = M.broker_ran
  if commands and commands.add_command then
    pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0598") end end)
    commands.add_command("tp-efficiency-economy-0598", "Report/toggle Tech Priests cooperative parallelization route economy. Params: on/off/status", function(cmd)
      local r = root()
      local p = cmd and cmd.parameter or ""
      if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false end
      local player = cmd and cmd.player_index and game and game.get_player(cmd.player_index) or nil
      local lines = {
        "[tp-efficiency-economy-0598] enabled=" .. tostring(r.enabled) .. " pairs=" .. tostring(pair_count()),
      }
      local stats = r.stats or {}
      local keys = {}
      for k in pairs(stats) do keys[#keys+1] = k end
      table.sort(keys)
      for i = 1, math.min(#keys, 20) do
        lines[#lines+1] = "  " .. keys[i] .. "=" .. tostring(stats[keys[i]])
      end
      local msg = table.concat(lines, "\n")
      if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
    end)
  end
  return true
end

return M
