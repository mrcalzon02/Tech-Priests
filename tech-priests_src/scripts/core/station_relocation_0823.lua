-- Physical, inventory-counted recovery and priest-preserving handoff for ranked
-- Cogitator expansion. A mined station is never credited until the real engine
-- reports exactly one station item in the receiving inventory.
local Recovery = require("scripts.core.station_recycling_0822")
local M = { version = "0.1.674-dev.0823" }
local function valid(e) return e and e.valid end
local function unit(pair) return valid(pair and pair.station) and pair.station.unit_number or nil end
local function root()
  if not (storage and storage.tech_priests) then return nil end
  local tp = storage.tech_priests
  tp.station_relocation_0823 = tp.station_relocation_0823 or {}
  return tp.station_relocation_0823
end
local function same_position(a, b)
  return a and b and math.abs(a.x-b.x) < 0.1 and math.abs(a.y-b.y) < 0.1
end
local function matching(lease, station)
  return valid(station) and station.name == lease.item
    and station.surface == lease.surface and station.force == lease.force
    and same_position(station.position, lease.target)
end
local function active_for_pair(pair)
  local leases = root()
  if not leases then return nil end
  for _, lease in pairs(leases) do
    if lease.pair == pair and lease.status ~= "complete" then return lease end
  end
  return nil
end
function M.protect_priest(pair, priest)
  local lease = pair and active_for_pair(pair)
  return lease ~= nil and valid(priest) and priest == lease.priest
end
-- The legacy station-removal handler must NOT cleanup_pair or destroy the
-- priest during our physical LuaEntity.mine call. This guard is transaction-
-- scoped, not a global override for normal station death or player mining.
function M.intercept_removed(entity, event)
  if not (entity and event and defines and defines.events
      and event.name ~= defines.events.on_entity_died) then return false end
  local leases = root()
  if not leases then return false end
  for _, lease in pairs(leases) do
    if lease.old_station == entity and
        (lease.status == "mining" or lease.status == "mined"
          or lease.status == "building") then
      return true
    end
  end
  return false
end
local function detach(lease)
  local tp = storage.tech_priests
  local pair = lease.pair
  if tp.pairs_by_station then tp.pairs_by_station[lease.old_unit] = nil end
  if tp.station_by_priest then tp.station_by_priest[lease.priest_unit] = nil end
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.pairs_by_priest[lease.priest_unit] = pair
  -- Keep the old station reference for forensic identity, but it is invalid
  -- after physical mining. The pair cannot be scheduled until a new station.
  pair.station_unit = lease.old_unit
  pair.relocation_pending_0823 = true
end
function M.try_recover(parent, candidate, rec, ghost, inv)
  local leases = root()
  if not leases then return false, "storage-unavailable" end
  if not (valid(parent and parent.station) and valid(ghost)
      and ghost.ghost_name == rec.station_item
      and ghost.surface == parent.station.surface
      and ghost.force == parent.station.force
      and same_position(ghost.position, rec.ghost_position)) then
    return false, "invalid-physical-ghost"
  end
  if not (inv and inv.valid and type(inv.get_item_count) == "function"
      and type(inv.get_insertable_count) == "function") then
    return false, "receiver-inventory-unobservable"
  end
  local existing = rec.relocation_old_station_unit_0823
    and leases[rec.relocation_old_station_unit_0823]
  if existing then
    return existing.status == "mined", "existing-relocation-" .. tostring(existing.status)
  end
  if not candidate then return false, "no-candidate" end
  local safe, reason = Recovery.check_candidate(parent, candidate, rec.station_item)
  if not safe then return false, reason end
  local old_unit = unit(candidate)
  if not old_unit or leases[old_unit] or active_for_pair(candidate) then
    return false, "station-already-leased"
  end
  for _, lease in pairs(leases) do
    if lease.rec_id == rec.id or lease.worker_unit == unit(parent) then
      return false, "worker-already-relocating"
    end
  end
  local before = inv.get_item_count(rec.station_item)
  if before ~= 0 then return false, "receiver-already-stocked" end
  if inv.get_insertable_count(rec.station_item) < 1 then
    return false, "receiver-full"
  end
  local station, priest = candidate.station, candidate.priest
  local lease = {
    old_unit = old_unit, old_station = station, priest = priest,
    priest_unit = priest.unit_number, pair = candidate,
    worker_unit = unit(parent), rec_id = rec.id, item = rec.station_item,
    target = {x=rec.ghost_position.x, y=rec.ghost_position.y},
    force = station.force, surface = station.surface, status = "mining",
    started_tick = game and game.tick or 0
  }
  leases[old_unit] = lease
  -- LuaEntity.mine is the ONLY producer of the recovered item. Its inventory
  -- argument is the real worker station inventory, never a synthetic buffer.
  local ok, mined = pcall(function()
    return station.mine({inventory=inv, force=true, raise_destroy=true})
  end)
  local after_ok, after = pcall(function() return inv.get_item_count(rec.station_item) end)
  if valid(station) then
    leases[old_unit] = nil
    return false, ok and "engine-mining-refused" or "engine-mining-error"
  end
  if not (after_ok and after == before + 1 and (not ok or mined ~= false)) then
    lease.status = "custody-error"
    return false, "mined-station-item-custody-error"
  end
  detach(lease)
  lease.status = "mined"
  rec.relocation_old_station_unit_0823 = old_unit
  return true, "physical-station-mined"
end
function M.begin_build(rec, worker)
  local leases = root()
  local lease = leases and leases[rec and rec.relocation_old_station_unit_0823]
  if not lease then return false end
  if lease.status ~= "mined" or lease.rec_id ~= rec.id
      or lease.worker_unit ~= unit(worker) then return false end
  lease.status = "building"
  return true
end
function M.build_failed(rec)
  local leases = root()
  local lease = leases and leases[rec and rec.relocation_old_station_unit_0823]
  if lease and lease.status == "building" then lease.status = "mined" end
end
function M.claim(station)
  if not valid(station) then return false end
  local leases = root()
  if not leases then return false end
  for id, lease in pairs(leases) do
    if lease.status == "building" and matching(lease, station) then
      local pair, priest = lease.pair, lease.priest
      if valid(lease.old_station) or not valid(priest)
          or priest.unit_number ~= lease.priest_unit then return false end
      local tp = storage.tech_priests
      tp.pairs_by_station = tp.pairs_by_station or {}
      if tp.pairs_by_station[station.unit_number] then return false end
      tp.pairs_by_priest = tp.pairs_by_priest or {}
      tp.station_by_priest = tp.station_by_priest or {}
      pair.station = station
      pair.station_unit = station.unit_number
      pair.priest = priest
      pair.priest_unit = priest.unit_number
      pair.force = station.force.name
      pair.surface = station.surface.index
      if type(_G.get_station_operating_radius) == "function" then
        pair.radius = _G.get_station_operating_radius(station)
      end
      pair.mode = "idle"
      pair.target = nil
      pair.command_hierarchy_0480 = nil
      pair.relocation_pending_0823 = nil
      tp.pairs_by_station[station.unit_number] = pair
      tp.pairs_by_priest[priest.unit_number] = pair
      tp.station_by_priest[priest.unit_number] = station.unit_number
      leases[id] = nil
      if type(_G.ensure_pair_logistic_caches) == "function" then
        pcall(_G.ensure_pair_logistic_caches, pair)
      end
      if type(_G.return_to_station) == "function" then
        pcall(_G.return_to_station, priest, station)
      end
      local h = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
      if h and type(h.rebuild) == "function" then pcall(h.rebuild, "forced") end
      return true
    end
  end
  return false
end
function M.pending_for_record(rec)
  local leases = root()
  return leases and rec and rec.relocation_old_station_unit_0823
    and leases[rec.relocation_old_station_unit_0823] or nil
end
_G.TechPriestsStationRelocation0823 = M
_G.tech_priests_relocation_intercept_removed_0823 = M.intercept_removed
_G.tech_priests_relocation_claim_0823 = M.claim
_G.tech_priests_relocation_protect_priest_0823 = M.protect_priest
return M
