-- scripts/core/task_retention_visual_lease_0476.lua
-- Tech Priests 0.1.476
-- Late authority for two related stabilization problems:
--   * Cogitator overlay/radius lines must persist while relevant, then vanish
--     when the player is no longer hovering/selecting a station/priest or
--     holding a Cogitator station for placement.
--   * Order queues must retain attention.  A current task should not be
--     abandoned for a new writ unless it completes, expires, or a higher
--     authority such as combat/repair/consecration legitimately preempts it.

local M = {}
M.version = "0.1.476"
M.storage_key = "task_retention_visual_lease_0476"
M.visual_tick_interval = 15
M.retention_tick_interval = 41
M.default_task_retention_ticks = 60 * 20
M.standard_writ_cadence_ticks = 60 * 10
M.magos_writ_cadence_ticks = 60 * 30
M.magos_plan_cadence_ticks = 60 * 30
M.standard_pending_cap = 3
M.magos_pending_cap = 2
M.critical_preempt_delta = 250

local original_order_submit = nil
local original_magos_submit_plan = nil
local original_sound_tick_pair = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end
local function lower(v) return string.lower(tostring(v or "")) end
local function clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function setting_seconds(name, fallback)
  if settings and settings.global and settings.global[name] ~= nil then
    local v = tonumber(settings.global[name].value)
    if v then return v end
  end
  return fallback
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    last_context_active = {},
    inactive_cleaned = {},
  }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.last_context_active = r.last_context_active or {}
  r.inactive_cleaned = r.inactive_cleaned or {}
  return r
end

local function enabled() return root().enabled ~= false end
local function stat(name, delta) local r = root(); r.stats[name] = (r.stats[name] or 0) + (delta or 1) end

local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function is_magos_pair(pair)
  if not valid_pair(pair) then return false end
  local sname = lower(pair.station and pair.station.name)
  local pname = lower(pair.priest and pair.priest.name)
  local tier = lower(pair.tier or pair.rank or pair.station_rank)
  return sname:find("planetary%-magos") ~= nil or pname:find("planetary%-magos") ~= nil or tier:find("planetary%-magos") ~= nil
end

local priority_by_kind = {
  validate = 1000,
  combat = 900,
  defense = 900,
  repair = 800,
  consecration = 700,
  sanctify = 700,
  assignment = 610,
  logistics = 600,
  supply = 590,
  scavenge = 580,
  acquisition = 570,
  gather = 570,
  direct_mine = 570,
  emergency_craft = 540,
  emergency = 530,
  return_to_station = 400,
  idle = 0,
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

local function priority_for(order)
  if not order then return 0 end
  if tonumber(order.priority) then return tonumber(order.priority) end
  return priority_by_kind[normalize_kind(order.kind or order.type or order.source)] or 100
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  return v.item_name or v.item or v.name or v.output_item or v.wanted_item or v.requested_item or v.kind
end

local function order_item(order)
  return item_from(order) or item_from(order and order.task) or item_from(order and order.request)
end

local function low_writ_order(order)
  local k = normalize_kind(order and (order.kind or order.type or order.source))
  return k == "logistics" or k == "scavenge" or k == "acquisition" or k == "gather" or k == "direct_mine" or k == "emergency_craft" or k == "assignment"
end

local function critical_order(order, current)
  local k = normalize_kind(order and (order.kind or order.type or order.source))
  if k == "combat" or k == "repair" or k == "consecration" or k == "sanctify" or k == "validate" then return true end
  local op = priority_for(order)
  local cp = priority_for(current)
  return op >= cp + M.critical_preempt_delta
end

local function same_orderish(a, b)
  if not (a and b) then return false end
  if a.key and b.key and a.key == b.key then return true end
  local ak = normalize_kind(a.kind or a.type or a.source)
  local bk = normalize_kind(b.kind or b.type or b.source)
  local ai = order_item(a)
  local bi = order_item(b)
  return ak == bk and ai ~= nil and bi ~= nil and tostring(ai) == tostring(bi)
end

local function simple_duplicate(pair, order)
  local q = pair and pair.order_queue_0469
  if not q or not order then return false end
  if same_orderish(q.current, order) then return true end
  for _, pending in ipairs(q.pending or {}) do
    if same_orderish(pending, order) then return true end
  end
  return false
end

local function retention_ticks_for(pair, order)
  local seconds = setting_seconds("tech-priests-task-retention-seconds", M.default_task_retention_ticks / 60)
  local k = normalize_kind(order and order.kind)
  if k == "combat" then seconds = math.min(seconds, 8) end
  if k == "repair" or k == "consecration" then seconds = math.max(seconds, 12) end
  return math.floor(clamp(seconds, 1, 600) * 60)
end

local function writ_cadence_ticks_for(pair)
  local setting_name = is_magos_pair(pair) and "tech-priests-magos-writ-cadence-seconds" or "tech-priests-standard-writ-cadence-seconds"
  local fallback = is_magos_pair(pair) and (M.magos_writ_cadence_ticks / 60) or (M.standard_writ_cadence_ticks / 60)
  return math.floor(clamp(setting_seconds(setting_name, fallback), 1, 3600) * 60)
end

local function pending_cap_for(pair)
  local name = is_magos_pair(pair) and "tech-priests-magos-pending-writ-cap" or "tech-priests-standard-pending-writ-cap"
  local fallback = is_magos_pair(pair) and M.magos_pending_cap or M.standard_pending_cap
  if settings and settings.global and settings.global[name] ~= nil then
    return math.floor(clamp(tonumber(settings.global[name].value), 0, 20))
  end
  return fallback
end

local function ensure_current_retention(pair)
  local q = pair and pair.order_queue_0469
  local cur = q and q.current
  if not cur then return nil end
  if not cur.retain_until_0476 then
    cur.retain_until_0476 = now() + retention_ticks_for(pair, cur)
    cur.retention_started_0476 = now()
  end
  return cur
end

function M.wrap_order_queue()
  local oq = rawget(_G, "TECH_PRIESTS_ORDER_QUEUE_0469")
  if not (oq and type(oq.submit) == "function") then return false end
  if oq.task_retention_wrapped_0476 then return true end
  original_order_submit = oq.submit
  oq.task_retention_wrapped_0476 = true
  oq.submit = function(pair, order, opts)
    if not (enabled() and valid_pair(pair) and order) then
      return original_order_submit(pair, order, opts)
    end

    local q = pair.order_queue_0469
    local cur = ensure_current_retention(pair)
    if q and cur then
      order.kind = normalize_kind(order.kind or order.type or order.source)
      order.priority = priority_for(order)
      local duplicate = simple_duplicate(pair, order)
      local can_preempt = critical_order(order, cur) or (opts and opts.force_preempt)

      if order.priority > priority_for(cur) and not can_preempt and now() < (cur.retain_until_0476 or 0) then
        pair.task_retention_0476 = {
          tick = now(),
          action = "preempt-held",
          current = cur.key,
          incoming = order.key or order_item(order),
          until_tick = cur.retain_until_0476,
        }
        order.priority = math.min(priority_for(cur), order.priority)
        stat("preemptions_held")
      end

      if low_writ_order(order) and not duplicate then
        local cap = pending_cap_for(pair)
        local pending_count = #(q.pending or {})
        local next_tick = tonumber(pair.next_low_writ_tick_0476 or 0) or 0
        if cap >= 0 and pending_count >= cap then
          pair.task_retention_0476 = { tick = now(), action = "pending-cap-held", pending = pending_count, cap = cap, incoming = order.key or order_item(order) }
          stat("pending_cap_held")
          return false, "retention-pending-cap", cur
        end
        if now() < next_tick then
          pair.task_retention_0476 = { tick = now(), action = "cadence-held", next_tick = next_tick, incoming = order.key or order_item(order) }
          stat("cadence_held")
          return false, "retention-cadence", cur
        end
      end
    end

    local ok, state, existing = original_order_submit(pair, order, opts)
    local q2 = pair and pair.order_queue_0469
    local cur2 = q2 and q2.current
    if cur2 and not cur2.retain_until_0476 then
      cur2.retain_until_0476 = now() + retention_ticks_for(pair, cur2)
      cur2.retention_started_0476 = now()
    end
    if low_writ_order(order) and (state == "active" or state == "queued" or state == "preempt") then
      pair.next_low_writ_tick_0476 = now() + writ_cadence_ticks_for(pair)
      pair.last_low_writ_0476 = { tick = now(), state = state, item = order_item(order), key = order.key }
    end
    return ok, state, existing
  end
  _G.tech_priests_0469_submit_order = oq.submit
  return true
end

local function magos_plan_duplicate(q, item, reason)
  if not q then return false end
  local keypart = tostring(item or "none") .. ":" .. tostring(reason or "")
  local function match(plan)
    if not plan then return false end
    if item and tostring(plan.item or "") == tostring(item) then return true end
    if plan.key and tostring(plan.key):find(keypart, 1, true) then return true end
    return false
  end
  if match(q.current) then return true end
  for _, p in ipairs(q.pending or {}) do if match(p) then return true end end
  return false
end

function M.wrap_magos_planning()
  local mp = rawget(_G, "TECH_PRIESTS_MAGOS_PLANNING_QUEUE_0471")
  if not (mp and type(mp.submit_plan) == "function") then return false end
  if mp.retention_wrapped_0476 then return true end
  original_magos_submit_plan = mp.submit_plan
  mp.retention_wrapped_0476 = true
  mp.submit_plan = function(pair, item, reason, plan_table)
    if enabled() and is_magos_pair(pair) and item then
      local q = pair.magos_planning_queue_0471
      local duplicate = magos_plan_duplicate(q, item, reason)
      if q and q.current and not duplicate then
        local cap = pending_cap_for(pair)
        local next_tick = tonumber(pair.next_magos_plan_tick_0476 or 0) or 0
        if #(q.pending or {}) >= math.max(1, cap) then
          pair.magos_retention_0476 = { tick = now(), action = "plan-ledger-full", item = item, pending = #(q.pending or {}) }
          stat("magos_plan_cap_held")
          return false, "planning-ledger-full", q.current
        end
        if now() < next_tick then
          pair.magos_retention_0476 = { tick = now(), action = "plan-cadence-held", item = item, next_tick = next_tick }
          stat("magos_plan_cadence_held")
          return false, "planning-cadence", q.current
        end
      end
    end
    local ok, result, rec = original_magos_submit_plan(pair, item, reason, plan_table)
    if is_magos_pair(pair) and (result == "current" or result == "queued") then
      local seconds = setting_seconds("tech-priests-magos-plan-cadence-seconds", M.magos_plan_cadence_ticks / 60)
      pair.next_magos_plan_tick_0476 = now() + math.floor(clamp(seconds, 1, 3600) * 60)
      pair.last_magos_plan_0476 = { tick = now(), result = result, item = item, reason = reason }
    end
    return ok, result, rec
  end
  _G.tech_priests_magos_planning_queue_0471_submit = mp.submit_plan
  return true
end

local function sound_action_event(pair)
  if not valid_pair(pair) then return nil end
  local q = pair.order_queue_0469
  local order = pair.active_order_0469 or (q and q.current) or nil
  local kind = normalize_kind(order and order.kind or pair.mode)
  local mode = lower(pair.mode)
  if kind == "combat" or mode:find("combat", 1, true) or mode:find("defend", 1, true) or mode:find("laser%-fallback") then return "emergency_laser_action" end
  if kind == "repair" or mode:find("repair", 1, true) then return "repair_action" end
  if kind == "consecration" or mode:find("consecr", 1, true) or mode:find("sanct", 1, true) then return "consecrate_action" end
  if kind == "emergency_craft" or mode:find("craft", 1, true) then return "crafting_action" end
  if kind == "acquisition" or kind == "scavenge" or mode:find("gather", 1, true) or mode:find("mine", 1, true) or mode:find("scavenge", 1, true) then return "mining_laser_action" end
  if kind == "logistics" or mode:find("logistic", 1, true) then return "logistics_request" end
  return nil
end

local function stable_sound_signature(pair)
  local q = pair and pair.order_queue_0469
  local order = pair and (pair.active_order_0469 or (q and q.current)) or nil
  if order then return safe(order.key) .. "|" .. safe(order.item) .. "|" .. safe(order.kind) end
  return "no-active-order"
end

function M.wrap_sound_manager()
  local sm = rawget(_G, "TECH_PRIESTS_SOUND_MANAGER_0475")
  if not (sm and type(sm.tick_pair) == "function" and type(sm.emit) == "function") then return false end
  if sm.retention_wrapped_0476 then return true end
  original_sound_tick_pair = sm.tick_pair
  sm.retention_wrapped_0476 = true
  sm.station_task_switch_cooldown = math.max(tonumber(sm.station_task_switch_cooldown or 0) or 0, 60 * 15)
  sm.writ_cooldown = math.max(tonumber(sm.writ_cooldown or 0) or 0, 60 * 12)
  sm.action_ambience_cooldown = math.max(tonumber(sm.action_ambience_cooldown or 0) or 0, 60 * 6)
  sm.tick_pair = function(pair)
    if not valid_pair(pair) then return end
    local sig = stable_sound_signature(pair)
    if pair.sound_manager_stable_signature_0476 == nil then
      pair.sound_manager_stable_signature_0476 = sig
    elseif pair.sound_manager_stable_signature_0476 ~= sig then
      local next_switch = tonumber(pair.next_station_switch_sound_0476 or 0) or 0
      pair.sound_manager_stable_signature_0476 = sig
      if now() >= next_switch then
        local order = pair.active_order_0469 or (pair.order_queue_0469 and pair.order_queue_0469.current) or nil
        sm.emit(pair, "station_task_switch", {
          source = "station",
          item = order and order.item,
          key = sig,
          cooldown_key = "station-switch-stable-0476:" .. safe(valid(pair.station) and pair.station.unit_number or "?"),
          cooldown_ticks = 60 * 15,
          volume_multiplier = 0.30,
        })
        pair.next_station_switch_sound_0476 = now() + 60 * 15
        stat("station_switch_sounds")
      else
        stat("station_switch_sounds_suppressed")
      end
    end

    local event = sound_action_event(pair)
    if event then
      local order = pair.active_order_0469 or (pair.order_queue_0469 and pair.order_queue_0469.current) or nil
      local cd = (event == "emergency_laser_action") and (60 * 3) or (60 * 8)
      sm.emit(pair, event, {
        source = event == "logistics_request" and "station" or "priest",
        item = order and order.item,
        key = event,
        cooldown_key = "action-ambience-0476:" .. event,
        cooldown_ticks = cd,
        volume_multiplier = (event == "emergency_laser_action") and 0.32 or 0.22,
      })
    end
  end
  return true
end

local function held_station_name(player)
  if not (player and player.valid) then return nil end
  local stack = player.cursor_stack
  if stack and stack.valid_for_read then
    local name = tostring(stack.name or "")
    if name:find("cogitator%-station") then return name end
  end
  return nil
end

local function selected_is_station_or_priest(player)
  local e = player and player.valid and player.selected or nil
  if not valid(e) then return false end
  local n = tostring(e.name or "")
  return n:find("cogitator%-station") ~= nil or n:find("tech%-priest") ~= nil or n:find("magos%-tech%-priest") ~= nil
end

local function destroy_list(list)
  if not list then return end
  for _, obj in pairs(list) do pcall(function() if obj and obj.valid then obj.destroy() end end) end
end

function M.patch_visual_authority()
  local vis = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
  if vis then
    vis.ttl = 120
    vis.redraw_period = 60
    vis.refresh_period = 15
  end
end

function M.visual_lease_tick()
  if not (game and game.connected_players and storage and storage.tech_priests) then return end
  local vis = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
  local vroot = storage.tech_priests.alt_writ_visual_stability_0474
  if not vroot then return end
  vroot.context_inactive_cleaned_0476 = vroot.context_inactive_cleaned_0476 or {}
  for _, player in pairs(game.connected_players) do
    if player and player.valid then
      local active_context = held_station_name(player) ~= nil or selected_is_station_or_priest(player)
      if active_context then
        vroot.context_inactive_cleaned_0476[player.index] = nil
      elseif not vroot.context_inactive_cleaned_0476[player.index] then
        destroy_list(vroot.objects_by_player and vroot.objects_by_player[player.index])
        if vroot.objects_by_player then vroot.objects_by_player[player.index] = nil end
        if vroot.signature_by_player then vroot.signature_by_player[player.index] = nil end
        vroot.context_inactive_cleaned_0476[player.index] = now()
        stat("visual_context_clears")
        if vis and type(vis.refresh_player) == "function" then pcall(vis.refresh_player, player) end
      end
    end
  end
end

function M.retention_tick()
  if not enabled() then return end
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      ensure_current_retention(pair)
      local q = pair.order_queue_0469
      local cur = q and q.current
      if cur and cur.retain_until_0476 and now() > cur.retain_until_0476 then cur.retention_released_0476 = true end
    end
  end
end

function M.describe(pair)
  local r = root()
  local lines = {}
  lines[#lines + 1] = "enabled=" .. safe(r.enabled) .. " held-preemptions=" .. safe(r.stats.preemptions_held or 0) .. " cadence-held=" .. safe(r.stats.cadence_held or 0) .. " pending-cap-held=" .. safe(r.stats.pending_cap_held or 0) .. " visual-clears=" .. safe(r.stats.visual_context_clears or 0)
  if pair and valid_pair(pair) then
    local q = pair.order_queue_0469
    local cur = q and q.current
    lines[#lines + 1] = "current=" .. safe(cur and cur.key or "none") .. " item=" .. safe(cur and cur.item) .. " retain-until=" .. safe(cur and cur.retain_until_0476) .. " next-writ=" .. safe(pair.next_low_writ_tick_0476)
    lines[#lines + 1] = "pending=" .. safe(q and #(q.pending or {}) or 0) .. " last-hold=" .. safe(pair.task_retention_0476 and pair.task_retention_0476.action)
    if is_magos_pair(pair) then lines[#lines + 1] = "magos-next-plan=" .. safe(pair.next_magos_plan_tick_0476) .. " last-magos-hold=" .. safe(pair.magos_retention_0476 and pair.magos_retention_0476.action) end
  end
  return lines
end

local function selected_pair(player)
  if not (player and player.valid and storage and storage.tech_priests) then return nil end
  local e = player.selected
  if valid(e) then
    local unit = e.unit_number
    return (storage.tech_priests.pairs_by_station or {})[unit] or (storage.tech_priests.pairs_by_priest or {})[unit]
  end
  return nil
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-task-retention-0476") end end)
  pcall(function()
    commands.add_command("tp-task-retention-0476", "Tech Priests: inspect/toggle task retention, slow writ cadence, and overlay lease cleanup.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local param = lower(event and event.parameter or "status")
      local r = root()
      if param == "off" or param == "disable" then r.enabled = false end
      if param == "on" or param == "enable" then r.enabled = true end
      if param == "visual" or param == "clear-visuals" then M.visual_lease_tick() end
      if player and player.valid then
        for _, line in ipairs(M.describe(selected_pair(player))) do player.print("[tp-task-retention-0476] " .. line) end
      end
    end)
  end)
end

function M.install()
  if M._installed then return true end
  M._installed = true
  root()
  M.patch_visual_authority()
  M.wrap_order_queue()
  M.wrap_magos_planning()
  M.wrap_sound_manager()
  _G.TECH_PRIESTS_TASK_RETENTION_VISUAL_LEASE_0476 = M
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.visual_tick_interval, function() M.visual_lease_tick() end, { owner = "task_retention_visual_lease_0476", category = "visuals", priority = "last" })
    registry.on_nth_tick(M.retention_tick_interval, function() M.retention_tick() end, { owner = "task_retention_visual_lease_0476", category = "scheduler", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.visual_tick_interval, function() M.visual_lease_tick() end) end)
    pcall(function() script.on_nth_tick(M.retention_tick_interval, function() M.retention_tick() end) end)
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.476] task retention, slow writ cadence, sound-switch throttling, and overlay lease authority installed") end
  return true
end

return M
