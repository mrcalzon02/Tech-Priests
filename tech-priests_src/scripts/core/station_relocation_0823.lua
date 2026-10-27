-- Physical, inventory-counted recovery and priest-preserving handoff for ranked
-- Cogitator expansion. A mined station is never credited until the real engine
-- reports exactly one station item in the receiving inventory.
local Recovery = require("scripts.core.station_recycling_0822")
local Cargo = require("scripts.core.station_cargo_0824")
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
-- A position/prototype match alone is insufficient: another construction
-- ghost could occupy the same site after a cancellation or reload. A
-- relocation lease may mine a staffed station only for its reserved ghost.
local function exact_record_ghost(parent, rec, ghost)
  return valid(parent and parent.station) and rec and valid(ghost)
    and ghost.name == "entity-ghost"
    and ghost.unit_number ~= nil and rec.ghost_unit ~= nil
    and ghost.unit_number == rec.ghost_unit
    and ghost.ghost_name == rec.station_item
    and ghost.surface == parent.station.surface
    and ghost.force == parent.station.force
    and same_position(ghost.position, rec.ghost_position)
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
  -- Never teleport hidden helpers or destroy their inventory. A failed
  -- post-mine readback leaves the recovered station item quarantined.
  local clean, reason = Recovery.empty_helpers(pair, lease)
  if clean then
    for _, key in ipairs({"logistic_requester", "logistic_return_cache"}) do
      local helper = pair[key]
      if valid(helper) then
        local destroyed = pcall(function()
          helper.destroy({raise_destroy=false})
        end)
        if not destroyed or valid(helper) then
          clean, reason = false, "linked-helper-retirement-failed:" .. key
          break
        end
      end
      pair[key] = nil
    end
  end
  if tp.pairs_by_station then tp.pairs_by_station[lease.old_unit] = nil end
  if tp.station_by_priest then tp.station_by_priest[lease.priest_unit] = nil end
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.pairs_by_priest[lease.priest_unit] = pair
  -- Keep the old station reference for forensic identity, but it is invalid
  -- after physical mining. The pair cannot be scheduled until a new station.
  pair.station_unit = lease.old_unit
  pair.relocation_pending_0823 = true
  return clean, reason
end
function M.try_recover(parent, candidate, rec, ghost, inv)
  local leases = root()
  if not leases then return false, "storage-unavailable" end
  if not exact_record_ghost(parent, rec, ghost) then
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
  -- A remote LuaEntity.mine into a station inventory would teleport the
  -- recovered item. Require the worker priest to stand within local reach of
  -- BOTH the dismantled station and the receiving station before mining.
  -- Distant recovery needs a separate move/carry/deposit state machine.
  local priest_pos = valid(parent.priest) and parent.priest.position or nil
  local function in_reach(pos)
    if not (priest_pos and pos) then return false end
    local dx, dy = priest_pos.x - pos.x, priest_pos.y - pos.y
    return dx * dx + dy * dy <= 25
  end
  if not in_reach(parent.station.position)
      or not in_reach(candidate.station.position) then
    return false, "worker-not-in-local-physical-transfer-reach"
  end
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
    force = station.force, surface = station.surface,
    position = {x=station.position.x, y=station.position.y}, status = "mining",
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
  local clean, reason = detach(lease)
  rec.relocation_old_station_unit_0823 = old_unit
  if not clean then
    lease.status = "custody-error"
    return false, reason
  end
  lease.status = "mined"
  return true, "physical-station-mined"
end
-- Long-distance recovery: the worker walks to the *source* station and
-- physically mines it into an engine-owned inventory carried by that worker.
-- No remote insertion into the parent station inventory is permitted.
function M.try_recover_carried(parent, candidate, rec, ghost)
  local leases = root()
  if not leases then return false, "storage-unavailable" end
  if not (valid(parent and parent.priest)
      and exact_record_ghost(parent, rec, ghost)) then
    return false, "invalid-physical-ghost"
  end
  local existing = rec.relocation_old_station_unit_0823
    and leases[rec.relocation_old_station_unit_0823]
  if existing then
    return existing.status == "mined", "existing-relocation-" .. tostring(existing.status)
  end
  if not valid(candidate and candidate.station) then
    return false, "no-valid-recovery-candidate"
  end
  local pos = parent.priest.position
  local site = candidate.station.position
  if not (pos and site and (pos.x-site.x)^2 + (pos.y-site.y)^2 <= 25) then
    return false, "worker-not-at-recovery-site"
  end
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
  -- Reserve the inventory BEFORE engine mining, so a post-mutation callback
  -- exception cannot strand an untracked physical station item.
  local reserved, bag_or_reason = Cargo.reserve_recovery(parent, rec)
  if not reserved then return false, bag_or_reason end
  local bag = bag_or_reason
  local station, priest = candidate.station, candidate.priest
  local lease = {
    old_unit = old_unit, old_station = station, priest = priest,
    priest_unit = priest.unit_number, pair = candidate,
    worker_unit = unit(parent), rec_id = rec.id, item = rec.station_item,
    target = {x=rec.ghost_position.x, y=rec.ghost_position.y},
    force = station.force, surface = station.surface,
    position = {x=station.position.x, y=station.position.y}, status = "mining",
    started_tick = game and game.tick or 0
  }
  leases[old_unit] = lease
  local ok, mined = pcall(function()
    return station.mine({inventory=bag, force=true, raise_destroy=true})
  end)
  local cargo = Cargo.get(parent, rec)
  local observed_ok, observed = pcall(function()
    return cargo and cargo.inventory and
      cargo.inventory.get_item_count(rec.station_item) or nil
  end)
  if not observed_ok then observed = nil end
  if valid(station) and observed == 0 then
    leases[old_unit] = nil
    local aborted = Cargo.abort_recovery(parent, rec)
    if not aborted then
      lease.status = "custody-error"
      leases[old_unit] = lease
      rec.relocation_old_station_unit_0823 = old_unit
      return false, "empty-recovery-cleanup-failed"
    end
    return false, ok and "engine-mining-refused" or "engine-mining-error"
  end
  if valid(station) or observed ~= 1 then
    -- Preserve BOTH real custody references for forensic repair. If the
    -- station vanished, detach its priest to prevent the legacy cleanup path
    -- from killing the survivor on the next scheduler pass.
    lease.status = "custody-error"
    rec.relocation_old_station_unit_0823 = old_unit
    if not valid(station) then detach(lease) end
    return false, "recovery-station-or-item-custody-error"
  end
  -- The physical engine mutation, not the callback return, is authoritative.
  -- A callback may throw after the station has actually been mined.
  local clean, reason = detach(lease)
  rec.relocation_old_station_unit_0823 = old_unit
  if not clean then
    lease.status = "custody-error"
    return false, reason
  end
  lease.status = "mined"
  local confirmed, why = Cargo.confirm_recovery(parent, rec)
  if not confirmed then
    lease.status = "custody-error"
    return false, why
  end
  return true, "physical-station-mined-to-carrier"
end
-- First stage of a no-spare-item five-station reversal. Unlike ordinary
-- relocation, the old Junior peer is physically mined BEFORE a replacement
-- ghost can be placed. Its living priest stays in the 0823 lifecycle lease;
-- the single recovered item stays in the walking parent's 0824 engine hold.
-- This function neither stages the item remotely nor permits ancestor mining.
function M.try_stage_leaf(parent, candidate, rec)
  local leases = root()
  if not leases then return false, "storage-unavailable" end
  if not (valid(parent and parent.station) and valid(parent and parent.priest)
      and valid(candidate and candidate.station) and valid(candidate and candidate.priest)
      and type(rec) == "table" and type(rec.id) == "string"
      and (rec.id:sub(1,14) == "reversal-leaf:"
        or (rec.id:match("^reversal%-ancestor:")
          and (rec.reversal_stage_index == 2 or rec.reversal_stage_index == 3
          or rec.reversal_stage_index == 4)))
      and rec.station_item == (rec.reversal_stage_index == 4
        and "senior-cogitator-station" or rec.reversal_stage_index == 3
        and "intermediate-cogitator-station" or "junior-cogitator-station")
      and rec.leaf_station_unit == unit(candidate)
      and rec.worker_station_unit == unit(parent)
      and rec.worker_priest_unit == parent.priest.unit_number
      and rec.leaf_priest_unit == candidate.priest.unit_number) then
    return false, "reversal-leaf-identity-invalid"
  end
  if rec.relocation_old_station_unit_0823 then
    return false, "reversal-leaf-already-leased"
  end
  local a, b = parent.priest.position, candidate.station.position
  if not (a and b and (a.x-b.x)^2 + (a.y-b.y)^2 <= 25) then
    return false, "worker-not-at-reversal-leaf"
  end
  local safe, reason = Recovery.check_candidate(parent, candidate, rec.station_item)
  if not safe then return false, reason end
  local old_unit = unit(candidate)
  if not old_unit or leases[old_unit] or active_for_pair(candidate) then
    return false, "reversal-leaf-already-leased"
  end
  for _, lease in pairs(leases) do
    if lease.rec_id == rec.id or lease.worker_unit == unit(parent) then
      return false, "reversal-worker-already-relocating"
    end
  end
  -- The worker cannot simultaneously hold another physical construction
  -- cargo. Do not steal an inventory from an existing 0824 transaction.
  for _, cargo in pairs(storage.tech_priests.station_cargo_0824 or {}) do
    if cargo.station_unit == unit(parent)
        and cargo.priest_unit == parent.priest.unit_number then
      return false, "reversal-worker-has-other-cargo"
    end
  end
  local reserved, bag_or_reason = Cargo.reserve_recovery(parent, rec)
  if not reserved then return false, bag_or_reason end
  local station, priest = candidate.station, candidate.priest
  local lease = {
    old_unit=old_unit, old_station=station, priest=priest,
    priest_unit=priest.unit_number, pair=candidate,
    worker_unit=unit(parent), rec_id=rec.id, item=rec.station_item,
    -- No target yet: the 0823 claim path cannot accidentally attach this
    -- priest to an unrelated station built while the item is staged.
    target=nil, force=station.force, surface=station.surface,
    position={x=station.position.x,y=station.position.y},
    status="mining", started_tick=game and game.tick or 0,
    reversal_leaf_0851=rec.reversal_stage_index == nil,
    reversal_ancestor_0853=rec.reversal_stage_index == 2,
    reversal_ancestor_0854=rec.reversal_stage_index == 3,
    reversal_ancestor_0855=rec.reversal_stage_index == 4
  }
  leases[old_unit] = lease
  local ok, mined = pcall(function()
    return station.mine({inventory=bag_or_reason, force=true, raise_destroy=true})
  end)
  local cargo = Cargo.get(parent, rec)
  local observed_ok, observed = pcall(function()
    return cargo and cargo.inventory.get_item_count(rec.station_item) or nil
  end)
  if not observed_ok then observed=nil end
  if valid(station) and observed == 0 then
    leases[old_unit] = nil
    if not Cargo.abort_recovery(parent, rec) then
      lease.status="custody-error"
      leases[old_unit]=lease
      rec.relocation_old_station_unit_0823=old_unit
      return false, "reversal-empty-cargo-cleanup-failed"
    end
    return false, ok and "engine-mining-refused" or "engine-mining-error"
  end
  if valid(station) or observed ~= 1 then
    lease.status="custody-error"
    rec.relocation_old_station_unit_0823=old_unit
    if not valid(station) then detach(lease) end
    return false, "reversal-leaf-custody-unverifiable"
  end
  local clean, why = detach(lease)
  rec.relocation_old_station_unit_0823=old_unit
  if not clean then
    lease.status="custody-error"
    return false, why
  end
  lease.status="staged"
  local confirmed, why = Cargo.confirm_recovery(parent, rec)
  if not confirmed then
    lease.status="custody-error"
    return false, why
  end
  return true, "reversal-leaf-physically-mined-to-worker"
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
          or priest.unit_number ~= lease.priest_unit
          or valid(pair.logistic_requester)
          or valid(pair.logistic_return_cache) then return false end
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
-- 0908: the original Senior was mined leaf-first into a separate stage
-- inventory and later physically carried to its replacement ghost. Only now
-- may the staged 0823 lease become an ordinary, one-item build lease. This
-- changes NO inventory; 0824 remains the sole physical debit authority.
local function same_engine_domain_0908(a,b)
  return a and b and (a==b
    or (type(a.index)=="number" and type(b.index)=="number"
      and a.index==b.index))
end
function M.arm_staged_rebuild(parent,rec,stage,ghost)
  local leases=root()
  local tp=storage and storage.tech_priests
  if not(leases and tp and valid(parent and parent.station)
      and valid(parent and parent.priest)
      and type(rec)=="table" and rec.status=="active"
      and rec.station_item=="senior-cogitator-station"
      and rec.station_entity==rec.station_item
      and type(stage)=="table" and stage.phase=="in-magos-depot"
      and stage.reversal_stage_index==4
      and rec.reversal_stage_0855==stage
      and rec.worker_station_unit==parent.station.unit_number
      and stage.worker_station_unit==parent.station.unit_number
      and stage.worker_priest_unit==parent.priest.unit_number
      and stage.station_item==rec.station_item
      and rec.relocation_old_station_unit_0823==nil) then
    return false,"staged-senior-build-authority-invalid"
  end
  local lease=leases[stage.leaf_station_unit]
  if not(lease and lease.status=="staged" and lease.reversal_ancestor_0855
      and lease.rec_id==stage.id and lease.old_unit==stage.leaf_station_unit
      and lease.priest_unit==stage.leaf_priest_unit
      and lease.worker_unit==parent.station.unit_number
      and lease.item==rec.station_item and lease.target==nil
      and not valid(lease.old_station)
      and valid(lease.priest) and lease.priest.unit_number==lease.priest_unit
      and lease.pair and lease.pair.priest==lease.priest
      and tp.pairs_by_priest and tp.pairs_by_priest[lease.priest_unit]==lease.pair
      and tp.pairs_by_station and tp.pairs_by_station[lease.old_unit]==nil
      and not valid(lease.pair.logistic_requester)
      and not valid(lease.pair.logistic_return_cache)) then
    return false,"staged-senior-original-priest-lease-invalid"
  end
  if not(valid(ghost) and ghost.name=="entity-ghost"
      and ghost.ghost_name==rec.station_item
      and type(ghost.unit_number)=="number"
      and ghost.unit_number==rec.ghost_unit
      and same_position(ghost.position,rec.ghost_position)
      and same_engine_domain_0908(ghost.force,parent.station.force)
      and same_engine_domain_0908(ghost.surface,parent.station.surface)
      and same_engine_domain_0908(lease.force,parent.station.force)
      and same_engine_domain_0908(lease.surface,parent.station.surface)
      and parent.priest.position
      and (parent.priest.position.x-ghost.position.x)^2
        +(parent.priest.position.y-ghost.position.y)^2<=25) then
    return false,"staged-senior-physical-ghost-or-reach-invalid"
  end
  for old,other in pairs(leases) do
    if old~=stage.leaf_station_unit and other.rec_id==rec.id then
      return false,"staged-senior-duplicate-build-lease"
    end
  end
  lease.target={x=rec.ghost_position.x,y=rec.ghost_position.y}
  lease.rec_id=rec.id
  lease.status="mined"
  rec.relocation_old_station_unit_0823=lease.old_unit
  return true,"original-senior-lease-armed-for-physical-build"
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
