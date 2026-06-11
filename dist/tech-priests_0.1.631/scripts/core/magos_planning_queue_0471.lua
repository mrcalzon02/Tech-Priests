-- scripts/core/magos_planning_queue_0471.lua
-- Tech Priests 0.1.471
-- Planetary Magos planning queue.
--
-- The Planetary Magos needs two layers of intent: a slow strategic construction
-- queue built from ratio/construction doctrine, and ordinary immediate personal
-- work orders used to gather, defend, repair, consecrate, or place the next
-- object.  This module records and de-duplicates the strategic layer so the
-- planner stops rediscovering the same construction ambition every few ticks.

local M = {}
M.version = "0.1.471"
M.storage_key = "magos_planning_queue_0471"
M.queue_limit = 10
M.plan_lease_ticks = 60 * 60 * 5

local original_pick_standard_need = nil
local original_service_magos_planner = nil

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
local function surface_name(pair) return pair and valid(pair.station) and pair.station.surface and pair.station.surface.name or "unknown-surface" end

local function is_magos_pair(pair)
  if not valid_pair(pair) then return false end
  local tier = lower(pair.tier or pair.rank or pair.station_rank)
  local sname = lower(pair.station.name)
  local pname = lower(pair.priest.name)
  if tier:find("planetary%-magos", 1, false) then return true end
  if sname:find("planetary%-magos", 1, false) or pname:find("planetary%-magos", 1, false) then return true end
  if _G.tech_priests_0255_pair_is_magos_planner then local ok, yes = pcall(_G.tech_priests_0255_pair_is_magos_planner, pair); if ok and yes then return true end end
  return false
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {} }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  return root
end

local function enabled() return ensure_root().enabled ~= false end

local function queue(pair)
  if not pair then return nil end
  pair.magos_planning_queue_0471 = pair.magos_planning_queue_0471 or {
    version = M.version,
    current = nil,
    pending = {},
    keys = {},
    history = {},
    stats = {},
  }
  local q = pair.magos_planning_queue_0471
  q.version = M.version
  q.pending = q.pending or {}
  q.keys = {}
  q.history = q.history or {}
  q.stats = q.stats or {}
  local clean = {}
  for _, plan in ipairs(q.pending or {}) do
    if plan and plan.key and plan.status ~= "complete" and plan.status ~= "cancelled" and plan.status ~= "failed" then
      if not q.keys[plan.key] then q.keys[plan.key] = true; clean[#clean + 1] = plan end
    end
  end
  q.pending = clean
  return q
end

local function plan_key(pair, item, reason)
  return "plan:" .. safe(station_unit(pair) or "?") .. ":" .. safe(surface_name(pair)) .. ":" .. safe(item or "none") .. ":" .. safe(reason or "standard")
end

local function remember(q, plan, status, why)
  q.history[#q.history + 1] = { key = plan and plan.key or "nil", item = plan and plan.item or nil, status = status, reason = why, tick = now() }
  while #q.history > 12 do table.remove(q.history, 1) end
end

local function station_has_item(pair, item)
  if not (valid_pair(pair) and item) then return false end
  local inv = nil
  if _G.get_station_inventory then local ok, out = pcall(_G.get_station_inventory, pair.station); if ok then inv = out end end
  if not inv and pair.station.get_inventory and defines and defines.inventory then
    local ids = { defines.inventory.chest, defines.inventory.assembling_machine_input, defines.inventory.furnace_source }
    for _, id in ipairs(ids) do
      local ok, out = pcall(function() return pair.station.get_inventory(id) end)
      if ok and out and out.valid then inv = out; break end
    end
  end
  if inv and inv.valid then local ok, c = pcall(function() return inv.get_item_count(item) end); return ok and (tonumber(c) or 0) > 0 end
  return false
end

local function immediate_work_matches(pair, item)
  if not valid_pair(pair) then return false end
  local q = pair.order_queue_0469
  local current = q and q.current or pair.active_order_0469
  if current and item and tostring(current.item or "") == tostring(item) and current.status ~= "complete" and current.status ~= "failed" and current.status ~= "cancelled" then return true end
  if pair.emergency_craft then
    local cur = pair.emergency_craft.current or pair.emergency_craft
    local it = cur.item or cur.item_name or cur.output_item or pair.emergency_craft.item or pair.emergency_craft.item_name or pair.emergency_craft.output_item
    if item and it == item then return true end
  end
  if pair.scavenge then
    local it = pair.scavenge.item or pair.scavenge.item_name or pair.scavenge.name
    if item and it == item then return true end
  end
  return false
end

function M.submit_plan(pair, item, reason, plan_table)
  if not enabled() or not is_magos_pair(pair) or not item then return true, "not-magos-or-disabled" end
  local q = queue(pair)
  local key = plan_key(pair, item, reason)
  if q.current and q.current.key == key and q.current.status ~= "complete" and q.current.status ~= "cancelled" and q.current.status ~= "failed" then
    q.current.last_seen_tick = now()
    q.current.seen_count = (q.current.seen_count or 0) + 1
    q.stats.duplicates_blocked = (q.stats.duplicates_blocked or 0) + 1
    ensure_root().stats.duplicates_blocked = (ensure_root().stats.duplicates_blocked or 0) + 1
    return false, "duplicate-current", q.current
  end
  if q.keys[key] then
    q.stats.duplicates_blocked = (q.stats.duplicates_blocked or 0) + 1
    ensure_root().stats.duplicates_blocked = (ensure_root().stats.duplicates_blocked or 0) + 1
    return false, "duplicate-pending"
  end
  local rec = {
    key = key,
    item = item,
    reason = reason or "standard-industry",
    status = "current",
    created_tick = now(),
    last_seen_tick = now(),
    expires_tick = now() + M.plan_lease_ticks,
    station_unit = station_unit(pair),
    surface = surface_name(pair),
    ratio_plan = plan_table,
  }
  if not q.current then
    q.current = rec
    pair.magos_current_plan_0471 = rec
    remember(q, rec, "current", "new-plan")
    q.stats.started = (q.stats.started or 0) + 1
    ensure_root().stats.started = (ensure_root().stats.started or 0) + 1
    return true, "current", rec
  end
  if #q.pending >= M.queue_limit then
    q.stats.queue_full = (q.stats.queue_full or 0) + 1
    ensure_root().stats.queue_full = (ensure_root().stats.queue_full or 0) + 1
    return false, "queue-full", q.current
  end
  rec.status = "queued"
  q.keys[key] = true
  q.pending[#q.pending + 1] = rec
  remember(q, rec, "queued", "behind-current")
  q.stats.queued = (q.stats.queued or 0) + 1
  ensure_root().stats.queued = (ensure_root().stats.queued or 0) + 1
  return false, "queued", rec
end

local function pop_next(q)
  while q and #q.pending > 0 do
    local rec = table.remove(q.pending, 1)
    if rec and rec.key then q.keys[rec.key] = nil end
    if rec and rec.key and rec.status ~= "complete" and rec.status ~= "failed" and rec.status ~= "cancelled" then return rec end
  end
  return nil
end

function M.tick_pair(pair)
  if not (enabled() and is_magos_pair(pair)) then return false end
  local q = queue(pair)
  local cur = q.current
  if cur then
    local complete = false
    local why = nil
    if cur.expires_tick and now() > cur.expires_tick then complete = true; why = "expired" end
    if not complete and station_has_item(pair, cur.item) then complete = true; why = "item-in-reliquary" end
    if not complete and pair.construction then complete = true; why = "construction-opened" end
    if complete then
      cur.status = why == "expired" and "failed" or "complete"
      cur.finished_tick = now()
      cur.finish_reason = why
      remember(q, cur, cur.status, why)
      q.current = pop_next(q)
      if q.current then q.current.status = "current"; q.current.activated_tick = now(); remember(q, q.current, "current", "promotion") end
      pair.magos_current_plan_0471 = q.current
      return true
    elseif immediate_work_matches(pair, cur.item) then
      cur.status = "delegated"
      cur.delegated_tick = cur.delegated_tick or now()
      pair.magos_current_plan_0471 = cur
    end
  else
    q.current = pop_next(q)
    if q.current then q.current.status = "current"; q.current.activated_tick = now(); pair.magos_current_plan_0471 = q.current; return true end
  end
  return false
end

function M.tick_all()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do pcall(M.tick_pair, pair) end
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  if _G.tech_priests_find_pair_for_player_selection_0184 then local ok, pair = pcall(_G.tech_priests_find_pair_for_player_selection_0184, player); if ok and pair then return pair end end
  local selected = player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local unit = selected.unit_number
    return (storage.tech_priests.pairs_by_station or {})[unit] or (storage.tech_priests.pairs_by_priest or {})[unit]
  end
  return nil
end

local function describe(pair)
  local q = pair and queue(pair)
  local lines = {}
  if not q then return { "no Magos planning queue" } end
  local cur = q.current
  lines[#lines + 1] = "current=" .. (cur and (safe(cur.key) .. " item=" .. safe(cur.item) .. " status=" .. safe(cur.status) .. " reason=" .. safe(cur.reason)) or "none")
  lines[#lines + 1] = "pending=" .. safe(#(q.pending or {})) .. " duplicates=" .. safe(q.stats.duplicates_blocked or 0) .. " queued=" .. safe(q.stats.queued or 0)
  for i, rec in ipairs(q.pending or {}) do lines[#lines + 1] = "pending[" .. i .. "]=" .. safe(rec.key) .. " item=" .. safe(rec.item) .. " status=" .. safe(rec.status) end
  return lines
end

function M.install()
  _G.TECH_PRIESTS_MAGOS_PLANNING_QUEUE_0471 = M
  _G.tech_priests_magos_planning_queue_0471_submit = M.submit_plan

  if type(_G.tech_priests_0255_pick_standard_need) == "function" and not original_pick_standard_need then
    original_pick_standard_need = _G.tech_priests_0255_pick_standard_need
    _G.tech_priests_0255_pick_standard_need = function(pair, op)
      local item, reason = original_pick_standard_need(pair, op)
      if item and is_magos_pair(pair) then
        local plan = op and op.magos_ratio_plan_0257 or nil
        local ok, result, rec = M.submit_plan(pair, item, reason, plan)
        -- If the exact strategic plan is already current and has already been
        -- handed to an immediate order, do not rediscover and reannounce it on
        -- every planner pulse.  The personal order queue is already carrying it.
        if result == "duplicate-current" and immediate_work_matches(pair, item) then return nil, "plan-already-under-rite" end
      end
      return item, reason
    end
  end

  if type(_G.tech_priests_0255_service_magos_standard_planner) == "function" and not original_service_magos_planner then
    original_service_magos_planner = _G.tech_priests_0255_service_magos_standard_planner
    _G.tech_priests_0255_service_magos_standard_planner = function(pair, op)
      pcall(M.tick_pair, pair)
      return original_service_magos_planner(pair, op)
    end
  end

  if TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
    TechPriestsRuntimeEventRegistry.on_nth_tick(179, function() M.tick_all() end, { owner = "magos_planning_queue_0471", category = "scheduler" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(179, M.tick_all) end)
  end
  if commands and commands.add_command then
    pcall(function() if commands.remove_command then commands.remove_command("tp-magos-planning-0471") end end)
    pcall(function()
      commands.add_command("tp-magos-planning-0471", "Tech Priests: inspect Planetary Magos strategic planning queue.", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        if not (player and player.valid) then return end
        local pair = selected_pair(player)
        if not pair then player.print("[tp-magos-planning-0471] select a Planetary Magos station or priest."); return end
        if not is_magos_pair(pair) then player.print("[tp-magos-planning-0471] selected pair is not a Planetary Magos planning cell."); return end
        for _, line in ipairs(describe(pair)) do player.print("[tp-magos-planning-0471] " .. line) end
      end)
    end)
  end
  if log then log("[Tech-Priests 0.1.471] Planetary Magos strategic planning queue installed") end
  return true
end

return M
