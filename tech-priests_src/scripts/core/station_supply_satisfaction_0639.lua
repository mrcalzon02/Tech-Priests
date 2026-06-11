-- scripts/core/station_supply_satisfaction_0639.lua
-- Tech Priests 0.1.639
--
-- Stale survival-supply satisfaction clearer.
--
-- The 0.1.637 live logs showed stations still advertising the ammo-needs writ
-- after the player had supplied ammunition.  The stale state lived in old
-- emergency/supply fields such as survival-ammo, last_item=firearm-magazine, and
-- blocker="station lacks firearm-magazine (0/1)" while the actual work stack had
-- moved on to unrelated raw-resource acquisition.  This module does not add a new
-- behavior tree branch; it only reconciles already-satisfied critical supply
-- requests against station-owned inventory and clears the obsolete request/icon
-- state.

local M = {}
M.version = "0.1.639"
M.storage_key = "station_supply_satisfaction_0639"
M.tick_interval = 37
M.max_pairs_per_pulse = 32
M.log_interval = 600

local CRITICAL = {
  ["firearm-magazine"] = true,
  ["piercing-rounds-magazine"] = true,
  ["uranium-rounds-magazine"] = true,
  ["repair-pack"] = true,
  ["sacred-machine-oil"] = true,
  ["machine-maintenance-litany"] = true,
  ["ritual-of-machine-appeasement"] = true,
}

local AMMO_EQUIVALENTS = {
  ["firearm-magazine"] = true,
  ["piercing-rounds-magazine"] = true,
  ["uranium-rounds-magazine"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, s = pcall(function() return tostring(v) end); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1)
end

local function record(action, pair, detail, force)
  local r = root()
  local su = safe(station_unit(pair))
  local ev = { tick = now(), action = tostring(action or "event"), station = su, detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 80 do table.remove(r.recent, 1) end
  stat(action)
  local key = tostring(action) .. ":" .. su
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.639] " .. safe(action) .. " station=" .. su .. " " .. safe(detail)) end
  end
end

local function item_exists(name)
  return name and prototypes and prototypes.item and prototypes.item[name] ~= nil
end

local function canonical_item(item)
  if item == "ammo" then return "firearm-magazine" end
  if item == "repair" then return "repair-pack" end
  return item
end

local function item_from(v)
  if type(v) == "string" then return canonical_item(v) end
  if type(v) ~= "table" then return nil end
  return canonical_item(v.item or v.item_name or v.name or v.output_item or v.wanted_item or v.requested_item or v.kind)
end

local function item_matches(v, item)
  local found = item_from(v)
  if found == item then return true end
  if AMMO_EQUIVALENTS[item] and found and AMMO_EQUIVALENTS[found] then return true end
  return false
end

local function critical_item(item)
  item = canonical_item(item)
  return item and CRITICAL[item] == true
end

local function safe_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end

local function safe_get_inventory(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function add_inventory(out, seen, inv, source)
  if inv and inv.valid and not seen[tostring(inv)] then
    out[#out + 1] = { inv = inv, source = source or "inventory" }
    seen[tostring(inv)] = true
  end
end

local function station_owned_sources(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end

  if type(rawget(_G, "tech_priests_inventory_steward_sources_for_pair")) == "function" then
    local ok, sources = pcall(rawget(_G, "tech_priests_inventory_steward_sources_for_pair"), pair)
    if ok and type(sources) == "table" then
      for _, src in ipairs(sources) do
        if src and src.inv and src.inv.valid then add_inventory(out, seen, src.inv, src.source or src.inventory_id or "steward") end
      end
    end
  end

  -- Fallback-only source.  For satisfaction checks we may read the station chest;
  -- generic insertion is still owned by the 0.1.638 deposit safety guard.
  if defines and defines.inventory then
    add_inventory(out, seen, safe_get_inventory(pair.station, defines.inventory.chest), "station-chest")
  end

  return out
end

local function available_count(pair, item)
  if not (valid_pair(pair) and item_exists(item)) then return 0 end
  local total = 0
  for _, src in ipairs(station_owned_sources(pair)) do total = total + safe_count(src.inv, item) end
  if total > 0 then return total end
  -- Any magazine satisfies the generic survival-ammo icon/request.
  if item == "firearm-magazine" then
    for alt in pairs(AMMO_EQUIVALENTS) do
      if alt ~= item and item_exists(alt) then
        for _, src in ipairs(station_owned_sources(pair)) do total = total + safe_count(src.inv, alt) end
      end
    end
  end
  return total
end

local function requested_items(pair)
  local out = {}
  local function add(item)
    item = canonical_item(item)
    if critical_item(item) then out[item] = true end
  end
  if not pair then return out end
  add(pair.logistic_requested_item)
  add(pair.requested_item)
  add(pair.last_item)
  add(item_from(pair.active_supply_request))
  add(item_from(pair.supply_request))
  add(pair.inventory_scan and item_from(pair.inventory_scan))
  add(pair.inventory_scan and item_from(pair.inventory_scan.request))
  add(item_from(pair.scavenge))
  add(item_from(pair.emergency_craft))
  add(item_from(pair.direct_acquisition_task_0336))
  add(item_from(pair.active_acquisition_0333))
  add(item_from(pair.active_order_0469))
  local q = pair.order_queue_0469
  if q then
    add(item_from(q.current))
    for _, order in ipairs(q.pending or {}) do add(item_from(order)) end
  end
  for _, op in ipairs({ pair.independent_emergency_operation_0184, pair.emergency_operation }) do
    if type(op) == "table" then
      add(op.last_item)
      local text = lower(op.phase or "") .. " " .. lower(op.last_blocker_0264 or "") .. " " .. lower(op.last_blocker_0266 or "") .. " " .. lower(op.last_blocker_0267 or "") .. " " .. lower(op.blocker or "")
      if text:find("survival%-ammo", 1, false) or text:find("firearm%-magazine", 1, false) or text:find("ammo", 1, true) then add("firearm-magazine") end
      if text:find("repair%-pack", 1, false) or text:find("survival%-repair", 1, false) then add("repair-pack") end
    end
  end
  return out
end

local function complete_order(q, order, item, reason)
  if not (q and order) then return false end
  q.history = q.history or {}
  q.history[#q.history + 1] = { key = order.key, kind = order.kind, item = order.item or item, status = "complete", reason = reason, tick = now() }
  while #q.history > 16 do table.remove(q.history, 1) end
  return true
end

local function clear_op(op, item)
  if type(op) ~= "table" then return false end
  local text = lower(op.phase or "") .. " " .. lower(op.last_blocker_0264 or "") .. " " .. lower(op.last_blocker_0266 or "") .. " " .. lower(op.last_blocker_0267 or "") .. " " .. lower(op.blocker or "")
  local matched = item_matches(op.last_item, item)
    or (item == "firearm-magazine" and (text:find("survival%-ammo", 1, false) or text:find("firearm%-magazine", 1, false) or text:find("ammo", 1, true)))
    or (item == "repair-pack" and (text:find("survival%-repair", 1, false) or text:find("repair%-pack", 1, false)))
  if not matched then return false end
  op.last_blocker_0264 = nil
  op.last_blocker_0266 = nil
  op.last_blocker_0267 = nil
  op.blocker = nil
  op.satisfied_item_0639 = item
  op.satisfied_tick_0639 = now()
  if lower(op.phase or ""):find("survival", 1, true) then op.phase = "survival-satisfied" end
  return true
end

local function clear_request_state(pair, item, reason)
  if not (pair and item) then return false end
  local changed = false
  if item_matches(pair.logistic_requested_item, item) then pair.logistic_requested_item = nil; pair.logistic_requested_count = nil; changed = true end
  if item_matches(pair.requested_item, item) then pair.requested_item = nil; changed = true end
  if item_matches(pair.last_item, item) then pair.last_item = nil; changed = true end
  if item_matches(pair.active_supply_request, item) then pair.active_supply_request = nil; changed = true end
  if item_matches(pair.supply_request, item) then pair.supply_request = nil; changed = true end
  if pair.inventory_scan and (item_matches(pair.inventory_scan, item) or item_matches(pair.inventory_scan.request, item)) then pair.inventory_scan = nil; changed = true end
  if item_matches(pair.scavenge, item) then pair.scavenge = nil; changed = true end
  if item_matches(pair.emergency_craft, item) then pair.emergency_craft = nil; changed = true end
  if item_matches(pair.direct_acquisition_task_0336, item) then pair.direct_acquisition_task_0336 = nil; changed = true end
  if item_matches(pair.active_acquisition_0333, item) then pair.active_acquisition_0333 = nil; changed = true end

  local q = pair.order_queue_0469
  if q then
    if q.current and item_matches(q.current, item) then
      complete_order(q, q.current, item, reason)
      q.current.status = "complete"
      q.current.finished_tick = now()
      q.current.finish_reason = reason
      q.current = nil
      pair.active_order_0469 = nil
      changed = true
    end
    local keep = {}
    q.pending_keys = {}
    for _, order in ipairs(q.pending or {}) do
      if order and item_matches(order, item) then
        complete_order(q, order, item, reason)
        changed = true
      elseif order then
        keep[#keep + 1] = order
        if order.key then q.pending_keys[order.key] = true end
      end
    end
    q.pending = keep
  end

  if clear_op(pair.independent_emergency_operation_0184, item) then changed = true end
  if clear_op(pair.emergency_operation, item) then changed = true end

  if changed then
    pair.last_supply_satisfied_0639 = { tick = now(), item = item, reason = reason }
    if pair.mode and lower(pair.mode):find("independent%-emergency", 1, false) then pair.mode = "returning" end
    record("satisfied-stale-supply-0639", pair, "item=" .. safe(item) .. " reason=" .. safe(reason), true)
  end
  return changed
end

function M.item_satisfied(pair, item)
  item = canonical_item(item)
  if not critical_item(item) then return false end
  return available_count(pair, item) >= 1
end

function M.service_pair(pair, reason)
  local r = root()
  if r.enabled == false then return false end
  if not valid_pair(pair) then return false end
  local changed = false
  for item in pairs(requested_items(pair)) do
    local have = available_count(pair, item)
    if have >= 1 then
      if clear_request_state(pair, item, reason or "station-supply-present-0639") then
        changed = true
        stat("items_satisfied", 1)
      end
    else
      stat("items_still_missing", 1)
    end
  end
  return changed
end

function M.service_all(reason)
  local r = root()
  if r.enabled == false then return 0 end
  local n, changed = 0, 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then
      n = n + 1
      local ok, did = pcall(M.service_pair, pair, reason or "pulse")
      if ok and did then changed = changed + 1 end
    end
  end
  r.last_service_tick = now()
  return changed
end

local function selected_pair(player)
  local selected = player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local unit = selected.unit_number
    if unit and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[unit] then return storage.tech_priests.pairs_by_station[unit] end
    if unit and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[unit] then return storage.tech_priests.pairs_by_priest[unit] end
  end
  if selected and selected.valid and type(_G.find_pair_for_entity) == "function" then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok then return pair end end
  return nil
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-supply-satisfaction-0639") end end)
  commands.add_command("tp-supply-satisfaction-0639", "Tech Priests 0.1.639: clear stale satisfied ammo/repair/supply writs. Params: status/all/kick/on/off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false elseif p == "all" then M.service_all("command-all") elseif p == "kick" then local pair = selected_pair(player); if pair then M.service_pair(pair, "command-kick") end end
    local pair = selected_pair(player)
    local counts = ""
    if pair then
      counts = " selected=" .. safe(station_unit(pair)) .. " ammo=" .. safe(available_count(pair, "firearm-magazine")) .. " repair=" .. safe(available_count(pair, "repair-pack"))
    end
    local msg = "[tp-supply-satisfaction-0639] enabled=" .. safe(r.enabled) .. " satisfied=" .. safe(r.stats["satisfied-stale-supply-0639"] or 0) .. " items=" .. safe(r.stats.items_satisfied or 0) .. " missing=" .. safe(r.stats.items_still_missing or 0) .. counts
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  root()
  _G.TechPriestsStationSupplySatisfaction0639 = M
  _G.tech_priests_writ_item_satisfied_0639 = M.item_satisfied
  install_command()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "station_supply_satisfaction_0639", category = "inventory", interval = M.tick_interval, priority = 75, budget = 8, fn = function(event, budget) M.service_all("broker") return true end, note = "clear stale satisfied ammo/repair/supply writ states" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "station_supply_satisfaction_0639", category = "inventory", priority = "late" })
    elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.639] station supply satisfaction clearer installed; stale ammo/repair icons clear when station-owned inventory has the requested item") end
  return true
end

return M
