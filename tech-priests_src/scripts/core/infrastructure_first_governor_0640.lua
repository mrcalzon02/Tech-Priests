-- scripts/core/infrastructure_first_governor_0640.lua
-- Tech Priests 0.1.643
--
-- Infrastructure-first behavior governor.
--
-- The 0.1.639 behavior logs showed higher-tier station/cogitator dependency
-- requests leaking into primitive acquisition.  Senior/intermediate stations were
-- trying to direct-gather servitor-parts and offworld-cogitator-components, then
-- falling through into literal-mismatch ore targets.  This module gates those
-- high-tier requests until local industry exists.
--
-- 0.1.643 adds the normal-mining preference: emergency micro-miners are now the
-- fallback of last resort. If minable resource patches exist inside station
-- authority, the local infrastructure step should prefer normal mining drills
-- starting with burner mining drills, then higher mining drill items when burner
-- drills do not exist in the current mod set.

local M = {}
M.version = "0.1.643"
M.storage_key = "infrastructure_first_governor_0640"
M.tick_interval = 23
M.max_pairs_per_pulse = 32
M.log_interval = 600
M.min_iron_plate = 4
M.min_copper_plate = 2

local EMERGENCY_ENTITY_BY_ITEM = {
  ["tech-priests-emergency-miner"] = "miner",
  ["tech-priests-emergency-smelter"] = "smelter",
  ["tech-priests-emergency-assembler"] = "assembler",
  ["tech-priests-emergency-power-grid"] = "power-grid",
  ["tech-priests-atmospheric-water-condenser"] = "condenser",
  ["tech-priests-emergency-boiler"] = "boiler",
  ["tech-priests-emergency-steam-engine"] = "steam-engine",
  ["tech-priests-emergency-laboratorium"] = "lab",
}

local NORMAL_MINER_ITEMS = {
  "burner-mining-drill",
  "electric-mining-drill",
  "big-mining-drill",
}

local HIGH_TIER_ITEMS = {
  ["servitor-parts"] = true,
  ["offworld-cogitator-components"] = true,
  ["relic-fragment"] = true,
  ["void-sealed-cargo"] = true,
  ["machine-maintenance-litany"] = true,
  ["ritual-of-machine-appeasement"] = true,
  ["junior-cogitator-station"] = true,
  ["intermediate-cogitator-station"] = true,
  ["senior-cogitator-station"] = true,
  ["planetary-magos-cogitator-station"] = true,
  ["void-cogitator-station"] = true,
  ["advanced-circuit"] = true,
  ["processing-unit"] = true,
  ["roboport"] = true,
}

local LOCAL_PRODUCTS = {
  ["iron-plate"] = true,
  ["copper-plate"] = true,
  ["stone-brick"] = true,
  ["iron-gear-wheel"] = true,
  ["repair-pack"] = true,
  ["firearm-magazine"] = true,
  ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true,
  ["big-mining-drill"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    audit_only = false,
    stats = {},
    recent = {},
    last_log = {},
  }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.audit_only == nil then r.audit_only = false end
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
  stat(action)
  local su = safe(station_unit(pair))
  local ev = { tick = now(), action = tostring(action or "event"), station = su, priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 120 do table.remove(r.recent, 1) end
  local key = tostring(action) .. ":" .. su
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.643] " .. safe(action) .. " station=" .. su .. " priest=" .. safe(priest_unit(pair)) .. " " .. safe(detail)) end
  end
end

local function item_exists(name)
  return name and prototypes and prototypes.item and prototypes.item[name] ~= nil
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  local cur = v.current or v.request or v
  return cur.output_item or cur.item_name or cur.item or cur.name or cur.wanted_item or cur.requested_item or cur.target_item or cur.craft or cur.kind
end

local function high_tier(item)
  item = tostring(item or "")
  return HIGH_TIER_ITEMS[item] == true
end

local function local_product(item)
  item = tostring(item or "")
  return LOCAL_PRODUCTS[item] == true or EMERGENCY_ENTITY_BY_ITEM[item] ~= nil
end

local function safe_inventory(entity, id)
  if not (valid(entity) and entity.get_inventory and id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function station_inventories(pair)
  local out = {}
  if not (valid_pair(pair) and defines and defines.inventory) then return out end
  local ids = { defines.inventory.chest, defines.inventory.assembling_machine_input, defines.inventory.assembling_machine_output, defines.inventory.furnace_result, defines.inventory.furnace_source }
  local seen = {}
  for _, id in ipairs(ids) do
    local inv = safe_inventory(pair.station, id)
    if inv and not seen[tostring(inv)] then out[#out + 1] = inv; seen[tostring(inv)] = true end
  end
  return out
end

local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(n) or 0) or 0
end

local function station_count(pair, item)
  local total = 0
  for _, inv in ipairs(station_inventories(pair)) do total = total + inv_count(inv, item) end
  return total
end

local function radius_for(pair)
  local r = tonumber(pair and pair.radius) or 36
  if pair and pair.station and pair.station.valid and type(_G.get_station_operating_radius) == "function" then
    local ok, got = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(got) then r = tonumber(got) end
  end
  return math.max(8, r)
end

local function role_from_name(name)
  return EMERGENCY_ENTITY_BY_ITEM[name]
end

local function resource_patches_in_range(pair)
  local out = {}
  if not valid_pair(pair) then return out end
  local r = radius_for(pair)
  local ok, resources = pcall(function()
    return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r, type = "resource" })
  end)
  if ok and resources then
    for _, res in pairs(resources) do
      if valid(res) and dist_sq(res.position, pair.station.position) <= r * r and (not res.amount or res.amount > 0) then
        out[#out + 1] = res
      end
    end
  end
  return out
end

local function has_resource_patches(pair)
  return #resource_patches_in_range(pair) > 0
end

local function best_normal_miner_item(pair)
  -- Burner drills are the first planned normal-industry mining target. Higher
  -- drills can be selected later by the coming master planner when it knows the
  -- station has the technology, power, and belt/storage logic to exploit them.
  for _, item in ipairs(NORMAL_MINER_ITEMS) do
    if item_exists(item) then return item end
  end
  return nil
end

local function known_facility_roles(pair)
  local roles = {}
  if not valid_pair(pair) then return roles end
  local facility_root = storage and storage.tech_priests and storage.tech_priests.emergency_facility_doctrine_0343 or nil
  local by_station = facility_root and facility_root.by_station and facility_root.by_station[station_unit(pair)] or nil
  if by_station and facility_root.facilities then
    for key in pairs(by_station) do
      local rec = facility_root.facilities[key]
      if rec and rec.entity and rec.entity.valid and rec.role then roles[rec.role] = true end
    end
  end
  local r = radius_for(pair)
  local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r }) end)
  if ok and ents then
    for _, e in pairs(ents) do
      if valid(e) and dist_sq(e.position, pair.station.position) <= r * r then
        local role = role_from_name(e.name)
        if role then roles[role] = true end
        if e.type == "mining-drill" and e.name ~= "tech-priests-emergency-miner" then
          roles.miner = true
          roles.normal_miner = true
        end
      end
    end
  end
  return roles
end

local function current_items(pair)
  local out = {}
  local function add(source, v)
    local item = item_from(v)
    if item then out[#out + 1] = { source = source, item = item } end
  end
  if not pair then return out end
  add("direct_acquisition_task_0336", pair.direct_acquisition_task_0336)
  add("active_acquisition_0333", pair.active_acquisition_0333)
  add("emergency_craft", pair.emergency_craft)
  add("station_crafting_task_0337", pair.station_crafting_task_0337)
  add("active_craft_0479", pair.active_craft_0479)
  add("scavenge", pair.scavenge)
  add("active_supply_request", pair.active_supply_request)
  add("supply_request", pair.supply_request)
  add("logistic_requested_item", pair.logistic_requested_item)
  add("requested_item", pair.requested_item)
  add("last_item", pair.last_item)
  if pair.order_queue_0469 then
    add("order_queue.current", pair.order_queue_0469.current)
    for _, order in ipairs(pair.order_queue_0469.pending or {}) do add("order_queue.pending", order) end
  end
  return out
end

local function high_tier_pressure(pair)
  for _, rec in ipairs(current_items(pair)) do if high_tier(rec.item) then return rec.item, rec.source end end
  return nil, nil
end

local function need_local_step(pair)
  if not valid_pair(pair) then return nil, "invalid" end
  local roles = known_facility_roles(pair)
  local resources_in_range = has_resource_patches(pair)
  local normal_miner_item = best_normal_miner_item(pair)
  local iron_ore = station_count(pair, "iron-ore")
  local copper_ore = station_count(pair, "copper-ore")
  local iron_plate = station_count(pair, "iron-plate")
  local copper_plate = station_count(pair, "copper-plate")

  if not roles.smelter then return "tech-priests-emergency-smelter", "missing-emergency-smelter" end
  if iron_plate < M.min_iron_plate and (iron_ore > 0 or roles.miner) then return "iron-plate", "need-local-iron-plate" end
  if resources_in_range and not roles.normal_miner then
    if normal_miner_item then return normal_miner_item, "prefer-normal-miner-on-local-resource" end
    return nil, "local-resource-present-but-no-normal-miner-prototype"
  end
  if (not resources_in_range) and not roles.miner then return "tech-priests-emergency-miner", "no-local-resource-use-emergency-miner" end
  if not roles.assembler then return "tech-priests-emergency-assembler", "missing-emergency-assembler" end
  if copper_plate < M.min_copper_plate and copper_ore > 0 then return "copper-plate", "need-local-copper-plate" end
  return nil, "local-fabrication-ready"
end

local function defer_order(q, order, item, reason)
  if not (q and order) then return false end
  q.history = q.history or {}
  q.history[#q.history + 1] = { key = order.key or "nil", kind = order.kind or "nil", item = order.item or item, status = "deferred", reason = reason, tick = now() }
  while #q.history > 16 do table.remove(q.history, 1) end
  return true
end

local function clear_high_tier_state(pair, reason)
  if not pair then return 0 end
  local cleared = 0
  local function clear_field(field)
    local item = item_from(pair[field])
    if high_tier(item) then pair[field] = nil; cleared = cleared + 1 end
  end
  clear_field("direct_acquisition_task_0336")
  clear_field("active_acquisition_0333")
  clear_field("emergency_craft")
  clear_field("station_crafting_task_0337")
  clear_field("active_craft_0479")
  clear_field("scavenge")
  clear_field("active_supply_request")
  clear_field("supply_request")
  if high_tier(pair.logistic_requested_item) then pair.logistic_requested_item = nil; pair.logistic_requested_count = nil; cleared = cleared + 1 end
  if high_tier(pair.requested_item) then pair.requested_item = nil; cleared = cleared + 1 end
  if high_tier(pair.last_item) then pair.last_item = nil; cleared = cleared + 1 end

  local q = pair.order_queue_0469
  if q then
    if q.current and high_tier(item_from(q.current)) then
      defer_order(q, q.current, item_from(q.current), reason)
      q.current = nil
      pair.active_order_0469 = nil
      cleared = cleared + 1
    end
    local keep = {}
    q.pending_keys = {}
    for _, order in ipairs(q.pending or {}) do
      if order and high_tier(item_from(order)) then
        defer_order(q, order, item_from(order), reason)
        cleared = cleared + 1
      elseif order then
        keep[#keep + 1] = order
        if order.key then q.pending_keys[order.key] = true end
      end
    end
    q.pending = keep
  end
  return cleared
end

local function already_working_local(pair, item)
  if not item then return false end
  for _, rec in ipairs(current_items(pair)) do
    if rec.item == item and local_product(rec.item) then return true end
  end
  return false
end

local function assign_local_step(pair, item, why, high_item, high_source)
  if not (valid_pair(pair) and item and item_exists(item)) then return false, "invalid-local-step" end
  if already_working_local(pair, item) then return true, "already-working-local-step" end
  pair.emergency_craft = {
    item_name = item,
    output_item = item,
    count = (item == "iron-plate" and M.min_iron_plate) or (item == "copper-plate" and M.min_copper_plate) or 1,
    required_count = (item == "iron-plate" and M.min_iron_plate) or (item == "copper-plate" and M.min_copper_plate) or 1,
    infrastructure_first_0640 = true,
    normal_mining_preference_0643 = (item == "burner-mining-drill" or item == "electric-mining-drill" or item == "big-mining-drill") or nil,
    reason = "infrastructure-first-governor-0643",
    started_tick = now(),
  }
  pair.mode = "infrastructure-first-0643"
  pair.local_infrastructure_gate_0640 = { tick = now(), item = item, why = why, blocked_item = high_item, blocked_source = high_source }
  if type(_G.tech_priests_emit_overhead_status_0473) == "function" then
    pcall(_G.tech_priests_emit_overhead_status_0473, pair, "local infrastructure first: [item=" .. tostring(item) .. "]", { r = 1.0, g = 0.74, b = 0.20, a = 0.95 }, 90, 0.64, "infrastructure-first-0643")
  end
  local ok, Prod = pcall(require, "scripts.core.emergency_production_executor_0514")
  if ok and Prod and type(Prod.service_pair) == "function" then pcall(Prod.service_pair, pair, "infrastructure-first-0643") end
  return true, "assigned-local-step"
end

function M.service_pair(pair, reason)
  local r = root()
  if r.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  local needed, why = need_local_step(pair)
  if not needed then return false, why end

  local high_item, high_source = high_tier_pressure(pair)
  -- Enforce local fabrication if high-tier pressure is present, or if the pair is
  -- idle/loitering while it still lacks the fabrication spine.
  local should_gate = high_item ~= nil or pair.mode == nil or lower(pair.mode):find("idle", 1, true) or lower(pair.mode):find("scaveng", 1, true) or lower(pair.mode):find("logistics", 1, true) or lower(pair.mode):find("assignment", 1, true)
  if not should_gate then return false, "local-step-needed-but-active-work-continues" end

  if r.audit_only == true then
    record("infrastructure-gate-audit-0643", pair, "needed=" .. safe(needed) .. " why=" .. safe(why) .. " high=" .. safe(high_item) .. " source=" .. safe(high_source), false)
    return false, "audit-only"
  end

  local cleared = clear_high_tier_state(pair, "infrastructure-first-0643")
  local ok, result = assign_local_step(pair, needed, why, high_item, high_source)
  if ok then
    record("infrastructure-gate-assigned-0643", pair, "needed=" .. safe(needed) .. " why=" .. safe(why) .. " blocked=" .. safe(high_item) .. " source=" .. safe(high_source) .. " cleared=" .. safe(cleared), true)
    return true, result
  end
  return false, result
end

function M.service_all(reason)
  local r = root()
  if r.enabled == false then return 0 end
  local serviced = 0
  for _, pair in pairs(pair_map()) do
    if serviced >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then
      local ok, acted = pcall(M.service_pair, pair, reason or "pulse")
      if ok and acted then serviced = serviced + 1 end
    end
  end
  r.last_service_tick = now()
  return serviced
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

function M.status_for_pair(pair)
  if not valid_pair(pair) then return "invalid" end
  local needed, why = need_local_step(pair)
  local high_item, high_source = high_tier_pressure(pair)
  local roles = known_facility_roles(pair)
  local list = {}
  for k, v in pairs(roles) do if v then list[#list + 1] = k end end
  table.sort(list)
  return "station=" .. safe(station_unit(pair))
    .. " needed=" .. safe(needed or "none")
    .. " why=" .. safe(why)
    .. " high=" .. safe(high_item or "none")
    .. " source=" .. safe(high_source or "none")
    .. " roles=" .. table.concat(list, ",")
    .. " resources_in_range=" .. safe(#resource_patches_in_range(pair))
    .. " normal_miner_item=" .. safe(best_normal_miner_item(pair) or "none")
    .. " iron_ore=" .. safe(station_count(pair, "iron-ore"))
    .. " iron_plate=" .. safe(station_count(pair, "iron-plate"))
    .. " copper_ore=" .. safe(station_count(pair, "copper-ore"))
    .. " copper_plate=" .. safe(station_count(pair, "copper-plate"))
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-infra-first-0640") end end)
  commands.add_command("tp-infra-first-0640", "Tech Priests 0.1.643: infrastructure-first behavior governor. Params: status/kick/all/on/off/audit-on/audit-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false elseif p == "audit-on" then r.audit_only = true elseif p == "audit-off" then r.audit_only = false elseif p == "all" then M.service_all("command-all") elseif p == "kick" then local pair = selected_pair(player); if pair then M.service_pair(pair, "command-kick") end end
    local msg = "[tp-infra-first-0640] version=" .. M.version .. " enabled=" .. safe(r.enabled) .. " audit=" .. safe(r.audit_only) .. " assigned=" .. safe((r.stats["infrastructure-gate-assigned-0643"] or 0) + (r.stats["infrastructure-gate-assigned-0640"] or 0)) .. " audits=" .. safe((r.stats["infrastructure-gate-audit-0643"] or 0) + (r.stats["infrastructure-gate-audit-0640"] or 0))
    if player and player.valid then
      player.print(msg)
      local pair = selected_pair(player)
      if pair then player.print(M.status_for_pair(pair)) end
      for i = math.max(1, #r.recent - 6), #r.recent do local ev = r.recent[i]; if ev then player.print("  [" .. safe(ev.tick) .. "] " .. safe(ev.action) .. " station=" .. safe(ev.station) .. " " .. safe(ev.detail)) end end
    elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  root()
  _G.TechPriestsInfrastructureFirstGovernor0640 = M
  install_command()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "infrastructure_first_governor_0640", category = "emergency", interval = M.tick_interval, priority = 95, budget = 10, fn = function(event, budget) M.service_all("broker") return true end, note = "gate high-tier acquisition behind local industry; prefer normal miners over emergency miners when resources exist" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "infrastructure_first_governor_0640", category = "emergency", priority = "early" })
    elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.643] infrastructure-first behavior governor installed; normal mining drills are preferred over emergency micro-miners when local resources exist") end
  return true
end

return M
