-- scripts/core/scheduler_contract_0512.lua
-- Tech Priests 0.1.512
--
-- Scheduler contract pass.  The dispatcher now owns the per-pair runtime pulse,
-- but the legacy planning side can still submit and refresh too aggressively.
-- This module makes the order queue a stable intent authority: active work gets
-- a lease, passive refreshes cannot churn the current order, and strategic
-- Planetary Magos cascade/planning pulses are cooldown-gated while work is
-- already underway.

local M = {}
M.version = "0.1.512"
M.storage_key = "scheduler_contract_0512"

M.active_order_lease_ticks = 60 * 12
M.same_family_debounce_ticks = 60 * 4
M.passive_refresh_block_ticks = 60 * 20
M.cascade_cooldown_ticks = 60 * 30
M.dispatcher_context_ticks = 60 * 5
M.queue_limit_soft = 8
M.tick_interval = 37

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local passive_sources = {
  ["mouse-over"] = true,
  ["radar-priest-scan"] = true,
  ["overview-ui"] = true,
  ["command-overview"] = true,
  ["gui-refresh"] = true,
  ["workstate-gui"] = true,
}

local strategic_sources = {
  emergency_acquire = true,
  doctrine_handle_no_source = true,
  doctrine_start_direct = true,
  magos_planning = true,
  resource_expansion = true,
}

local interrupt_kinds = {
  combat = true,
  defense = true,
  repair = true,
  validate = true,
}

local function normalize_kind(kind)
  local k = lower(kind)
  if k == "" then return "idle" end
  if k:find("combat", 1, true) or k:find("defend", 1, true) or k:find("laser%-fallback") then return "combat" end
  if k:find("repair", 1, true) then return "repair" end
  if k:find("consecr", 1, true) or k:find("sanct", 1, true) then return "consecration" end
  if k:find("assign", 1, true) then return "assignment" end
  if k:find("logistic", 1, true) or k:find("supply", 1, true) then return "logistics" end
  if k:find("scavenge", 1, true) then return "scavenge" end
  if k:find("mine", 1, true) or k:find("acqui", 1, true) or k:find("gather", 1, true) or k:find("resource", 1, true) then return "acquisition" end
  if k:find("emergency", 1, true) or k:find("craft", 1, true) then return "emergency_craft" end
  return k
end

local function family_for(order)
  local k = normalize_kind(order and order.kind or nil)
  if k == "logistics" or k == "scavenge" or k == "acquisition" or k == "direct_mine" or k == "gather" then return "supply-acquisition" end
  if k == "emergency_craft" then return "station-craft" end
  if k == "combat" or k == "repair" or k == "consecration" or k == "assignment" then return k end
  return k ~= "" and k or "idle"
end

local function item_from(order)
  if type(order) ~= "table" then return nil end
  return order.item or order.item_name or order.output_item or order.wanted_item or order.requested_item or (order.task and (order.task.item or order.task.item_name or order.task.output_item or order.task.wanted_item or order.task.requested_item))
end

local function source_for(order)
  if type(order) ~= "table" then return "unknown" end
  return lower(order.source or order.reason or (order.task and (order.task.owner_system or order.task.source)) or "unknown")
end

local function is_passive_source(src)
  src = lower(src)
  if passive_sources[src] then return true end
  return src:find("mouse", 1, true) or src:find("overview", 1, true) or src:find("radar", 1, true) or src:find("gui", 1, true)
end

local function is_strategic_source(src)
  src = lower(src)
  if strategic_sources[src] then return true end
  return src:find("magos", 1, true) or src:find("cascade", 1, true) or src:find("resource%-expansion", 1, false) or src:find("doctrine", 1, true) or src:find("emergency", 1, true)
end

local function q_of(pair)
  return pair and pair.order_queue_0469 or nil
end

local function current_order(pair)
  local q = q_of(pair)
  return q and q.current or nil
end

local function order_active(order)
  if not order then return false end
  local s = lower(order.status or "active")
  return s ~= "complete" and s ~= "failed" and s ~= "cancelled"
end

local function active_work(pair)
  if not pair then return false end
  local cur = current_order(pair)
  if order_active(cur) then return true end
  local mode = lower(pair.mode)
  if mode:find("travelling", 1, true) or mode:find("gather", 1, true) or mode:find("mine", 1, true) or mode:find("craft", 1, true) or mode:find("scavenge", 1, true) or mode:find("construct", 1, true) then return true end
  if pair.emergency_craft or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333 or pair.scavenge or pair.active_task or pair.active_task_0285 then return true end
  return false
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stable_current = true,
    passive_refresh_guard = true,
    strategic_cooldown = true,
    fold_same_family = true,
    protect_dispatcher_current = true,
    stats = {},
    last_submission = {},
    last_refresh = {},
    last_cascade = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.stable_current == nil then r.stable_current = true end
  if r.passive_refresh_guard == nil then r.passive_refresh_guard = true end
  if r.strategic_cooldown == nil then r.strategic_cooldown = true end
  if r.fold_same_family == nil then r.fold_same_family = true end
  if r.protect_dispatcher_current == nil then r.protect_dispatcher_current = true end
  r.stats = r.stats or {}
  r.last_submission = r.last_submission or {}
  r.last_refresh = r.last_refresh or {}
  r.last_cascade = r.last_cascade or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, n)
  local r = M.root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function record(action, pair, detail)
  local r = M.root()
  stat(action)
  local ev = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 160 do table.remove(r.recent, 1) end
  return ev
end

local function submission_key(pair, order)
  local fam = family_for(order)
  local item = item_from(order) or "none"
  return safe(station_unit(pair)) .. ":" .. fam .. ":" .. safe(item)
end

local function same_family_item(a, b)
  return a and b and family_for(a) == family_for(b) and safe(item_from(a) or "none") == safe(item_from(b) or "none")
end

local function current_has_lease(pair, cur)
  cur = cur or current_order(pair)
  if not order_active(cur) then return false end
  local activated = tonumber(cur.activated_tick or cur.created_tick or 0) or 0
  if now() - activated < M.active_order_lease_ticks then return true end
  local d = pair and pair.dispatcher_0510 or nil
  if d and now() - (tonumber(d.tick) or -1000000) < M.dispatcher_context_ticks and d.family and lower(d.family) ~= "idle" then return true end
  return false
end

local function fold_into_current(pair, cur, order, why)
  if not (cur and order) then return false end
  cur.updated_tick = now()
  cur.last_folded_0512 = { tick = now(), source = source_for(order), reason = tostring(why or "fold"), incoming_key = order.key }
  if tonumber(order.count) and tonumber(cur.count) then cur.count = math.max(tonumber(cur.count) or 1, tonumber(order.count) or 1) end
  if order.target and not cur.target then cur.target = order.target end
  if order.source then cur.last_source_0512 = order.source end
  return true
end

local function should_block_submission(pair, order)
  local r = M.root()
  if r.enabled == false or not valid_pair(pair) or type(order) ~= "table" then return false end
  local cur = current_order(pair)
  local fam = family_for(order)
  local src = source_for(order)
  local pri = tonumber(order.priority) or 0
  local curpri = tonumber(cur and cur.priority) or 0

  if r.stable_current ~= false and order_active(cur) and current_has_lease(pair, cur) and not interrupt_kinds[normalize_kind(order.kind)] then
    if same_family_item(cur, order) then
      fold_into_current(pair, cur, order, "same-family-active-lease")
      record("submission-folded-0512", pair, "family=" .. safe(fam) .. " item=" .. safe(item_from(order)) .. " source=" .. safe(src))
      return true, "folded-current-lease"
    end
    if pri <= curpri and (is_passive_source(src) or is_strategic_source(src)) then
      record("submission-held-0512", pair, "family=" .. safe(fam) .. " item=" .. safe(item_from(order)) .. " source=" .. safe(src) .. " cur=" .. safe(cur.key))
      return true, "held-current-lease"
    end
  end

  if r.fold_same_family ~= false then
    local key = submission_key(pair, order)
    local last = r.last_submission[key]
    if last and now() - (tonumber(last.tick) or 0) < M.same_family_debounce_ticks and (is_passive_source(src) or is_strategic_source(src)) then
      record("submission-debounced-0512", pair, "key=" .. safe(key) .. " source=" .. safe(src))
      return true, "same-family-debounce"
    end
    r.last_submission[key] = { tick = now(), source = src }
  end

  return false
end

local function wrap_order_queue_submit()
  local ok, OQ = pcall(require, "scripts.core.order_queue_0469")
  if not (ok and OQ and type(OQ.submit) == "function") or OQ.scheduler_contract_0512_wrapped then return false end
  OQ.scheduler_contract_0512_wrapped = true
  OQ.TECH_PRIESTS_0512_PRE_SUBMIT = OQ.submit
  OQ.submit = function(pair, order, opts, ...)
    local block, why = should_block_submission(pair, order)
    if block then return false, "duplicate", current_order(pair) end
    return OQ.TECH_PRIESTS_0512_PRE_SUBMIT(pair, order, opts, ...)
  end
  return true
end

local function protect_order_queue_tick()
  local ok, OQ = pcall(require, "scripts.core.order_queue_0469")
  if not (ok and OQ and type(OQ.tick_pair) == "function") or OQ.scheduler_contract_0512_tick_wrapped then return false end
  OQ.scheduler_contract_0512_tick_wrapped = true
  OQ.TECH_PRIESTS_0512_PRE_TICK_PAIR = OQ.tick_pair
  OQ.tick_pair = function(pair, reason, ...)
    local r = M.root()
    local before = current_order(pair)
    local before_key = before and before.key or nil
    local before_status = before and before.status or nil
    local protected = r.enabled ~= false and r.protect_dispatcher_current ~= false and valid_pair(pair) and order_active(before) and current_has_lease(pair, before)
    local result = OQ.TECH_PRIESTS_0512_PRE_TICK_PAIR(pair, reason, ...)
    local after = current_order(pair)
    if protected and before_key and not after and active_work(pair) then
      local q = q_of(pair)
      if q then
        before.status = before_status or "active"
        before.updated_tick = now()
        before.reheld_by_0512 = { tick = now(), reason = tostring(reason or "tick-pair"), mode = tostring(pair.mode or "") }
        q.current = before
        pair.active_order_0469 = before
        record("current-reheld-0512", pair, "key=" .. safe(before_key) .. " reason=" .. safe(reason) .. " mode=" .. safe(pair.mode))
      end
    end
    return result
  end
  return true
end

local function wrap_order_refresh()
  if type(_G.tech_priests_0270_refresh_orders_for_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0512_PRE_REFRESH_ORDERS") then return false end
  local prev = _G.tech_priests_0270_refresh_orders_for_pair
  _G.TECH_PRIESTS_0512_PRE_REFRESH_ORDERS = prev
  _G.tech_priests_0270_refresh_orders_for_pair = function(pair, source, ...)
    local r = M.root()
    source = tostring(source or "unknown")
    if r.enabled ~= false and r.passive_refresh_guard ~= false and valid_pair(pair) and active_work(pair) and is_passive_source(source) then
      local key = safe(station_unit(pair)) .. ":" .. lower(source)
      local last = r.last_refresh[key] or -1000000
      if now() - last < M.passive_refresh_block_ticks then
        record("passive-refresh-blocked-0512", pair, "source=" .. safe(source) .. " mode=" .. safe(pair.mode))
        return false
      end
      r.last_refresh[key] = now()
    end
    return prev(pair, source, ...)
  end
  return true
end

local function wrap_cascade()
  local ok, Cascade = pcall(require, "scripts.core.emergency_cascade")
  if not (ok and Cascade and type(Cascade.cascade_from) == "function") or Cascade.scheduler_contract_0512_wrapped then return false end
  Cascade.scheduler_contract_0512_wrapped = true
  Cascade.TECH_PRIESTS_0512_PRE_CASCADE_FROM = Cascade.cascade_from
  Cascade.cascade_from = function(leader, reason, ...)
    local r = M.root()
    if r.enabled ~= false and r.strategic_cooldown ~= false and valid_pair(leader) then
      local key = safe(station_unit(leader)) .. ":" .. lower(reason or "cascade")
      local last = r.last_cascade[key] or -1000000
      if active_work(leader) and now() - last < M.cascade_cooldown_ticks then
        record("cascade-held-0512", leader, "reason=" .. safe(reason) .. " mode=" .. safe(leader.mode))
        return 0
      end
      r.last_cascade[key] = now()
    end
    return Cascade.TECH_PRIESTS_0512_PRE_CASCADE_FROM(leader, reason, ...)
  end
  return true
end

function M.audit_pair(pair)
  local lines = {}
  if not pair then return { "scheduler0512 no pair" } end
  local r = M.root()
  local q = q_of(pair)
  local cur = q and q.current or nil
  lines[#lines + 1] = "scheduler0512 station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair))
    .. " enabled=" .. safe(r.enabled) .. " mode=" .. safe(pair.mode) .. " active_work=" .. safe(active_work(pair))
  lines[#lines + 1] = "scheduler0512 current=" .. safe(cur and cur.key or "none") .. " kind=" .. safe(cur and cur.kind or "nil")
    .. " family=" .. safe(cur and family_for(cur) or "nil") .. " item=" .. safe(cur and item_from(cur) or "nil")
    .. " status=" .. safe(cur and cur.status or "nil") .. " lease=" .. safe(current_has_lease(pair, cur))
  lines[#lines + 1] = "scheduler0512 pending=" .. safe(q and q.pending and #q.pending or 0)
    .. " folded=" .. safe(r.stats["submission-folded-0512"] or 0)
    .. " held=" .. safe(r.stats["submission-held-0512"] or 0)
    .. " debounced=" .. safe(r.stats["submission-debounced-0512"] or 0)
    .. " refresh_blocked=" .. safe(r.stats["passive-refresh-blocked-0512"] or 0)
    .. " cascade_held=" .. safe(r.stats["cascade-held-0512"] or 0)
  return lines
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  local tp = storage and storage.tech_priests or nil
  if selected and selected.valid and tp then
    if tp.pairs_by_station and tp.pairs_by_station[selected.unit_number] then return tp.pairs_by_station[selected.unit_number] end
    if tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number] then return tp.pairs_by_priest[selected.unit_number] end
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-scheduler-0512") end end)
  commands.add_command("tp-scheduler-0512", "Tech Priests 0.1.512: scheduler/order queue contract. Params: on/off/all/stable-on/stable-off/refresh-on/refresh-off/cascade-on/cascade-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "stable-on" then r.stable_current = true end
    if p == "stable-off" then r.stable_current = false end
    if p == "refresh-on" then r.passive_refresh_guard = true end
    if p == "refresh-off" then r.passive_refresh_guard = false end
    if p == "cascade-on" then r.strategic_cooldown = true end
    if p == "cascade-off" then r.strategic_cooldown = false end
    local lines = { "[tp-scheduler-0512] enabled=" .. safe(r.enabled) .. " stable_current=" .. safe(r.stable_current) .. " passive_refresh_guard=" .. safe(r.passive_refresh_guard) .. " strategic_cooldown=" .. safe(r.strategic_cooldown) }
    if p == "all" then
      for _, pair in pairs(pair_map()) do for _, line in ipairs(M.audit_pair(pair)) do lines[#lines + 1] = line end end
    else
      local pair = selected_pair(player)
      if pair then for _, line in ipairs(M.audit_pair(pair)) do lines[#lines + 1] = line end else lines[#lines + 1] = "select a Cogitator Station or Tech-Priest for pair status" end
    end
    local msg = table.concat(lines, "\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.scheduler_contract_0512_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.scheduler_contract_0512_wrapped = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 SCHEDULER-CONTRACT-0512 BEGIN enabled=" .. safe(r.enabled)
      .. " stable=" .. safe(r.stable_current)
      .. " refresh_guard=" .. safe(r.passive_refresh_guard)
      .. " cascade_cooldown=" .. safe(r.strategic_cooldown)
      .. " folded=" .. safe(r.stats["submission-folded-0512"] or 0)
      .. " held=" .. safe(r.stats["submission-held-0512"] or 0)
      .. " debounced=" .. safe(r.stats["submission-debounced-0512"] or 0)
      .. " reheld=" .. safe(r.stats["current-reheld-0512"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        for _, line in ipairs(M.audit_pair(pair)) do lines[#lines + 1] = "PAIR-DUMP-0468 " .. line end
      end
    end
    for i = math.max(1, #r.recent - 12), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "PAIR-DUMP-0468 sched0512.recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 SCHEDULER-CONTRACT-0512 END"
    return lines
  end
  return true
end

function M.tick_all(reason)
  -- Lightweight periodic sanitation: the actual order queue still owns
  -- promotion/completion. This pass only records obvious queue pressure.
  local r = M.root()
  if r.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      local q = q_of(pair)
      if q and q.pending and #q.pending > M.queue_limit_soft then
        record("queue-pressure-0512", pair, "pending=" .. safe(#q.pending) .. " reason=" .. safe(reason))
      end
      n = n + 1
    end
  end
  return n
end

function M.install()
  M.root()
  wrap_order_queue_submit()
  protect_order_queue_tick()
  wrap_order_refresh()
  wrap_cascade()
  wrap_pair_dump()
  install_command()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and type(registry.on_nth_tick) == "function" then
    registry.on_nth_tick(M.tick_interval, function() M.tick_all("nth-tick-0512") end, { owner = "scheduler_contract_0512", category = "scheduler", priority = "late", note = "stable current-order lease and passive refresh guard" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.tick_interval, function() M.tick_all("nth-tick-0512") end)
  end
  _G.TechPriestsSchedulerContract0512 = M
  if log then log("[Tech-Priests 0.1.512] scheduler contract installed; active orders leased, passive refresh churn held, strategic cascade cooldown enabled") end
  return true
end

return M
