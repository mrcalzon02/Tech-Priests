-- scripts/core/single_dispatcher_0510.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- One fair per-pair scheduler/executor dispatcher and canonical action owner.

local M={version="0.1.674-dev",storage_key="single_dispatcher_0510",tick_interval=5,max_pairs_per_pulse=24,legacy_gate_window=30}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function lower(v)return string.lower(tostring(v or""))end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function priest_unit(p)return p and(p.priest_unit or(valid(p.priest)and p.priest.unit_number))or nil end
local OWNERSHIP={
 ["direct-acquisition"]="dispatcher_owns_direct",["station-craft"]="dispatcher_owns_station_craft",["consecration"]="dispatcher_owns_consecration",["repair"]="dispatcher_owns_repair",["combat-repair"]="dispatcher_owns_combat_repair",["construction"]="dispatcher_owns_construction",["machine-logistics"]="dispatcher_owns_machine_logistics",["item-family-logistics"]="dispatcher_owns_item_family_logistics",["energy-family-logistics"]="dispatcher_owns_energy_family_logistics",["rocket-silo-logistics"]="dispatcher_owns_rocket_silo_logistics",["artillery-logistics"]="dispatcher_owns_artillery_logistics",["roboport-repair-pack-logistics"]="dispatcher_owns_roboport_repair_pack_logistics",
}
local function root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,gate_legacy_tick=true,suppress_independent_executor_pulses=true,stats={},recent={},cursor=0}
 storage.tech_priests[M.storage_key]=r;r.version=M.version
 for _,key in pairs(OWNERSHIP)do if r[key]==nil then r[key]=true end end
 if r.enabled==nil then r.enabled=true end;if r.gate_legacy_tick==nil then r.gate_legacy_tick=true end;if r.suppress_independent_executor_pulses==nil then r.suppress_independent_executor_pulses=true end;r.stats=r.stats or{};r.recent=r.recent or{};r.cursor=tonumber(r.cursor)or 0;return r
end
-- The 0569 economy bucket coordinates dispatcher ownership through this
-- canonical state accessor; keep the module's private root as the sole source.
M.root=root
local function stat(k,n)local r=root();r.stats[k]=(r.stats[k]or 0)+(tonumber(n)or 1)end
local function record(action,pair,detail)local r=root();local sig=safe(station_unit(pair))..":"..safe(action)..":"..safe(detail);if r.last_signature==sig then return end;r.last_signature=sig;r.recent[#r.recent+1]={tick=now(),action=safe(action),station=station_unit(pair),priest=priest_unit(pair),detail=safe(detail)};while #r.recent>120 do table.remove(r.recent,1)end end
local function order_tick(pair)local q=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469");if q and type(q.tick_pair)=="function"then local ok,acted=pcall(q.tick_pair,pair,"single-dispatcher-0510");return ok and acted==true end;return false end
local function classifier(pair)local a=rawget(_G,"TECH_PRIESTS_ACTION_STATE_ARBITER_0488");if a and type(a.action)=="function"then local ok,v=pcall(a.action,pair);if ok and type(v)=="table"then return v end end;return{kind=lower(pair.mode)~=""and lower(pair.mode)or"idle",source="compatibility-mode"}end
local function direct_active(pair)local mod=rawget(_G,"TechPriestsDirectAcquisitionExecutor0513")or package.loaded["scripts.core.direct_acquisition_executor_0513"];if not mod then return false end;if pair.direct_acquisition_custody_0513 then return true end;if type(mod.current_direct_task)=="function"then local task,current=mod.current_direct_task(pair);return task~=nil and current~=nil end;return false end
local function family_for(pair,action)
 local kind=lower(action and action.kind);if kind=="acquisition"and direct_active(pair)then return"direct-acquisition"end;if kind=="crafting"or kind=="station-craft"or kind=="emergency-craft"then return"station-craft"end
 if kind=="construction"or kind=="construction-placement"then return"construction"end
 if kind=="machine-logistics"or kind=="machine_logistics"then return"machine-logistics"end;if kind=="item-family-logistics"or kind=="item_family_logistics"then return"item-family-logistics"end;if kind=="energy-family-logistics"or kind=="energy_family_logistics"then return"energy-family-logistics"end;if kind=="rocket-silo-logistics"or kind=="rocket_silo_logistics"then return"rocket-silo-logistics"end;if kind=="artillery-logistics"or kind=="artillery_logistics"then return"artillery-logistics"end;if kind=="roboport-repair-pack-logistics"or kind=="roboport_repair_pack_logistics"then return"roboport-repair-pack-logistics"end
 if kind:find("consecr",1,true)then return"consecration"end;if kind=="combat-repair"then return"combat-repair"end;if kind=="repair"then return"repair"end;return kind~=""and kind or"idle"
end
local function target_fields(action)local target=action and action.target;local position=action and action.position;if valid(target)then position=target.position end;return target,position and{x=position.x,y=position.y}or nil end
local function publish_action(pair,action,family,status,detail)
 local previous=pair.canonical_action_0744;local target,position=target_fields(action);local order=pair.order_queue_0469 and pair.order_queue_0469.current or pair.active_order_0469;local action_id=order and order.key or family..":"..safe(station_unit(pair))
 local rec={version=M.version,action_id=action_id,family=family,owner="single_dispatcher_0510",phase=action and action.phase or pair.dispatcher_phase or status,status=status,detail=safe(detail),order_key=order and order.key or action and action.order_key,item=action and action.item or order and order.item,target=target,target_unit=valid(target)and target.unit_number or nil,target_name=valid(target)and target.name or nil,target_surface=valid(target)and target.surface and target.surface.index or nil,position=position,source=action and action.source or"dispatcher",issued_tick=previous and previous.action_id==action_id and previous.issued_tick or now(),updated_tick=now()}
 pair.canonical_action_0744=rec;pair.dispatcher_0510={tick=rec.updated_tick,action=safe(action and action.kind or family),family=family,reason=safe(action and action.reason or action and action.source or detail),target=safe(rec.target_name and(rec.target_name.."#"..safe(rec.target_unit))or"nil"),gates_legacy=OWNERSHIP[family]~=nil and status~="idle"and status~="failed",acted=status=="acted",result=safe(detail)};return rec
end
local function normalize_execution(primary,secondary)
 local out={processed=1,acted=0,blocked=0,waiting=0,failed=0,exhausted=false,detail=safe(secondary or primary or"")}
 if type(primary)=="table"then for _,key in ipairs{"processed","acted","blocked","waiting","failed"}do out[key]=math.max(0,tonumber(primary[key])or(key=="processed"and 1 or 0))end;out.exhausted=primary.exhausted==true;out.detail=safe(primary.detail or primary.reason or secondary or"")
 elseif primary==true then out.acted=1 elseif type(primary)=="number"then out.acted=math.max(0,primary)else local d=lower(out.detail);if d:find("block",1,true)then out.blocked=1 elseif d:find("wait",1,true)or d:find("cooldown",1,true)or d:find("move",1,true)then out.waiting=1 elseif d:find("fail",1,true)or d:find("error",1,true)then out.failed=1 end end;return out
end
local function call_module(module_name,global_name,fn_name,pair,reason)
 local mod=rawget(_G,global_name)or package.loaded[module_name];if not mod then local ok,loaded=pcall(require,module_name);if ok then mod=loaded end end
 if not(mod and type(mod[fn_name])=="function")then return{processed=1,failed=1,detail=module_name.."."..fn_name.." unavailable"}end
 local ok,primary,secondary=pcall(mod[fn_name],pair,reason);if not ok then return{processed=1,failed=1,detail=safe(primary)}end;return normalize_execution(primary,secondary)
end
local EXECUTORS={
 ["direct-acquisition"]={"scripts.core.direct_acquisition_executor_0513","TechPriestsDirectAcquisitionExecutor0513"},["consecration"]={"scripts.core.consecration_executor_0515","TechPriestsConsecrationExecutor0515"},["combat-repair"]={"scripts.core.combat_repair_doctrine_0517","TechPriestsCombatRepairDoctrine0517"},["repair"]={"scripts.core.repair_executor_0516","TechPriestsRepairExecutor0516"},["construction"]={"scripts.core.construction_planner","TechPriestsConstructionPlanner0338"},["machine-logistics"]={"scripts.core.logistics_machine_fulfillment_0528","TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528"},["item-family-logistics"]={"scripts.core.item_family_logistics_0702","TechPriestsItemFamilyLogistics0702"},["energy-family-logistics"]={"scripts.core.energy_family_logistics_0707","TechPriestsEnergyFamilyLogistics0707"},["rocket-silo-logistics"]={"scripts.core.rocket_silo_logistics_0710","TechPriestsRocketSiloLogistics0710"},["artillery-logistics"]={"scripts.core.artillery_logistics_0713","TechPriestsArtilleryLogistics0713"},["roboport-repair-pack-logistics"]={"scripts.core.roboport_repair_pack_logistics_0715","TechPriestsRoboportRepairPackLogistics0715"},
}
local function execute(pair,family,reason)
 if family=="station-craft"then local result=call_module("scripts.core.emergency_production_executor_0514","TechPriestsEmergencyProductionExecutor0514","service_pair",pair,reason);if result.failed==0 and(result.acted>0 or result.waiting>0 or result.blocked>0)then return result end;local fallback=call_module("scripts.core.crafting_executor","TechPriestsCraftingExecutor","service_pair",pair,reason);if fallback.failed==0 then return fallback end;return result.failed>0 and result or fallback end
 local spec=EXECUTORS[family];if spec then return call_module(spec[1],spec[2],"service_pair",pair,reason)end;return{processed=1,waiting=family~="idle"and 1 or 0,detail=family=="idle"and"idle"or"compatibility-leaf-family"}
end
local function family_owned(r,family)local key=OWNERSHIP[family];return key~=nil and r[key]~=false end
local function relinquish_unladen_direct_movement(pair,family)
 if (family~="station-craft" and family~="machine-logistics")
   or pair.direct_acquisition_custody_0513 then return false end
 if family=="station-craft" then
   local craft=pair.emergency_craft
   if not (type(craft)=="table" and craft.strict_recipe_0647==true) then return false end
 else
   local logistics=rawget(_G,"TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
     or package.loaded["scripts.core.logistics_machine_fulfillment_0528"]
   local mined=logistics
     and type(logistics.completed_bootstrap_mining_output)=="function"
     and logistics.completed_bootstrap_mining_output(pair)==true
   local needed=logistics
     and type(logistics.infrastructure_prerequisite_output_ready_1045)=="function"
     and logistics.infrastructure_prerequisite_output_ready_1045(pair)==true
   if not (mined or needed) then return false end
 end
 local ctl=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
 if not (ctl and type(ctl.request_status)=="function" and type(ctl.stop)=="function") then return false end
 local ok,status=pcall(ctl.request_status,pair)
 if not (ok and type(status)=="table" and status.active==true
    and status.owner=="direct-acquisition-0513") then return false end
 -- Only the stale direct-acquisition movement request is ours to retire.
 -- Combat, rescue, safety enforcement and custody-return routes are untouched.
 local reason=family=="machine-logistics" and "dispatcher-output-collection-handoff-0510"
   or "dispatcher-strict-craft-handoff-0510"
 local ok_stop,stopped=pcall(ctl.stop,pair,reason)
 if ok_stop and stopped==true then
   stat(family=="machine-logistics" and "output-collection-direct-route-released"
     or "strict-craft-direct-route-released")
   return true
 end
 return false
end
function M.service_pair(pair,reason)
 local r=root();if r.enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end
 -- The 0836 planner also runs in its broker cadence. Distinguish that
 -- from the canonical 0510 dispatcher actually reaching the rail branch.
 local rail_mission=pair.remote_rail_outpost_0835
 if rail_mission and rail_mission.rail_frontier_0836
     and now()-(tonumber(rail_mission.last_dispatch_entry_tick_0510)or -600)>=600 then
  rail_mission.last_dispatch_entry_tick_0510=now()
 end
 -- Diagnose a stalled existing return BEFORE direct-custody and defense early
 -- returns. Observe 0528 phase regardless of its custody flag: 0984 drill
 -- escrow is a distinct physical inventory and must never be inferred from
 -- 0528 custody. Rate-limit per pair and retain a save-safe scalar snapshot.
 local pending_machine=pair.machine_logistics_0528
 if type(pending_machine)=="table"
     and lower(pending_machine.phase)=="return-custody-to-station" then
  local previous=pair.machine_return_entry_probe_0510
  local flags={
   "0528-custody="..safe(pending_machine.custody~=nil),
   "pair-0528-custody="..safe(pair.machine_logistics_custody_0528~=nil),
   "direct-custody="..safe(pair.direct_acquisition_custody_0513~=nil),
   "direct-active="..safe(direct_active(pair)),
   "defense-task="..safe(pair.defense_task_0259~=nil),
   "combat-target="..safe(valid(pair.combat_target)),
   "machine-valid="..safe(valid(pending_machine.machine)),
   "order="..safe((pair.order_queue_0469 and pair.order_queue_0469.current
     or pair.active_order_0469) and
     (pair.order_queue_0469 and pair.order_queue_0469.current
       or pair.active_order_0469).kind),
   "movement-owner="..safe(pair.movement_request_0418
     and pair.movement_request_0418.owner),
  }
  local signature=table.concat(flags,",")
  local emit=not previous or previous.signature~=signature
    or now()-(tonumber(previous.last_log_tick)or 0)>=600
  if emit and log then
   log("[TP-0528-ENTRY-0510] tick="..safe(now())
     .." station="..safe(station_unit(pair))
     .." priest="..safe(priest_unit(pair))
     .." last-service="..safe(pending_machine.active_updated_tick)
     .." phase="..safe(pending_machine.phase)
     .." "..signature)
  end
  pair.machine_return_entry_probe_0510={
   tick=now(),last_log_tick=emit and now()
     or previous.last_log_tick,signature=signature,
   last_service_tick=pending_machine.active_updated_tick,
  }
 end
 -- 1141: A committed, counted ranked ore receipt must receive another real
 -- 0837 service attempt even while the final Magos is completing its OWN
 -- incumbent defense, construction or 0513 cargo return. The normal 1129
 -- courier-owner branch lies behind those early-returning dispatcher duties.
 -- Only an existing exact-root mission and already-active upstream relay
 -- qualify. 0837 itself exclusively owns physical pickup, movement, debit,
 -- counted deposit, original priest identities and refusal of busy workers.
 -- This observation/owner call never synthesizes cargo or cancels work.
 local mission=pair.resource_expansion_0259
   and pair.resource_expansion_0259.chain_0820
 local relay=mission and mission.return_courier_0837
 if mission and mission.status=="reached-resource"
   and mission.root_station_unit==station_unit(pair) and relay
   -- 1249: terminal 0513 work can finish while the Magos is busy
   -- with its OWN incumbent cargo/defense. The root does not own the
   -- terminal's original task and cannot freeze its *future* courier.
   -- Call the original 0837 authority before early dispatcher returns;
   -- it still refuses live terminal tasks, orders, movement and cargo.
   and (relay.phase=="awaiting-terminal-duty"
     or relay.phase=="first-hop-delivered"
     or (type(relay.hop_index)=="number" and relay.hop_index>=2
       and relay.phase~="magos-delivered"
       and relay.phase~="custody-blocked")) then
  local courier=rawget(_G,"TechPriestsResourceReturnCourier0837")
    or package.loaded["scripts.core.resource_return_courier_0837"]
  if courier and type(courier.service)=="function" then
   local ok,progress,detail=pcall(courier.service,pair)
   pair.courier_owner_service_1141={
    tick=now(),advanced=ok and progress==true,
    detail=safe(ok and detail or progress),
    phase=safe(relay.phase),
   }
   if not ok then
    pair.courier_owner_failure_1141={
      tick=now(),reason=safe(progress),
      count=(pair.courier_owner_failure_1141
        and pair.courier_owner_failure_1141.count or 0)+1}
    record("counted-courier-owner-service-error-1141",pair,safe(progress))
    stat("failures")
   elseif progress==true then
    stat("counted-courier-owner-advanced-1141")
   end
  end
 end
 -- A hostile incident may arrive while the priest is physically carrying
 -- mined ore. Perimeter defense correctly yields that custody, but the action
 -- classifier may still select combat and strand the RETURN route forever.
 -- Complete the incumbent physical delivery BEFORE any combat/defense
 -- arbitration. The authoritative 0513 executor still enforces actual
 -- station contact, atomic deposit and exact cargo conservation.
 -- No new mining task is assigned here; after deposit the pending hostile
 -- incident is serviced on the next dispatcher pulse.
 if pair.direct_acquisition_custody_0513 and family_owned(r,"direct-acquisition") then
  local action={kind="acquisition",source="existing-physical-custody",
    reason="finish-physical-return-before-defense",
    item=pair.direct_acquisition_custody_0513.item,target=pair.station}
  local result=execute(pair,"direct-acquisition",
    "dispatcher-0510:physical-custody-return")
  local status=result.failed>0 and "failed"
    or result.acted>0 and "acted" or result.blocked>0 and "blocked"
    or result.waiting>0 and "waiting" or "idle"
  publish_action(pair,action,"direct-acquisition",status,result.detail)
  stat("pairs_processed");stat("actions",result.acted);stat("failures",result.failed)
  record("dispatch-physical-custody-return",pair,result.detail)
  return result
 end
 -- Evaluate a previously registered hostile-defense emergency BEFORE the
 -- routine order queue can issue fresh industrial work to an unladen priest.
 -- Existing physical custody still wins inside defense.service_pair and may
 -- complete normally through the current dispatcher below.
 -- The canonical per-pair dispatcher owns urgent hostile defense execution.
 -- Reuse the physical perimeter executor; never steal an item while a
 -- separate logistics subsystem retains custody.
 local defense=rawget(_G,"TechPriestsDefensePerimeter0259")
 if defense and type(defense.has_pending)=="function"
     and type(defense.service_pair)=="function"
     and defense.has_pending(pair) then
  local ok,response=pcall(defense.service_pair,pair)
  if not ok then
   -- Retain bounded, station-local evidence rather than silently swallowing
   -- the authoritative perimeter executor's runtime failure.
   pair.defense_dispatch_failure_0818={
     tick=now(),reason=safe(response),
     count=(pair.defense_dispatch_failure_0818
       and pair.defense_dispatch_failure_0818.count or 0)+1,
   }
   record("defense-dispatch-error",pair,safe(response))
   stat("failures")
   return {processed=1,failed=1,detail=safe(response)}
  end
  if type(response)=="table"
      and ((response.acted or 0)>0
       or (pair.defense_task_0259 and (response.waiting or 0)>0)) then
   local action={kind="defense",reason="persistent-hostile-incident",
     position=pair.defense_task_0259 and pair.defense_task_0259.position}
   local status=(response.acted or 0)>0 and "acted" or "waiting"
   publish_action(pair,action,"defense",status,response.detail)
   stat("pairs_processed")
   stat("actions",response.acted or 0)
   record("dispatch-defense",pair,safe(response.detail))
   return response
  end
 end
 -- 1035: Resume an already-started physical 0528 machine transaction before
 -- issuing fresh routine orders. The native receiver-output task stopped
 -- receiving service while its priest walked away, despite a live machine
 -- reservation. No new candidate is started here, and explicit foreign
 -- orders, strict craft, direct work, construction, custody and defense win.
 local machine=pair.machine_logistics_0528
 local phase=type(machine)=="table" and lower(machine.phase) or ""
 local order=pair.order_queue_0469 and pair.order_queue_0469.current
   or pair.active_order_0469
 local order_kind=lower(order and order.kind)
 local foreign_order=order and order_kind~="machine-logistics"
   and order_kind~="machine_logistics"
 local craft=pair.emergency_craft
 local strict_craft=type(craft)=="table" and craft.strict_recipe_0647==true
 if family_owned(r,"machine-logistics")
   and phase~="" and phase~="complete" and phase~="failed"
   and phase~="idle" and phase~="none"
   and (valid(machine.machine)
     -- An invalidated receiver is no longer needed to return output ALREADY
     -- debited into the original engine-owned 0984 hold. Require a proven
     -- existing 0528 carrier, never initiate a new transaction here.
     or (phase=="return-custody-to-station"
       and machine.action=="clear-output"
       and type(machine.custody)=="table"
       and machine.custody.inventory_0984
       and pair.machine_logistics_custody_0528==machine.custody
       and type(machine.drill_pickup_0983)=="table"))
   -- A real 0528 custody hold cannot be abandoned merely because a newer
   -- routine order or strict craft request appeared while the worker walked.
   -- Resume only its existing transaction; all competing physical custody
   -- and defense exclusions below remain authoritative.
   and (machine.custody or pair.machine_logistics_custody_0528
     or (not foreign_order and not strict_craft))
   and not direct_active(pair)
   and not (pair.construction_task_0338 or pair.construction_custody_0338
     or pair.construction_task_0340 or pair.inventory_transfer_custody_0687
     or pair.emergency_facility_feed_custody_0357
     or pair.item_family_custody_0702 or pair.energy_family_custody_0707
     or pair.rocket_silo_custody_0710 or pair.artillery_custody_0713
     or pair.roboport_repair_custody_0715 or pair.defense_task_0259
     -- A planned/active expansion is not itself physical worker custody.
     -- Preserve its priority for unladen machine work, but do not strand
     -- an already-held 0528 item when no 0256 builder lease exists.
     or (pair.station_expansion_0256
       and pair.station_expansion_0256.status=="active"
       and not (machine.custody or pair.machine_logistics_custody_0528))) then
   local action={kind="machine-logistics",source="incumbent-0528",
     reason=phase,item=machine.item,target=machine.machine}
   local result=execute(pair,"machine-logistics",
     "dispatcher-0510:resume-incumbent-0528")
   local status=result.failed>0 and "failed"
     or result.acted>0 and "acted" or result.blocked>0 and "blocked"
     or result.waiting>0 and "waiting" or "idle"
   publish_action(pair,action,"machine-logistics",status,result.detail)
   stat("pairs_processed");stat("actions",result.acted);stat("failures",result.failed)
   record("dispatch-incumbent-machine",pair,result.detail)
   return result
 end
 -- 2026-11-06: Retain the exact reason an incumbent physically held 0528
 -- return was not serviced. This is diagnostic only: no ownership, movement,
 -- item debit, or scheduling priority changes. The record survives reload.
 if type(machine)=="table" and (machine.custody or pair.machine_logistics_custody_0528)
   and phase=="return-custody-to-station" then
  local exclusions={}
  local function excluded(name,condition)
   if condition then exclusions[#exclusions+1]=name end
  end
  excluded("family-disabled",not family_owned(r,"machine-logistics"))
  excluded("machine-invalid",not valid(machine.machine))
  excluded("direct-active",direct_active(pair))
  excluded("construction-0338",pair.construction_task_0338 or pair.construction_custody_0338)
  excluded("construction-0340",pair.construction_task_0340)
  excluded("transfer-0687",pair.inventory_transfer_custody_0687)
  excluded("facility-feed-0357",pair.emergency_facility_feed_custody_0357)
  excluded("item-family-0702",pair.item_family_custody_0702)
  excluded("energy-family-0707",pair.energy_family_custody_0707)
  excluded("rocket-0710",pair.rocket_silo_custody_0710)
  excluded("artillery-0713",pair.artillery_custody_0713)
  excluded("roboport-0715",pair.roboport_repair_custody_0715)
  excluded("defense-task-0259",pair.defense_task_0259)
  local prior=pair.machine_return_dispatch_block_0510
  local reason_block=#exclusions>0 and table.concat(exclusions,",")
    or "incumbent-branch-not-entered"
  if log and (not prior or prior.reason~=reason_block
      or now()-(tonumber(prior.last_log_tick)or 0)>=600) then
   log("[TP-0528-RETURN-DISPATCH] tick="..safe(now())
     .." station="..safe(station_unit(pair))
     .." reason="..reason_block
     .." last_service="..safe(machine.active_updated_tick))
  end
  pair.machine_return_dispatch_block_0510={
   last_log_tick=(not prior or prior.reason~=reason_block
      or now()-(tonumber(prior.last_log_tick)or 0)>=600)
      and now() or prior.last_log_tick,
   tick=now(),phase=phase,reason=reason_block
     or "incumbent-branch-not-entered",
   last_machine_service_tick=machine.active_updated_tick,
   carried_item=machine.item,
  }
 end
 -- The rail observer is strictly read-only toward Factorio entities.
 -- Running it before the relay-chain evaluator surfaces a distinct railroad
 -- strategy without letting one planner create another planner's buildings.
 local rail=rawget(_G,"TechPriestsRemoteRailOutpost0835")
 if rail and type(rail.observe_pair)=="function" then
  local ok,done,why=pcall(rail.observe_pair,pair)
  if not ok then
   pair.remote_rail_outpost_probe_failure_0835={
     tick=now(),reason=safe(done)}
   record("remote-rail-survey-error",pair,safe(done))
   stat("failures")
  end
 end
 -- Rail 0836 owns only the next surveyed segment/request. Its physical
 -- worker remains the existing 0338 construction planner, invoked by THIS
 -- dispatcher; all rail stock removal and returns use that executor's
 -- conservation/position checks. Preserve existing combat, material and
 -- machine-logistics custody rather than inventing a parallel builder.
 local frontier=rawget(_G,"TechPriestsRailTrackFrontier0836")
 if frontier and type(frontier.service_pair)=="function"
    and not (pair.defense_task_0259
      or pair.machine_logistics_custody_0528
      or pair.direct_acquisition_custody_0513
      or pair.emergency_facility_feed_custody_0357
      or (pair.station_expansion_0256
        and pair.station_expansion_0256.status=="active")) then
  local ok,active,why=pcall(frontier.service_pair,pair)
  if not ok then
   pair.remote_rail_frontier_failure_0836={tick=now(),reason=safe(active)}
   record("rail-frontier-error",pair,safe(active))
   stat("failures")
   return {processed=1,failed=1,detail=safe(active)}
  end
  local m=pair.remote_rail_outpost_0835
  local pending=m and m.pending_rail_0836
  -- Rate-limited readback of the true 0836->0510 handoff; not a second
  -- dispatcher, and not permission to displace an incumbent physical duty.
  if m and m.rail_frontier_0836
      and now()-(tonumber(m.last_frontier_dispatch_tick_0510)or -600)>=600 then
   m.last_frontier_dispatch_tick_0510=now()
   m.last_frontier_dispatch_0510={
    tick=now(),active=active==true,reason=safe(why),
    pending=pending~=nil,request_matches=pending~=nil
      and pair.construction_request==pending.request,
    builder=pair.construction_task_0338~=nil,
   }
  end
  -- Record the EXACT canonical admission refusal for a still-original
  -- rail request. A bare "active_order=true" obscures the order identity.
  -- This is a bounded read-only diagnostic: never mutate an order, yield
  -- its ownership, preempt real cargo, or issue an independent executor.
  if pending and pair.construction_request==pending.request and not active then
   local last=pair.remote_rail_admission_refusal_0510
   local refusal=safe(why)
   if not last or last.reason~=refusal
       or now()-(tonumber(last.tick)or 0)>=300 then
    local q=pair.order_queue_0469
    local o=(q and q.current)or pair.active_order_0469
    local selection=pair.canonical_action_0744
    pair.remote_rail_admission_refusal_0510={
     tick=now(),reason=refusal,
     order_kind=safe(o and o.kind),order_source=safe(o and o.source),
     order_status=safe(o and o.status),order_key=safe(o and o.key),
     action_family=safe(selection and selection.family),
     action_detail=safe(selection and selection.detail),
     active_task=pair.active_task~=nil,
     current_task=pair.current_task~=nil,
     construction_task=pair.construction_task_0338~=nil,
     construction_custody=pair.construction_custody_0338~=nil,
     movement_owner=safe(pair.movement_request_0418
       and pair.movement_request_0418.owner),
     builder_blocker=safe(pair.construction_blocked_reason_0338),
    }
   end
  end
  if active and pending and pair.construction_request==pending.request then
   local planner=rawget(_G,"TechPriestsConstructionPlanner0338")
   if not(planner and type(planner.discover_pair)=="function")then
    return {processed=1,blocked=1,detail="rail-construction-authority-unavailable"}
   end
   -- The canonical request is immutable until the actual builder confirms
   -- a placed, real rail or returns its held item after failure.
   if not pair.construction_task_0338 then
    local discovered,err=pcall(planner.discover_pair,pair,true)
    if not discovered then
     return {processed=1,blocked=1,detail="rail-discovery-error:"..safe(err)}
    end
   end
   local result=execute(pair,"construction","dispatcher-0510:rail-frontier-0836")
   local status=result.failed>0 and "failed" or result.acted>0 and "acted"
     or result.blocked>0 and "blocked"
     or result.waiting>0 and "waiting" or "idle"
   publish_action(pair,{kind="construction",source="rail-frontier-0836",
     item="rail",position=pending.position,
     reason="physical-rail-frontier"}, "construction",status,result.detail)
   stat("pairs_processed");stat("actions",result.acted);stat("failures",result.failed)
   record("dispatch-rail-physical-builder",pair,result.detail)
   return result
  end
  -- A first-locomotive writ is separate from an active local miner.
  -- 0338 may admit it only if its exact construction_request still belongs
  -- to the original post-audit Magos, and the 0469 order has explicitly
  -- authorized a source-less yield. A started physical builder keeps custody.
  local first=m and m.first_locomotive_0836
  local loco=first and first.phase=="awaiting-original-0338"
    and first.request
  if loco and pair.construction_request==loco
    and m.status=="rail-track-established"
    and loco.item_name=="locomotive"
    and loco.entity_name=="locomotive"
    and loco.site_reason=="original-first-locomotive-0836"
    and loco.rail_mission_station_unit_0836==station_unit(pair) then
   local task=pair.construction_task_0338
   local carrying=pair.construction_custody_0338
   local original=(task and task.request_value==loco)
     or (carrying and carrying.request_value==loco)
   if not original then
    local q=pair.order_queue_0469
    local order=pair.active_order_0469 or (q and q.current)
    if order then
     local owner=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
     local ok,allowed=false,false
     if owner and type(owner.can_yield_uncommitted_rail_0836)=="function" then
      ok,allowed=pcall(owner.can_yield_uncommitted_rail_0836,pair,loco)
     end
     if not(ok and allowed==true)then
      return {processed=1,blocked=1,detail="locomotive-order-yield-refused"}
     end
    end
    if pair.active_task or pair.current_task or pair.active_task_0285
      or pair.defense_task_0259 or pair.construction_task_0338
      or pair.construction_custody_0338 or pair.construction_task_0340
      or pair.machine_logistics_custody_0528
      or pair.inventory_transfer_custody_0687
      or pair.direct_acquisition_custody_0513
      or pair.robot_network_task_0338 or pair.robot_network_request_0338
      or pair.movement_request_0418 then
     return {processed=1,blocked=1,detail="locomotive-incumbent-physical-work"}
    end
   end
   local planner=rawget(_G,"TechPriestsConstructionPlanner0338")
     or package.loaded["scripts.core.construction_planner"]
   if not (planner and type(planner.discover_pair)=="function")then
    return {processed=1,blocked=1,detail="locomotive-builder-unavailable"}
   end
   if not original then
    local ok,candidate=pcall(planner.discover_pair,pair,true)
    if not ok or not(candidate and candidate.request_field=="construction_request"
      and candidate.request_value==loco
      and candidate.item_name=="locomotive")then
     return {processed=1,blocked=1,detail="locomotive-original-candidate-refused"}
    end
   end
   local result=execute(pair,"construction",
     "dispatcher-0510:first-original-paid-locomotive-0836")
   local status=result.failed>0 and "failed" or result.acted>0
     and "acted" or result.blocked>0 and "blocked"
     or result.waiting>0 and "waiting" or "idle"
   publish_action(pair,{kind="construction",source="first-paid-locomotive-0836",
     item="locomotive",position=first.position,reason="native-paid-rolling-stock"},
     "construction",status,result.detail)
   stat("pairs_processed");stat("actions",result.acted);stat("failures",result.failed)
   record("dispatch-first-native-locomotive-0836",pair,result.detail)
   return result
  end
  -- A first-wagon writ is separate from an active local miner.
  -- 0338 may admit it only if its exact construction_request still belongs
  -- to the original post-audit Magos, and the 0469 order has explicitly
  -- authorized a source-less yield. A started physical builder keeps custody.
  local second=m and m.first_wagon_0836
  local wagon=second and second.phase=="awaiting-original-0338"
    and second.request
  if wagon and pair.construction_request==wagon
    and m.status=="rail-track-established"
    and wagon.item_name=="cargo-wagon"
    and wagon.entity_name=="cargo-wagon"
    and wagon.site_reason=="original-first-wagon-0836"
    and m.first_locomotive_0836
    and m.first_locomotive_0836.phase=="native-paid-locomotive-verified"
    and wagon.rail_mission_station_unit_0836==station_unit(pair) then
   local task=pair.construction_task_0338
   local carrying=pair.construction_custody_0338
   local original=(task and task.request_value==wagon)
     or (carrying and carrying.request_value==wagon)
   if not original then
    local q=pair.order_queue_0469
    local order=pair.active_order_0469 or (q and q.current)
    if order then
     local owner=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
     local ok,allowed=false,false
     if owner and type(owner.can_yield_uncommitted_rail_0836)=="function" then
      ok,allowed=pcall(owner.can_yield_uncommitted_rail_0836,pair,wagon)
     end
     if not(ok and allowed==true)then
      return {processed=1,blocked=1,detail="wagon-order-yield-refused"}
     end
    end
    if pair.active_task or pair.current_task or pair.active_task_0285
      or pair.defense_task_0259 or pair.construction_task_0338
      or pair.construction_custody_0338 or pair.construction_task_0340
      or pair.machine_logistics_custody_0528
      or pair.inventory_transfer_custody_0687
      or pair.direct_acquisition_custody_0513
      or pair.robot_network_task_0338 or pair.robot_network_request_0338
      or pair.movement_request_0418 then
     return {processed=1,blocked=1,detail="wagon-incumbent-physical-work"}
    end
   end
   local planner=rawget(_G,"TechPriestsConstructionPlanner0338")
     or package.loaded["scripts.core.construction_planner"]
   if not (planner and type(planner.discover_pair)=="function")then
    return {processed=1,blocked=1,detail="wagon-builder-unavailable"}
   end
   if not original then
    local ok,candidate=pcall(planner.discover_pair,pair,true)
    if not ok or not(candidate and candidate.request_field=="construction_request"
      and candidate.request_value==wagon
      and candidate.item_name=="cargo-wagon")then
     return {processed=1,blocked=1,detail="wagon-original-candidate-refused"}
    end
   end
   local result=execute(pair,"construction",
     "dispatcher-0510:first-original-paid-wagon-0836")
   local status=result.failed>0 and "failed" or result.acted>0
     and "acted" or result.blocked>0 and "blocked"
     or result.waiting>0 and "waiting" or "idle"
   publish_action(pair,{kind="construction",source="first-paid-wagon-0836",
     item="cargo-wagon",position=second.position,reason="native-paid-rolling-stock"},
     "construction",status,result.detail)
   stat("pairs_processed");stat("actions",result.acted);stat("failures",result.failed)
   record("dispatch-first-native-wagon-0836",pair,result.detail)
   return result
  end
 end
 -- A strategic Magos resource chain owns only its intent. The existing
 -- station expansion executor still controls actual physical construction.
 local chain=rawget(_G,"TechPriestsResourceStationChain0820")
 if chain and type(chain.service_pair)=="function" then
  local ok,err=pcall(chain.service_pair,pair)
  if not ok then
   pair.resource_expansion_dispatch_failure_0820={
     tick=now(),reason=safe(err),
     count=(pair.resource_expansion_dispatch_failure_0820
       and pair.resource_expansion_dispatch_failure_0820.count or 0)+1}
   record("resource-chain-error",pair,safe(err))
   stat("failures")
   return {processed=1,failed=1,detail=safe(err)}
  end
 end
 local expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
 if expansion and type(expansion.service_station_expansion_assignment)=="function"
     and pair.station_expansion_0256
     and pair.station_expansion_0256.status=="active"
     and not(pair.machine_logistics_custody_0528
       or pair.direct_acquisition_custody_0513
       or pair.emergency_facility_feed_custody_0357
       or pair.defense_task_0259) then
  local ok,worked=pcall(expansion.service_station_expansion_assignment,pair)
  if not ok then
   pair.station_expansion_dispatch_failure_0820={
     tick=now(),reason=safe(worked),
     count=(pair.station_expansion_dispatch_failure_0820
       and pair.station_expansion_dispatch_failure_0820.count or 0)+1}
   record("station-expansion-error",pair,safe(worked))
   stat("failures")
   return {processed=1,failed=1,detail=safe(worked)}
  end
  if worked then
   local action={kind="station-expansion",
     reason="physical-ranked-resource-relay"}
   publish_action(pair,action,"station-expansion","acted",
     "one physical Cogitator construction assignment")
   stat("pairs_processed")
   stat("actions")
   return {processed=1,acted=1,detail="ranked-physical-expansion"}
  end
 end
 -- A verified 0837 courier reservation is a FUTURE-work barrier only.
 -- A busy priest must finish existing orders and physically held inventory,
 -- but an unladen priest must not immediately acquire a fresh routine order
 -- each time its prior duty finishes. Otherwise the ore courier can starve
 -- forever while the dispatcher continually assigns new bootstrap work.
 -- Never require the courier during on_tick: the control-stage loader or
 -- CI fixture must preload it before dispatch.
 local courier=rawget(_G,"TechPriestsResourceReturnCourier0837")
    or package.loaded["scripts.core.resource_return_courier_0837"]
 if courier and type(courier.worker_reserved)=="function" then
  local ok,reserved=pcall(courier.worker_reserved,pair)
  if not ok then
   record("ore-courier-reservation-error",pair,safe(reserved))
   stat("failures")
  elseif reserved==true and not (
      pair.active_task or pair.current_task or pair.emergency_craft
      or pair.active_acquisition_0333 or pair.direct_acquisition_task_0336
      or pair.inventory_transfer_custody_0687
      or pair.construction_task_0338 or pair.construction_task_0340
      or pair.construction_custody_0338
      or pair.direct_acquisition_custody_0513
      or pair.machine_logistics_custody_0528
      or pair.active_order_0469
      or (pair.order_queue_0469 and pair.order_queue_0469.current)
      or (pair.station_expansion_0256
          and pair.station_expansion_0256.status=="active")) then
   -- 1129: The Magos is ALSO the final reserved receiver in its own 0837
   -- route. The old future-work guard returned here BEFORE calling the
   -- existing resource-expansion owner below. Once the terminal finished its
   -- incumbent mining and became dormant, no one serviced the courier again.
   -- Preserve the future-work barrier, but allow only this exact ROOT's
   -- already-active physical resource mission to service its own courier.
   -- Do not invoke arbitrary orders, mine, create inventory or bypass any
   -- courier eligibility gate: 0259 -> 1011 -> 0837 remain sole authorities.
   local mission=pair.resource_expansion_0259
     and pair.resource_expansion_0259.chain_0820
   if mission and mission.status=="reached-resource"
       and mission.root_station_unit==pair.station.unit_number
       and mission.return_courier_0837
       and mission.return_courier_0837.phase~="magos-delivered"
       and type(_G.tech_priests_0259_resource_expansion_service)=="function" then
    local ok,progress=pcall(_G.tech_priests_0259_resource_expansion_service,pair)
    if not ok then
     record("ore-courier-root-service-error",pair,safe(progress))
     stat("failures")
     return {processed=1,failed=1,detail=safe(progress)}
    end
    local advanced=progress==true
    local result={processed=1,acted=advanced and 1 or 0,
      waiting=advanced and 0 or 1,
      detail="reserved-magos-physical-courier-owner-serviced"}
    publish_action(pair,{kind="idle",source="resource-return-courier-0837",
      reason="root-physical-courier-owner-service"},"idle",
      advanced and "acted" or "waiting",result.detail)
    record("ore-courier-root-service",pair,
      "existing reached-resource objective serviced without new orders")
    stat("pairs_processed")
    if advanced then stat("actions") end
    return result
   end
   local action={kind="idle",source="resource-return-courier-0837",
     reason="reserved-after-existing-duty"}
   publish_action(pair,action,"idle","waiting",
     "physical-ore-courier-awaiting-owner-service")
   record("ore-courier-yield-new-orders",pair,
     "existing-duty-finished; preserve future ore pickup")
   stat("pairs_processed")
   return {processed=1,waiting=1,
     detail="physical-ore-courier-awaiting-owner-service"}
  end
 end
 -- Discover ore shortages at the root Magos, at the historical 1200-tick
 -- planning cadence, rather than giving every junior an unrelated mission.
 if type(_G.tech_priests_0259_resource_expansion_service)=="function" then
  local ok,err=pcall(_G.tech_priests_0259_resource_expansion_service,pair)
  if not ok then
   record("resource-expansion-planner-error",pair,safe(err))
   stat("failures")
   return {processed=1,failed=1,detail=safe(err)}
  end
 end
 -- 1254: physical power construction gets one 0338 execution attempt
 -- BEFORE ordinary new orders, but never seizes incumbent assignments or
 -- real held cargo. 0338 remains the only source/debit/movement authority.
 local power=pair.structure_construction_requested_item
 if type(power)=="table" and power.owner=="power-setup-1252"
   and family_owned(r,"construction")
   and not(pair.active_task or pair.active_task_0285 or pair.current_task
     or pair.emergency_craft or pair.active_craft_0479
     or pair.active_order_0469
     or (pair.order_queue_0469 and pair.order_queue_0469.current)
     or pair.active_supply_request
     or pair.direct_acquisition_task_0336
     or pair.direct_acquisition_custody_0513
     or pair.machine_logistics_custody_0528
     or pair.construction_task_0338 or pair.construction_custody_0338
     or pair.construction_task_0340 or pair.inventory_transfer_custody_0687
     or pair.energy_family_custody_0707 or pair.item_family_custody_0702
     or pair.defense_task_0259
     or (pair.station_expansion_0256
       and pair.station_expansion_0256.status=="active")
     or pair.remote_drill_request_1011
     or pair.robot_network_task_0338 or pair.robot_network_request_0338
     or pair.construction_request)then
  local movement=pair.movement_request_0418
  local leased=movement
    and (tonumber(movement.expires_tick)or now())>=now()
  if not leased and not direct_active(pair)then
   local planner=rawget(_G,"TechPriestsConstructionPlanner0338")
     or package.loaded["scripts.core.construction_planner"]
   if planner and type(planner.discover_pair)=="function"then
    local ok,candidate=pcall(planner.discover_pair,pair,true)
    if ok and candidate and candidate.request_value==power then
     local result=execute(pair,"construction",
       "dispatcher-0510:funded-physical-power-1254")
     local status=result.failed>0 and"failed"
       or result.acted>0 and"acted"
       or result.blocked>0 and"blocked"
       or result.waiting>0 and"waiting"or"idle"
     publish_action(pair,{kind="construction",
       source="physical-power-setup-1252",
       item=power.item_name,position=power.position,
       reason="one-real-stored-power-item"},
       "construction",status,result.detail)
     stat("pairs_processed")
     stat("actions",result.acted)
     stat("failures",result.failed)
     record("dispatch-stocked-power-physical-builder",pair,result.detail)
     return result
    end
   end
  end
 end
 -- 1258: a funded, existing real 0691 steam pipe request gets ONE
 -- 0338 builder attempt before NEW routine orders, never before incumbent
 -- cargo, a moving priest, an active order or a started physical build.
 local pipe_request=pair.construction_request
 local fluid_plan=pair.standard_fluid_route_plan_0691
 if type(pipe_request)=="table"
    and pipe_request.source=="standard-fluid-route-0691"
    and pipe_request.item_name=="pipe"and pipe_request.entity_name=="pipe"
    and type(fluid_plan)=="table"
    and fluid_plan.id==pipe_request.route_plan_id
    and fluid_plan.state=="construction-requested"
    and family_owned(r,"construction")
    and not(pair.active_task or pair.active_task_0285 or pair.current_task
      or pair.emergency_craft or pair.active_craft_0479
      or pair.active_order_0469
      or (pair.order_queue_0469 and pair.order_queue_0469.current)
      or pair.active_supply_request or pair.direct_acquisition_task_0336
      or pair.direct_acquisition_custody_0513
      or pair.machine_logistics_custody_0528
      or pair.construction_task_0338 or pair.construction_custody_0338
      or pair.construction_task_0340 or pair.inventory_transfer_custody_0687
      or pair.energy_family_custody_0707 or pair.item_family_custody_0702
      or pair.defense_task_0259
      or (pair.station_expansion_0256
        and pair.station_expansion_0256.status=="active")
      or pair.remote_drill_request_1011
      or pair.robot_network_task_0338 or pair.robot_network_request_0338
      or pair.structure_construction_requested_item)then
   local movement=pair.movement_request_0418
   local leased=movement
     and (tonumber(movement.expires_tick)or now())>=now()
   if not leased and not direct_active(pair)then
    local planner=rawget(_G,"TechPriestsConstructionPlanner0338")
      or package.loaded["scripts.core.construction_planner"]
    if planner and type(planner.discover_pair)=="function"then
     local ok,candidate=pcall(planner.discover_pair,pair,true)
     if ok and candidate and candidate.request_value==pipe_request then
      local result=execute(pair,"construction",
        "dispatcher-0510:funded-real-fluid-pipe-1258")
      local status=result.failed>0 and"failed"
        or result.acted>0 and"acted"
        or result.blocked>0 and"blocked"
        or result.waiting>0 and"waiting"or"idle"
      publish_action(pair,{kind="construction",
        source="standard-fluid-route-0691",item="pipe",
        position=pipe_request.position,
        reason="counted-native-pipe-prerequisite"},
        "construction",status,result.detail)
      stat("pairs_processed");stat("actions",result.acted)
      stat("failures",result.failed)
      record("dispatch-stocked-steam-pipe-builder",pair,result.detail)
      return result
     end
    end
   end
 end
 -- Only issue routine orders after defense/expansion can take a free priest.
 order_tick(pair)
 local craft=pair.emergency_craft
 if (type(craft)=="table" and craft.strict_recipe_0647==true)
   or direct_active(pair) then
  local logistics=rawget(_G,"TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
   or package.loaded["scripts.core.logistics_machine_fulfillment_0528"]
  if logistics and type(logistics.yield_for_bootstrap)=="function" then
   pcall(logistics.yield_for_bootstrap,pair,"dispatcher-bootstrap-prerequisite-0510")
  end
 end
 local action=classifier(pair);local family=family_for(pair,action);publish_action(pair,action,family,"selected",reason or action.reason)
 relinquish_unladen_direct_movement(pair,family)
 if type(_G.tech_priests_0507_action_claim)=="function"then pcall(_G.tech_priests_0507_action_claim,pair,family,"single-dispatcher_0510",action.reason or reason or"service")end
 local selected=family_owned(r,family)and execute(pair,family,"dispatcher-0510:"..safe(reason))or{processed=1,waiting=family~="idle"and 1 or 0,detail=family=="idle"and"idle"or"compatibility-leaf-family"};local execution=normalize_execution(selected)
 local status=execution.failed>0 and"failed"or execution.acted>0 and"acted"or execution.blocked>0 and"blocked"or execution.waiting>0 and"waiting"or"idle";publish_action(pair,action,family,status,execution.detail);if status~="idle"then record("dispatch-"..family,pair,status.." "..safe(execution.detail))end;stat("pairs_processed");stat("actions",execution.acted);stat("failures",execution.failed);return execution
end
function M.service_all(reason,budget)
 local r=root();if r.enabled==false then return{processed=0,acted=0,detail="disabled"}end;local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end;table.sort(list,function(a,b)return a.key<b.key end);if #list==0 then return{processed=0,acted=0,detail="no-pairs"}end
 local limit=math.max(1,math.min(#list,math.floor(tonumber(budget)or M.max_pairs_per_pulse)));local start=r.cursor%#list+1;local aggregate={processed=0,acted=0,blocked=0,waiting=0,failed=0,exhausted=#list>limit};r.dispatching=true
 for i=0,limit-1 do local pair=list[((start+i-1)%#list)+1].pair;local ok,out=pcall(M.service_pair,pair,reason or"broker");aggregate.processed=aggregate.processed+1;if ok and type(out)=="table"then for _,key in ipairs{"acted","blocked","waiting","failed"}do aggregate[key]=aggregate[key]+(tonumber(out[key])or 0)end else aggregate.failed=aggregate.failed+1;record("dispatcher-error",pair,ok and"invalid-result"or out)end end
 r.dispatching=false;r.cursor=(start+limit-2)%#list+1;aggregate.detail="pairs="..aggregate.processed.." acted="..aggregate.acted.." failed="..aggregate.failed;return aggregate
end
function M.should_gate_legacy(pair)local r=root();if r.enabled==false or r.gate_legacy_tick==false or not valid_pair(pair)then return false end;local d=pair.dispatcher_0510;return d and now()-(tonumber(d.tick)or-1000000)<=M.legacy_gate_window and d.gates_legacy==true end
local function wrap_legacy_tick_pair()if type(_G.tick_pair)~="function"or rawget(_G,"TECH_PRIESTS_0510_PRE_TICK_PAIR")then return true end;_G.TECH_PRIESTS_0510_PRE_TICK_PAIR=_G.tick_pair;_G.tick_pair=function(pair,...)if M.should_gate_legacy(pair)then stat("legacy-tick-gated");return true end;return _G.TECH_PRIESTS_0510_PRE_TICK_PAIR(pair,...)end;return true end
local function wrap_executor_pulses()
 local ok_a,acquisition=pcall(require,"scripts.core.acquisition_executor");if ok_a and acquisition and type(acquisition.pulse)=="function"and not acquisition.dispatcher_0510_pulse_wrapped then acquisition.dispatcher_0510_pulse_wrapped=true;acquisition.TECH_PRIESTS_0510_PRE_PULSE=acquisition.pulse;acquisition.pulse=function(reason)local r=root();local text=tostring(reason or"");if r.enabled~=false and r.suppress_independent_executor_pulses~=false and not r.dispatching and not text:find("manual",1,true)and not text:find("kick",1,true)and not text:find("dispatcher%-0510")then stat("independent-direct-pulse-suppressed");return false end;return acquisition.TECH_PRIESTS_0510_PRE_PULSE(reason)end end
 local ok_c,craft=pcall(require,"scripts.core.crafting_executor");if ok_c and craft and type(craft.pulse)=="function"and not craft.dispatcher_0510_pulse_wrapped then craft.dispatcher_0510_pulse_wrapped=true;craft.TECH_PRIESTS_0510_PRE_PULSE=craft.pulse;craft.pulse=function(...)local r=root();if r.enabled~=false and r.suppress_independent_executor_pulses~=false and not r.dispatching then stat("independent-craft-pulse-suppressed");return false end;return craft.TECH_PRIESTS_0510_PRE_PULSE(...)end end
end
local function wrap_diagnostics()local d=rawget(_G,"TechPriestsEmergencyDiagnostics0468")or rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468");if not(d and type(d.pair_dump_lines)=="function")or d.single_dispatcher_0510_wrapped then return false end;d.single_dispatcher_0510_wrapped=true;local previous=d.pair_dump_lines;d.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local r=root();lines[#lines+1]="PAIR-DUMP-0468 SINGLE-DISPATCHER-0510 version="..M.version.." processed="..safe(r.stats.pairs_processed or 0).." actions="..safe(r.stats.actions or 0).." failures="..safe(r.stats.failures or 0).." legacy_gated="..safe(r.stats["legacy-tick-gated"]or 0);return lines end;return true end
function M.install()
 root();wrap_executor_pulses();wrap_legacy_tick_pair();wrap_diagnostics();if commands and commands.remove_command then pcall(commands.remove_command,"tp-dispatcher-0510")end
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or package.loaded["scripts.core.runtime_tick_broker"];if not broker then local ok,loaded=pcall(require,"scripts.core.runtime_tick_broker");if ok then broker=loaded end end
 if not(broker and type(broker.install)=="function"and type(broker.register_service)=="function")then return false end;local ok,installed=pcall(broker.install);if not(ok and installed==true)then return false end
 local service=broker.register_service({name="single_dispatcher_0510",category="dispatcher",interval=M.tick_interval,priority=20,budget=M.max_pairs_per_pulse,note="canonical per-pair action and executor owner",fn=function(_,budget)return M.service_all("broker-0510",budget)end});_G.TechPriestsSingleDispatcher0510=M;if log then log("[Tech-Priests recovery] canonical dispatcher installed; construction, artillery, and roboport aware")end;return service~=nil
end
return M
