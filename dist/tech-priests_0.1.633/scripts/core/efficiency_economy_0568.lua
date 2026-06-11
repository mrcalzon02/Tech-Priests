-- scripts/core/efficiency_economy_0568.lua
-- Tech Priests 0.1.568
--
-- Economy/efficiency pass for large priest deployments.  This module is a
-- governor over existing authorities.  It does not create work, move priests,
-- choose targets, mine, repair, consecrate, construct, or complete tasks.  It
-- reduces churn by rate-limiting diagnostic/log spam, staggering selected
-- service loops, pacing resource-expansion scans, and pruning old scan caches.

local M = {}
M.version = "0.1.568"
M.storage_key = "efficiency_economy_0568"

M.heartbeat_cooldown_ticks = 60 * 60
M.no_active_heartbeat_cooldown_ticks = 60 * 120
M.order_refresh_log_cooldown_ticks = 60 * 10
M.raw_fallback_log_cooldown_ticks = 60 * 30
M.generic_repeated_log_cooldown_ticks = 60 * 5

M.resource_initial_defer_min_ticks = 60 * 10
M.resource_phase_span_ticks = 60 * 90
M.resource_scan_window_ticks = 60 * 10
M.resource_scans_per_window = 2
M.resource_pair_retry_ticks = 60 * 45

M.cache_prune_interval_ticks = 60 * 60
M.radar_seen_keep_ticks = 60 * 60 * 12
M.expansion_seen_keep_ticks = 60 * 60 * 6

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function pos_text(pos)
  if type(pos) ~= "table" then return safe(pos) end
  return string.format("%.1f,%.1f", tonumber(pos.x) or tonumber(pos[1]) or 0, tonumber(pos.y) or tonumber(pos[2]) or 0)
end
local function hash_text(text)
  text = tostring(text or "")
  local h = 0
  for i = 1, #text do h = (h * 33 + string.byte(text, i)) % 2147483647 end
  return h
end
local function active_work(pair)
  if not pair then return false end
  local q = pair.order_queue_0469
  if q and q.current and q.current.status == "active" then return true end
  if pair.active_order_0469 and pair.active_order_0469.status == "active" then return true end
  if pair.dispatcher_0510 and pair.dispatcher_0510.family and pair.dispatcher_0510.family ~= "idle" then return true end
  if pair.movement_request_0418 or pair.movement_lease_0518 then return true end
  local mode = lower(pair.mode)
  return mode:find("emergency",1,true) or mode:find("gather",1,true) or mode:find("craft",1,true) or mode:find("logistics",1,true) or mode:find("return",1,true)
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version = M.version, enabled = true, compact_diagnostics = true, log_until = {}, stats = {}, nth_next = {}, resource_window = {}, recent = {} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.compact_diagnostics == nil then r.compact_diagnostics = true end
  r.log_until = r.log_until or {}
  r.stats = r.stats or {}
  r.nth_next = r.nth_next or {}
  r.resource_window = r.resource_window or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root(); r.recent[#r.recent+1]={tick=now(), action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent > 40 do table.remove(r.recent, 1) end
end

local function cooldown_key_for_log(message)
  local msg = tostring(message or "")
  if msg:find("heartbeat: no active emergency operations", 1, true) == 1 then
    return "heartbeat:no-active", M.no_active_heartbeat_cooldown_ticks, "heartbeat_no_active_suppressed"
  end
  if msg:find("heartbeat:", 1, true) == 1 then
    local station = msg:match("station=([^%s]+)") or msg:match("(.-) mode=") or msg
    local mode = msg:match(" mode=([^%s]+)") or "?"
    local blocker = msg:match(" blocker=([^%s]+)") or "?"
    return "heartbeat:" .. station .. ":" .. mode .. ":" .. blocker, M.heartbeat_cooldown_ticks, "heartbeat_suppressed"
  end
  if msg:find("orders refreshed", 1, true) == 1 then
    local st = msg:match("station=([^%s]+)") or "?"
    local src = msg:match("source=([^%s]+)") or "?"
    local mode = msg:match("mode=([^%s]+)") or "?"
    return "orders:" .. st .. ":" .. src .. ":" .. mode, M.order_refresh_log_cooldown_ticks, "order_refresh_log_suppressed"
  end
  if msg:find("raw fallback candidate", 1, true) then
    local st = msg:match("station=([^%s]+)") or "?"
    local req = msg:match("requested=([^%s]+)") or "?"
    local item = msg:match("item=([^%s]+)") or "?"
    return "raw-fallback:" .. st .. ":" .. req .. ":" .. item, M.raw_fallback_log_cooldown_ticks, "raw_fallback_log_suppressed"
  end
  if msg:find("radar", 1, true) or msg:find("candidate", 1, true) then
    return "generic:" .. msg, M.generic_repeated_log_cooldown_ticks, "generic_repeated_log_suppressed"
  end
  return nil, 0, nil
end

local function wrap_log_output()
  if type(_G.tech_priests_0264_log) ~= "function" or rawget(_G, "TECH_PRIESTS_0568_PRE_0264_LOG") then return false end
  local prev = _G.tech_priests_0264_log
  _G.TECH_PRIESTS_0568_PRE_0264_LOG = prev
  _G.tech_priests_0264_log = function(message, ...)
    local r = M.root()
    if r.enabled ~= false then
      local key, cd, stat_key = cooldown_key_for_log(message)
      if key and cd and cd > 0 then
        local until_tick = tonumber(r.log_until[key] or 0) or 0
        if now() < until_tick then
          stat(stat_key or "log_suppressed")
          return false
        end
        r.log_until[key] = now() + cd
      end
    end
    return prev(message, ...)
  end
  return true
end

local function compact_pair_dump_lines()
  local total, valid_stations, valid_priests, active, moving, queued = 0,0,0,0,0,0
  local rows = {}
  for key,pair in pairs(pair_map()) do
    total = total + 1
    if pair and valid(pair.station) then valid_stations = valid_stations + 1 end
    if pair and valid(pair.priest) then valid_priests = valid_priests + 1 end
    local q = pair and pair.order_queue_0469 or nil
    local pending = q and q.pending and #q.pending or 0
    local cur = (q and q.current) or (pair and pair.active_order_0469) or nil
    local is_active = active_work(pair)
    if is_active then active = active + 1 end
    if pair and (pair.movement_request_0418 or pair.movement_lease_0518 or lower(pair.mode):find("return",1,true)) then moving = moving + 1 end
    queued = queued + pending
    if is_active or pending > 0 or total <= 6 then rows[#rows+1] = { key=tostring(key), pair=pair, pending=pending, cur=cur } end
  end
  table.sort(rows, function(a,b) return tostring(a.key) < tostring(b.key) end)
  local r=M.root()
  local lines = {}
  lines[#lines+1] = "BEGIN compact-0568 pair_count="..safe(total).." valid_stations="..safe(valid_stations).." valid_priests="..safe(valid_priests)
    .." active="..safe(active).." moving="..safe(moving).." pending_orders="..safe(queued)
    .." heartbeat_suppressed="..safe(r.stats.heartbeat_suppressed or 0)
    .." order_refresh_suppressed="..safe(r.stats.order_refresh_log_suppressed or 0)
    .." resource_scans_deferred="..safe(r.stats.resource_scan_deferred or 0)
    .." nth_skipped="..safe(r.stats.nth_handler_skipped or 0)
  local limit = 14
  for i,row in ipairs(rows) do
    if i > limit then lines[#lines+1] = "compact-0568 omitted_rows="..safe(#rows-limit); break end
    local pair=row.pair or {}
    local req=pair.movement_request_0418 or pair.movement_lease_0518 or {}
    local cur=row.cur or {}
    lines[#lines+1] = "pair["..safe(row.key).."] station="..safe(station_unit(pair)).." priest="..safe(priest_unit(pair))
      .." mode="..safe(pair.mode).." order="..safe(cur.key).."/"..safe(cur.status).." pending="..safe(row.pending)
      .." move="..safe(req.owner or req.reason).."@"..pos_text(req)
  end
  lines[#lines+1] = "END compact-0568"
  return lines
end

local function write_pair_dump_line(text)
  if type(_G.tech_priests_0264_log) == "function" then
    local ok = pcall(function() _G.tech_priests_0264_log("PAIR-DUMP-0468 " .. tostring(text or ""), true) end)
    if ok then return true end
  end
  if helpers and helpers.write_file then
    local line = "[Tech-Priests "..M.version.."][tick "..safe(now()).."] PAIR-DUMP-0468 "..tostring(text or "").."\n"
    local ok = pcall(function() helpers.write_file("tech-priests-emergency-diagnostics.log", line, true) end)
    if ok then return true end
  end
  return false
end

local function wrap_diagnostics_compact()
  local diag = rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.write_pair_dump)=="function") or diag.efficiency_economy_0568_write_wrapped then return false end
  diag.efficiency_economy_0568_write_wrapped = true
  diag.TECH_PRIESTS_0568_PRE_WRITE_PAIR_DUMP = diag.write_pair_dump
  diag.write_pair_dump = function(reason, force)
    local r=M.root()
    if r.enabled ~= false and r.compact_diagnostics ~= false then
      write_pair_dump_line("reason="..safe(reason or "periodic").." compact=0568")
      for _,line in ipairs(compact_pair_dump_lines()) do write_pair_dump_line(line) end
      stat("compact_pair_dumps")
      return true
    end
    return diag.TECH_PRIESTS_0568_PRE_WRITE_PAIR_DUMP(reason, force)
  end
  if type(diag.pair_dump_lines)=="function" and not diag.efficiency_economy_0568_lines_wrapped then
    diag.efficiency_economy_0568_lines_wrapped = true
    diag.TECH_PRIESTS_0568_PRE_PAIR_DUMP_LINES = diag.pair_dump_lines
    diag.pair_dump_lines = function(...)
      local r=M.root()
      if r.enabled ~= false and r.compact_diagnostics ~= false then return compact_pair_dump_lines() end
      return diag.TECH_PRIESTS_0568_PRE_PAIR_DUMP_LINES(...)
    end
  end
  return true
end

local function wrap_resource_expansion()
  if type(_G.tech_priests_0259_resource_expansion_service) ~= "function" or rawget(_G,"TECH_PRIESTS_0568_PRE_RESOURCE_EXPANSION") then return false end
  local prev = _G.tech_priests_0259_resource_expansion_service
  _G.TECH_PRIESTS_0568_PRE_RESOURCE_EXPANSION = prev
  _G.tech_priests_0259_resource_expansion_service = function(pair, ...)
    local r=M.root()
    if r.enabled ~= false and valid_pair(pair) then
      local unit = tonumber(station_unit(pair) or 0) or 0
      local state = pair.resource_expansion_0259 or {}
      pair.resource_expansion_0259 = state
      if not state.economy_seeded_0568 then
        state.economy_seeded_0568 = true
        state.next_tick = math.max(tonumber(state.next_tick or 0) or 0, now() + M.resource_initial_defer_min_ticks + (unit % M.resource_phase_span_ticks))
        pair.resource_expansion_phase_0568 = unit % M.resource_phase_span_ticks
        stat("resource_initial_phased")
        return false
      end
      local next_allowed = tonumber(pair.resource_expansion_next_allowed_0568 or 0) or 0
      if now() < next_allowed then stat("resource_pair_cooldown"); return false end
      local window = math.floor(now() / M.resource_scan_window_ticks)
      if r.resource_window.id ~= window then r.resource_window = { id=window, scans=0 } end
      if (r.resource_window.scans or 0) >= M.resource_scans_per_window then
        state.next_tick = now() + M.resource_scan_window_ticks + (unit % 600)
        pair.resource_expansion_next_allowed_0568 = state.next_tick
        stat("resource_scan_deferred")
        return false
      end
      r.resource_window.scans = (r.resource_window.scans or 0) + 1
      pair.resource_expansion_next_allowed_0568 = now() + M.resource_pair_retry_ticks + (unit % 600)
      stat("resource_scan_allowed")
    end
    return prev(pair, ...)
  end
  return true
end

local nth_min_intervals = {
  movement_recovery_authority_0508 = 60 * 5,
  mobility_recovery_contract_0506 = 60 * 5,
  behavior_stack_cleanup_0509 = 60 * 5,
  acquisition_unstick = 60 * 4,
  acquisition_repair = 60 * 3,
  magos_planning_queue_0471 = 60 * 5,
  network_visuals = 60 * 2,
  workstate_gui_radar_recovery_0465 = 60,
  operational_sounds_0531 = 60 * 2,
}

local function wrap_nth_tick_registry()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if not (R and type(R.nth_tick_routes)=="table") then return false end
  local wrapped = 0
  for tick, route in pairs(R.nth_tick_routes) do
    if type(route)=="table" then
      for _, entry in ipairs(route) do
        if entry and type(entry.handler)=="function" and not entry.efficiency_0568_wrapped then
          local owner = tostring(entry.owner or "")
          local min_interval = nth_min_intervals[owner]
          if min_interval then
            local prev = entry.handler
            entry.efficiency_0568_wrapped = true
            entry.TECH_PRIESTS_0568_PRE_HANDLER = prev
            entry.handler = function(event)
              local r=M.root()
              if r.enabled == false then return prev(event) end
              local key = "nth:"..owner..":"..safe(tick)
              local next_tick = tonumber(r.nth_next[key] or -1) or -1
              if next_tick < 0 then
                r.nth_next[key] = now() + (hash_text(key) % min_interval)
                stat("nth_handler_phased")
                return false
              end
              if now() < next_tick then stat("nth_handler_skipped"); return false end
              r.nth_next[key] = now() + min_interval
              stat("nth_handler_run")
              return prev(event)
            end
            wrapped = wrapped + 1
          end
        end
      end
    end
  end
  if wrapped > 0 then remember("nth-wrapped", "wrapped="..safe(wrapped)) end
  return wrapped > 0
end

local function prune_cache_table(tbl, keep_ticks)
  if type(tbl) ~= "table" then return 0 end
  local n = 0
  for k,v in pairs(tbl) do
    if type(v)=="number" and now() - v > keep_ticks then tbl[k]=nil; n=n+1 end
  end
  return n
end

function M.service()
  local r=M.root()
  if r.enabled == false then return end
  local econ557 = storage and storage.tech_priests and storage.tech_priests.efficiency_economy_0557 or nil
  if econ557 then
    local a = prune_cache_table(econ557.radar_seen, M.radar_seen_keep_ticks)
    local b = prune_cache_table(econ557.expansion_seen, M.expansion_seen_keep_ticks)
    if a+b > 0 then stat("cache_entries_pruned", a+b); remember("cache-prune", "entries="..safe(a+b)) end
  end
  local rlog = r.log_until or {}
  local removed = 0
  for k,v in pairs(rlog) do if type(v)=="number" and now() > v + 60 * 30 then rlog[k]=nil; removed=removed+1 end end
  if removed > 0 then stat("log_cooldowns_pruned", removed) end
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0568") end end)
  commands.add_command("tp-efficiency-economy-0568", "Tech Priests 0.1.568 economy pass. Params: on/off/compact/verbose/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true elseif param=="off" then r.enabled=false elseif param=="compact" then r.compact_diagnostics=true elseif param=="verbose" then r.compact_diagnostics=false end
    local msg = "[tp-efficiency-economy-0568] enabled="..safe(r.enabled).." compact="..safe(r.compact_diagnostics)
      .." heartbeat_suppressed="..safe(r.stats.heartbeat_suppressed or 0)
      .." order_refresh_suppressed="..safe(r.stats.order_refresh_log_suppressed or 0)
      .." raw_fallback_suppressed="..safe(r.stats.raw_fallback_log_suppressed or 0)
      .." resource_deferred="..safe(r.stats.resource_scan_deferred or 0)
      .." nth_skipped="..safe(r.stats.nth_handler_skipped or 0)
      .." compact_dumps="..safe(r.stats.compact_pair_dumps or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  wrap_log_output()
  wrap_diagnostics_compact()
  wrap_resource_expansion()
  wrap_nth_tick_registry()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.cache_prune_interval_ticks, function() M.service() end, { owner="efficiency_economy_0568", category="economy", note="prune memoization/cooldown tables" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.cache_prune_interval_ticks, function() M.service() end)
  end
  install_command()
  _G.TechPriestsEfficiencyEconomy0568 = M
  if log then log("[Tech-Priests 0.1.568] economy governor installed; compact diagnostics, rate-limited heartbeat/order-refresh logging, phased resource-expansion scans, selected staggered services, and cache pruning enabled") end
  return true
end

return M
