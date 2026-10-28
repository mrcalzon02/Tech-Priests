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
  -- Planning may observe an uncommitted 0647 ingredient request. This does
  -- NOT authorize a mine: the real 0823 boundary still invokes strict 0822
  -- without planning_only after the 0640 owner explicitly yields its request.
  local safe, why = Recovery.check_candidate(junior, leaf, expected[1], true)
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
    -- 0938: the ORIGINAL rebuilt Intermediate's active first-Junior ghost
    -- reserves its FUTURE mundane work, like the earlier Intermediate child.
    -- 0937 engine logs showed 0647 ingredient acquisition instead of depot
    -- pickup. This reservation cannot cancel a current duty or move an item.
    local junior=type(rec)=="table" and rec.reversal_junior_0919
    if rec and rec.status=="active"
        and rec.station_item=="junior-cogitator-station"
        and rec.worker_station_unit==unit
        and rec.requester_station_unit==unit
        and tp.station_expansion_by_worker_0256
        and tp.station_expansion_by_worker_0256[unit]==rec.id
        and type(junior)=="table"
        and junior.original_intermediate_priest==pair.priest.unit_number
        and type(pair.reversal_junior_followup_0920)=="table"
        and pair.reversal_junior_followup_0920.root_writ_id==junior.root_writ_id
        and pair.station.name=="intermediate-cogitator-station"
        and tp.pairs_by_station and tp.pairs_by_station[unit]==pair
        and tp.pairs_by_priest
        and tp.pairs_by_priest[pair.priest.unit_number]==pair then
      local root=tp.station_expansion_0256[junior.root_writ_id]
      local step=root and root.reversal_junior_0919
      local stage=root and root.reversal_stage_0853
      local prior=root and root.reversal_stage_0854
      if root and root.status=="complete"
          and root.worker_station_unit==junior.magos_station_unit
          and tp.station_reversal_followup_0911
          and tp.station_reversal_followup_0911[junior.magos_station_unit]==root.id
          and tp.pairs_by_station[junior.magos_station_unit]
          and prior and prior.leaf_priest_unit==pair.priest.unit_number
          and stage and stage.id==junior.stage_id
          and step and step.status=="ghost-reserved"
          and step.child_writ_id==rec.id
          and step.ghost_unit==rec.ghost_unit then
        return true,rec
      end
    end
    -- 0945: the rebuilt ORIGINAL first Junior is the sole physical carrier
    -- for the second original Junior's separate Magos depot. The 0944 engine
    -- timed out with a recipe-only 0647 mode. Reserve FUTURE mundane work
    -- only for the exact live peer ghost, original priests and staged lease.
    -- This is scheduling authority, NOT inventory/movement/build authority.
    local peer=type(rec)=="table" and rec.reversal_second_junior_0943
    if type(peer)=="table" and rec.status=="active"
        and rec.station_item=="junior-cogitator-station"
        and rec.worker_station_unit==unit
        and rec.requester_station_unit==unit
        and pair.station.name=="junior-cogitator-station"
        and peer.original_first_junior_priest==pair.priest.unit_number
        and tp.station_expansion_by_worker_0256
        and tp.station_expansion_by_worker_0256[unit]==rec.id
        and tp.pairs_by_station and tp.pairs_by_station[unit]==pair
        and tp.pairs_by_priest
        and tp.pairs_by_priest[pair.priest.unit_number]==pair then
      local root=tp.station_expansion_0256[peer.root_writ_id]
      local step=root and root.reversal_second_junior_0943
      local first=root and root.reversal_stage_0853
      local second=root and root.reversal_stage_0851
      local first_step=root and root.reversal_junior_0919
      local first_child=first_step and tp.station_expansion_0256
        and tp.station_expansion_0256[first_step.child_writ_id]
      local lease=second and tp.station_relocation_0823
        and tp.station_relocation_0823[second.leaf_station_unit]
      local original=second and tp.pairs_by_priest
        and tp.pairs_by_priest[second.leaf_priest_unit]
      if root and root.status=="complete"
          and root.worker_station_unit==peer.magos_station_unit
          and tp.station_reversal_followup_0911
          and tp.station_reversal_followup_0911[peer.magos_station_unit]==root.id
          and tp.pairs_by_station[peer.magos_station_unit]
          and step and step.status=="ghost-reserved"
          and step.child_writ_id==rec.id
          and step.ghost_unit==rec.ghost_unit
          and first and first.reversal_stage_index==2
          and first.leaf_priest_unit==pair.priest.unit_number
          and first_child and first_child.status=="complete"
          and first_child.relocation_old_station_unit_0823==first.leaf_station_unit
          and second and second.id==peer.stage_id
          and second.station_item=="junior-cogitator-station"
          and second.phase=="in-magos-depot"
          and second.worker_priest_unit==pair.priest.unit_number
          and second.leaf_priest_unit==peer.original_priest
          and second.worker_station_unit==first.leaf_station_unit
          and tp.pairs_by_station[first.leaf_station_unit]==nil
          and tp.pairs_by_station[second.leaf_station_unit]==nil
          and tp.station_by_priest
          and tp.station_by_priest[pair.priest.unit_number]==unit
          and original and original.priest and original.priest.valid
          and original.priest.unit_number==second.leaf_priest_unit
          and lease and lease.status=="staged"
          and lease.old_unit==second.leaf_station_unit
          and lease.priest_unit==second.leaf_priest_unit
          and lease.priest==original.priest then
        return true,rec
      end
    end
    -- 0913: the newly rebuilt original Senior must be allowed to finish
    -- an existing duty, then physically retrieve the protected Intermediate
    -- item. Reserve only FUTURE work under the exact completed root writ.
    local follow=type(rec)=="table" and rec.reversal_followup_0911
    if rec and rec.status=="active" and follow
        and rec.station_item=="intermediate-cogitator-station"
        and rec.worker_station_unit==unit
        and tp.station_expansion_by_worker_0256
        and tp.station_expansion_by_worker_0256[unit]==rec.id
        and follow.original_senior_priest==pair.priest.unit_number
        and follow.magos_station_unit~=unit then
      local root=tp.station_expansion_0256[follow.root_writ_id]
      local next_step=root and root.reversal_next_0911
      if root and root.status=="complete"
          and root.reversal_stage_0854
          and root.reversal_stage_0854.id==follow.stage_id
          and next_step and next_step.status=="ghost-reserved"
          and next_step.child_writ_id==rec.id
          and next_step.ghost_unit==rec.ghost_unit
          and tp.pairs_by_station and tp.pairs_by_station[unit]==pair
          and tp.pairs_by_station[follow.magos_station_unit] then
        return true,rec
      end
    end
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

-- 0958: a legacy logistics entry point must not CREATE a new request
-- against an idle priest reserved by a real active reversal writ. Existing
-- logistics, inventory, crafting, combat and orders are never cancelled.
-- This is future scheduling only, not authority to mine a station.
function M.defer_new_legacy_logistics_0958(pair)
  if not valid(pair) or pair.mode~="idle" then return false end
  local reserved,writ=M.future_worker_reserved(pair)
  if not(reserved and writ and writ.status=="active") then return false end
  for _,key in ipairs({
      "logistic_requested_item","requested_item","active_supply_request",
      "inventory_scan","scavenge","cram","active_task","current_task",
      "emergency_craft","active_craft_0479","station_crafting_task_0337",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "direct_acquisition_custody_0513","inventory_transfer_custody_0687",
      "machine_logistics_custody_0528","emergency_production_custody_0514",
      "construction_custody_0338","construction_task","build_task",
      "combat_target","repair_target","consecration_target",
      "infrastructure_recipe_request_0647"}) do
    if pair[key]~=nil and pair[key]~=false then return false end
  end
  local order=pair.order_queue_0469 and pair.order_queue_0469.current
  if order and order.status=="active" then return false end
  return true
end

-- 0883: the canonical 0285 new-task gate must honor a REAL active
-- five-station recovery writ. Existing work, carried cargo, combat, repair and
-- consecration are untouched; this only defers an otherwise idle priest's
-- next ordinary job while a later-stage physical recovery awaits that priest.
-- Original 0285 validation and assignment remain the sole task authority.
function M.install_ordinary_assignment_reservation_0883()
  if rawget(_G,"TECH_PRIESTS_0850_PRE_RESERVATION_ASSIGN_0883") then
    return true
  end
  local previous=rawget(_G,"tech_priests_0285_assign_task")
  if type(previous)~="function" then return false end
  local ordinary={
    logistics=true,assignment=true,emergency_craft=true,scavenge=true
  }
  _G.TECH_PRIESTS_0850_PRE_RESERVATION_ASSIGN_0883=previous
  _G.tech_priests_0285_assign_task=function(pair,task,reason)
    local kind=type(task)=="table" and tostring(task.type or task.kind or "") or ""
    if ordinary[kind] and valid(pair)
        and not (pair.active_task or pair.active_task_0285
          or pair.emergency_craft or pair.direct_acquisition_custody_0513
          or pair.machine_logistics_custody_0528
          or pair.inventory_transfer_custody_0687
          or pair.construction_task_0338
          or pair.combat_target or pair.repair_target
          or pair.consecration_target)
    then
      local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
      if type(probe)=="function" then
        local ok,status=pcall(probe,pair)
        if ok and type(status)=="table" and status.priority=="idle" then
          local reserved,writ=M.future_worker_reserved(pair)
          if reserved then
            pair.reversal_deferred_assignments_0883=
              (pair.reversal_deferred_assignments_0883 or 0)+1
            pair.last_reversal_assignment_deferred_0883={
              tick=game and game.tick or 0,
              kind=kind,writ_id=writ and writ.id
            }
            return false
          end
        end
      end
    end
    return previous(pair,task,reason)
  end
  return true
end

-- 0885: 0252 recipe fanout creates its authoritative delegation BEFORE it
-- calls the 0285 task assigner. Reserving only that later callback cannot
-- prevent a new assignment from occupying an imminent physical recovery worker.
-- Gate the initial 0252 record creation instead. Existing assignments,
-- ingredient inventories, direct-mining cargo, combat and other priorities
-- are neither cancelled nor changed.
function M.install_new_delegation_reservation_0885()
  if rawget(_G,"TECH_PRIESTS_0850_PRE_CREATE_ASSIGNMENT_0885") then
    return true
  end
  local previous=rawget(_G,"tech_priests_0252_create_assignment")
  if type(previous)~="function" then return false end
  _G.TECH_PRIESTS_0850_PRE_CREATE_ASSIGNMENT_0885=previous
  _G.tech_priests_0252_create_assignment=function(requester,worker,...)
    if valid(worker) then
      local reserved,writ=M.future_worker_reserved(worker)
      if reserved then
        worker.reversal_deferred_delegations_0885=
          (worker.reversal_deferred_delegations_0885 or 0)+1
        worker.last_reversal_delegation_deferred_0885={
          tick=game and game.tick or 0,
          requester_unit=valid(requester) and requester.station.unit_number,
          writ_id=writ and writ.id
        }
        return nil
      end
    end
    return previous(requester,worker,...)
  end
  return true
end

-- 0890: A genuine fourth-stage reversal has already placed THREE distinct
-- physically mined station items in Magos custody. A legacy independent
-- emergency operation can still hold the Magos in its *planning* mode even
-- though no task or item transaction is active. Yield only that future
-- planning tick; never cancel the operation or an existing duty.
function M.idle_emergency_planning_yield_0890(pair)
  if not(valid(pair) and (pair.mode=="idle"
      or pair.mode=="independent-emergency-operation")
      and not(pair.dead or pair.recalling or pair.deploying)) then
    return false,"invalid-or-busy-magos"
  end
  local reserved,rec=M.future_worker_reserved(pair)
  if not(reserved and rec and pair.station.unit_number==rec.worker_station_unit
      and pair.station_expansion_0256==rec
      and type(rec.reversal_plan_0850)=="table"
      and type(rec.reversal_plan_0850.stages)=="table"
      and #rec.reversal_plan_0850.stages==4
      and (not rec.reversal_stage_0855
        or rec.reversal_stage_0855.phase~="in-magos-depot")) then
    return false,"no-active-four-stage-writ"
  end
  local seen={}
  for i,key in ipairs({"reversal_stage_0851","reversal_stage_0853",
      "reversal_stage_0854"}) do
    local stage=rec[key]
    local step=rec.reversal_plan_0850.stages[i]
    if not(type(stage)=="table" and stage.phase=="in-magos-depot"
        and type(step)=="table" and stage.leaf_station_unit==step.station_unit
        and stage.worker_station_unit==step.parent_station_unit
        and stage.station_item==step.item) then
      return false,"prior-stage-unverified:"..i
    end
    local entry=Depot.get_staged(pair,stage)
    if not(entry and entry.inventory and not seen[entry.inventory]) then
      return false,"prior-depot-unverified:"..i
    end
    seen[entry.inventory]=true
  end
  local tp=storage and storage.tech_priests
  local indexed_op=tp and tp.emergency_operation_by_station
    and tp.emergency_operation_by_station[pair.station.unit_number]
  local paired_op=pair.independent_emergency_operation_0184
  -- 0892: Factorio can retain the 0184 planning *mode* after its operation
  -- record has disappeared. The original strict identity requirement made
  -- this no-op label permanently block fourth-stage physical recovery.
  -- A live operation still has to be idle; conflicting records fail closed.
  if indexed_op~=nil and paired_op~=nil and indexed_op~=paired_op then
    return false,"emergency-operation-identity-mismatch"
  end
  local op=indexed_op or paired_op
  if op~=nil then
    if not(type(op)=="table" and op.enabled==true
        and not(op.construction or op.acquisition)
        and not(type(op.task_force_jobs_0187)=="table"
          and next(op.task_force_jobs_0187))) then
      return false,"emergency-operation-not-idle"
    end
  elseif pair.mode~="independent-emergency-operation" then
    return false,"no-stale-emergency-planning-mode"
  end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "emergency_craft","scavenge","cram","emergency_assist_job_0187",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "direct_acquisition_custody_0513","inventory_transfer_custody_0687",
      "machine_logistics_custody_0528","construction_custody_0338",
      "emergency_production_custody_0514","station_crafting_task_0337",
      "station_expansion_op_0256"}) do
    if pair[key]~=nil and pair[key]~=false then
      return false,"active-duty:"..key
    end
  end
  local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
  if type(probe)~="function" then return false,"priority-probe-unavailable" end
  local ok,priority=pcall(probe,pair)
  if not(ok and type(priority)=="table" and priority.priority=="idle") then
    return false,"priority-not-idle:"..tostring(type(priority)=="table"
      and priority.priority or priority)
  end
  return true,rec
end

-- 0264's emergency arbiter consults its op getter BEFORE the older 0184
-- service. Deferring only the service would make 0264 forcibly restore
-- independent-emergency-operation, indefinitely starving physical recovery.
-- Both existing entrypoints must therefore agree on the same verified
-- idle-planning yield. No emergency record is disabled or deleted.
function M.install_emergency_planning_reservation_0890()
  if rawget(_G,"TECH_PRIESTS_0850_PRE_EMERGENCY_GET_0890") then
    return true
  end
  local previous_get=rawget(_G,"tech_priests_0264_get_op")
  local previous_service=rawget(_G,
    "tech_priests_service_independent_emergency_operation_0184")
  local previous_0266=rawget(_G,"tech_priests_0266_get_op")
  if type(previous_get)~="function" or type(previous_service)~="function"
      or type(previous_0266)~="function" then
    return false
  end
  _G.TECH_PRIESTS_0850_PRE_EMERGENCY_GET_0890=previous_get
  _G.TECH_PRIESTS_0850_PRE_EMERGENCY_SERVICE_0890=previous_service
  _G.TECH_PRIESTS_0850_PRE_EMERGENCY_0266_GET_0891=previous_0266
  _G.tech_priests_0264_get_op=function(pair)
    local ok,yield=pcall(M.idle_emergency_planning_yield_0890,pair)
    if ok and yield then return nil end
    return previous_get(pair)
  end
  -- 0891: 0266 falls back to the original 0184 operation when 0264's
  -- getter returns nil. Its independent five-second survival heartbeat
  -- can otherwise restore emergency planning while a verified fourth-stage
  -- recovery is reserved. Close that bypass only for the same fully
  -- authenticated idle-planning case; active survival work stays untouched.
  _G.tech_priests_0266_get_op=function(pair,...)
    local ok,yield=pcall(M.idle_emergency_planning_yield_0890,pair)
    if ok and yield then return nil end
    return previous_0266(pair,...)
  end
  -- 0893: The fourth-stage executor reuses this exact read-only reservation.
  _G.tech_priests_0850_idle_emergency_planning_probe_0893=
    M.idle_emergency_planning_yield_0890
  _G.tech_priests_service_independent_emergency_operation_0184=function(pair,...)
    local ok,yield,rec=pcall(M.idle_emergency_planning_yield_0890,pair)
    if ok and yield then
      if pair.mode=="independent-emergency-operation" then pair.mode="idle" end
      pair.last_reversal_emergency_planning_deferred_0890={
        tick=game and game.tick or 0,writ_id=rec.id
      }
      return false
    end
    return previous_service(pair,...)
  end
  return true
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
-- 0870: the legacy command wrapper labels movement "legacy-command".
-- Canonical 0418 then rejects a Junior's distant peer recovery as ordinary
-- out-of-work-radius movement. Live 0850/0822 preflight authorizes this
-- physical recovery, so submit the walk to the existing 0418 movement owner.
-- No teleport, priority override, or direct engine-command bypass is added.
local function request_recovery_walk(worker,destination,leg,command)
  local reason="station-recovery-"..leg.."-0851"
  local priority=leg=="return" and 56 or 45
  local route=rawget(_G,"tech_priests_request_movement_0418")
  if type(route)=="function" then
    -- 0872: the engine's 0871 run still failed after the initial return
    -- handoff. Each repeated request recomputed a *moving* 0418 ground
    -- waypoint, which retarget debounce refused even though the controller
    -- already owned the same final Magos destination. Let 0418 advance its
    -- own short waypoints; only reuse a LIVE, same-owner, same-leg, same-goal
    -- request confirmed by the canonical status API. Never reuse a clamped,
    -- expired, replaced, safety-owned, or different-destination request.
    local status_fn=rawget(_G,"tech_priests_movement_status_0418")
    local req=worker and worker.movement_request_0418
    if type(status_fn)=="function" and type(req)=="table"
        and req.owner=="station-recovery-0851"
        and req.reason==reason and req.priority==priority then
      local ok_status,status=pcall(status_fn,worker,"station-recovery-0851")
      local goal=req.ground_route_final_destination or req
      if ok_status and type(status)=="table"
          and status.active==true and status.owner_match==true
          and status.reason==reason and status.expires_tick==req.expires_tick
          and (status.status=="active" or status.status=="arrived")
          and type(goal)=="table" and type(goal.x)=="number"
          and type(goal.y)=="number" and destination
          and dist2(goal,destination)<=0.04 then
        return true,"canonical-recovery-route-in-progress"
      end
    end
    local ok,accepted,why=pcall(route,worker,destination,reason,{
        -- 0871: the real engine mined the Junior leaf, but a same-priority
        -- return was repeatedly held by 0418's 90-tick retarget debounce.
        -- Only the already custody-verified return leg gains +11, clearing
        -- the churn band without outranking combat or safety enforcement.
        owner="station-recovery-0851",
        priority=priority,ttl=60*10,
        radius=2,distraction=defines.distraction.none
      })
    if not ok then return false,"route-exception:"..tostring(accepted) end
    if accepted==true then return true,"canonical-recovery-route-accepted" end
    return false,tostring(why or "route-refused")
  end
  -- Only older installations without 0418 use the original engine path.
  -- A present controller's refusal is NEVER bypassed.
  local ok,accepted=pcall(command,worker.priest,{
    type=defines.command.go_to_location,destination=destination,
    radius=2,distraction=defines.distraction.none
  })
  if not ok then return false,"legacy-command-exception:"..tostring(accepted) end
  return accepted~=false,accepted==false and "legacy-command-refused"
    or "legacy-command-accepted"
end
-- Public movement entry point also lets the source regression exercise the
-- exact production request/reuse path against the real 0418 controller.
M.request_recovery_walk=request_recovery_walk
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
    -- 0956: a resource-starved leaf may have an uncommitted 0647 ingredient
    -- *plan* even though it has no task, custody or physical ingredients.
    -- Only 0640 may retire its own request, and only against this exact
    -- live original Magos writ and full read-only reversal preflight.
    local leaf=tp.pairs_by_station[first.station_unit]
    -- 0957: also ask the 0640 owner to retire an intact pending recipe
    -- request left behind when its worker has already returned to idle.
    -- Never retire an unowned bare logistic request or a live task.
    if valid(leaf) and (leaf.mode=="infrastructure-material-acquisition-0647"
        or (leaf.mode=="idle"
          and type(leaf.infrastructure_recipe_request_0647)=="table")) then
      local governor=rawget(_G,"TechPriestsInfrastructureFirstGovernor0640")
      if not(governor and
          type(governor.yield_uncommitted_recipe_to_reversal_0938)=="function") then
        return true,"reversal-leaf-0647-owner-unavailable"
      end
      local ok,yielded,why=pcall(
        governor.yield_uncommitted_recipe_to_reversal_0938,leaf,rec)
      if not(ok and yielded==true) then
        return true,"reversal-leaf-uncommitted-plan-not-yielded:"..
          tostring(ok and why or yielded)
      end
    end
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
      local accepted,why=request_recovery_walk(
        worker,leaf.station.position,"leaf",command)
      rec.reversal_route_denial_0870=not accepted and tostring(why):sub(1,160)
        or nil
      return true,accepted and "reversal-walking-to-real-junior-leaf"
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
      local accepted,why=request_recovery_walk(
        worker,magos.station.position,"return",command)
      rec.reversal_route_denial_0870=not accepted and tostring(why):sub(1,160)
        or nil
      return true,accepted and "reversal-carrying-real-leaf-item-to-magos"
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
