-- scripts/core/status_churn_damper_0532.lua
-- Tech Priests 0.1.532
--
-- Late authority shim for the observed overhead/task churn.  It does not create
-- work, complete orders, move priests, draw independent text, or take over the
-- dispatcher.  It only damps stale passive refreshes and idle visual clears that
-- were allowed to leak into the visible overhead state while an order was still
-- active.

local M = {}
M.version = "0.1.532"
M.storage_key = "status_churn_damper_0532"
M.passive_refresh_block_ticks = 60 * 20
M.status_hold_ticks = 60 * 2
M.status_idle_grace_ticks = 60 * 3
M.status_stale_clear_ticks = 60 * 10
M.rewrap_interval = 97

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_key(pair) return tostring(station_unit(pair) or (valid(pair and pair.priest) and pair.priest.unit_number) or "?") end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local passive_sources = {
  ["mouse-over"] = true,
  ["radar-priest-scan"] = true,
  ["overview-ui"] = true,
  ["command-overview"] = true,
  ["gui-refresh"] = true,
  ["workstate-gui"] = true,
}

local idleish_modes = {
  [""] = true,
  idle = true,
  ["no-managed-priority-claimed"] = true,
  ["no-managed-priority"] = true,
  ["scheduler-0277"] = true,
  ["scheduler-idle"] = true,
  ["nothing-claimed"] = true,
}

local function root()
  if not storage then return { enabled = true, stats = {}, last_refresh = {}, status_leases = {}, recent = {} } end
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if not r then
    r = { version = M.version, enabled = true, passive_refresh_guard = true, visual_clear_guard = true, overhead_hold = true, duplicate_heartbeat_guard = true, stats = {}, last_refresh = {}, status_leases = {}, recent = {} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.passive_refresh_guard == nil then r.passive_refresh_guard = true end
  if r.visual_clear_guard == nil then r.visual_clear_guard = true end
  if r.overhead_hold == nil then r.overhead_hold = true end
  if r.duplicate_heartbeat_guard == nil then r.duplicate_heartbeat_guard = true end
  r.stats = r.stats or {}
  r.last_refresh = r.last_refresh or {}
  r.status_leases = r.status_leases or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function record(action, pair, detail)
  local r = root()
  stat(action)
  local ev = { tick = now(), action = tostring(action or "event"), station = pair_key(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 80 do table.remove(r.recent, 1) end
end

local function is_passive_source(src)
  src = lower(src)
  if passive_sources[src] then return true end
  return src:find("mouse", 1, true) or src:find("overview", 1, true) or src:find("radar", 1, true) or src:find("gui", 1, true)
end

local function current_order(pair)
  local q = pair and pair.order_queue_0469 or nil
  return pair and ((q and q.current) or pair.active_order_0469) or nil
end

local function order_active(order)
  if type(order) ~= "table" then return false end
  local s = lower(order.status or "active")
  return s ~= "complete" and s ~= "failed" and s ~= "cancelled"
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  return v.item or v.item_name or v.output_item or v.wanted_item or v.requested_item or v.resource or v.name or (type(v.task) == "table" and item_from(v.task))
end

local function kind_from(v)
  if type(v) ~= "table" then return "" end
  return lower(v.kind or v.type or v.family or v.source or "")
end

local function active_dispatcher(pair)
  local d = pair and pair.dispatcher_0510 or nil
  if type(d) ~= "table" then return false end
  local fam = lower(d.family or d.kind or "")
  local t = tonumber(d.tick or 0) or 0
  return fam ~= "" and fam ~= "idle" and now() - t < 60 * 5
end

local function active_work(pair)
  if not pair then return false end
  if order_active(current_order(pair)) then return true end
  if active_dispatcher(pair) then return true end
  local mode = lower(pair.mode)
  if mode:find("travelling", 1, true) or mode:find("gather", 1, true) or mode:find("mine", 1, true) or mode:find("craft", 1, true) or mode:find("scavenge", 1, true) or mode:find("construct", 1, true) or mode:find("acqui", 1, true) or mode:find("logistic", 1, true) then return true end
  if pair.emergency_craft or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333 or pair.scavenge or pair.active_task or pair.active_task_0285 then return true end
  return false
end

local function stable_visual_for(pair)
  local order = current_order(pair)
  local k = kind_from(order)
  if k:find("combat", 1, true) then return "combat-writ-active" end
  if k:find("repair", 1, true) then return "repair-writ-active" end
  if k:find("consecr", 1, true) or k:find("sanct", 1, true) then return "consecration-writ-active" end
  if k:find("craft", 1, true) or k:find("emergency", 1, true) then return "station-craft-writ-active" end
  if k:find("assign", 1, true) then return "assignment-writ-active" end
  if k:find("logistic", 1, true) or k:find("supply", 1, true) or k:find("gather", 1, true) or k:find("acqui", 1, true) or k:find("resource", 1, true) then return "logistics-writ-active" end
  if order_active(order) then return "order-writ-active" end
  if active_dispatcher(pair) then return "dispatcher-writ-active" end
  return nil
end

local function label_item(name)
  name = tostring(name or "field materials")
  name = name:gsub("%[item=([^%]]+)%]", "%1")
  return name:gsub("-", " ")
end

local function active_order_status(pair)
  local order = current_order(pair)
  if not order_active(order) then return nil, nil, 0 end
  local item = item_from(order) or item_from(pair and pair.emergency_craft) or "field materials"
  local k = kind_from(order)
  if k:find("combat", 1, true) then return "Battle rite sealed", { r = 1.0, g = 0.28, b = 0.18, a = 0.96 }, 900 end
  if k:find("repair", 1, true) then return "Repair writ: " .. label_item(item), { r = 0.38, g = 1.0, b = 0.42, a = 0.96 }, 820 end
  if k:find("consecr", 1, true) or k:find("sanct", 1, true) then return "Consecration writ: " .. label_item(item), { r = 0.50, g = 1.0, b = 0.76, a = 0.96 }, 790 end
  if k:find("craft", 1, true) or k:find("emergency", 1, true) then return "Forge writ: " .. label_item(item), { r = 1.0, g = 0.74, b = 0.24, a = 0.96 }, 760 end
  if k:find("assign", 1, true) then return "Subordinate writ: " .. label_item(item), { r = 0.88, g = 0.88, b = 1.0, a = 0.96 }, 720 end
  return "Station writ: " .. label_item(item), { r = 0.98, g = 0.72, b = 0.22, a = 0.96 }, 700
end

local function status_priority(text, pair)
  local s = lower(text)
  if s == "" then return 0 end
  if s:find("battle", 1, true) or s:find("combat", 1, true) or s:find("hostile", 1, true) then return 900 end
  if s:find("conversation", 1, true) or s:find("vox", 1, true) or s:find("speaking", 1, true) then return 860 end
  if s:find("repair", 1, true) then return 820 end
  if s:find("consecr", 1, true) or s:find("sanct", 1, true) then return 790 end
  if s:find("craft", 1, true) or s:find("forge", 1, true) then return 760 end
  if s:find("writ", 1, true) then return 700 end
  if s:find("acquir", 1, true) or s:find("gather", 1, true) or s:find("scav", 1, true) or s:find("mine", 1, true) then return 680 end
  if s:find("cogitat", 1, true) or s:find("route", 1, true) or s:find("calibr", 1, true) then return 360 end
  if active_work(pair) then return 420 end
  return 200
end

local function should_prefer_order_text(candidate_text, candidate_pri, order_pri)
  if not candidate_text or candidate_text == "" then return true end
  local s = lower(candidate_text)
  if s:find("no managed", 1, true) or s:find("idle", 1, true) or s:find("cogitat", 1, true) or s:find("calibr", 1, true) then return true end
  if s:find("acquiring field materials", 1, true) then return true end
  return (order_pri or 0) > (candidate_pri or 0) + 40
end

local function wrap_refresh()
  if type(_G.tech_priests_0270_refresh_orders_for_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0532_PRE_REFRESH_ORDERS") then return false end
  local prev = _G.tech_priests_0270_refresh_orders_for_pair
  _G.TECH_PRIESTS_0532_PRE_REFRESH_ORDERS = prev
  _G.tech_priests_0270_refresh_orders_for_pair = function(pair, source, ...)
    local r = root()
    source = tostring(source or "unknown")
    if r.enabled ~= false and r.passive_refresh_guard ~= false and valid_pair(pair) and active_work(pair) and is_passive_source(source) then
      local key = pair_key(pair) .. ":" .. lower(source)
      local last = r.last_refresh[key] or -1000000
      if now() - last < M.passive_refresh_block_ticks then
        record("passive-refresh-blocked-0532", pair, "source=" .. safe(source) .. " mode=" .. safe(pair.mode) .. " current=" .. safe(current_order(pair) and current_order(pair).key))
        return false
      end
      r.last_refresh[key] = now()
    end
    return prev(pair, source, ...)
  end
  return true
end

local function wrap_task_clears()
  if type(_G.tech_priests_clear_pair_task_0276) == "function" and not rawget(_G, "TECH_PRIESTS_0532_PRE_CLEAR_PAIR_TASK_0276") then
    local prev = _G.tech_priests_clear_pair_task_0276
    _G.TECH_PRIESTS_0532_PRE_CLEAR_PAIR_TASK_0276 = prev
    _G.tech_priests_clear_pair_task_0276 = function(pair, visual_state, ...)
      local r = root()
      local state = lower(visual_state or "")
      if r.enabled ~= false and r.visual_clear_guard ~= false and valid_pair(pair) and active_work(pair) and idleish_modes[state] then
        local stable = stable_visual_for(pair) or pair.visual_state_0276 or pair.mode or "order-writ-active"
        if idleish_modes[lower(stable)] then stable = "order-writ-active" end
        pair.task_kind_0276 = pair.task_kind_0276 or "order"
        pair.task_phase_0276 = pair.task_phase_0276 or "active-order-lease"
        pair.visual_state_0276 = stable
        pair.mode = stable
        pair.last_scheduler_clear_suppressed_0532 = { tick = now(), requested = tostring(visual_state or "nil"), current = current_order(pair) and current_order(pair).key or nil }
        record("visual-clear-held-0532", pair, "requested=" .. safe(visual_state) .. " stable=" .. safe(stable))
        return false
      end
      return prev(pair, visual_state, ...)
    end
  end

  if type(_G.tech_priests_0277_clear_task) == "function" and not rawget(_G, "TECH_PRIESTS_0532_PRE_CLEAR_TASK_0277") then
    local prev = _G.tech_priests_0277_clear_task
    _G.TECH_PRIESTS_0532_PRE_CLEAR_TASK_0277 = prev
    _G.tech_priests_0277_clear_task = function(pair, reason, ...)
      local r = root()
      local state = lower(reason or "")
      if r.enabled ~= false and r.visual_clear_guard ~= false and valid_pair(pair) and active_work(pair) and idleish_modes[state] then
        local stable = stable_visual_for(pair) or pair.visual_state_0276 or pair.mode or "order-writ-active"
        if idleish_modes[lower(stable)] then stable = "order-writ-active" end
        pair.task_kind_0276 = pair.task_kind_0276 or "order"
        pair.task_phase_0276 = pair.task_phase_0276 or "active-order-lease"
        pair.visual_state_0276 = stable
        pair.mode = stable
        pair.last_scheduler_clear_suppressed_0532 = { tick = now(), requested = tostring(reason or "nil"), current = current_order(pair) and current_order(pair).key or nil }
        record("legacy-clear-held-0532", pair, "requested=" .. safe(reason) .. " stable=" .. safe(stable))
        return false
      end
      return prev(pair, reason, ...)
    end
  end
end

local function wrap_overhead()
  local gov = rawget(_G, "TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471")
  if not (gov and type(gov) == "table" and type(gov.canonical_status) == "function") or gov.status_churn_damper_0532_wrapped then return false end
  local prev = gov.canonical_status
  gov.status_churn_damper_0532_previous = prev
  gov.status_churn_damper_0532_wrapped = true
  gov.canonical_status = function(pair, incoming, ...)
    local text, color = prev(pair, incoming, ...)
    local r = root()
    if r.enabled == false or r.overhead_hold == false or not valid_pair(pair) then return text, color end

    local order_text, order_color, order_pri = active_order_status(pair)
    local cand_pri = status_priority(text, pair)
    if order_text and should_prefer_order_text(text, cand_pri, order_pri) then
      text, color, cand_pri = order_text, order_color, order_pri
    elseif text then
      cand_pri = status_priority(text, pair)
    end

    local key = pair_key(pair)
    local lease = r.status_leases[key]
    local t = now()
    if text and text ~= "" then
      if lease and lease.text and lease.text ~= text and t < (tonumber(lease.hold_until) or 0) and cand_pri <= (tonumber(lease.priority) or 0) then
        record("overhead-transition-held-0532", pair, "from=" .. safe(lease.text) .. " to=" .. safe(text))
        return lease.text, lease.color
      end
      r.status_leases[key] = { text = text, color = color, priority = cand_pri, tick = t, hold_until = t + M.status_hold_ticks, idle_until = t + M.status_idle_grace_ticks, stale_until = t + M.status_stale_clear_ticks }
      return text, color
    end

    if lease and lease.text and active_work(pair) and t < (tonumber(lease.idle_until) or 0) then
      record("overhead-idle-held-0532", pair, "text=" .. safe(lease.text))
      return lease.text, lease.color
    end
    if lease and t > (tonumber(lease.stale_until) or 0) then r.status_leases[key] = nil end
    return text, color
  end
  return true
end

local function wrap_heartbeat_log()
  if type(_G.tech_priests_0264_log) ~= "function" or rawget(_G, "TECH_PRIESTS_0532_PRE_0264_LOG") then return false end
  local prev = _G.tech_priests_0264_log
  _G.TECH_PRIESTS_0532_PRE_0264_LOG = prev
  local last_key, last_tick = nil, -1
  _G.tech_priests_0264_log = function(message, ...)
    local r = root()
    local msg = tostring(message or "")
    if r.enabled ~= false and r.duplicate_heartbeat_guard ~= false and msg:find("heartbeat:", 1, true) == 1 then
      local key = msg
      local t = now()
      if key == last_key and t == last_tick then
        stat("duplicate-heartbeat-held-0532")
        return false
      end
      last_key, last_tick = key, t
    end
    return prev(message, ...)
  end
  return true
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.status_churn_damper_0532_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.status_churn_damper_0532_wrapped = true
  diag.pair_dump_lines = function(...)
    local lines = prev(...)
    local r = root()
    lines[#lines + 1] = "STATUS-CHURN-0532 BEGIN enabled=" .. safe(r.enabled)
      .. " refresh_guard=" .. safe(r.passive_refresh_guard)
      .. " visual_guard=" .. safe(r.visual_clear_guard)
      .. " overhead_hold=" .. safe(r.overhead_hold)
      .. " passive_refresh_blocked=" .. safe(r.stats["passive-refresh-blocked-0532"] or 0)
      .. " visual_clear_held=" .. safe((r.stats["visual-clear-held-0532"] or 0) + (r.stats["legacy-clear-held-0532"] or 0))
      .. " overhead_held=" .. safe((r.stats["overhead-transition-held-0532"] or 0) + (r.stats["overhead-idle-held-0532"] or 0))
      .. " heartbeat_dupes=" .. safe(r.stats["duplicate-heartbeat-held-0532"] or 0)
    for _, p in pairs(pair_map()) do
      if p and valid(p.station) then
        local order = current_order(p)
        lines[#lines + 1] = "STATUS-CHURN-0532 pair[" .. safe(pair_key(p)) .. "] mode=" .. safe(p.mode) .. " active=" .. safe(active_work(p)) .. " current=" .. safe(order and order.key or "none") .. " visual=" .. safe(p.visual_state_0276)
      end
    end
    for i = math.max(1, #r.recent - 10), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "STATUS-CHURN-0532 recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "STATUS-CHURN-0532 END"
    return lines
  end
  return true
end

local function selected_pair(player)
  local selected = player and player.selected
  local tp = storage and storage.tech_priests or nil
  if selected and selected.valid and tp then
    return (tp.pairs_by_station or {})[selected.unit_number] or (tp.pairs_by_priest or {})[selected.unit_number]
  end
  return nil
end

local function audit_pair(pair)
  local order = current_order(pair)
  local lines = {}
  lines[#lines + 1] = "status0532 station=" .. safe(pair_key(pair)) .. " mode=" .. safe(pair and pair.mode) .. " visual=" .. safe(pair and pair.visual_state_0276) .. " active=" .. safe(active_work(pair))
  lines[#lines + 1] = "status0532 current=" .. safe(order and order.key or "none") .. " kind=" .. safe(order and order.kind or "nil") .. " item=" .. safe(order and item_from(order) or "nil") .. " status=" .. safe(order and order.status or "nil")
  local r = root()
  local lease = r.status_leases[pair_key(pair)]
  lines[#lines + 1] = "status0532 lease=" .. safe(lease and lease.text or "none") .. " hold_until=" .. safe(lease and lease.hold_until or "nil")
  return lines
end

local function register_command()
  if not (commands and commands.add_command) then return false end
  pcall(function() if commands.remove_command then commands.remove_command("tp-status-churn-0532") end end)
  commands.add_command("tp-status-churn-0532", "Tech Priests 0.1.532: inspect task/status churn damper. Usage: status|all|on|off|refresh-on|refresh-off|visual-on|visual-off|overhead-on|overhead-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false end
    if p == "refresh-on" then r.passive_refresh_guard = true elseif p == "refresh-off" then r.passive_refresh_guard = false end
    if p == "visual-on" then r.visual_clear_guard = true elseif p == "visual-off" then r.visual_clear_guard = false end
    if p == "overhead-on" then r.overhead_hold = true elseif p == "overhead-off" then r.overhead_hold = false end
    local lines = { "[tp-status-churn-0532] enabled=" .. safe(r.enabled) .. " refresh_guard=" .. safe(r.passive_refresh_guard) .. " visual_guard=" .. safe(r.visual_clear_guard) .. " overhead_hold=" .. safe(r.overhead_hold) }
    if p == "all" then
      for _, pair in pairs(pair_map()) do for _, line in ipairs(audit_pair(pair)) do lines[#lines + 1] = line end end
    else
      local pair = selected_pair(player)
      if pair then for _, line in ipairs(audit_pair(pair)) do lines[#lines + 1] = line end else lines[#lines + 1] = "select a Cogitator Station or Tech-Priest, or use /tp-status-churn-0532 all" end
    end
    local msg = table.concat(lines, "\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
  return true
end

function M.install()
  root()
  _G.TECH_PRIESTS_STATUS_CHURN_DAMPER_0532 = M
  wrap_refresh()
  wrap_task_clears()
  wrap_overhead()
  wrap_heartbeat_log()
  wrap_pair_dump()
  register_command()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.rewrap_interval, function()
      wrap_refresh(); wrap_task_clears(); wrap_overhead(); wrap_heartbeat_log(); wrap_pair_dump()
    end, { owner = "status_churn_damper_0532", category = "visual", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.rewrap_interval, function() wrap_refresh(); wrap_task_clears(); wrap_overhead(); wrap_heartbeat_log(); wrap_pair_dump() end) end)
  end
  if log then log("[Tech-Priests 0.1.532] status/task churn damper installed; active writs hold visual state, passive refreshes are debounced, duplicate heartbeats are filtered, and overhead text has a short lease") end
  return true
end

return M
