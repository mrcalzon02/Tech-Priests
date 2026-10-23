-- Ranked Cogitator station recovery: non-destructive, fail-closed preflight.
-- This module does NOT mine a staffed station. The canonical 0499 lifecycle
-- still destroys its priest on station removal; a relocation lease and exact
-- receiving-inventory transaction are mandatory before executing recovery.
local M = { version = "0.1.674-dev.0822", probe_interval = 60 * 15 }

local function valid(e) return e and e.valid end
local function unit(pair)
  return valid(pair and pair.station) and pair.station.unit_number or nil
end
local function rank(pair)
  local h = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not (h and type(h.rank) == "function") then return nil end
  local ok, n = pcall(h.rank, pair)
  return ok and tonumber(n) or nil
end
local function empty_inventory(inv)
  if not (inv and inv.valid and inv.get_contents) then return false end
  local ok, contents = pcall(function() return inv.get_contents() end)
  if not ok or type(contents) ~= "table" then return false end
  for _, stack in pairs(contents) do
    local count = type(stack) == "table" and tonumber(stack.count) or tonumber(stack)
    if not count or count > 0 then return false end
  end
  return true
end
local function no_items_in_entity(entity)
  if not valid(entity) then return false end
  local seen = {}
  local function check(inv)
    if not inv or inv.valid == false or seen[inv] then return true end
    seen[inv] = true
    return empty_inventory(inv)
  end
  if entity.get_main_inventory then
    local ok, inv = pcall(function() return entity.get_main_inventory() end)
    if not ok or not check(inv) then return false end
  end
  if entity.get_inventory then
    local ids = defines and defines.inventory or {}
    for _, key in ipairs({ "character_main", "chest", "spider_trunk", "car_trunk",
      "character_guns", "character_ammo", "character_armor", "character_trash" }) do
      if ids[key] then
        local ok, inv = pcall(function() return entity.get_inventory(ids[key]) end)
        if not ok or not check(inv) then return false end
      end
    end
  end
  return true
end
local function mine_yields_exact_station(station, item)
  if station.minable ~= true then return false end
  local ok, props = pcall(function()
    return station.prototype and station.prototype.mineable_properties
  end)
  if not ok or not props or not props.products then return false end
  local n = 0
  for _, product in pairs(props.products) do
    n = n + 1
    if product.name ~= item or (product.type and product.type ~= "item")
        or tonumber(product.amount) ~= 1
        or (product.probability and tonumber(product.probability) ~= 1) then
      return false
    end
  end
  return n == 1
end
local busy_keys = {
  "station_expansion_0256", "station_expansion_op_0256",
  "remote_resource_assignment_0820", "inventory_transfer_custody_0687",
  "active_task", "current_task", "construction_task", "build_task",
  "repair_target", "combat_target", "consecration_target",
  "emergency_craft", "emergency_assist_job_0187",
  "direct_acquisition_task_0336", "active_acquisition_0333",
  "construction_task_0338", "construction_task_0340",
  "construction_task_0342", "construction_task_0357",
  "station_crafting_task_0337",
}
local function active_mission(pair)
  local state = pair.resource_expansion_0259
  local mission = state and state.chain_0820
  if mission and mission.status ~= "cancelled" and mission.status ~= "blocked" then
    return true
  end
  local tp = storage and storage.tech_priests
  local station_id = unit(pair)
  for _, rec in pairs(tp and tp.station_expansion_0256 or {}) do
    if rec.status == "active" and
        (rec.requester_station_unit == station_id or rec.worker_station_unit == station_id) then
      return true
    end
  end
  for _, other in pairs(tp and tp.pairs_by_station or {}) do
    local root_mission = other and other.resource_expansion_0259
      and other.resource_expansion_0259.chain_0820
    if root_mission and root_mission.status ~= "cancelled"
        and root_mission.status ~= "blocked"
        and (root_mission.current_station_unit == station_id
          or root_mission.root_station_unit == station_id) then
      return true
    end
  end
  return false
end
local function no_station_custody(pair)
  local sources = rawget(_G, "tech_priests_0358_station_sources_for_pair")
  if type(sources) ~= "function" then return false, "inventory-authority-unavailable" end
  local ok, slots = pcall(sources, pair)
  if not ok or type(slots) ~= "table" or #slots == 0 then
    return false, "station-inventory-unobservable"
  end
  for _, slot in ipairs(slots) do
    if slot.owner ~= pair.station then
      return false, "dependent-storage-or-facility"
    end
    if not empty_inventory(slot.inv) then return false, "station-inventory-not-empty" end
  end
  local tp = storage and storage.tech_priests or {}
  local id = unit(pair)
  local steward = tp.inventory_steward_0357 or tp.inventory_steward_0356
  if steward and steward.stashes_by_station and next(steward.stashes_by_station[id] or {}) then
    return false, "station-stash-custody"
  end
  local facilities = tp.emergency_facility_doctrine_0343
  if facilities and facilities.by_station and next(facilities.by_station[id] or {}) then
    return false, "station-facility-custody"
  end
  if not no_items_in_entity(pair.priest) then return false, "priest-cargo-not-empty" end
  for _, key in ipairs({ "proxy", "logistic_requester", "logistic_return_cache" }) do
    if valid(pair[key]) then
      return false, "linked-helper-needs-lifecycle:" .. key
    end
  end
  return true, "empty-custody"
end

function M.check_candidate(parent, candidate, station_item)
  if not (valid(parent and parent.station) and valid(parent and parent.priest)
      and valid(candidate and candidate.station) and valid(candidate and candidate.priest)) then
    return false, "invalid-station-or-priest"
  end
  if parent == candidate or unit(parent) == unit(candidate) then return false, "self-recovery" end
  if candidate.station.name ~= station_item then return false, "wrong-station-item" end
  if parent.station.surface ~= candidate.station.surface
      or parent.station.force ~= candidate.station.force then return false, "foreign-domain" end
  local h = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local parent_rank, child_rank = rank(parent), rank(candidate)
  if not (h and parent_rank and child_rank and parent_rank >= 1 and parent_rank <= 4) then
    return false, "hierarchy-unavailable"
  end
  if parent_rank > 1 then
    if child_rank ~= parent_rank - 1 or type(h.is_direct_subordinate) ~= "function"
        or h.is_direct_subordinate(parent, candidate) ~= true then
      return false, "not-direct-lower-rank-subordinate"
    end
  else
    local peer = false
    if child_rank == 1 and type(h.peers) == "function" then
      for _, p in ipairs(h.peers(parent) or {}) do
        if p == candidate then peer = true; break end
      end
    end
    if not peer then return false, "not-junior-peer" end
  end
  local slate = candidate.command_hierarchy_0480
  if not slate or #(slate.direct_subordinate_units or {}) > 0 then
    return false, "station-has-descendants"
  end
  for _, peer_id in ipairs(slate.peer_units or {}) do
    if peer_id ~= unit(parent) then return false, "station-has-other-peers" end
  end
  if candidate.mode and candidate.mode ~= "idle" then return false, "priest-not-idle" end
  if candidate.dead or candidate.recalling or candidate.deploying then
    return false, "priest-unavailable"
  end
  for _, key in ipairs(busy_keys) do
    if candidate[key] ~= nil and candidate[key] ~= false then
      return false, "active-pair-duty:" .. key
    end
  end
  if active_mission(candidate) then return false, "active-station-expansion-or-resource-mission" end
  if not mine_yields_exact_station(candidate.station, station_item) then
    return false, "station-mining-product-not-exact"
  end
  local safe, reason = no_station_custody(candidate)
  if not safe then return false, reason end
  return true, "eligible-for-lifecycle-lease"
end

function M.find_candidate(parent, station_item, target)
  local tp = storage and storage.tech_priests
  if not (tp and tp.pairs_by_station) then return nil, "pair-registry-unavailable" end
  local best, score
  for _, candidate in pairs(tp.pairs_by_station) do
    local ok = M.check_candidate(parent, candidate, station_item)
    if ok then
      -- Prefer the station least useful to the outbound resource objective.
      local pos = candidate.station.position
      local dx = target and target.x and pos.x - target.x or 0
      local dy = target and target.y and pos.y - target.y or 0
      local distance = dx * dx + dy * dy
      if not best or distance > score
          or (distance == score and unit(candidate) < unit(best)) then
        best, score = candidate, distance
      end
    end
  end
  if not best then return nil, "no-safe-subordinate-station" end
  return best, "eligible-but-awaiting-priest-lifecycle-lease"
end

_G.TechPriestsStationRecycling0822 = M
return M
