-- Network-wide emergency supply assessment and construction coordination.
-- First stage: identify real deficits and select the existing construction authority.
-- Never conjure resources or claim a planning ghost is a completed facility.
local M = {}
M.version = "0.1.675"
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
    r.assessments[key] = report
  end
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
      return { processed=count, acted=0, detail="network shortage and production-capacity assessment; construction not yet authorized" }
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
