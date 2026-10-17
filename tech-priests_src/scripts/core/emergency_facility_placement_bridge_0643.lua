-- Network-wide emergency supply assessment and construction coordination.
-- First stage: identify real deficits and select the existing construction authority.
-- Never conjure resources or claim a planning ghost is a completed facility.
local M = {}
M.version = "0.1.677"
M.interval = 113
M.minimum = { ["iron-plate"] = 20, ["copper-plate"] = 12, ["iron-gear-wheel"] = 8 }
local function valid(e) return e and e.valid end
local function registered_pairs()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests.emergency_facility_placement_bridge_0643
  if not r then
    r = { assessments = {}, reservations = {}, stats = {} }
    storage.tech_priests.emergency_facility_placement_bridge_0643 = r
  end
  return r
end
local function count_inventory(inv, name)
  if not (inv and inv.valid) then return 0 end
  return inv.get_item_count(name)
end
local function count_entity(entity, name)
  local total = 0
  if not (valid(entity) and entity.get_inventory and defines and defines.inventory) then return total end
  local seen = {}
  for _, id in pairs(defines.inventory) do
    if type(id) == "number" and not seen[id] then
      seen[id] = true
      local ok, inv = pcall(entity.get_inventory, entity, id)
      if ok then total = total + count_inventory(inv, name) end
    end
  end
  return total
end
local function active_pairs()
  local result = {}
  for _, pair in pairs(registered_pairs()) do
    if pair and valid(pair.station) and valid(pair.priest) then result[#result + 1] = pair end
  end
  table.sort(result, function(a,b) return a.station.unit_number < b.station.unit_number end)
  return result
end

local function infrastructure(group)
  local roles = { mining=0, smelting=0, crafting=0 }
  local seen = {}
  for _, pair in ipairs(group) do
    local station = pair.station
    local entities = station.surface.find_entities_filtered{
      position=station.position, radius=36, force=station.force,
      type={"mining-drill","furnace","assembling-machine"}
    }
    for _, e in pairs(entities) do
      if valid(e) and e.unit_number and not seen[e.unit_number] then
        seen[e.unit_number] = true
        local role = e.type == "mining-drill" and "mining"
          or (e.type == "furnace" or e.name == "tech-priests-emergency-smelter") and "smelting"
          or "crafting"
        roles[role] = roles[role] + 1
      end
    end
  end
  return roles
end
local function accessible_logistic_stock(group, item)
  local total, seen, seen_networks = 0, {}, {}
  for _, pair in ipairs(group) do
    local station = pair.station
    local ok, network = pcall(function() return station.logistic_network end)
    if ok and network and network.valid and not seen_networks[network] then
      seen_networks[network] = true
      local containers = station.surface.find_entities_filtered{
        position=station.position, radius=36, force=station.force, type="logistic-container"
      }
      for _, e in pairs(containers) do
        if valid(e) and e.unit_number and not seen[e.unit_number] then
          local linked, owner = pcall(function() return e.logistic_network end)
          if linked and owner == network then
            seen[e.unit_number] = true
            total = total + count_entity(e, item)
          end
        end
      end
    end
  end
  return total
end

local function snapshot(group)
  local out = { available = {}, required = {}, deficits = {}, station_count = #group, capacity = infrastructure(group) }
  -- Count each physical station once. Separate force/surface groups cannot
  -- promise delivery to one another merely because they share an item name.
  for name, reserve in pairs(M.minimum) do
    local available, seen = 0, {}
    for _, pair in ipairs(group) do
      local station = pair.station
      if not seen[station.unit_number] then
        seen[station.unit_number] = true
        available = available + count_entity(station, name)
      end
    end
    available = available + accessible_logistic_stock(group, name)
    out.available[name], out.required[name] = available, reserve * #group
    if available < out.required[name] then
      out.deficits[name] = out.required[name] - available
    end
  end
  return out
end
local function classify(item)
  if item == "iron-plate" then return "smelting", "iron-ore" end
  if item == "copper-plate" then return "smelting", "copper-ore" end
  if item == "iron-gear-wheel" then return "crafting", "iron-plate" end
  return nil, nil
end

-- Shared demand reservations. A reservation is a planning claim, never proof
-- that a machine has been built or is operating.
local STAGE_ENTITY = {
  mining = "burner-mining-drill",
  smelting = "stone-furnace",
  crafting = "assembling-machine-1",
  research = "lab"
}
local function candidate_for(group, stage)
  for _, pair in ipairs(group) do
    if pair and valid(pair.station) and valid(pair.priest) then
      local name = STAGE_ENTITY[stage]
      if name and prototypes.entity[name] then return pair, name end
    end
  end
  return nil, nil
end
local function synchronize_reservations(key, group, report)
  local r = root()
  local reservations = r.reservations
  local desired = {}
  for _, need in ipairs(report.needs) do
    if need.decision == "missing-production-capacity" then
      local stage = need.stage
      local pair, entity = candidate_for(group, stage)
      if pair and entity then
        local id = key .. ":" .. stage
        desired[id] = true
        local previous = reservations[id]
        if not previous or previous.stage ~= stage then
          reservations[id] = {
            network = key, stage = stage, entity = entity,
            station_unit = pair.station.unit_number,
            status = "reserved", created_tick = game.tick,
            item = need.item, missing = need.missing
          }
        else
          previous.missing = need.missing
          previous.last_assessed_tick = game.tick
        end
      end
    end
  end
  for id, reservation in pairs(reservations) do
    if reservation.network == key and not desired[id] then
      reservations[id] = nil
    end
  end
end
local function science_gap(group, report)
  -- A lab alone is insufficient: science requires unlocked recipes,
  -- pack production, power, and an available research objective.
  local force = group[1] and group[1].station.force
  if not force or not force.current_research then return end
  local packs = force.current_research.research_unit_ingredients
  if not packs then return end
  report.science = { research = force.current_research.name, packs = {} }
  for _, ingredient in pairs(packs) do
    local name = ingredient.name or ingredient[1]
    if name then
      local amount = tonumber(ingredient.amount or ingredient[2]) or 1
      report.science.packs[#report.science.packs+1] = { item=name, per_unit=amount }
    end
  end
  table.sort(report.science.packs, function(a,b) return a.item < b.item end)
end


local function connect_construction(groups)
  local r = root()
  local Planner = rawget(_G, "TechPriestsConstructionBootstrapGhostPlanner0645")
  if not Planner then
    local ok, module = pcall(require, "scripts.core.construction_bootstrap_ghost_planner_0645")
    if ok then Planner = module end
  end
  if not (Planner and type(Planner.service_pair) == "function") then
    return 0
  end
  local acted = 0
  local ids = {}
  for id in pairs(r.reservations) do ids[#ids+1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local reservation = r.reservations[id]
    local group = groups[reservation.network]
    if group then
      for _, pair in ipairs(group) do
        if pair.station.unit_number == reservation.station_unit then
          local rec = pair.construction_bootstrap_ghost_0645
          if rec and rec.ghost and rec.ghost.valid then
            reservation.status = rec.entity_name == reservation.entity and "awaiting-construction" or "waiting-other-construction"
            reservation.ghost_name = rec.entity_name
          elseif rec and rec.status == "blocked-no-site" then
            reservation.status = "blocked"
            reservation.blocker = rec.blocker
          else
            -- Reuse the canonical planner's technology, placement, and
            -- ghost ownership checks; never spawn a machine directly.
            local ok, created, why = pcall(Planner.service_pair, pair, "emergency-network:" .. id, reservation.entity)
            if not ok then
              reservation.status = "planner-error"
              reservation.blocker = tostring(created)
            elseif created then
              acted = acted + 1
              reservation.status = "construction-requested"
              reservation.requested_tick = game.tick
            else
              reservation.status = "awaiting-planner"
              reservation.blocker = why
            end
          end
          break
        end
      end
    end
  end
  return acted
end

function M.assess()
  local r = root()
  local groups = {}
  for _, pair in ipairs(active_pairs()) do
    local key = tostring(pair.station.force.index) .. ":" .. tostring(pair.station.surface.index)
    local group = groups[key] or {}
    group[#group+1] = pair
    groups[key] = group
  end
  r.assessments = {}
  for key, group in pairs(groups) do
    local report = snapshot(group)
    report.tick = game.tick
    report.needs = {}
    for item, missing in pairs(report.deficits) do
      local stage, input = classify(item)
      report.needs[#report.needs+1] = { item=item, missing=missing, stage=stage, input=input, existing_capacity=report.capacity[stage] or 0, decision=(report.capacity[stage] or 0)>0 and 'investigate-throughput-or-delivery' or 'missing-production-capacity' }
    end
    table.sort(report.needs, function(a,b) return a.item < b.item end)
    science_gap(group, report)
    synchronize_reservations(key, group, report)
    r.assessments[key] = report
  end
  r.last_construction_requests = connect_construction(groups)
  r.last_assessment_tick = game.tick
  r.stats.assessments = (r.stats.assessments or 0) + 1
  return r.assessments
end
function M.install()
  if M.installed then return true end
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then
    local ok, found = pcall(require, "scripts.core.runtime_tick_broker")
    if ok then broker = found end
  end
  if not (broker and type(broker.register_service) == "function") then
    error("emergency facility assessment requires runtime tick broker")
  end
  local service = broker.register_service({
    name = "emergency_facility_placement_bridge_0643",
    category = "diagnostics",
    interval = M.interval,
    priority = 950,
    budget = 4,
    fn = function()
      local reports = M.assess()
      local count = 0
      for _ in pairs(reports) do count = count + 1 end
      return { processed=count, acted=root().last_construction_requests or 0, detail="network shortage reservations routed through canonical construction planner" }
    end,
    note = "force/surface resource, logistics and production-capacity assessment"
  })
  if not service then error("emergency facility assessment broker registration failed") end
  root()
  M.installed = true
  if log then log("[Tech-Priests] emergency facility network shortage assessment installed") end
  return true
end
return M
