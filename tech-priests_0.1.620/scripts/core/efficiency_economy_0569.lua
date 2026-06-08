-- scripts/core/efficiency_economy_0569.lua
-- Tech Priests 0.1.569
--
-- First budgeted-scheduler economy pass.  This is deliberately a governor over
-- existing authority layers, not a new behavior controller.  It does not choose
-- work, move priests, mine, repair, consecrate, construct, or complete orders.
-- It begins the long-term megabase performance plan by making the dispatcher and
-- selected background services run in small rolling buckets, while preserving
-- the scheduler -> dispatcher -> executor route.

local M = {}
M.version = "0.1.569"
M.storage_key = "efficiency_economy_0569"

-- Tuned conservatively.  Active pairs still receive frequent service, idle pairs
-- are sampled slowly so hundreds of idle priests do not all cost work together.
M.dispatcher_active_budget = 10
M.dispatcher_idle_budget = 4
M.idle_pair_rescan_ticks = 60 * 5
M.full_pair_reindex_ticks = 60 * 30
M.dirty_region_keep_ticks = 60 * 60 * 10
M.dirty_region_prune_ticks = 60 * 60

-- Stronger background cadence floors for systems that are reporters/recovery
-- guards rather than live action executors.
M.owner_min_intervals = {
  action_state_arbiter_0488 = 60,
  overhead_status_governor_0471 = 60,
  overhead_text_authority_0473 = 60,
  status_churn_damper_0532 = 60 * 2,
  station_network_overlay = 60 * 2,
  scan_beam_controller_0529 = 60,
  self_station_scan_visual_authority_0489 = 60,
  radar_afterglow = 60 * 3,
  network_visuals = 60 * 3,
  ground_item_hoover_0529 = 60 * 2,
  conversation_voice_0530 = 60 * 5,
  chatter = 60 * 5,
  idle_priest_conversations = 60 * 5,
  idle_player_conversations = 60 * 5,
  operational_sounds_0531 = 60 * 3,
  task_pair_audit_0498 = 60 * 10,
  diagnostics_behavior_authority_0468 = 60 * 10,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function hash_text(text) text=tostring(text or ""); local h=0; for i=1,#text do h=(h*33+string.byte(text,i))%2147483647 end; return h end

local function active_work(pair)
  if not pair then return false end
  local q = pair.order_queue_0469
  if q and q.current and q.current.status == "active" then return true end
  if pair.active_order_0469 and pair.active_order_0469.status == "active" then return true end
  if pair.dispatcher_0510 and pair.dispatcher_0510.family and pair.dispatcher_0510.family ~= "idle" then return true end
  if pair.movement_request_0418 or pair.movement_lease_0518 then return true end
  local mode = lower(pair.mode)
  return mode:find("emergency",1,true) or mode:find("gather",1,true) or mode:find("craft",1,true)
    or mode:find("logistics",1,true) or mode:find("return",1,true) or mode:find("repair",1,true)
    or mode:find("consecr",1,true) or mode:find("combat",1,true)
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      dispatcher_bucket_enabled = true,
      background_bucket_enabled = true,
      dirty_tracking_enabled = true,
      pair_cursor = 0,
      indexed_tick = -1,
      pair_index = {},
      nth_next = {},
      dirty_regions = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_bucket_enabled == nil then r.dispatcher_bucket_enabled = true end
  if r.background_bucket_enabled == nil then r.background_bucket_enabled = true end
  if r.dirty_tracking_enabled == nil then r.dirty_tracking_enabled = true end
  r.pair_index = r.pair_index or {}
  r.nth_next = r.nth_next or {}
  r.dirty_regions = r.dirty_regions or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root(); r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 48 do table.remove(r.recent, 1) end
end

local function rebuild_pair_index(force)
  local r=M.root()
  local current_count = 0
  for _,pair in pairs(pair_map()) do if valid_pair(pair) then current_count = current_count + 1 end end
  if not force and (now() - (tonumber(r.indexed_tick or -1000000) or -1000000) < M.full_pair_reindex_ticks) and #(r.pair_index or {}) > 0 and #(r.pair_index or {}) == current_count then return r.pair_index end
  local rows = {}
  for key,pair in pairs(pair_map()) do
    if valid_pair(pair) then rows[#rows+1] = { key = tonumber(station_unit(pair) or key) or 0, pair = pair } end
  end
  table.sort(rows, function(a,b) return (a.key or 0) < (b.key or 0) end)
  r.pair_index = rows
  r.indexed_tick = now()
  if r.pair_cursor > #rows then r.pair_cursor = 0 end
  stat("pair_index_rebuilt")
  return rows
end

local function service_dispatcher_bucket(D, reason)
  local r=M.root()
  if r.enabled == false or r.dispatcher_bucket_enabled == false then return D.TECH_PRIESTS_0569_PRE_SERVICE_ALL(reason) end
  if type(D.service_pair) ~= "function" then return D.TECH_PRIESTS_0569_PRE_SERVICE_ALL(reason) end
  local rows = rebuild_pair_index(false)
  local count = #rows
  if count == 0 then return 0 end

  local active_budget = M.dispatcher_active_budget
  local idle_budget = M.dispatcher_idle_budget
  local active_done, idle_done, visited = 0, 0, 0
  local cursor = tonumber(r.pair_cursor or 0) or 0
  D.root().dispatching = true
  while visited < count and (active_done < active_budget or idle_done < idle_budget) do
    cursor = (cursor % count) + 1
    visited = visited + 1
    local pair = rows[cursor] and rows[cursor].pair or nil
    if valid_pair(pair) then
      local is_active = active_work(pair)
      local due_idle = now() >= (tonumber(pair.next_idle_dispatch_0569 or 0) or 0)
      if is_active and active_done < active_budget then
        local ok = pcall(D.service_pair, pair, reason or "bucket-0569-active")
        if ok then active_done = active_done + 1; stat("dispatcher_active_serviced") end
      elseif (not is_active) and idle_done < idle_budget and due_idle then
        pair.next_idle_dispatch_0569 = now() + M.idle_pair_rescan_ticks + ((tonumber(station_unit(pair) or 0) or 0) % 300)
        local ok = pcall(D.service_pair, pair, reason or "bucket-0569-idle")
        if ok then idle_done = idle_done + 1; stat("dispatcher_idle_serviced") end
      else
        stat(is_active and "dispatcher_active_deferred" or "dispatcher_idle_deferred")
      end
    end
  end
  r.pair_cursor = cursor
  D.root().dispatching = false
  return active_done + idle_done
end

local function wrap_dispatcher()
  local ok, D = pcall(require, "scripts.core.single_dispatcher_0510")
  if not (ok and D and type(D.service_all)=="function") or D.efficiency_economy_0569_wrapped then return false end
  D.efficiency_economy_0569_wrapped = true
  D.TECH_PRIESTS_0569_PRE_SERVICE_ALL = D.service_all
  D.service_all = function(reason, ...)
    return service_dispatcher_bucket(D, reason, ...)
  end
  remember("dispatcher-bucket", "active_budget="..safe(M.dispatcher_active_budget).." idle_budget="..safe(M.dispatcher_idle_budget))
  return true
end

local function wrap_nth_tick_registry()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if not (R and type(R.nth_tick_routes)=="table") then return false end
  local wrapped = 0
  for tick, route in pairs(R.nth_tick_routes) do
    if type(route)=="table" then
      for _, entry in ipairs(route) do
        if entry and type(entry.handler)=="function" and not entry.efficiency_0569_wrapped then
          local owner = tostring(entry.owner or "")
          local min_interval = M.owner_min_intervals[owner]
          if min_interval and min_interval > 0 then
            local prev = entry.handler
            entry.efficiency_0569_wrapped = true
            entry.TECH_PRIESTS_0569_PRE_HANDLER = prev
            entry.handler = function(event)
              local r=M.root()
              if r.enabled == false or r.background_bucket_enabled == false then return prev(event) end
              local key = "nth:"..owner..":"..safe(tick)
              local next_tick = tonumber(r.nth_next[key] or -1) or -1
              if next_tick < 0 then
                r.nth_next[key] = now() + (hash_text(key) % min_interval)
                stat("background_phased")
                return false
              end
              if now() < next_tick then stat("background_skipped_"..owner); stat("background_skipped_total"); return false end
              r.nth_next[key] = now() + min_interval
              stat("background_run_"..owner); stat("background_run_total")
              return prev(event)
            end
            wrapped = wrapped + 1
          end
        end
      end
    end
  end
  if wrapped > 0 then remember("background-bucket", "wrapped="..safe(wrapped)) end
  return wrapped > 0
end

local function surface_key(surface)
  if not surface then return "nil" end
  return tostring(surface.index or surface.name or "surface")
end

local function mark_dirty(entity, reason)
  local r=M.root()
  if r.enabled == false or r.dirty_tracking_enabled == false then return end
  if not valid(entity) then return end
  local pos = entity.position or {x=0,y=0}
  local sx, sy = math.floor((pos.x or 0) / 32), math.floor((pos.y or 0) / 32)
  local key = surface_key(entity.surface)..":"..sx..":"..sy
  local rec = r.dirty_regions[key] or { surface = surface_key(entity.surface), x = sx, y = sy, first_tick = now(), count = 0 }
  rec.last_tick = now(); rec.reason = tostring(reason or "changed"); rec.count = (rec.count or 0) + 1
  r.dirty_regions[key] = rec
  stat("dirty_region_marks")
end

local function install_dirty_events()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  local events = defines and defines.events or nil
  if not (R and R.on_event and events) then return false end
  local ids = {
    events.on_built_entity,
    events.on_robot_built_entity,
    events.script_raised_built,
    events.script_raised_revive,
    events.on_player_mined_entity,
    events.on_robot_mined_entity,
    events.on_entity_died,
    events.script_raised_destroy,
  }
  R.on_event(ids, function(event)
    local e = event and (event.entity or event.created_entity or event.destination)
    mark_dirty(e, event and event.name or "entity-change")
  end, nil, { owner="efficiency_economy_0569", category="dirty-region", note="record entity changes for later event-driven scan queues" })
  remember("dirty-events", "installed")
  return true
end

function M.service()
  local r=M.root()
  local removed = 0
  for k,rec in pairs(r.dirty_regions or {}) do
    if type(rec) ~= "table" or now() - (tonumber(rec.last_tick or 0) or 0) > M.dirty_region_keep_ticks then r.dirty_regions[k]=nil; removed=removed+1 end
  end
  if removed > 0 then stat("dirty_regions_pruned", removed) end
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0569") end end)
  commands.add_command("tp-efficiency-economy-0569", "Tech Priests 0.1.569 budgeted economy governor. Params: on/off/dispatcher-on/dispatcher-off/background-on/background-off/dirty-on/dirty-off/reindex/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true elseif param=="off" then r.enabled=false
    elseif param=="dispatcher-on" then r.dispatcher_bucket_enabled=true elseif param=="dispatcher-off" then r.dispatcher_bucket_enabled=false
    elseif param=="background-on" then r.background_bucket_enabled=true elseif param=="background-off" then r.background_bucket_enabled=false
    elseif param=="dirty-on" then r.dirty_tracking_enabled=true elseif param=="dirty-off" then r.dirty_tracking_enabled=false
    elseif param=="reindex" then rebuild_pair_index(true) end
    local dirty_count=0; for _ in pairs(r.dirty_regions or {}) do dirty_count=dirty_count+1 end
    local msg = "[tp-efficiency-economy-0569] enabled="..safe(r.enabled)
      .." dispatcher_bucket="..safe(r.dispatcher_bucket_enabled).." background_bucket="..safe(r.background_bucket_enabled)
      .." dirty_tracking="..safe(r.dirty_tracking_enabled).." pairs_indexed="..safe(#(r.pair_index or {}))
      .." active_serviced="..safe(r.stats.dispatcher_active_serviced or 0).." idle_serviced="..safe(r.stats.dispatcher_idle_serviced or 0)
      .." active_deferred="..safe(r.stats.dispatcher_active_deferred or 0).." idle_deferred="..safe(r.stats.dispatcher_idle_deferred or 0)
      .." background_skipped="..safe(r.stats.background_skipped_total or 0).." dirty_regions="..safe(dirty_count)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  wrap_dispatcher()
  wrap_nth_tick_registry()
  install_dirty_events()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.dirty_region_prune_ticks, function() M.service() end, { owner="efficiency_economy_0569", category="economy", note="prune dirty-region cache" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.dirty_region_prune_ticks, function() M.service() end)
  end
  install_command()
  _G.TechPriestsEfficiencyEconomy0569 = M
  if log then log("[Tech-Priests 0.1.569] budgeted economy governor installed; dispatcher buckets, background service buckets, and dirty-region cache scaffold enabled") end
  return true
end

return M
