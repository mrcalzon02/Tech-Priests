-- Tech Priests 0.1.674-dev read-only fluid-turret connection proposals.
--
-- For an unconnected fluid turret, select one accepted attack fluid and one real
-- same-force source segment with measured supply and an actual unused pipe
-- interface. Existing accepted fluid identity is preserved first to avoid mixing;
-- otherwise accepted fluids are ranked by damage modifier before source distance.
-- Proposals contain exact runtime port positions for 0718 to resolve to one
-- fluidbox. This module does not reserve tiles, place pipes, move priests, mutate
-- fluid, change filters, or alter turret targeting/firing.

local M = {
  version = "0.1.674-dev",
  storage_key = "fluid_turret_connection_proposals_0717",
  proposal_ttl = 60 * 20,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_sources = 192,
}

local FLUID_ENTITY_TYPES = {
  "pipe", "pipe-to-ground", "pump", "storage-tank", "offshore-pump",
  "assembling-machine", "furnace", "mining-drill", "boiler", "generator",
  "reactor", "fluid-turret", "rocket-silo",
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    read_only = true,
    stats = {},
    recent = {},
    proposals = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.read_only == nil then r.read_only = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.proposals = r.proposals or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail)
  local r = root()
  stat(action)
  r.recent[#r.recent + 1] = {
    tick = now(), action = tostring(action),
    station = safe(station_unit(pair)), detail = tostring(detail or ""),
  }
  while #r.recent > 140 do table.remove(r.recent, 1) end
end

local function readiness()
  return rawget(_G, "TechPriestsFluidTurretReadiness0716")
    or package.loaded["scripts.core.fluid_turret_readiness_0716"]
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok, box = pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end

local function segment_contents(box, index)
  local contents = {}
  if box and box.valid then pcall(function() contents = box.get_fluid_segment_contents(index) or {} end) end
  return type(contents) == "table" and contents or {}
end

local function segment_capacity(box, index)
  local value = 0
  if box and box.valid then pcall(function() value = tonumber(box.get_capacity(index)) or 0 end) end
  return value
end

local function segment_id(box, index)
  local value
  if box and box.valid then pcall(function() value = box.get_fluid_segment_id(index) end) end
  return value
end

local function free_interfaces(box, index)
  local out = {}
  if not (box and box.valid) then return out end
  local connections = {}
  pcall(function() connections = box.get_pipe_connections(index) or {} end)
  for _, connection in pairs(connections or {}) do
    if type(connection) == "table" then
      local owner
      if connection.target then pcall(function() owner = connection.target.owner end) end
      local connected = connection.target ~= nil or valid(owner)
      local position = connection.target_position or connection.position
      if not connected and position then out[#out + 1] = { x = position.x, y = position.y } end
    end
  end
  return out
end

local function segment_for_fluid(entity, fluid)
  local out = {}
  local box = fluidbox(entity)
  if not box then return out end
  for index = 1, #box do
    local contents = segment_contents(box, index)
    local amount = tonumber(contents[fluid]) or 0
    local wrong
    for name, other in pairs(contents) do
      if name ~= fluid and (tonumber(other) or 0) > 0.001 then wrong = name break end
    end
    if amount > 0.001 and not wrong then
      local interfaces = free_interfaces(box, index)
      if #interfaces > 0 then
        out[#out + 1] = {
          entity = entity,
          entity_name = entity.name,
          entity_unit = entity.unit_number,
          position = { x = entity.position.x, y = entity.position.y },
          fluidbox_index = index,
          segment_id = segment_id(box, index),
          amount = amount,
          capacity = segment_capacity(box, index),
          interfaces = interfaces,
        }
      end
    end
  end
  return out
end

local function service_radius(pair)
  local radius = tonumber(pair and pair.radius) or M.service_radius_floor
  if valid_pair(pair) and type(_G.get_station_operating_radius) == "function" then
    local ok, value = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(value) then radius = tonumber(value) end
  end
  return math.max(8, math.min(math.max(radius, M.service_radius_floor), M.service_radius_cap))
end

local function routed_find(surface, filters, category, key, ttl)
  local scanner = rawget(_G, "TechPriestsScanRouting0610")
    or package.loaded["scripts.core.scan_routing_0610"]
  if scanner and type(scanner.find_entities) == "function" then
    local entities = select(1, scanner.find_entities(surface, filters, {
      category = category, negative_key = key, negative_ttl = ttl or 60 * 5,
    }))
    return entities or {}
  end
  local ok, entities = pcall(function() return surface.find_entities_filtered(filters) end)
  return ok and entities or {}
end

local function find_source(pair, turret, fluid, turret_targets)
  local radius = service_radius(pair)
  local p = pair.station.position
  local entities = routed_find(turret.surface, {
    area = { { p.x - radius, p.y - radius }, { p.x + radius, p.y + radius } },
    force = turret.force,
    type = FLUID_ENTITY_TYPES,
    limit = M.max_scan_sources,
  }, "fluid-turret-source", "fluid-turret-source:"
      .. tostring(turret.surface.index) .. ":"
      .. tostring(turret.force.index) .. ":" .. tostring(fluid), 60 * 5)

  local best, best_score
  for _, entity in pairs(entities) do
    if valid(entity) and entity ~= turret then
      for _, segment in ipairs(segment_for_fluid(entity, fluid)) do
        local nearest = dist_sq(entity.position, turret.position)
        for _, target in ipairs(turret_targets or {}) do
          nearest = math.min(nearest, dist_sq(entity.position, target))
        end
        local score = nearest - math.min(segment.amount, 100000) * 0.001
        if not best_score or score < best_score then
          best, best_score = segment, score
          best.distance_sq = nearest
          best.selection_score = score
        end
      end
    end
  end
  return best
end

local function accepted_damage_lookup(report)
  local lookup = {}
  for _, accepted in ipairs(report.accepted_fluids or {}) do
    if accepted.name then
      lookup[accepted.name] = tonumber(accepted.damage_modifier) or 1
    end
  end
  return lookup
end

local function preferred_fluids(report)
  local out, seen = {}, {}
  local damage = accepted_damage_lookup(report)

  local function append(name, reason)
    if type(name) ~= "string" or seen[name]
      or not (report.accepted_lookup and report.accepted_lookup[name])
    then
      return
    end
    seen[name] = true
    out[#out + 1] = {
      name = name,
      reason = reason,
      damage_modifier = damage[name] or 1,
    }
  end

  -- Preserve a fluid already present in the turret before considering damage
  -- preference. Connecting a different accepted fluid would still contaminate the
  -- live turret buffer even if that fluid has a higher damage modifier.
  local present = {}
  for name, amount in pairs(report.buffer and report.buffer.contents or {}) do
    if report.accepted_lookup and report.accepted_lookup[name]
      and (tonumber(amount) or 0) > 0.001
    then
      present[#present + 1] = name
    end
  end
  for _, record_data in ipairs(report.pipeline and report.pipeline.records or {}) do
    for name, amount in pairs(record_data.segment_contents or {}) do
      if report.accepted_lookup and report.accepted_lookup[name]
        and (tonumber(amount) or 0) > 0.001
      then
        present[#present + 1] = name
      end
    end
  end
  table.sort(present)
  for _, name in ipairs(present) do append(name, "existing-turret-fluid") end

  local remaining = {}
  for _, accepted in ipairs(report.accepted_fluids or {}) do
    if accepted.name and not seen[accepted.name] then
      remaining[#remaining + 1] = {
        name = accepted.name,
        damage_modifier = tonumber(accepted.damage_modifier) or 1,
      }
    end
  end
  table.sort(remaining, function(a, b)
    if a.damage_modifier == b.damage_modifier then return a.name < b.name end
    return a.damage_modifier > b.damage_modifier
  end)
  for _, accepted in ipairs(remaining) do append(accepted.name, "highest-damage-compatible") end
  return out
end

local function build_for_report(pair, report)
  if not (valid_pair(pair) and report and valid(report.entity)
    and report.state == "input-pipeline-unconnected")
  then
    return nil
  end
  local targets = report.pipeline and report.pipeline.free_targets or {}
  if #targets == 0 then return nil end

  local preferences = preferred_fluids(report)
  local best_proposal
  -- Preference order is authoritative. find_source already chooses the best source
  -- by distance and available amount for one fluid, so a lower-ranked fluid may not
  -- displace a higher-damage fluid merely because its source is closer.
  for rank, preference in ipairs(preferences) do
    local source = find_source(pair, report.entity, preference.name, targets)
    if source then
      best_proposal = {
        version = M.version,
        tick = now(),
        expires_tick = now() + M.proposal_ttl,
        read_only = true,
        action = "connect-fluid-turret-input",
        turret = report.entity,
        turret_name = report.entity_name,
        turret_unit = report.entity_unit,
        fluid = preference.name,
        fluid_damage_modifier = preference.damage_modifier,
        fluid_preference_reason = preference.reason,
        fluid_preference_rank = rank,
        fluidbox_index = nil,
        connection_targets = targets,
        source = source,
        state = "source-network-found",
      }
      stat("preference-" .. preference.reason)
      break
    end
  end
  if not best_proposal then
    local first = preferences[1]
    best_proposal = {
      version = M.version,
      tick = now(),
      expires_tick = now() + M.proposal_ttl,
      read_only = true,
      action = "connect-fluid-turret-input",
      turret = report.entity,
      turret_name = report.entity_name,
      turret_unit = report.entity_unit,
      fluid = first and first.name or nil,
      fluid_damage_modifier = first and first.damage_modifier or nil,
      fluid_preference_reason = first and first.reason or "none",
      fluid_preference_rank = first and 1 or nil,
      fluidbox_index = nil,
      connection_targets = targets,
      source = nil,
      state = "no-source-network-found",
    }
  end
  return best_proposal
end

function M.refresh_pair(pair, force)
  if root().enabled == false or not valid_pair(pair) then return 0 end
  local doctrine = readiness()
  if doctrine and type(doctrine.scan_pair) == "function" then pcall(doctrine.scan_pair, pair, force == true) end
  local proposals = {}
  for _, report in ipairs(pair.fluid_turret_reports_0716 or {}) do
    local proposal = build_for_report(pair, report)
    if proposal then proposals[#proposals + 1] = proposal end
  end
  pair.fluid_turret_connection_proposals_0717 = proposals
  root().proposals[tostring(station_unit(pair) or "?")] = proposals
  stat("pair-refreshes")
  stat("proposals-created", #proposals)
  for _, proposal in ipairs(proposals) do
    if proposal.state == "source-network-found" then stat("source-networks-found") end
  end
  return #proposals
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.fluid_turret_connection_proposals_0717_wrapped then return true end
  diagnostics.fluid_turret_connection_proposals_0717_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 FLUID-TURRET-PROPOSALS-0717 enabled="
      .. safe(r.enabled)
      .. " read_only=true fluid_mutations=0 construction_tasks=0"
      .. " proposals=" .. safe(r.stats["proposals-created"] or 0)
      .. " sources=" .. safe(r.stats["source-networks-found"] or 0)
      .. " existing_fluid=" .. safe(r.stats["preference-existing-turret-fluid"] or 0)
      .. " damage_preferred=" .. safe(r.stats["preference-highest-damage-compatible"] or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local proposals = pair.fluid_turret_connection_proposals_0717 or {}
        for index, proposal in ipairs(proposals) do
          if index > 4 then break end
          lines[#lines + 1] = "PAIR-DUMP-0468 fluid-turret-proposal["
            .. safe(station_unit(pair)) .. ":" .. safe(index) .. "]"
            .. " state=" .. safe(proposal.state)
            .. " turret=" .. safe(proposal.turret_name)
            .. " fluid=" .. safe(proposal.fluid)
            .. " damage=" .. safe(proposal.fluid_damage_modifier)
            .. " preference=" .. safe(proposal.fluid_preference_reason)
            .. " source=" .. safe(proposal.source and proposal.source.entity_name or "none")
            .. " targets=" .. safe(#(proposal.connection_targets or {}))
        end
      end
    end
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "fluid_turret_connection_proposals_0717",
    category = "machine-logistics",
    interval = 229,
    priority = 80,
    budget = 6,
    note = "read-only damage-ranked accepted-fluid source discovery for unconnected fluid turrets",
    fn = function(_, budget)
      local count = 0
      for _, pair in pairs(pair_map()) do
        if valid_pair(pair) then
          M.refresh_pair(pair, false)
          count = count + 1
          if count >= (tonumber(budget) or 6) then break end
        end
      end
      return count > 0, "pairs=" .. safe(count)
    end,
  })
  return service ~= nil
end

function M.install()
  root()
  local broker_ok = register_service()
  local diagnostics_ok = patch_diagnostics()
  _G.TechPriestsFluidTurretConnectionProposals0717 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] damage-ranked fluid-turret source proposals armed broker="
      .. safe(broker_ok) .. " diagnostics=" .. safe(diagnostics_ok))
  end
  return broker_ok and diagnostics_ok
end

return M
