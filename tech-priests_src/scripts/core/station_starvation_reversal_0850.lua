-- Method I: fail-closed five-station, no-spare-item reversal preflight.
-- This is an ordering witness, NOT permission to mine, move or fabricate stock.
-- Each eventual physical stage must independently revalidate 0822 custody and
-- hierarchy before taking a real station item into an engine-owned carrier.
local Recovery = require("scripts.core.station_recycling_0822")
local Relocation = require("scripts.core.station_relocation_0823")
local Cargo = require("scripts.core.station_cargo_0824")
local Depot = require("scripts.core.station_starvation_depot_0852")
local Ancestor = require("scripts.core.station_starvation_ancestor_0853")
local M = { version = "0.1.674-dev.0850" }

local expected = {
  [3] = "senior-cogitator-station",
  [2] = "intermediate-cogitator-station",
  [1] = "junior-cogitator-station",
}
local function valid(pair)
  return pair and pair.station and pair.station.valid
    and pair.priest and pair.priest.valid
    and pair.station.unit_number ~= nil
end
local function dist2(a, b)
  local x, y = a.x-b.x, a.y-b.y
  return x*x+y*y
end
local function rank(h, pair)
  local ok, result = pcall(h.rank, pair)
  return ok and tonumber(result) or nil
end
local function same_domain(a, b)
  return a.station.surface == b.station.surface
    and a.station.force == b.station.force
end
local function only_child(tp, h, parent, required_rank, label)
  local slate = parent.command_hierarchy_0480
  local ids = slate and slate.direct_subordinate_units
  if type(ids) ~= "table" or #ids ~= 1 then
    return nil, "ambiguous-" .. label .. "-subordinates"
  end
  local id = ids[1]
  local child = tp.pairs_by_station[id]
  if not valid(child) then return nil, "missing-" .. label .. "-pair" end
  if not same_domain(parent, child) or rank(h, child) ~= required_rank
      or child.station.name ~= expected[required_rank] then
    return nil, "wrong-" .. label .. "-rank-or-domain"
  end
  local ch = child.command_hierarchy_0480
  local observed, linked = pcall(h.is_direct_subordinate, parent, child)
  if not (ch and ch.superior_unit == parent.station.unit_number
      and observed and linked == true) then
    return nil, "invalid-" .. label .. "-link"
  end
  return child
end

function M.preflight(magos, target, station_item)
  if station_item ~= expected[3] then return nil, "not-senior-item" end
  if not (valid(magos) and target and type(target.x) == "number"
      and type(target.y) == "number"
      and target.x == target.x and target.y == target.y
      and math.abs(target.x) < math.huge
      and math.abs(target.y) < math.huge) then
    return nil, "root-or-known-resource-target-unavailable"
  end
  local tp = storage and storage.tech_priests
  local h = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not (tp and type(tp.pairs_by_station) == "table" and h
      and type(h.rank) == "function"
      and type(h.is_direct_subordinate) == "function"
      and type(h.peers) == "function") then
    return nil, "hierarchy-or-pair-registry-unavailable"
  end
  if rank(h, magos) ~= 4 then return nil, "not-planetary-magos" end
  local senior, reason = only_child(tp, h, magos, 3, "root")
  if not senior then return nil, reason end
  local intermediate
  intermediate, reason = only_child(tp, h, senior, 2, "senior")
  if not intermediate then return nil, reason end
  local junior
  junior, reason = only_child(tp, h, intermediate, 1, "intermediate")
  if not junior then return nil, reason end
  local peers_ok, peers = pcall(h.peers, junior)
  if not peers_ok then return nil, "junior-peer-authority-unobservable" end
  local slate = junior.command_hierarchy_0480
  if type(peers) ~= "table" or #peers ~= 1
      or not slate or type(slate.peer_units) ~= "table"
      or #slate.peer_units ~= 1 then
    return nil, "ambiguous-junior-peers"
  end
  local leaf = peers[1]
  if not valid(leaf) or leaf == junior
      or leaf.station.unit_number ~= slate.peer_units[1]
      or not same_domain(junior, leaf)
      or rank(h, leaf) ~= 1 or leaf.station.name ~= expected[1] then
    return nil, "invalid-junior-peer"
  end
  local leaf_slate = leaf.command_hierarchy_0480
  local back_ok, back = pcall(h.peers, leaf)
  if not back_ok then return nil, "leaf-peer-authority-unobservable" end
  if not (leaf_slate and type(leaf_slate.peer_units) == "table"
      and #leaf_slate.peer_units == 1
      and leaf_slate.peer_units[1] == junior.station.unit_number
      and type(back) == "table" and #back == 1 and back[1] == junior
      and type(leaf_slate.direct_subordinate_units) == "table"
      and #leaf_slate.direct_subordinate_units == 0
      and leaf_slate.superior_unit == nil) then
    return nil, "leaf-has-other-command-custody"
  end
  local seen = {}
  for _, pair in ipairs({magos, senior, intermediate, junior, leaf}) do
    local id = pair.station.unit_number
    if seen[id] or tp.pairs_by_station[id] ~= pair
        or not same_domain(magos, pair) then
      return nil, "duplicate-foreign-or-unregistered-station"
    end
    seen[id] = true
  end
  -- Reversal is justified only if the existing terminal is farther from
  -- the real needed patch than the Magos itself. Never dismantle a useful
  -- forward chain just because a station item happens to be unavailable.
  local base=magos.station.position
  local dx,dy=leaf.station.position.x-base.x,leaf.station.position.y-base.y
  local tx,ty=target.x-base.x,target.y-base.y
  -- Distance alone misclassifies a perpendicular chain as "opposed":
  -- its terminal is farther from a sideways target by Pythagoras despite
  -- having made no backward progress. Require a genuine negative direction
  -- projection before scheduling irreversible leaf-first recycling.
  if dx*tx+dy*ty >= 0
      or dist2(leaf.station.position,target)
        <= dist2(base,target) then
    return nil, "existing-chain-not-opposed-to-target"
  end
  local safe, why = Recovery.check_candidate(junior, leaf, expected[1])
  if not safe then return nil, "leaf-preflight:" .. tostring(why) end
  -- Primitive IDs only: safe across save/reload. Ancestors are NOT cleared
  -- or certified yet; each will require a fresh 0822 check after its children
  -- have been physically recovered and all real custody has been reconciled.
  return {
    status = "leaf-first-preflight-only",
    root_station_unit = magos.station.unit_number,
    target = {x=target.x, y=target.y},
    required_item = station_item,
    stages = {
      {parent_station_unit=junior.station.unit_number,
       station_unit=leaf.station.unit_number, item=expected[1]},
      {parent_station_unit=intermediate.station.unit_number,
       station_unit=junior.station.unit_number, item=expected[1]},
      {parent_station_unit=senior.station.unit_number,
       station_unit=intermediate.station.unit_number, item=expected[2]},
      {parent_station_unit=magos.station.unit_number,
       station_unit=senior.station.unit_number, item=expected[3]},
    },
    first_leaf_preflight_tick = game and game.tick or 0,
  }, "leaf-first-order-verified-no-items-moved"
end

-- An active five-station reversal writ reserves FUTURE ordinary planning
-- availability for its original participating priests, not their current
-- duties, mined inventory, or authority to deconstruct. This lookup uses
-- only the persisted 0256 writ and primitive station IDs. The actual mine
-- remains gated by a fresh 0822 custody check at the physical boundary.
function M.future_worker_reserved(pair)
  if not valid(pair) then return false end
  local tp=storage and storage.tech_priests
  local unit=pair.station.unit_number
  if not(tp and tp.station_expansion_0256 and unit) then return false end
  for _,rec in pairs(tp.station_expansion_0256) do
    if type(rec)=="table" and rec.status=="active"
        and rec.station_item==expected[3] then
      local plan=rec.reversal_plan_0850
      if type(plan)=="table" and plan.status=="leaf-first-preflight-only"
          and type(plan.stages)=="table" and #plan.stages==4
          and plan.root_station_unit==rec.worker_station_unit
          and type(plan.target)=="table" then
        local seen={}
        local matches=unit==rec.worker_station_unit
        local coherent=true
        for i=1,4 do
          local step=plan.stages[i]
          if not(type(step)=="table"
              and step.item==expected[i==3 and 2 or i==4 and 3 or 1]
              and type(step.station_unit)=="number"
              and type(step.parent_station_unit)=="number"
              and step.station_unit~=step.parent_station_unit
              and not seen[step.station_unit]) then
            coherent=false
            break
          end
          seen[step.station_unit]=true
          if unit==step.station_unit or unit==step.parent_station_unit then
            matches=true
          end
        end
        -- Malformed plans never authorize a new reservation. If physical
        -- staging has begun, its existing lease/hold remains quarantined
        -- by 0823/0824 independent of this future-work reservation.
        if coherent and matches and rec.worker_station_unit
            and tp.pairs_by_station
            and tp.pairs_by_station[rec.worker_station_unit] then
          return true,rec
        end
      end
    end
  end
  return false
end

-- A serialized preflight is only a historical observation, never a license
-- for later mining. The 0256 executor re-reads every live hierarchy/custody
-- dependency before keeping it active. This function is read-only: physical
-- staging must independently recheck again at the exact mutation boundary.
function M.validate_plan(magos, plan, target, station_item)
  if type(plan)~="table" or plan.status~="leaf-first-preflight-only"
      or type(plan.stages)~="table" or #plan.stages~=4
      or type(plan.target)~="table" then
    return false,"missing-or-malformed-stored-reversal-plan"
  end
  if not (valid(magos) and plan.root_station_unit==magos.station.unit_number
      and station_item==expected[3] and plan.required_item==station_item) then
    return false,"reversal-plan-root-or-item-changed"
  end
  if not (target and type(target.x)=="number" and type(target.y)=="number"
      and plan.target.x==target.x and plan.target.y==target.y) then
    return false,"reversal-plan-target-changed"
  end
  local current,why=M.preflight(magos,target,station_item)
  if not current then return false,"reversal-plan-live-"..tostring(why) end
  for i=1,4 do
    local saved,live=plan.stages[i],current.stages[i]
    if type(saved)~="table"
        or saved.parent_station_unit~=live.parent_station_unit
        or saved.station_unit~=live.station_unit
        or saved.item~=live.item then
      return false,"reversal-plan-stage-changed:"..i
    end
  end
  return true,"reversal-plan-live-preflight-verified"
end

-- Production entry point for the FIRST physical stage only. The terminal
-- Junior peer is mined into its parent's engine-owned carried inventory, and
-- that same parent walks the item back to the Magos. The hold is NOT credited
-- to the Magos chest: a later explicit co-located handoff must establish
-- permanent depot custody before any ancestor can be recovered.
local function close(a,b)
  return a and b and (a.x-b.x)^2+(a.y-b.y)^2<=25
end
local function worker_idle(pair)
  if not (valid(pair) and pair.mode=="idle" and not pair.dead
      and not pair.recalling and not pair.deploying) then return false end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_expansion_0256",
      "station_expansion_op_0256","station_crafting_task_0337"}) do
    if pair[key]~=nil and pair[key]~=false then return false end
  end
  return true
end
function M.service_first_leaf(magos, rec, command)
  if not (valid(magos) and rec and rec.status=="active"
      and rec.station_item==expected[3]
      and type(rec.reversal_plan_0850)=="table") then
    -- A stage already owns a physical station item and an original priest's
    -- relocation lease. A missing/corrupt planning record must not make the
    -- caller resume ordinary item acquisition or complete an unrelated ghost.
    -- Only a later explicit custody reconciliation can release this hold.
    if rec and rec.reversal_stage_0851 then
      return true,"reversal-staged-plan-or-root-unavailable"
    end
    return false,"no-active-five-station-reversal"
  end
  local plan=rec.reversal_plan_0850
  local stage=rec.reversal_stage_0851
  if stage~=nil and type(stage)~="table" then
    return true,"reversal-stage-identity-changed"
  end
  local tp=storage and storage.tech_priests
  if not (tp and tp.pairs_by_station and type(command)=="function"
      and defines and defines.command and defines.distraction) then
    return true,"reversal-movement-or-registry-unavailable"
  end
  local first=plan.stages and plan.stages[1]
  if not (type(first)=="table" and first.item==expected[1]) then
    return true,"reversal-stage-order-unavailable"
  end
  -- Verify permanent custody before requiring the original carrier station:
  -- that Junior is itself the next station to be physically recovered.
  if stage and stage.phase=="in-magos-depot" then
    if stage.id~=("reversal-leaf:"..tostring(rec.id)..":"..tostring(first.station_unit))
        or stage.station_item~=expected[1]
        or stage.leaf_station_unit~=first.station_unit
        or stage.worker_station_unit~=first.parent_station_unit then
      return true,"reversal-stage-identity-changed"
    end
    local entry,why=Depot.get_staged(magos,stage)
    if not entry then
      return true,"reversal-depot-staged-custody-unverified:"..tostring(why)
    end
    return Ancestor.service(magos,rec,plan,command)
  end
  local worker=tp.pairs_by_station[first.parent_station_unit]
  if not (valid(worker) and same_domain(worker,magos)) then
    return true,"reversal-junior-worker-unavailable"
  end
  if stage then
    if stage.id~=("reversal-leaf:"..tostring(rec.id)..":"..tostring(first.station_unit))
        or stage.station_item~=expected[1]
        or stage.leaf_station_unit~=first.station_unit
        or stage.worker_station_unit~=first.parent_station_unit
        or stage.worker_priest_unit~=worker.priest.unit_number then
      return true,"reversal-stage-identity-changed"
    end
  else
    local mission=magos.resource_expansion_0259
      and magos.resource_expansion_0259.chain_0820
    local safe,why=M.validate_plan(magos,plan,mission and mission.target,rec.station_item)
    if not safe then return true,"reversal-live-preflight:"..tostring(why) end
    if not worker_idle(worker) then
      return true,"reversal-junior-worker-has-existing-duty"
    end
    local leaf=tp.pairs_by_station[first.station_unit]
    if not valid(leaf) then return true,"reversal-terminal-leaf-unavailable" end
    stage={
      id="reversal-leaf:"..tostring(rec.id)..":"..tostring(first.station_unit),
      station_item=expected[1],leaf_station_unit=first.station_unit,
      leaf_priest_unit=leaf.priest.unit_number,
      worker_station_unit=first.parent_station_unit,
      worker_priest_unit=worker.priest.unit_number,
      phase="to-leaf",started_tick=game and game.tick or 0
    }
    rec.reversal_stage_0851=stage
  end
  if stage.phase=="to-leaf" then
    local leaf=tp.pairs_by_station[first.station_unit]
    if not (valid(leaf) and leaf.priest.unit_number==stage.leaf_priest_unit) then
      return true,"reversal-leaf-identity-unavailable"
    end
    -- A saved walk order is not authority to mine. Recheck the original
    -- five-station topology and 0822 custody at the actual mine boundary.
    local mission=magos.resource_expansion_0259
      and magos.resource_expansion_0259.chain_0820
    local safe,why=M.validate_plan(magos,plan,mission and mission.target,rec.station_item)
    if not safe then return true,"reversal-leaf-live-preflight:"..tostring(why) end
    if not worker_idle(worker) then
      return true,"reversal-junior-worker-has-existing-duty"
    end
    if not close(worker.priest.position,leaf.station.position) then
      local ok,accepted=pcall(command,worker.priest,{
        type=defines.command.go_to_location,
        destination=leaf.station.position,radius=2,
        distraction=defines.distraction.none
      })
      return true,(ok and accepted~=false)
        and "reversal-walking-to-real-junior-leaf"
        or "reversal-leaf-movement-refused"
    end
    local mined,reason=Relocation.try_stage_leaf(worker,leaf,stage)
    if not mined then return true,"reversal-leaf-mine-blocked:"..tostring(reason) end
    stage.phase="to-magos"
    stage.mined_tick=game and game.tick or 0
  end
  if stage.phase=="to-magos" or stage.phase=="at-magos-with-carried-item" then
    local lease=Relocation.pending_for_record(stage)
    local cargo=Cargo.get(worker,stage)
    if not (lease and lease.status=="staged" and lease.reversal_leaf_0851
        and lease.old_unit==stage.leaf_station_unit
        and lease.priest_unit==stage.leaf_priest_unit
        and lease.priest and lease.priest.valid
        and not (lease.old_station and lease.old_station.valid)
        and cargo and cargo.status=="carrying"
        and cargo.inventory.get_item_count(stage.station_item)==1) then
      return true,"reversal-staged-item-or-original-priest-custody-unverified"
    end
    Cargo.observe_carrier(worker,stage)
    if not close(worker.priest.position,magos.station.position) then
      if not worker_idle(worker) then
        return true,"reversal-carrier-has-existing-duty"
      end
      local ok,accepted=pcall(command,worker.priest,{
        type=defines.command.go_to_location,
        destination=magos.station.position,radius=2,
        distraction=defines.distraction.none
      })
      return true,(ok and accepted~=false)
        and "reversal-carrying-real-leaf-item-to-magos"
        or "reversal-return-movement-refused"
    end
    stage.phase="at-magos-with-carried-item"
    stage.arrived_tick=stage.arrived_tick or (game and game.tick or 0)
    local deposited,why=Depot.handoff(magos,worker,stage)
    if not deposited then
      return true,"reversal-magos-depot-handoff-blocked:"..tostring(why)
    end
    stage.phase="in-magos-depot"
    stage.deposited_tick=game and game.tick or 0
    return true,"reversal-leaf-item-stored-in-magos-depot"
  end
  return true,"reversal-stage-unknown-phase"
end

_G.TechPriestsStationStarvationReversal0850 = M
return M
