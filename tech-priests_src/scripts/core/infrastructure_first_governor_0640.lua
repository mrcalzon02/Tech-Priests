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
M.assignment_retry_ticks = 60 * 30
M.assignment_terminal_ticks = 60 * 5
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
  ["copper-cable"] = true,
  ["electronic-circuit"] = true,
  ["stone-furnace"] = true,
  ["iron-chest"] = true,
  ["wooden-chest"] = true,
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
  local ok, ents = pcall(function() return pair.station.surface.find_entities_filtered({ position = pair.station.position, radius = r, force = pair.station.force, type = { "mining-drill", "furnace", "assembling-machine", "container", "logistic-container", "lab" } }) end)
  if ok and ents then
    for _, e in pairs(ents) do
      if valid(e) and dist_sq(e.position, pair.station.position) <= r * r then
        local role = role_from_name(e.name)
        if role then roles[role] = true end
        -- Standard, physically present furnaces are legitimate early smelters.
        if e.type == "furnace" then roles.smelter = true end
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

  -- Once the first real workshop exists, smelt a physically mined copper
  -- batch before resuming the more expensive burner-drill gear chain.
  -- This is an engine-owned furnace task; it never fabricates copper plates.
  -- Active strict recipes remain protected by the service_pair task guard.
  local circuit_recipe = pair.station.force and pair.station.force.recipes
    and pair.station.force.recipes["electronic-circuit"]
  if roles.assembler and roles.smelter and circuit_recipe
      and circuit_recipe.enabled==true
      and station_count(pair,"electronic-circuit")<1
      and copper_plate<1 and copper_ore>0
      and not pair.direct_acquisition_custody_0513
      and not pair.emergency_production_custody_0514
      and not pair.construction_custody_0338
      and not pair.machine_logistics_custody_0528 then
    return "copper-plate","first-electronics-physical-copper-smelting"
  end

  -- The emergency miner requires iron plate, and the first plate requires
  -- smelting hand-mined ore. Do not let a miner-first strategic plan create
  -- a circular dependency in a completely empty base.
  -- An emergency miner's enabled recipe consumes one actual iron plate.
  -- Requiring the four-plate general reserve before the first miner delays
  -- autonomous resource income and is not a physical recipe prerequisite.
  if roles.smelter and not roles.miner and iron_plate < 1 then
    return "iron-plate", "prerequisite-for-emergency-miner"
  end

  -- Factorio 2.0 Electronics is a craft-item trigger: ten genuine copper
  -- plates must be produced before the engine unlocks copper cable, circuits
  -- and the ordinary laboratory. Never demand those locked recipes first.
  -- This work stays on the physical furnace/extraction path, and the engine
  -- alone decides when the technology is researched.
  local electronics = pair.station.force and pair.station.force.technologies
    and pair.station.force.technologies["electronics"]
  local copper_in_flight=type(pair.emergency_craft)=="table"
    and pair.emergency_craft.infrastructure_first_0640==true
    and (pair.emergency_craft.output_item or pair.emergency_craft.item_name)
      =="copper-plate"
  if roles.smelter and roles.miner and electronics
      and electronics.enabled~=false and electronics.researched~=true
      and copper_plate<10 and (copper_ore>0 or copper_in_flight) then
    -- The ore may already reside in the real furnace input, not in general
    -- storage. An active smelting transaction must keep its stage until the
    -- copper-plate output or actual electronics unlock is observed.
    return "copper-plate","unlock-electronics-copper-trigger"
  end

  -- A pending machine recipe can require a manufactured intermediary (most
  -- importantly iron gear wheels for the first burner mining drill). Treat
  -- that as actual local production, not an indefinitely pending supply item.
  -- Descend only through bounded, known local products; raw ingredients stay
  -- in the physical acquisition path and never materialize synthetically.
  local pending=pair.infrastructure_recipe_request_0647
  -- An available workshop must schedule its first electronics chain before
  -- returning to the expensive standard-drill gear loop. The live task guard
  -- in service_pair protects an already-started physical craft, so naming the
  -- next electronics objective here does not overwrite current work or custody.
  if roles.assembler and station_count(pair,"electronic-circuit")<1
      and item_exists("electronic-circuit")
      -- Strict crafting has already committed its real recipe. Complete that
      -- transaction before changing the requested output to electronics.
      and not (type(pair.emergency_craft)=="table"
        and pair.emergency_craft.strict_recipe_0647==true)
      and not pair.emergency_production_custody_0514
      and not pair.direct_acquisition_custody_0513
      and not pair.construction_custody_0338
      and not pair.machine_logistics_custody_0528 then
    local ancestor,in_electronics_chain=pending,false
    for _=1,6 do
      if type(ancestor)~="table" then break end
      if ancestor.item=="electronic-circuit" then
        in_electronics_chain=true;break
      end
      ancestor=ancestor.parent_request_0647
    end
    local recipe=pair.station.force and pair.station.force.recipes
      and pair.station.force.recipes["electronic-circuit"]
    if not in_electronics_chain and recipe and recipe.enabled==true then
      return "electronic-circuit","bootstrap-first-electronics"
    end
  end
  local pending_need=1
  if type(pending)=="table" and pending.missing then
    for _,ingredient in ipairs(pending.ingredients or {}) do
      if ingredient.name==pending.missing then
        pending_need=math.max(1,tonumber(ingredient.count) or 1)
        break
      end
    end
  end
  if type(pending)=="table" and local_product(pending.missing)
      and pending.missing~=pending.item
      and station_count(pair,pending.missing)<pending_need then
    local next_item=pending.missing
    local seen={}
    for _=1,4 do
      if seen[next_item] then break end
      seen[next_item]=true
      local recipe=type(_G.tech_priests_get_recipe_ingredients_for_item_0185)=="function"
        and _G.tech_priests_get_recipe_ingredients_for_item_0185(next_item) or nil
      local child=nil
      for _,ingredient in ipairs(type(recipe)=="table" and recipe or {}) do
        local n=ingredient.name
        if n and n~=next_item and local_product(n) and item_exists(n)
            and station_count(pair,n)<math.max(1,tonumber(ingredient.count) or 1)
            and not seen[n] then child=n;break end
      end
      if not child then break end
      next_item=child
    end
    return next_item,"recipe-prerequisite-for:"..tostring(pending.item)
  end
  -- Preserve a child recipe while its missing ingredient is raw. Otherwise
  -- the central plan reselects the parent drill every pulse, overwrites the
  -- stone/ore request, and never converts accumulated raw stock into the child.
  if type(pending)=="table" and pending.missing and item_exists(pending.item) then
    return pending.item,pending.reason or ("pending-recipe-material:"..tostring(pending.item))
  end

  -- Make the first real workshop exercise its physical electronics recipe
  -- before the costlier standard drill. Every copper-cable subrecipe still
  -- consumes genuine stock through the canonical production ledger.
  if roles.assembler and station_count(pair,"electronic-circuit")<1
      and item_exists("electronic-circuit") then
    local recipe=pair.station.force and pair.station.force.recipes
      and pair.station.force.recipes["electronic-circuit"]
    if recipe and recipe.enabled==true then
      return "electronic-circuit","bootstrap-first-electronics"
    end
  end

  local Plan = rawget(_G, "TechPriestsMasterInfrastructurePlan0644")
  if Plan and type(Plan.build_plan) == "function" then
    local ok, plan = pcall(Plan.build_plan, pair, "infrastructure-first-0647")
    local target = ok and plan and plan.target or nil
    if target and target.preferred_item and target.preferred_item ~= "iron-plate" and target.preferred_item ~= "copper-plate" then
      return target.preferred_item, "central-plan:" .. tostring(target.stage or target.class or "bootstrap")
    end
  end
  if not roles.smelter then return "tech-priests-emergency-smelter", "missing-emergency-smelter" end
  if iron_plate < M.min_iron_plate and (iron_ore > 0 or roles.miner) then return "iron-plate", "need-local-iron-plate" end
  if resources_in_range and not roles.miner then return "tech-priests-emergency-miner", "bootstrap-emergency-miner-on-local-resource" end
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
  if not (pair and item) then return false end
  -- Inventory requests, last_item, and orders waiting in the queue are *not*
  -- active crafting. Treating them as work keeps the bootstrap gate locked
  -- after real ingredients arrive, even though no executor has a recipe task.
  for _,field in ipairs({"emergency_craft","station_crafting_task_0337","active_craft_0479"}) do
    local task=pair[field]
    if type(task)=="table" and item_from(task)==item and local_product(item)
      and task.current==nil then
      return true
    end
  end
  return false
end

local function set_local_gate(pair, item, why, fields)
  local gate = {
    tick = now(),
    last_seen_tick = now(),
    next_retry_tick = now() + M.assignment_retry_ticks,
    item = item,
    why = why,
  }
  for k, v in pairs(fields or {}) do gate[k] = v end
  pair.local_infrastructure_gate_0640 = gate
  return gate
end

local function matching_gate(pair, item, why)
  local gate = pair and pair.local_infrastructure_gate_0640
  if type(gate) ~= "table" then return nil end
  if gate.item ~= item then return nil end
  if gate.why ~= why then return nil end
  return gate
end

local function clear_local_gate(pair, reason)
  if pair and type(pair.local_infrastructure_gate_0640) == "table" then
    pair.last_local_infrastructure_gate_clear_0640 = { tick = now(), reason = tostring(reason or "cleared") }
    pair.local_infrastructure_gate_0640 = nil
    stat("infrastructure_gate_cleared_0643")
    return true
  end
  return false
end

local function gate_pending(pair, item, why)
  local gate = matching_gate(pair, item, why)
  if not gate then return false, nil end
  gate.last_seen_tick = now()
  if gate.state == "terminal-unverified-local-step" then
    -- The assignment aged out. Never duplicate a live production task, but
    -- recover if there is no active craft and no physical finished item.
    if already_working_local(pair, item) then
      return true, "bootstrap-local-step-still-active"
    end
    if station_count(pair, item) > 0 then
      gate.state = "finished-item-on-hand"
      gate.next_retry_tick = now()
      return false, "finished-item-ready"
    end
    if now() < (tonumber(gate.next_retry_tick) or 0) then
      return true, "bootstrap-unverified-retry-cooldown"
    end
    gate.state = "unverified-step-expired-retry"
    gate.next_retry_tick = now()
    record("infrastructure-unverified-step-retry-0643", pair, "item="..safe(item), true)
    return false, "unverified-no-active-task-retry"
  end
  if gate.state == "assigned-local-step" then
    local age = now() - (tonumber(gate.tick) or now())
    if age >= M.assignment_terminal_ticks then
      gate.state = "terminal-unverified-local-step"
      gate.terminal_tick = now()
      gate.next_retry_tick = math.max(tonumber(gate.next_retry_tick or 0) or 0, now() + M.assignment_retry_ticks)
      return true, "bootstrap-local-step-unverified-terminal"
    end
    return true, "bootstrap-local-step-already-assigned"
  end
  local request = pair.infrastructure_recipe_request_0647
  if request and request.item == item and request.missing then
    local required = 1
    for _, ingredient in ipairs(request.ingredients or {}) do
      if ingredient.name == request.missing then
        required = math.max(1, tonumber(ingredient.count) or 1)
        break
      end
    end
    if station_count(pair, request.missing) >= required then
      -- The last raw-material dependency was physically delivered.
      -- Release the wait gate and re-evaluate the full recipe immediately.
      if pair.requested_item == request.missing then pair.requested_item = nil end
      if pair.logistic_requested_item == request.missing then
        pair.logistic_requested_item = nil
        pair.logistic_requested_count = nil
      end
      -- Keep the child request and its parent chain until assign_local_step
      -- consumes it. Clearing it here loses the original drill dependency.
      gate.state = "materials-ready"
      gate.next_retry_tick = now()
      return false, "material-delivered-recheck-recipe"
    end
    gate.state = "waiting-recipe-material"
    return true, "bootstrap-material-request-already-assigned"
  end
  if already_working_local(pair, item) then
    gate.state = gate.state or "active-local-work"
    return true, "bootstrap-local-step-already-assigned"
  end
  local retry = tonumber(gate.next_retry_tick or 0) or 0
  if retry > now() then
    gate.state = gate.state or "waiting-assignment-retry"
    return true, "bootstrap-assignment-backoff"
  end
  return false, "retry-due"
end

local function record_pending_gate(pair, needed, why, pending_reason)
  local gate = matching_gate(pair, needed, why)
  if not gate then return end
  local due = tonumber(gate.next_log_tick or 0) or 0
  if now() < due then return end
  gate.next_log_tick = now() + M.log_interval
  record("infrastructure-gate-pending-0643", pair,
    "needed=" .. safe(needed)
      .. " why=" .. safe(why)
      .. " pending=" .. safe(pending_reason)
      .. " retry=" .. safe(gate.next_retry_tick),
    false)
end

local function recipe_enabled_for_item(pair,item)
  -- A recipe helper describes ingredients, not research permission. Confirm
  -- an enabled, actual player-force recipe produces the requested output.
  local recipes=pair and pair.station and pair.station.force and pair.station.force.recipes
  if not recipes then return false end
  for _,recipe in pairs(recipes) do
    local ok,enabled,produces=pcall(function()
      local found=false
      for _,product in pairs(recipe.products or {}) do
        if product.name==item and product.type~="fluid" then found=true;break end
      end
      return recipe.enabled==true,found
    end)
    if ok and enabled and produces then return true end
  end
  return false
end

local function assign_local_step(pair, item, why, high_item, high_source)
  if not (valid_pair(pair) and item and item_exists(item)) then return false, "invalid-local-step" end
  if already_working_local(pair, item) then return true, "already-working-local-step" end
  local count = (item == "iron-plate" and
    (why == "prerequisite-for-emergency-miner" and 1 or M.min_iron_plate))
    or (item == "copper-plate" and
      (why == "unlock-electronics-copper-trigger" and 10
        or M.min_copper_plate)) or 1
  local required_stock=1
  local parent=pair.infrastructure_recipe_request_0647
  if type(parent)=="table" and parent.item~=item and parent.missing==item then
    for _,ingredient in ipairs(parent.ingredients or {}) do
      if ingredient.name==item then
        required_stock=math.max(1,tonumber(ingredient.count) or 1)
        break
      end
    end
  end
  local placeable = false
  local item_proto = prototypes and prototypes.item and prototypes.item[item] or nil
  if item_proto then pcall(function() placeable = item_proto.place_result ~= nil end) end

  -- Every manufactured intermediary uses a real ingredient transaction.
  -- Smelted plates take the physical furnace path, not a simulated craft.
  local recipe_item = item ~= "iron-plate" and item ~= "copper-plate"
    and item ~= "stone-brick" and (placeable or local_product(item))
  -- Manufactured prerequisites may need multiple physical units. Run one
  -- complete strict-recipe transaction per output until the parent's exact
  -- stock requirement is met. Existing partial stock is not completion.
  if recipe_item and station_count(pair,item) < required_stock then
    local ingredients = type(_G.tech_priests_get_recipe_ingredients_for_item_0185) == "function"
      and _G.tech_priests_get_recipe_ingredients_for_item_0185(item) or nil
    if type(ingredients)~="table" or #ingredients==0 then
      return false,"authoritative-recipe-unavailable:"..item
    end
    if not recipe_enabled_for_item(pair,item) then
      return false,"recipe-locked-or-unavailable:"..item
    end
    local missing = nil
    for _, ingredient in ipairs(ingredients or {}) do
      if station_count(pair, ingredient.name) < math.max(1, tonumber(ingredient.count) or 1) then missing = ingredient; break end
    end
    if missing then
      pair.requested_item = missing.name
      pair.logistic_requested_item = missing.name
      pair.logistic_requested_count = math.max(1, tonumber(missing.count) or 1)
      pair.infrastructure_recipe_request_0647 = { tick = now(), item = item,
        ingredients = ingredients, missing = missing.name, reason = why,
        parent_request_0647 = type(parent)=="table" and
          (parent.item==item and parent.parent_request_0647 or parent) or nil }
      pair.mode = "infrastructure-material-acquisition-0647"
      set_local_gate(pair, item, why, { state = "waiting-recipe-material", missing = missing.name, blocked_item = high_item, blocked_source = high_source })
      return true, "requested-recipe-material"
    end
    if pair.requested_item and pair.infrastructure_recipe_request_0647 and pair.requested_item == pair.infrastructure_recipe_request_0647.missing then pair.requested_item = nil end
    if pair.logistic_requested_item and pair.infrastructure_recipe_request_0647 and pair.logistic_requested_item == pair.infrastructure_recipe_request_0647.missing then
      pair.logistic_requested_item = nil
      pair.logistic_requested_count = nil
    end
    pair.emergency_craft = {
      item_name = item,
      output_item = item,
      count = count,
      required_count = count,
      strict_recipe_0647 = true,
      strict_recipe_ingredients_0647 = ingredients,
      -- The station may already contain some units. A one-unit transaction
      -- must finish only after the parent's required physical stock exists.
      target_stock_0647 = required_stock,
      resume_parent_recipe_request_0647 = type(parent)=="table" and
        (parent.item==item and parent.parent_request_0647 or parent) or nil,
      infrastructure_first_0640 = true,
      reason = "infrastructure-first-governor-0647",
      started_tick = now(),
    }
    pair.infrastructure_recipe_request_0647 = nil
  else
    pair.emergency_craft = {
    item_name = item,
    output_item = item,
    count = count,
    required_count = count,
    infrastructure_first_0640 = true,
    facility_only_0647 = (item == "iron-plate" or item == "copper-plate") or nil,
    reason = "infrastructure-first-governor-0647",
    started_tick = now(),
  }
  end
  pair.mode = "infrastructure-first-0643"
  set_local_gate(pair, item, why, { state = "assigned-local-step", blocked_item = high_item, blocked_source = high_source })
  if type(_G.tech_priests_emit_overhead_status_0473) == "function" then
    pcall(_G.tech_priests_emit_overhead_status_0473, pair, "local infrastructure first: [item=" .. tostring(item) .. "]", { r = 1.0, g = 0.74, b = 0.20, a = 0.95 }, 90, 0.64, "infrastructure-first-0643")
  end
  -- Runtime require() is forbidden by Factorio after control.lua parsing.
  -- The production executor is already installed by control.lua; hand the
  -- recipe to that authoritative instance without creating another loader.
  local Prod = rawget(_G, "TechPriestsEmergencyProductionExecutor0514")
    or (package.loaded and package.loaded["scripts.core.emergency_production_executor_0514"])
  if Prod and type(Prod.service_pair) == "function" then
    local ran, why = pcall(Prod.service_pair, pair, "infrastructure-first-0643")
    if not ran then record("infrastructure-production-start-failed-0643", pair, safe(why), true) end
  else
    record("infrastructure-production-owner-unavailable-0643", pair, safe(item), true)
  end
  return true, "assigned-local-step"
end

-- One legitimately stored iron plate is enough to start the first
-- electronic-circuit recipe. Do not indefinitely hold the workshop behind a
-- bulk four-plate drill reserve while copper and the assembler already exist.
-- Only the canonical production executor can close the live batch.
local function complete_first_circuit_plate_reserve(pair)
  local task = pair.emergency_craft
  if not (type(task) == "table" and task.infrastructure_first_0640==true
      and task.facility_only_0647==true
      and (task.output_item or task.item_name)=="iron-plate"
      and (tonumber(task.count) or 0)>1
      and not pair.direct_acquisition_custody_0513
      and not pair.emergency_production_custody_0514
      and not pair.machine_logistics_custody_0528
      and not pair.construction_custody_0338) then return false end
  local recipe=pair.station.force and pair.station.force.recipes
    and pair.station.force.recipes["electronic-circuit"]
  local technologies=pair.station.force and pair.station.force.technologies
  local electronics=technologies and technologies["electronics"]
  local roles=known_facility_roles(pair)
  local copper_trigger_pending=electronics and electronics.enabled~=false
    and electronics.researched~=true
    and roles.smelter and roles.miner and station_count(pair,"copper-ore")>0
  local circuits_ready=recipe and recipe.enabled==true and roles.assembler
  if not ((circuits_ready or copper_trigger_pending)
      and station_count(pair,"electronic-circuit")<1) then return false end
  local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or (package.loaded and package.loaded["scripts.core.storage_role_authority_0686"])
  local real_plate=0
  if authority and type(authority.generic_item_count)=="function" then
    local ok,n=pcall(authority.generic_item_count,pair,"iron-plate")
    if ok then real_plate=tonumber(n) or 0 end
  else
    -- Startup compatibility: chest only, never Cogitator work inventories.
    local chest=defines and defines.inventory
      and safe_inventory(pair.station,defines.inventory.chest)
    if chest then
      local ok,n=pcall(function()return chest.get_item_count("iron-plate")end)
      if ok then real_plate=tonumber(n) or 0 end
    end
  end
  if real_plate<1 then return false end
  local production=rawget(_G,"TechPriestsEmergencyProductionExecutor0514")
    or (package.loaded and package.loaded["scripts.core.emergency_production_executor_0514"])
  if not (production and type(production.service_pair)=="function") then return false end
  -- Lower the *remaining batch target*, not the plate recipe, inventory, or
  -- parent drill request. Production checks the real stock and finalizes.
  task.count=1
  task.required_count=1
  task.target_stock_0647=1
  local ok,done,detail=pcall(production.service_pair,pair,"first-electronics-plate-handoff")
  if ok and done==true and detail=="complete" then
    record("infrastructure-first-circuit-plate-handoff-0643",pair,
      "physical iron-plate x1 completed reserve batch",true)
    return true
  end
  return false
end

-- Electronics is a *force-wide* item-production trigger. Once Factorio
-- researches it, each station's obsolete ten-copper-plate bootstrap batch
-- must not pin an assembler behind a ten-item local reserve indefinitely.
-- The authoritative production executor retires a task only after verifying
-- a real copper plate still exists in managed general stock; no item, research
-- state or active movement/cargo is manufactured or overwritten here.
local function close_researched_copper_trigger(pair)
  local task=pair.emergency_craft
  local gate=pair.local_infrastructure_gate_0640
  local electronics=pair.station.force and pair.station.force.technologies
    and pair.station.force.technologies["electronics"]
  if not (type(task)=="table" and task.infrastructure_first_0640==true
      and task.facility_only_0647==true
      and (task.output_item or task.item_name)=="copper-plate"
      and (tonumber(task.count) or 0)>1
      and type(gate)=="table" and gate.item=="copper-plate"
      and (gate.why=="unlock-electronics-copper-trigger"
        or gate.why=="first-electronics-physical-copper-smelting")
      -- Both the force-wide ten-plate trigger and a later copper reserve
      -- must yield once Electronics has genuinely unlocked and one real
      -- copper plate is held. Neither finished copper nor another active
      -- manufactured recipe can be erased or fabricated by this handoff.
      and electronics and electronics.researched==true
      and not pair.direct_acquisition_custody_0513
      and not pair.machine_logistics_custody_0528
      and not pair.emergency_production_custody_0514
      and not pair.construction_custody_0338) then return false end
  local order=pair.order_queue_0469 and pair.order_queue_0469.current
  if order and order.status=="active"
      and (order.item=="copper-plate"
        or task.order_key_0514 and order.key==task.order_key_0514) then
    return false
  end
  local real_plate=0
  local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or (package.loaded and package.loaded["scripts.core.storage_role_authority_0686"])
  if authority and type(authority.generic_item_count)=="function" then
    local ok,n=pcall(authority.generic_item_count,pair,"copper-plate")
    if ok then real_plate=math.max(0,tonumber(n) or 0) end
  else
    local chest=defines and defines.inventory
      and safe_inventory(pair.station,defines.inventory.chest)
    if chest then
      local ok,n=pcall(function()return chest.get_item_count("copper-plate")end)
      if ok then real_plate=math.max(0,tonumber(n) or 0) end
    end
  end
  if real_plate<1 then return false end
  local production=rawget(_G,"TechPriestsEmergencyProductionExecutor0514")
    or (package.loaded and package.loaded["scripts.core.emergency_production_executor_0514"])
  if not (production and type(production.service_pair)=="function") then return false end
  -- Only the already-achieved research-trigger *batch target* is reduced.
  -- The physical plate and all other manufacturing transactions stay intact.
  local old_count,old_required,old_target=task.count,task.required_count,
    task.target_stock_0647
  task.count=1
  task.required_count=1
  task.target_stock_0647=1
  local ok,done,detail=pcall(production.service_pair,pair,
    "research-complete-copper-trigger-handoff")
  if ok and done==true and detail=="complete" then
    record("electronics-trigger-copper-batch-completed-0640",pair,
      "force researched; physical copper plate held",true)
    return true
  end
  -- Retain the original batch if the authoritative owner could not complete
  -- the task; never strand a shortened but unfinished production request.
  if pair.emergency_craft==task then
    task.count,task.required_count,task.target_stock_0647=
      old_count,old_required,old_target
  end
  return false
end

function M.service_pair(pair, reason)
  local r = root()
  if r.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  complete_first_circuit_plate_reserve(pair)
  close_researched_copper_trigger(pair)
  local needed, why = need_local_step(pair)
  if not needed then
    clear_local_gate(pair, why or "local-fabrication-ready")
    return false, why
  end

  local high_item, high_source = high_tier_pressure(pair)
  -- Enforce local fabrication if high-tier pressure is present, or if the pair is
  -- idle/loitering while it still lacks the fabrication spine.
  -- A recipe wait is a live infrastructure obligation even if another module
  -- changed pair.mode after direct acquisition completed. Always revisit it.
  local waiting_recipe = type(pair.infrastructure_recipe_request_0647)=="table"
    and type(pair.local_infrastructure_gate_0640)=="table"
    and pair.local_infrastructure_gate_0640.state=="waiting-recipe-material"
  local should_gate = waiting_recipe or high_item ~= nil or pair.mode == nil or lower(pair.mode):find("idle", 1, true) or lower(pair.mode):find("scaveng", 1, true) or lower(pair.mode):find("logistics", 1, true) or lower(pair.mode):find("assignment", 1, true) or lower(pair.mode):find("infrastructure-material-acquisition", 1, true)
    or lower(pair.mode):find("infrastructure-first", 1, true)
  if not should_gate then return false, "local-step-needed-but-active-work-continues" end

  if r.audit_only == true then
    record("infrastructure-gate-audit-0643", pair, "needed=" .. safe(needed) .. " why=" .. safe(why) .. " high=" .. safe(high_item) .. " source=" .. safe(high_source), false)
    return false, "audit-only"
  end

  local pending, pending_reason = gate_pending(pair, needed, why)
  if pending then
    record_pending_gate(pair, needed, why, pending_reason)
    return false, pending_reason
  end

  -- Existing infrastructure manufacturing owns its physical ingredients and
  -- completion. A new strategic survey may name a different missing item
  -- while the old recipe is still running. Never overwrite its task/timer.
  -- The production owner alone may finalize this transaction; in particular
  -- a copper-plate smelt or gear craft cannot be replaced by a fresh four-
  -- plate iron reserve sweep before its output is deposited.
  local in_flight = pair.emergency_craft
  if type(in_flight) == "table" and in_flight.infrastructure_first_0640
      and (in_flight.output_item or in_flight.item_name) ~= needed then
    local active_item = in_flight.output_item or in_flight.item_name
    record_pending_gate(pair, needed, why,
      "protected-running-production:" .. safe(active_item))
    return false, "active-local-production-retained"
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

function M.report_lines()
  local r = root()
  local gates, terminal, recipe_wait, assigned = 0, 0, 0, 0
  for _, pair in pairs(pair_map()) do
    local gate = type(pair) == "table" and pair.local_infrastructure_gate_0640 or nil
    if type(gate) == "table" then
      gates = gates + 1
      if gate.state == "terminal-unverified-local-step" then terminal = terminal + 1 end
      if gate.state == "waiting-recipe-material" then recipe_wait = recipe_wait + 1 end
      if gate.state == "assigned-local-step" then assigned = assigned + 1 end
    end
  end
  return { "[tp-runtime-report] infrastructure-first-0640 enabled=" .. safe(r.enabled)
    .. " audit=" .. safe(r.audit_only)
    .. " gates=" .. safe(gates)
    .. " assigned_gates=" .. safe(assigned)
    .. " recipe_wait=" .. safe(recipe_wait)
    .. " terminal=" .. safe(terminal)
    .. " assigned=" .. safe(r.stats["infrastructure-gate-assigned-0643"] or 0)
    .. " pending=" .. safe(r.stats["infrastructure-gate-pending-0643"] or 0)
    .. " cleared=" .. safe(r.stats.infrastructure_gate_cleared_0643 or 0) }
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
  local gate = pair.local_infrastructure_gate_0640 or {}
  local list = {}
  for k, v in pairs(roles) do if v then list[#list + 1] = k end end
  table.sort(list)
  return "station=" .. safe(station_unit(pair))
    .. " needed=" .. safe(needed or "none")
    .. " why=" .. safe(why)
    .. " high=" .. safe(high_item or "none")
    .. " source=" .. safe(high_source or "none")
    .. " gate_item=" .. safe(gate.item or "none")
    .. " gate_state=" .. safe(gate.state or "none")
    .. " gate_retry=" .. safe(gate.next_retry_tick or "none")
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
  if M.installed then return true end
  local owner = nil
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then
    local ok, found = pcall(require, "scripts.core.runtime_tick_broker")
    if ok then broker = found end
  end
  if broker and type(broker.register_service) == "function" then
    local ok, service = pcall(broker.register_service, {
      name = "infrastructure_first_governor_0640",
      category = "emergency",
      interval = M.tick_interval,
      priority = 95,
      budget = 10,
      fn = function(event, budget)
        local acted = M.service_all("broker")
        return { processed = acted, acted = acted, detail = "infrastructure-first gate service" }
      end,
      note = "gate high-tier acquisition behind the central Martian bootstrap plan and honest recipe material acquisition"
    })
    if ok and service then owner = "runtime-tick-broker" end
  end
  if not owner then
    local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if not registry then
      local ok, found = pcall(require, "scripts.core.runtime_event_registry")
      if ok then registry = found end
    end
    if registry and type(registry.on_nth_tick) == "function" then
      local cadence = registry.on_nth_tick(M.tick_interval, function()
        M.service_all("nth-tick")
      end, {
        owner = "infrastructure_first_governor_0640",
        route = "infrastructure-first-fallback",
        category = "emergency",
        priority = "early"
      })
      if cadence then owner = "runtime-event-registry" end
    end
  end
  if not owner then
    if log then log("[Tech-Priests 0.1.647] infrastructure-first governor not installed: broker and registry ownership unavailable") end
    return false
  end
  root()
  _G.TechPriestsInfrastructureFirstGovernor0640 = M
  install_command()
  M.route_owner = owner
  M.installed = true
  if log then log("[Tech-Priests 0.1.647] infrastructure-first behavior governor installed via " .. owner .. "; central Martian bootstrap and recipe-backed construction requests active") end
  return true
end

return M
