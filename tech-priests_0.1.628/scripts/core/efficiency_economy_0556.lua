-- scripts/core/efficiency_economy_0556.lua
-- Tech Priests 0.1.556
--
-- Runtime economy governor for the current authority stack.  This is not a new
-- behavior owner.  It tunes and wraps existing authorities so rejected work,
-- passive refreshes, diagnostics, and movement-service pulses do not hammer the
-- same pair every few ticks.

local M = {}
M.version = "0.1.556"
M.storage_key = "efficiency_economy_0556"
M.passive_refresh_cooldown_ticks = 60 * 10
M.general_refresh_cooldown_ticks = 60 * 3
M.rejected_target_cooldown_ticks = 60 * 8
M.duplicate_submit_cooldown_ticks = 90
M.service_cooldown_ticks = 180
M.compact_pair_dump_limit = 12

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function pos_text(pos) if type(pos)~="table" then return safe(pos) end return string.format("%.1f,%.1f", tonumber(pos.x) or 0, tonumber(pos.y) or 0) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    compact_diagnostics = true,
    stats = {},
    last_refresh = {},
    rejected_until = {},
    duplicate_until = {},
    service_until = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.compact_diagnostics == nil then r.compact_diagnostics = true end
  r.stats = r.stats or {}
  r.last_refresh = r.last_refresh or {}
  r.rejected_until = r.rejected_until or {}
  r.duplicate_until = r.duplicate_until or {}
  r.service_until = r.service_until or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n)
  local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1)
end

local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1]={tick=now(), action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent > 64 do table.remove(r.recent,1) end
end

local function is_passive_source(src)
  src = lower(src)
  return src == "mouse-over" or src == "radar-priest-scan" or src == "overview-ui" or src:find("overview",1,true) or src:find("gui",1,true) or src:find("refresh",1,true)
end

local function active_work(pair)
  if not pair then return false end
  local q = pair.order_queue_0469
  if q and q.current and q.current.status == "active" then return true end
  if pair.active_order_0469 and pair.active_order_0469.status == "active" then return true end
  if pair.movement_request_0418 or pair.movement_lease_0518 then return true end
  if pair.dispatcher_0510 and pair.dispatcher_0510.family and pair.dispatcher_0510.family ~= "idle" then return true end
  local mode = lower(pair.mode)
  return mode:find("travelling",1,true) or mode:find("moving",1,true) or mode:find("logistics%-writ",1,false) or mode:find("gather",1,true) or mode:find("craft",1,true)
end

local function tune_existing_modules()
  local ok0508, R0508 = pcall(require, "scripts.core.movement_recovery_authority_0508")
  if ok0508 and R0508 then
    R0508.travel_reissue_ticks = math.max(tonumber(R0508.travel_reissue_ticks or 0) or 0, 240)
    R0508.log_interval = math.max(tonumber(R0508.log_interval or 0) or 0, 1800)
  end
  local ok0509, B0509 = pcall(require, "scripts.core.behavior_stack_cleanup_0509")
  if ok0509 and B0509 then
    B0509.travel_reissue_ticks = math.max(tonumber(B0509.travel_reissue_ticks or 0) or 0, 300)
    B0509.refresh_debounce_ticks = math.max(tonumber(B0509.refresh_debounce_ticks or 0) or 0, 1200)
    B0509.cascade_debounce_ticks = math.max(tonumber(B0509.cascade_debounce_ticks or 0) or 0, 1800)
    B0509.log_interval = math.max(tonumber(B0509.log_interval or 0) or 0, 1800)
  end
  local ok0518, C0518 = pcall(require, "scripts.core.movement_cadence_contract_0518")
  if ok0518 and C0518 then
    C0518.command_refresh_ticks = math.max(tonumber(C0518.command_refresh_ticks or 0) or 0, 90)
    C0518.retarget_hold_ticks = math.max(tonumber(C0518.retarget_hold_ticks or 0) or 0, 180)
    C0518.minimum_retarget_distance_sq = math.max(tonumber(C0518.minimum_retarget_distance_sq or 0) or 0, 6.25)
  end
  local ok0468, D0468 = pcall(require, "scripts.core.diagnostics_behavior_authority_0468")
  if ok0468 and D0468 then
    D0468.default_interval_ticks = math.max(tonumber(D0468.default_interval_ticks or 0) or 0, 60 * 5)
    D0468.min_interval_ticks = math.max(tonumber(D0468.min_interval_ticks or 0) or 0, 60 * 2)
  end
  remember("tuned", "movement/log/cascade/diagnostic cadences raised")
end

local function wrap_service(module_path, label, cooldown)
  local ok, Mod = pcall(require, module_path)
  if not (ok and Mod and type(Mod.service_all)=="function") or Mod.efficiency_economy_0556_wrapped then return false end
  Mod.efficiency_economy_0556_wrapped = true
  Mod.TECH_PRIESTS_0556_PRE_SERVICE_ALL = Mod.service_all
  Mod.service_all = function(...)
    local r=M.root()
    if r.enabled == false then return Mod.TECH_PRIESTS_0556_PRE_SERVICE_ALL(...) end
    local key = label
    local until_tick = tonumber(r.service_until[key] or 0) or 0
    if now() < until_tick then stat("service_skipped_" .. label); return false end
    r.service_until[key] = now() + (cooldown or M.service_cooldown_ticks)
    stat("service_run_" .. label)
    return Mod.TECH_PRIESTS_0556_PRE_SERVICE_ALL(...)
  end
  return true
end

local function wrap_order_refresh()
  if type(_G.tech_priests_0270_refresh_orders_for_pair) ~= "function" or rawget(_G,"TECH_PRIESTS_0556_PRE_REFRESH_ORDERS") then return false end
  local prev = _G.tech_priests_0270_refresh_orders_for_pair
  _G.TECH_PRIESTS_0556_PRE_REFRESH_ORDERS = prev
  _G.tech_priests_0270_refresh_orders_for_pair = function(pair, source, ...)
    local r=M.root()
    if r.enabled ~= false and valid_pair(pair) then
      local src = tostring(source or "unknown")
      local passive = is_passive_source(src)
      local cd = passive and (active_work(pair) and M.passive_refresh_cooldown_ticks or M.general_refresh_cooldown_ticks) or 0
      if cd > 0 then
        local key = safe(station_unit(pair)) .. ":" .. src .. ":" .. safe(pair.mode)
        local last = tonumber(r.last_refresh[key] or -1000000) or -1000000
        if now() - last < cd then
          stat("refresh_blocked")
          pair.last_refresh_blocked_0556 = { tick = now(), source = src, cooldown = cd }
          return false
        end
        r.last_refresh[key] = now()
      end
    end
    return prev(pair, source, ...)
  end
  return true
end

local function rejection_key(pair, target)
  return safe(station_unit(pair)) .. ":" .. safe(target)
end

local function wrap_rejected_direct_targets()
  if type(_G.tech_priests_0273_find_direct_target) == "function" and not rawget(_G,"TECH_PRIESTS_0556_PRE_FIND_DIRECT_TARGET") then
    local prev = _G.tech_priests_0273_find_direct_target
    _G.TECH_PRIESTS_0556_PRE_FIND_DIRECT_TARGET = prev
    _G.tech_priests_0273_find_direct_target = function(pair, target, ...)
      local r=M.root()
      local key = rejection_key(pair, target)
      if r.enabled ~= false and (tonumber(r.rejected_until[key] or 0) or 0) > now() then
        stat("direct_target_rejection_cooldown")
        return nil
      end
      local result = prev(pair, target, ...)
      if result == nil and r.enabled ~= false then
        r.rejected_until[key] = now() + M.rejected_target_cooldown_ticks
        pair.last_direct_target_rejected_cooldown_0556 = { tick = now(), target = tostring(target), until_tick = r.rejected_until[key] }
        stat("direct_target_rejection_recorded")
      end
      return result
    end
  end

  if type(_G.tech_priests_0273_begin_dirt) == "function" and not rawget(_G,"TECH_PRIESTS_0556_PRE_BEGIN_DIRT") then
    local prev = _G.tech_priests_0273_begin_dirt
    _G.TECH_PRIESTS_0556_PRE_BEGIN_DIRT = prev
    _G.tech_priests_0273_begin_dirt = function(pair, task, target, reason, ...)
      local r=M.root()
      local key = "dirt:" .. rejection_key(pair, target)
      if target ~= "stone" and r.enabled ~= false and (tonumber(r.rejected_until[key] or 0) or 0) > now() then
        stat("dirt_rejection_cooldown")
        if task then task.scan_due_tick = now() + M.rejected_target_cooldown_ticks end
        return false
      end
      local ok = prev(pair, task, target, reason, ...)
      if ok == false and target ~= "stone" and r.enabled ~= false then
        r.rejected_until[key] = now() + M.rejected_target_cooldown_ticks
        stat("dirt_rejection_recorded")
      end
      return ok
    end
  end
  return true
end

local function submission_key(pair, order)
  if not order then return nil end
  return safe(station_unit(pair)) .. ":" .. safe(order.key or (safe(order.kind) .. ":" .. safe(order.item or order.item_name or order.requested_item or order.output_item)))
end

local function wrap_order_queue_submit()
  local ok, OQ = pcall(require, "scripts.core.order_queue_0469")
  if not (ok and OQ and type(OQ.submit)=="function") or OQ.efficiency_economy_0556_wrapped then return false end
  OQ.efficiency_economy_0556_wrapped = true
  OQ.TECH_PRIESTS_0556_PRE_SUBMIT = OQ.submit
  OQ.submit = function(pair, order, opts, ...)
    local r=M.root()
    local key = submission_key(pair, order)
    if r.enabled ~= false and key and (tonumber(r.duplicate_until[key] or 0) or 0) > now() then
      stat("submission_cooldown_blocked")
      return false, "economy-cooldown", pair and pair.active_order_0469
    end
    local a,b,c = OQ.TECH_PRIESTS_0556_PRE_SUBMIT(pair, order, opts, ...)
    if r.enabled ~= false and key and (b == "duplicate" or b == "queued") then
      r.duplicate_until[key] = now() + M.duplicate_submit_cooldown_ticks
      stat("submission_cooldown_recorded")
    end
    return a,b,c
  end
  return true
end

local function compact_pair_dump_lines()
  local lines = {}
  local total, active, moving, queued = 0,0,0,0
  local rows = {}
  for key,pair in pairs(pair_map()) do
    total = total + 1
    local q = pair and pair.order_queue_0469
    local pending = q and q.pending and #q.pending or 0
    if active_work(pair) then active = active + 1 end
    if pair and (pair.movement_request_0418 or pair.movement_lease_0518 or lower(pair.mode):find("travelling",1,true)) then moving = moving + 1 end
    queued = queued + pending
    if active_work(pair) or pending > 0 or total <= 4 then rows[#rows+1] = { key=tostring(key), pair=pair, pending=pending } end
  end
  table.sort(rows, function(a,b) return tostring(a.key) < tostring(b.key) end)
  local r = M.root()
  lines[#lines+1] = "BEGIN compact-0556 pair_count=" .. safe(total) .. " active=" .. safe(active) .. " moving=" .. safe(moving) .. " pending_orders=" .. safe(queued)
    .. " refresh_blocked=" .. safe(r.stats.refresh_blocked or 0)
    .. " rejection_cooldowns=" .. safe((r.stats.direct_target_rejection_cooldown or 0) + (r.stats.dirt_rejection_cooldown or 0))
    .. " submit_cooldowns=" .. safe(r.stats.submission_cooldown_blocked or 0)
  local limit = M.compact_pair_dump_limit
  for i,row in ipairs(rows) do
    if i > limit then lines[#lines+1] = "compact-0556 omitted_rows=" .. safe(#rows - limit); break end
    local pair=row.pair or {}
    local q=pair.order_queue_0469 or {}
    local cur=q.current or pair.active_order_0469 or {}
    local req=pair.movement_request_0418 or pair.movement_lease_0518 or {}
    lines[#lines+1] = "pair[" .. row.key .. "] station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair))
      .. " mode=" .. safe(pair.mode)
      .. " order=" .. safe(cur.key) .. "/" .. safe(cur.status)
      .. " pending=" .. safe(row.pending)
      .. " move=" .. safe(req.owner or req.reason) .. "@" .. pos_text(req)
  end
  lines[#lines+1] = "END compact-0556"
  return lines
end

local function wrap_pair_dump_compact()
  local diag = rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.efficiency_economy_0556_wrapped then return false end
  diag.efficiency_economy_0556_wrapped = true
  diag.TECH_PRIESTS_0556_PRE_PAIR_DUMP_LINES = diag.pair_dump_lines
  diag.pair_dump_lines = function()
    local r=M.root()
    if r.enabled ~= false and r.compact_diagnostics ~= false then return compact_pair_dump_lines() end
    return diag.TECH_PRIESTS_0556_PRE_PAIR_DUMP_LINES()
  end
  return true
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0556") end end)
  commands.add_command("tp-efficiency-economy-0556", "Tech Priests 0.1.556 efficiency economy governor. Params: on/off/compact/verbose/status", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r=M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "compact" then r.compact_diagnostics = true end
    if p == "verbose" then r.compact_diagnostics = false end
    local msg = "[tp-efficiency-economy-0556] enabled=" .. safe(r.enabled)
      .. " compact_diagnostics=" .. safe(r.compact_diagnostics)
      .. " refresh_blocked=" .. safe(r.stats.refresh_blocked or 0)
      .. " rejection_cd=" .. safe((r.stats.direct_target_rejection_cooldown or 0) + (r.stats.dirt_rejection_cooldown or 0))
      .. " submit_cd=" .. safe(r.stats.submission_cooldown_blocked or 0)
      .. " service_skips=" .. safe((r.stats.service_skipped_0508 or 0) + (r.stats.service_skipped_0509 or 0))
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  tune_existing_modules()
  wrap_service("scripts.core.movement_recovery_authority_0508", "0508", 180)
  wrap_service("scripts.core.behavior_stack_cleanup_0509", "0509", 180)
  wrap_order_refresh()
  wrap_rejected_direct_targets()
  wrap_order_queue_submit()
  wrap_pair_dump_compact()
  install_command()
  _G.TechPriestsEfficiencyEconomy0556 = M
  if log then log("[Tech-Priests 0.1.556] efficiency economy governor installed; passive refreshes, repeated rejection loops, duplicate submissions, diagnostics, and legacy service pulses are cooldown-governed") end
  return true
end

return M
