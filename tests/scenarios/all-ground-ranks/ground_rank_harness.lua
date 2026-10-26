-- CI-only ground-rank recovery test, executed INSIDE the Tech-Priests mod.
-- No secondary mod, no shared cross-mod storage and no fabricated machines.
-- Copied into an isolated test installation, never packaged for players.
local M={}
-- Enabled only by the separate CI headless-server installation.
-- The uninterrupted 108,600-tick benchmark remains unchanged.
local SAVE_RELOAD_SMOKE=rawget(_G,"TP_CI_SAVE_RELOAD_SMOKE")==true
local LATE_COMBAT_SMOKE=rawget(_G,"TP_CI_LATE_COMBAT")==true
-- Factorio forbids require() during on_tick/service callbacks. Load the cargo
-- API only while control.lua is parsed, before the CI broker is registered.
local CARGO_ENGINE_0824=SAVE_RELOAD_SMOKE and require("scripts.core.station_cargo_0824") or nil
local ORE_ENGINE_CHAIN=SAVE_RELOAD_SMOKE and require("scripts.core.resource_station_chain_0820") or nil
local REVERSAL_ENGINE_0850=SAVE_RELOAD_SMOKE and require("scripts.core.station_starvation_reversal_0850") or nil
local REVERSAL_DEPOT_0852=SAVE_RELOAD_SMOKE and require("scripts.core.station_starvation_depot_0852") or nil
local REVERSAL_SENIOR_0855=SAVE_RELOAD_SMOKE and require("scripts.core.station_starvation_senior_0855") or nil
local ORE_ENGINE_COURIER=SAVE_RELOAD_SMOKE and require("scripts.core.resource_return_courier_0837") or nil
local stations={
  {name="junior-cogitator-station",x=0,y=0},
  {name="intermediate-cogitator-station",x=64,y=0},
  {name="senior-cogitator-station",x=128,y=0},
  {name="planetary-magos-cogitator-station",x=192,y=0},
}
local solid_resources={"iron-ore","copper-ore","coal","stone","uranium-ore"}
local function emit(message) log("[TP-GROUND-RANK-TEST] "..message) end
local function fail(message) error("[TP-GROUND-RANK-TEST] "..message) end

local function clear_fixture_area(surface)
  -- Make the playable test area independent of random terrain/resources.
  -- Never remove characters or entities outside the reserved rectangle.
  local area={{-28,-36},{220,40}}
  for _,e in pairs(surface.find_entities_filtered{area=area}) do
    if e.valid and (e.type=="resource" or e.type=="tree" or
       e.type=="simple-entity" or e.type=="cliff") then e.destroy() end
  end
end

local function create_patch(surface,name,cx,cy)
  if not prototypes.entity[name] then fail("Missing base resource prototype: "..name) end
  local count=0
  for dx=-2,2 do for dy=-2,2 do
    local pos={x=cx+dx,y=cy+dy}
    if surface.can_place_entity{name=name,position=pos} then
      local e=surface.create_entity{name=name,position=pos,amount=10000}
      if e and e.valid then count=count+1 end
    end
  end end
  if count~=25 then fail("Incomplete or obstructed resource patch: "..name.." tiles="..count.."/25") end
  emit("resource "..name.." tiles="..count)
end

local function setup_fixture()
  local surface=game.surfaces[1]
  local force=game.forces.player
  for _,s in ipairs(stations) do
    if not prototypes.entity[s.name] then fail("Missing station prototype: "..s.name) end
    surface.request_to_generate_chunks({x=s.x,y=s.y},2)
  end
  surface.force_generate_chunk_requests()
  clear_fixture_area(surface)
  -- Flatten the fixture into deterministic buildable terrain, including water.
  local tiles={}
  for x=-28,220 do for y=-36,40 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  for _,s in ipairs(stations) do
    local pos={x=s.x,y=s.y}
    local station=surface.create_entity{name=s.name,position=pos,force=force,raise_built=true}
    if not (station and station.valid) then fail("Unable to place "..s.name) end
    emit("placed "..s.name.." unit="..tostring(station.unit_number))
    local on_build_pair=storage.tech_priests and storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[station.unit_number]
    emit("INITIAL_PAIR station="..s.name.." force="..station.force.name..
      " paired="..tostring(on_build_pair~=nil)..
      " priest="..tostring(on_build_pair and on_build_pair.priest and on_build_pair.priest.valid or false))
    -- Each rank receives its own complete set of vanilla solid resources.
    for i,name in ipairs(solid_resources) do
      create_patch(surface,name,s.x-10+(i-1)*5,s.y-13)
    end
    if not prototypes.entity["crude-oil"] then fail("Missing crude-oil prototype") end
    local oilpos={x=s.x+9,y=s.y+12}
    if not surface.can_place_entity{name="crude-oil",position=oilpos} then
      fail("Crude oil location blocked near "..s.name)
    end
    local oil=surface.create_entity{name="crude-oil",position=oilpos,amount=100000}
    if not (oil and oil.valid) then fail("Could not create crude oil near "..s.name) end
    emit("resource crude-oil near "..s.name)
    -- Fail closed on accidental overlap with any station or unrelated structure.
    local patches={}
    for i,name in ipairs(solid_resources) do
      local cx=s.x-10+(i-1)*5
      local cy=s.y-13
      local resources=surface.find_entities_filtered{
        name=name,area={{cx-2.5,cy-2.5},{cx+2.5,cy+2.5}}
      }
      if #resources~=25 then fail("Patch inventory mismatch "..name.." near "..s.name) end
      for _,resource in ipairs(resources) do
        local p=resource.position
        for _,station_spec in ipairs(stations) do
          if math.abs(p.x-station_spec.x)<6 and math.abs(p.y-station_spec.y)<6 then
            fail("Resource intersects station exclusion zone: "..name)
          end
        end
        local blockers=surface.find_entities_filtered{
          position=p,radius=0.3,type={"assembling-machine","furnace","mining-drill","container","electric-pole"}
        }
        if #blockers>0 then fail("Structure overlaps resource "..name.." near "..s.name) end
      end
      patches[#patches+1]=name
    end
    emit("CLEAR resource placement near "..s.name.." types="..#patches+1)
  end
end

-- Four simultaneous startup conditions under the same force:
-- junior = empty control; intermediate = packaged machine items in its
-- Cogitator storage; senior = two already-placed machines plus a packaged
-- assembler; Magos = full prebuilt miner/smelter/workshop spine.
-- These are real Factorio items/entities granted ONLY to the isolated CI map.
-- No technologies, production counters, recipes, or task flags are modified.
local PRESTOCK_SPINE={
  "tech-priests-emergency-miner",
  "tech-priests-emergency-smelter",
  "tech-priests-emergency-assembler",
}
local PRESTOCK_MODES={
  ["junior-cogitator-station"]="empty-control",
  ["intermediate-cogitator-station"]="stored-machinery",
  ["senior-cogitator-station"]="mixed-machinery",
  ["planetary-magos-cogitator-station"]="prebuilt-machinery",
}
local function prestock_station(spec)
  return game.surfaces[1].find_entities_filtered{
    name=spec.name,position={spec.x,spec.y},radius=2,
    force=game.forces.player}[1]
end
local function prestock_count(surface,station,name)
  return #surface.find_entities_filtered{
    name=name,position=station.position,radius=22,force=station.force}
end
local function prestock_place(surface,station,name)
  if not prototypes.entity[name] then
    fail("PRESTOCK missing physical entity prototype "..name)
  end
  local offsets={{-12,9},{-7,9},{-2,9},{4,9},{10,8},
    {-12,4},{-7,4},{1,10},{10,3},{-13,14}}
  for _,offset in ipairs(offsets) do
    local p={x=station.position.x+offset[1],y=station.position.y+offset[2]}
    if surface.can_place_entity{name=name,position=p,force=station.force} then
      local entity=surface.create_entity{
        name=name,position=p,force=station.force,raise_built=true}
      if entity and entity.valid then return entity end
    end
  end
  fail("PRESTOCK could not physically place "..name..
    " near "..station.name)
end
local function prestock_fixture(state)
  local surface=game.surfaces[1]
  state.prestock={}
  state.prestock_ready={}
  for _,spec in ipairs(stations) do
    local station=prestock_station(spec)
    if not (station and station.valid) then
      fail("PRESTOCK missing station "..spec.name)
    end
    local mode=PRESTOCK_MODES[spec.name]
    local record={mode=mode,station_unit=station.unit_number,
      initial_entities={},prestock_items={}}
    local held=station.get_inventory(defines.inventory.chest)
    if mode~="empty-control" then
      local built=mode=="prebuilt-machinery" and 3
        or mode=="mixed-machinery" and 2 or 0
      for i,name in ipairs(PRESTOCK_SPINE) do
        if i<=built then
          local machine=prestock_place(surface,station,name)
          record.initial_entities[name]=machine.unit_number
        else
          if not (held and held.valid) then
            fail("PRESTOCK no general station inventory for "..spec.name)
          end
          local inserted=held.insert{name=name,count=1}
          if inserted~=1 then
            fail("PRESTOCK insertion refused for "..name..
              " near "..spec.name)
          end
          record.prestock_items[name]=1
        end
      end
    end
    state.prestock[spec.name]=record
    if mode=="prebuilt-machinery" then
      state.prestock_ready[spec.name]=0
    end
    emit("PRESTOCK_SETUP rank="..spec.name.." mode="..mode..
      " already_built="..tostring(
        (mode=="prebuilt-machinery" and 3)
        or (mode=="mixed-machinery" and 2) or 0)..
      " packaged="..tostring(
        (mode=="stored-machinery" and 3)
        or (mode=="mixed-machinery" and 1) or 0))
  end
end
local function prestock_checkpoint(state,elapsed)
  local surface=game.surfaces[1]
  local tp=storage and storage.tech_priests or {}
  local facility=tp.emergency_facility_doctrine_0343 or {}
  local governor=rawget(_G,"TechPriestsInfrastructureFirstGovernor0640")
  for _,spec in ipairs(stations) do
    local record=state.prestock and state.prestock[spec.name]
    local station=prestock_station(spec)
    if not (record and station and station.valid) then
      fail("PRESTOCK checkpoint lost station "..spec.name)
    end
    local pair=tp.pairs_by_station and tp.pairs_by_station[station.unit_number]
    local status="governor-unavailable"
    if pair and governor and type(governor.status_for_pair)=="function" then
      local ok,report=pcall(governor.status_for_pair,pair)
      if ok then status=tostring(report) end
    end
    local held=station.get_inventory(defines.inventory.chest)
    local built_total,packaged_total,owned_total=0,0,0
    local details={}
    for _,name in ipairs(PRESTOCK_SPINE) do
      local present=prestock_count(surface,station,name)
      local packaged=held and held.valid and held.get_item_count(name) or 0
      built_total=built_total+present
      packaged_total=packaged_total+packaged
      if present>1 then
        fail("PRESTOCK_DUPLICATE rank="..spec.name.." machine="..name..
          " count="..present.." elapsed="..elapsed)
      end
      local initial=record.initial_entities[name]
      if initial then
        local entities=surface.find_entities_filtered{
          name=name,position=station.position,radius=22,force=station.force}
        if #entities~=1 or entities[1].unit_number~=initial then
          fail("PRESTOCK_REPLACED rank="..spec.name.." machine="..name)
        end
      end
      local owned=false
      for key in pairs(facility.by_station and
          facility.by_station[station.unit_number] or {}) do
        local rec=facility.facilities and facility.facilities[key]
        if rec and rec.name==name and rec.entity and rec.entity.valid
            and rec.entity.force==station.force
            and rec.entity.surface==station.surface then
          owned=true
          break
        end
      end
      if owned then owned_total=owned_total+1 end
      details[#details+1]=name..":"..present.."/"..packaged..
        "/owned="..tostring(owned)
    end
    if built_total==3 and owned_total==3 then
      state.prestock_ready=state.prestock_ready or {}
      if state.prestock_ready[spec.name]==nil then
        state.prestock_ready[spec.name]=elapsed
      end
    end
    emit("PRESTOCK_CHECKPOINT rank="..spec.name..
      " mode="..record.mode.." elapsed="..elapsed..
      " built="..built_total.." packaged="..packaged_total..
      " owned="..owned_total.." machines="..table.concat(details,",")..
      " governor="..status)
    if elapsed>=900 and record.mode=="prebuilt-machinery" then
      if built_total~=3 or owned_total~=3 then
        fail("PRESTOCK_NOT_RECOGNIZED rank="..spec.name..
          " built="..built_total.." owned="..owned_total)
      end
      for _,name in ipairs(PRESTOCK_SPINE) do
        if status:find("needed="..name,1,true) then
          fail("PRESTOCK_BOOTSTRAP_NOT_SKIPPED rank="..spec.name..
            " duplicate_request="..name)
        end
      end
    end
    if elapsed>=36000 and record.mode=="stored-machinery"
        and built_total==0 then
      fail("PRESTOCK_INVENTORY_NOT_DEPLOYED rank="..spec.name..
        " packaged="..packaged_total)
    end
    if elapsed>=108000 and record.mode~="empty-control"
        and (built_total~=3 or packaged_total~=0 or owned_total~=3) then
      fail("PRESTOCK_SPINE_INCOMPLETE rank="..spec.name..
        " built="..built_total.." stored="..packaged_total..
        " owned="..owned_total)
    end
  end
  if elapsed>=108000 then
    for _,spec in ipairs(stations) do
      local record=state.prestock[spec.name]
      emit("PRESTOCK_OUTCOME rank="..spec.name..
        " mode="..record.mode..
        " first_sampled_ready_tick="..tostring(
          state.prestock_ready and state.prestock_ready[spec.name] or "not-ready"))
    end
  end
end

local function verify_pairs()
  local surface=game.surfaces[1]
  local tp=storage.tech_priests
  if not (tp and tp.pairs_by_station) then fail("Tech-Priests pair registry unavailable") end
  local paired=0
  for _,s in ipairs(stations) do
    local station=surface.find_entities_filtered{
      name=s.name,position={s.x,s.y},radius=2,force=game.forces.player
    }[1]
    if not (station and station.valid) then fail("Station missing: "..s.name) end
    local pair=tp.pairs_by_station[station.unit_number]
    if not (pair and pair.priest and pair.priest.valid) then
      fail("Station lacks living priest: "..s.name)
    end
    paired=paired+1
  end
  emit("PASS ground ranks with live pairs="..paired.." tick="..game.tick)
end

local function verify_recovery()
  local tp=storage.tech_priests
  local bridge=tp and tp.emergency_facility_placement_bridge_0643
  if not bridge then fail("Recovery bridge storage unavailable by tick "..game.tick) end
  if not bridge.last_assessment_tick then fail("Recovery assessment never executed") end
  local reports, reservations=0,0
  for key,report in pairs(bridge.assessments or {}) do
    reports=reports+1
    if not report.tick or type(report.deficits)~="table" or type(report.capacity)~="table" then
      fail("Malformed recovery assessment for network "..tostring(key))
    end
    for _,need in ipairs(report.needs or {}) do
      if need.missing<=0 then fail("Nonpositive reported deficit "..tostring(need.item)) end
    end
  end
  for id,reservation in pairs(bridge.reservations or {}) do
    reservations=reservations+1
    if not reservation.network or not reservation.stage or not reservation.station_unit then
      fail("Malformed recovery reservation "..tostring(id))
    end
    if reservation.status=="construction-requested" or reservation.status=="awaiting-construction" then
      local pair=tp.pairs_by_station[reservation.station_unit]
      local rec=pair and pair.construction_bootstrap_ghost_0645
      if not (rec and rec.entity_name==reservation.entity and rec.ghost and rec.ghost.valid) then
        fail("Recovery reservation lacks matching live ghost "..tostring(id))
      end
    end
  end
  if reports==0 then fail("No recovery network assessments") end
  emit("PASS recovery assessments="..reports.." reservations="..reservations..
    " tick="..game.tick)
end

local function count_operational_industry(surface)
  local counts={drills=0,furnaces=0,assemblers=0,labs=0}
  for _,e in pairs(surface.find_entities_filtered{force=game.forces.player,
      type={"mining-drill","furnace","assembling-machine","lab"}}) do
    if e.valid and e.name~="entity-ghost" then
      -- The genuine Tech-Priests micro-miner runs mining recipes on an
      -- assembling-machine prototype. Count it as a miner, never an assembler.
      if e.type=="mining-drill" or e.name=="tech-priests-emergency-miner" then
        counts.drills=counts.drills+1
      elseif e.type=="furnace" then counts.furnaces=counts.furnaces+1
      elseif e.type=="assembling-machine" then counts.assemblers=counts.assemblers+1
      elseif e.type=="lab" then counts.labs=counts.labs+1 end
    end
  end
  return counts
end

local function emit_industry()
  local surface=game.surfaces[1]
  local counts=count_operational_industry(surface)
  local force=game.forces.player
  local research=force.current_research
  local progress=force.research_progress or 0
  emit("ENDURANCE tick="..game.tick.." drills="..counts.drills..
    " furnaces="..counts.furnaces.." assemblers="..counts.assemblers..
    " labs="..counts.labs.." research="..(research and research.name or "none")..
    " progress="..progress)
end

-- Read-only bootstrap evidence: actual ore depletion, station custody,
-- attempted direct acquisition/crafting, gate state, and reservation blockers.
-- No resources, technology, tasks or entities are granted by this probe.
local function bootstrap_probe()
  local tp=storage and storage.tech_priests or {}
  local bootstrap=tp.bootstrap_resource_governor_0637 or {}
  local direct=tp.direct_acquisition_executor_0513 or {}
  local production=tp.emergency_production_executor_0514 or {}
  emit("BOOTSTRAP_GATE tick="..game.tick..
    " raw_governor_enabled="..tostring(bootstrap.enabled)..
    " raw_assigned="..tostring(bootstrap.stats and bootstrap.stats["bootstrap-assigned-direct-0637"] or 0)..
    " acquired="..tostring(direct.stats and direct.stats["physical-custody-acquired-0513"] or 0)..
    " deposited="..tostring(direct.stats and direct.stats["custody-deposited-0513"] or 0)..
    " crafted="..tostring(production.stats and production.stats.strict_transactions_started or 0))
  local machine=tp.logistics_machine_fulfillment_0528 or {}
  local facilities=tp.emergency_facility_doctrine_0343 or {}
  emit("COAL_FLOW tick="..game.tick..
    " coal_extracted="..tostring(direct.stats and direct.stats["extracted-item:coal"] or 0)..
    " coal_deposited="..tostring(direct.stats and direct.stats["deposited-item:coal"] or 0)..
    " machine_coal_fed="..tostring(machine.stats and machine.stats["fuel-fed:coal"] or 0)..
    " emergency_coal_fed="..tostring(facilities.stats and facilities.stats["fuel-fed:coal"] or 0)..
    " machine_stock_removed="..tostring(machine.stats and machine.stats.station_items_removed or 0)..
    " facility_feeding="..tostring(facilities.stats and facilities.stats.used or 0))
  emit("ELECTRONICS_OUTPUT_FLOW tick="..game.tick..
    " observed="..tostring(machine.stats
      and machine.stats["electronics-output-observed-0528"] or 0)..
    " excluded_as_automated="..tostring(machine.stats
      and machine.stats["electronics-output-automated-excluded-0528"] or 0)..
    " selected="..tostring(machine.stats
      and machine.stats["electronics-output-selected-0528"] or 0)..
    " removed="..tostring(machine.stats
      and machine.stats.machine_output_removed or 0)..
    " deposited="..tostring(machine.stats
      and machine.stats["output-complete"] or 0)..
    " abandoned="..tostring(machine.stats
      and machine.stats.bootstrap_machine_yields or 0))
  local dispatcher=tp.single_dispatcher_0510 or {}
  local constructor=tp.construction_planner or {}
  local broker=tp.runtime_tick_broker_0600 or {}
  local function stat_summary(values)
    local out={}
    for k,v in pairs(values or {}) do
      if type(v)=="number" and v>0 then out[#out+1]=tostring(k).."="..tostring(v) end
    end
    table.sort(out)
    return table.concat(out,",")
  end
  local broker_module=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  local registered=broker_module and broker_module.services or {}
  local dispatcher_registered=false
  for _,service in ipairs(registered) do
    if service.name=="single_dispatcher_0510" then dispatcher_registered=true end
  end
  local dispatch_runtime=broker.service_stats and broker.service_stats.single_dispatcher_0510 or {}
  emit("DISPATCHER_TRACE tick="..game.tick..
    " installed="..tostring(dispatcher.enabled)..
    " dispatcher_stats="..stat_summary(dispatcher.stats)..
    " construction_stats="..stat_summary(constructor.stats)..
    " broker_enabled="..tostring(broker.enabled)..
    " broker_services="..tostring(#registered)..
    " dispatcher_registered="..tostring(dispatcher_registered)..
    " dispatch_service_stats="..stat_summary(dispatch_runtime)..
    " dispatch_last="..tostring(dispatch_runtime.last_result and dispatch_runtime.last_result.detail))
  local movement=tp.movement_controller_0419 or {}
  local movement_stats=movement.stats or {}
  emit("WAYPOINT_RECOVERY tick="..game.tick..
    " teleports="..tostring(movement_stats.waypoint_recovery_teleports or 0)..
    " wrong_direction="..tostring(movement_stats["waypoint_recovery_wrong-direction"] or 0)..
    " wrong_position="..tostring(movement_stats["waypoint_recovery_wrong-position"] or 0)..
    " stalled="..tostring(movement_stats["waypoint_recovery_stalled-off-target"] or 0)..
    " blocked="..tostring(movement_stats.waypoint_recovery_blocked or 0)..
    " completed_route_handoffs="..tostring(movement_stats.completed_route_handoffs or 0)..
    " rejected_destinations_preserved="..tostring(movement_stats.rejected_destinations_preserved_routes or 0))
  local conflict_sources={}
  for signature,count in pairs(movement.priority_denials_by_requester or {}) do
    conflict_sources[#conflict_sources+1]={ signature=signature, count=count }
  end
  table.sort(conflict_sources,function(a,b)
    if a.count~=b.count then return a.count>b.count end
    return a.signature<b.signature
  end)
  local top_conflicts={}
  for i=1,math.min(#conflict_sources,8) do
    local entry=conflict_sources[i]
    top_conflicts[#top_conflicts+1]=entry.signature..":"..entry.count
  end
  local hold_sources={}
  for signature,count in pairs(movement.retarget_holds_by_requester or {}) do
    hold_sources[#hold_sources+1]={signature=signature,count=count}
  end
  table.sort(hold_sources,function(a,b)
    if a.count~=b.count then return a.count>b.count end
    return a.signature<b.signature
  end)
  local top_holds={}
  for i=1,math.min(#hold_sources,8) do
    local entry=hold_sources[i]
    top_holds[#top_holds+1]=entry.signature..":"..entry.count
  end
  local direct_runtime=tp.direct_acquisition_executor_0513 or {}
  local contract=tp.behavior_contracts_0479 or {}
  local observer=contract.stats or {}
  emit("MOVEMENT_ARBITRATION tick="..game.tick..
    " denied="..tostring(movement_stats.lower_priority_retargets_denied or 0)..
    " retarget_held="..tostring(movement_stats.retargets_held or 0)..
    " lease_held="..tostring(movement_stats.lease_retargets_held or 0)..
    " observer_delegated="..tostring(observer.movement_delegated_to_owner or 0)..
    " direct_delegated="..tostring(observer.movement_delegated_to_direct_executor or 0)..
    " observer_duplicates="..tostring(observer.duplicate_movement_skipped or 0)..
    " observer_fallback_requests="..tostring(observer.fallback_move_requests or 0)..
    " completed_construction_releases="..tostring(constructor.stats and constructor.stats.terminal_movement_released or 0)..
    " orphan_construction_releases="..tostring(movement_stats.orphaned_construction_routes_released or 0)..
    " direct_machine_route_yields="..tostring(direct_runtime.stats and direct_runtime.stats["machine-route-yields-0513"] or 0)..
    " machine_phase_handoffs="..tostring(movement_stats.machine_phase_route_handoffs or 0)..
    " top_conflicts="..table.concat(top_conflicts,";")..
    " top_holds="..table.concat(top_holds,";"))
  if (tonumber(dispatch_runtime.errors) or 0)>0 then
    for i=#(broker.recent or {}),1,-1 do
      local event=broker.recent[i]
      if event.service=="single_dispatcher_0510" and event.action=="error" then
        emit("DISPATCHER_ERROR tick="..game.tick..
          " detail="..tostring(event.detail))
        break
      end
    end
  end
  local bridge=tp.emergency_facility_placement_bridge_0643 or {}
  local ids={}
  for id in pairs(bridge.reservations or {}) do ids[#ids+1]=id end
  table.sort(ids)
  for _,id in ipairs(ids) do
    local r=bridge.reservations[id]
    local mat=r.material
    emit("RESERVATION id="..tostring(id).." entity="..tostring(r.entity)..
      " status="..tostring(r.status)..
      " blocker="..tostring(r.blocker or r.material_error)..
      " item="..tostring(mat and mat.item)..
      " available="..tostring(mat and mat.available or 0))
  end
  for _,spec in ipairs(stations) do
    local entity=game.surfaces[1].find_entities_filtered{
      name=spec.name, position={spec.x,spec.y},radius=2,force=game.forces.player
    }[1]
    local pair=entity and tp.pairs_by_station and tp.pairs_by_station[entity.unit_number]
    if pair then
      local inv=nil
      if defines and defines.inventory and defines.inventory.chest then
        local ok,found=pcall(function() return entity.get_inventory(defines.inventory.chest) end)
        if ok and found and found.valid then inv=found end
      end
      local function stock(item) return inv and inv.get_item_count(item) or 0 end
      local resources=game.surfaces[1].find_entities_filtered{
        position={spec.x-10,spec.y-13},radius=3,name="iron-ore"
      }
      local amount=0
      for _,ore in pairs(resources) do if ore.valid then amount=amount+(ore.amount or 0) end end
      local gate=pair.local_infrastructure_gate_0640 or {}
      local task=pair.direct_acquisition_task_0336 or pair.emergency_craft or {}
      local current=task.current or task
      local planner=pair.construction_bootstrap_ghost_0645 or {}
      emit("PRIEST_BOOTSTRAP rank="..spec.name..
        " mode="..tostring(pair.mode)..
        " iron_ore_stock="..stock("iron-ore")..
        " coal_stock="..stock("coal")..
        " iron_patch_amount="..amount..
        " plate_stock="..stock("iron-plate")..
        " stone_stock="..stock("stone")..
        " emergency_smelter_item="..stock("tech-priests-emergency-smelter")..
        " emergency_miner_item="..stock("tech-priests-emergency-miner")..
        " emergency_assembler_item="..stock("tech-priests-emergency-assembler")..
        " drill_stock="..stock("burner-mining-drill")..
        " furnace_stock="..stock("stone-furnace")..
        " assembler_stock="..stock("assembling-machine-1")..
        " gate="..tostring(gate.state)..":"..tostring(gate.item)..
        " needed="..tostring(pair.infrastructure_recipe_request_0647 and pair.infrastructure_recipe_request_0647.missing)..
        " direct="..tostring(pair.dispatcher_direct_0513 and pair.dispatcher_direct_0513.phase)..
        " craft="..tostring(pair.dispatcher_emergency_production_0514 and pair.dispatcher_emergency_production_0514.phase)..
        " target="..tostring(current.output_item or current.item_name)..
        " ghost="..tostring(planner.entity_name)..":"..tostring(planner.status)..
        " ghost_blocker="..tostring(planner.blocker)..
        " craft_task="..tostring(pair.emergency_craft and pair.emergency_craft.output_item)..
        " strict_recipe="..tostring(pair.emergency_craft and pair.emergency_craft.strict_recipe_0647)..
        " craft_due="..tostring(pair.emergency_craft and pair.emergency_craft.craft_due_tick_0514)..
        " facility_start="..tostring(pair.emergency_craft and pair.emergency_craft.facility_started_tick_0514)..
        " order="..tostring(pair.order_queue_0469 and pair.order_queue_0469.current and pair.order_queue_0469.current.kind)..
        ":"..tostring(pair.order_queue_0469 and pair.order_queue_0469.current and pair.order_queue_0469.current.status)..
        " gate_why="..tostring(gate.why)..
        " dispatcher_family="..tostring(pair.dispatcher_0510 and pair.dispatcher_0510.family)..
        " recipe_machine_custody="..tostring(pair.machine_logistics_0528 and pair.machine_logistics_0528.custody and pair.machine_logistics_0528.custody.item)..
        " machine_state="..tostring(pair.machine_logistics_0528 and pair.machine_logistics_0528.phase)..
        " machine_custody="..tostring(pair.machine_logistics_custody_0528 and pair.machine_logistics_custody_0528.item)..
        " order_crafting="..tostring(pair.station_crafting_task_0337 and pair.station_crafting_task_0337.item_name)..
        " craft_current="..tostring(pair.emergency_craft and pair.emergency_craft.current and pair.emergency_craft.current.kind)..
        " dispatcher_action="..tostring(pair.dispatcher_action)..
        " dispatcher_phase="..tostring(pair.dispatcher_phase)..
        " construction_candidate="..tostring(pair.construction_candidate_0338 and pair.construction_candidate_0338.entity_name)..
        " construction_task="..tostring(pair.construction_task_0338 and pair.construction_task_0338.phase)..
        " construction_blocked="..tostring(pair.construction_blocked_reason_0338)..
        " construction_last="..tostring(pair.construction_last_event_0338 and pair.construction_last_event_0338.action)..
        ":"..tostring(pair.construction_last_event_0338 and pair.construction_last_event_0338.detail))
      if game.tick>=36000 then
        -- Read-only movement/source evidence for physical construction failures.
        local build=pair.construction_task_0338
        local src=build and build.source_entity
        local mv=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
        local movement=nil
        if mv and type(mv.request_status)=="function" then
          local ok,status=pcall(mv.request_status,pair)
          if ok then movement=status end
        end
        local sx,sy=nil,nil
        if src and src.valid then sx=src.position.x;sy=src.position.y end
        local site=build and build.position or (planner and planner.position)
        local edge_distance=nil
        if src and src.valid then
          pcall(function()
            local box=src.selection_box
            local lt=box.left_top or box[1]
            local rb=box.right_bottom or box[2]
            local pt=pair.priest.position
            local x=math.max(lt.x,math.min(pt.x,rb.x))
            local y=math.max(lt.y,math.min(pt.y,rb.y))
            edge_distance=math.sqrt((pt.x-x)^2+(pt.y-y)^2)
          end)
        end
        emit("CONSTRUCTION_DIAG rank="..spec.name..
          " task="..tostring(build and build.phase)..
          " item="..tostring(build and build.item_name)..
          " source="..tostring(src and src.name)..
          " priest_xy="..tostring(pair.priest.position.x)..","..tostring(pair.priest.position.y)..
          " source_xy="..tostring(sx)..","..tostring(sy)..
          " source_edge_distance="..tostring(edge_distance)..
          " site_xy="..tostring(site and site.x)..","..tostring(site and site.y)..
          " movement_owner="..tostring(movement and movement.owner)..
          " movement_active="..tostring(movement and movement.active)..
          " movement_reason="..tostring(movement and movement.reason)..
          " retry_stand="..tostring(build and build.build_standoff_0338 and build.build_standoff_0338.x)..
          ","..tostring(build and build.build_standoff_0338 and build.build_standoff_0338.y)..
          " retry_count="..tostring(build and build.revive_reposition_attempts_0338)..
          " carried="..tostring(build and build.carried and build.carried.count))
        -- Probe actual blockers, not merely a can-place prediction. Ghosts
        -- aren't evidence that a physical device has been constructed.
        if build and build.ghost and build.ghost.valid then
          local g=build.ghost
          local box=g.selection_box
          local okay,near=pcall(function()
            return g.surface.find_entities_filtered({area=box})
          end)
          if okay and type(near)=="table" then
            for _,e in ipairs(near)do
              if e and e.valid and e~=g then
                emit("CONSTRUCTION_GHOST_NEIGHBOR rank="..spec.name..
                  " name="..tostring(e.name).." type="..tostring(e.type)..
                  " xy="..tostring(e.position and e.position.x)..
                  ","..tostring(e.position and e.position.y))
              end
            end
          end
        end
        local Site=rawget(_G,"TechPriestsConstructionSitePlanner")
        local Constraints=rawget(_G,"TechPriestsPlanningConstraints0646")
        local seen,probed,accepted,territory,legal={},0,0,0,0
        local ore_tiles=entity.surface.find_entities_filtered({
          position=entity.position,radius=pair.radius or 36,type="resource"})
        local example=nil
        for _,resource in pairs(ore_tiles or {}) do
          if resource.valid and (resource.amount or 1)>0 then
            local x0=math.floor(resource.position.x)
            local y0=math.floor(resource.position.y)
            for _,dx in ipairs({0,1}) do for _,dy in ipairs({0,1}) do
              local pos={x=x0+dx,y=y0+dy}
              local key=pos.x..":"..pos.y
              if not seen[key] then
                seen[key]=true;probed=probed+1
                local ok_place,can=pcall(function()
                  return entity.surface.can_place_entity({
                    name="burner-mining-drill",position=pos,force=entity.force})
                end)
                if ok_place and can==true then accepted=accepted+1 end
                local ok_policy,allowed=true,true
                if Constraints and type(Constraints.interior_position_allowed)=="function" then
                  ok_policy,allowed=pcall(Constraints.interior_position_allowed,pair,pos)
                end
                if ok_policy and allowed==true then territory=territory+1 end
                if ok_place and can==true and ok_policy and allowed==true then
                  legal=legal+1
                  if not example then example=pos.x..","..pos.y end
                end
              end
            end end
          end
        end
        local site_pos,site_why=nil,"planner-unavailable"
        if Site and type(Site.plan_site)=="function" then
          local ok,found,why=pcall(Site.plan_site,pair,{
            entity_name="burner-mining-drill",category="miner"})
          if ok then site_pos,site_why=found,why else site_why=found end
        end
        emit("MINER_SITE_DIAG rank="..spec.name..
          " resource_tiles="..tostring(#ore_tiles)..
          " candidates="..tostring(probed)..
          " factorio_can_place="..tostring(accepted)..
          " territory_legal="..tostring(territory)..
          " both_legal="..tostring(legal)..
          " example="..tostring(example)..
          " site="..tostring(site_pos and (site_pos.x..","..site_pos.y))..
          " blocker="..tostring(site_why)..
          " station_radius="..tostring(pair.radius))
      end
      if game.tick>=36000 then
        local drills=entity.surface.find_entities_filtered({
          force=entity.force,type="mining-drill",limit=12})
        for _,drill in pairs(drills or {}) do
          if drill.valid then
            local fuel,remaining=0,0
            pcall(function()
              local inv=drill.get_inventory(defines.inventory.fuel)
              fuel=inv and inv.valid and inv.get_item_count("coal") or 0
            end)
            pcall(function()
              local burner=drill.burner
              remaining=burner and burner.remaining_burning_fuel or 0
            end)
            local status,mine_target,drop_target,drop_position,energy="?",nil,nil,nil,nil
            pcall(function()status=drill.status end)
            pcall(function()mine_target=drill.mining_target end)
            pcall(function()drop_target=drill.drop_target end)
            pcall(function()drop_position=drill.drop_position end)
            pcall(function()energy=drill.energy end)
            emit("DRILL_OPERATION_DIAG rank="..spec.name..
              " name="..tostring(drill.name)..
              " unit="..tostring(drill.unit_number)..
              " fuel_coal="..tostring(fuel)..
              " burning_fuel="..tostring(remaining)..
              " status="..tostring(status)..
              " mining_target="..tostring(mine_target and mine_target.name)..
              " drop_target="..tostring(drop_target and drop_target.name)..
              " drop_position="..tostring(drop_position and
                (drop_position.x..","..drop_position.y))..
              " energy="..tostring(energy))
          end
        end
      end
      local request=pair.movement_request_0418 or {}
      local mc=tp.movement_controller_0419 or {}
      local root_req=mc.requests and (mc.requests[tostring(entity.unit_number)] or mc.requests[entity.unit_number]) or {}
      local priest_pos=pair.priest and pair.priest.valid and pair.priest.position
      local station_pos=entity.position
      local dx=priest_pos and priest_pos.x-station_pos.x or 0
      local dy=priest_pos and priest_pos.y-station_pos.y or 0
      local custody=pair.direct_acquisition_custody_0513 or {}
      local machine_custody=pair.machine_logistics_custody_0528 or {}
      local recovery=pair.movement_controller_last_recovery_0418 or {}
      local cmd=pair.movement_controller_last_command_0418 or {}
      local stats=mc.stats or {}
      emit("RETURN_TRACE rank="..spec.name..
        " distance="..tostring(math.floor(math.sqrt(dx*dx+dy*dy)*100)/100)..
        " priest_x="..tostring(priest_pos and priest_pos.x)..
        " priest_y="..tostring(priest_pos and priest_pos.y)..
        " custody="..tostring(custody.item)..":"..tostring(custody.count)..
        " machine_custody="..tostring(machine_custody.item)..":"..tostring(machine_custody.count)..
        " recovery="..tostring(recovery.reason)..":"..tostring(recovery.tick)..
        " recovery_blocker="..tostring(request.last_recovery_blocker or root_req.last_recovery_blocker)..
        " mining_lock="..tostring(pair.mining_lock_0315)..
        " craft_lock="..tostring(pair.station_craft_lock_0337)..
        " crafting_lock="..tostring(pair.crafting_lock_0418)..
        " conversation="..tostring(pair.idle_conversation)..
        " movement_state="..tostring(pair.movement_controller_state_0418)..
        " movement_clamp="..tostring(pair.movement_controller_clamp_0418)..
        " owner="..tostring(request.owner)..
        " reason="..tostring(request.reason)..
        " root_owner="..tostring(root_req.owner)..
        " root_reason="..tostring(root_req.reason)..
        " priority="..tostring(request.priority)..
        " target="..tostring(request.x)..","..tostring(request.y)..
        " waypoint_chunked="..tostring(request.ground_route_chunked)..
        " waypoint_final="..tostring(request.ground_route_final_destination and request.ground_route_final_destination.x)..
        ","..tostring(request.ground_route_final_destination and request.ground_route_final_destination.y)..
        " last_command="..tostring(cmd.tick)..":"..tostring(cmd.reason)..
        " movement_commands="..tostring(stats.commands or 0)..
        " retarget_held="..tostring(stats.retargets_held or 0)..
        " lease_held="..tostring(stats.lease_retargets_held or 0)..
        " priority_denied="..tostring(stats.lower_priority_retargets_denied or 0)..
        " stalled_repaths="..tostring(stats.stalled_repaths or 0)..
        " waypoint_advances="..tostring(stats.ground_waypoints_advanced or 0)..
        " overleash_preserved="..tostring(stats.overleash_returns_preserved_0566 or 0))
    end
  end
end

local function count_researched()
  local count=0
  for _,tech in pairs(game.forces.player.technologies) do
    if tech.researched then count=count+1 end
  end
  return count
end

local function verify_final(state)
  local completed_research=math.max(0,count_researched()-state.initial_researched)
  local surface=game.surfaces[1]
  local counts=count_operational_industry(surface)
  local stats=game.forces.player.get_item_production_statistics(surface)
  local ore=stats.get_input_count("iron-ore")+stats.get_input_count("copper-ore")
  local plates=stats.get_input_count("iron-plate")+stats.get_input_count("copper-plate")
  local circuits=stats.get_input_count("electronic-circuit")
  local science=stats.get_input_count("automation-science-pack")
  -- A science pack manufactured into a laboratory inventory is not proof
  -- of laboratory research. The engine's item consumption statistic counts
  -- actual packs spent on research; technology-trigger unlocks alone cannot
  -- satisfy this stronger progression assertion.
  local consumed_science=stats.get_output_count("automation-science-pack")
  local ongoing=game.forces.player.current_research
  local progress=game.forces.player.research_progress or 0
  emit("RESEARCH_ENGINE tick="..game.tick..
    " packs_produced="..science..
    " packs_consumed="..consumed_science..
    " current="..tostring(ongoing and ongoing.name)..
    " progress="..tostring(progress)..
    " automation_completed="..tostring(
      game.forces.player.technologies["automation"]
      and game.forces.player.technologies["automation"].researched))
  -- Read-only evidence for physically placed emergency mining machines.
  -- Do not satisfy an assertion by writing stock or assigning a recipe here.
  local facility=storage.tech_priests.emergency_facility_doctrine_0343 or {}
  local miner_entities=surface.find_entities_filtered{
    force=game.forces.player,name="tech-priests-emergency-miner"}
  emit("MINER_LIFECYCLE tick="..game.tick..
    " machines="..#miner_entities..
    " recipes_started="..tostring(facility.stats and facility.stats.miner_recipes_started or 0))
  for _,machine in ipairs(miner_entities) do
    local selected,output,coal_output,energy,status=nil,0,0,"?", "?"
    pcall(function()
      local recipe=machine.get_recipe and machine.get_recipe()
      selected=type(recipe)=="string" and recipe or (recipe and recipe.name)
    end)
    pcall(function()
      local inventory=machine.get_inventory(defines.inventory.assembling_machine_output)
      if inventory and inventory.valid then
        output=inventory.get_item_count("iron-ore")+inventory.get_item_count("copper-ore")
        coal_output=inventory.get_item_count("coal")
      end
    end)
    pcall(function()energy=tostring(machine.energy) end)
    pcall(function()status=tostring(machine.status) end)
    local diagnostic="none"
    local nearest,nearest_d= nil,math.huge
    for _,spec in ipairs(stations) do
      local station=surface.find_entities_filtered{
        name=spec.name,position={spec.x,spec.y},radius=2,force=machine.force
      }[1]
      if station and station.valid then
        local dx=station.position.x-machine.position.x
        local dy=station.position.y-machine.position.y
        local d=dx*dx+dy*dy
        if d<nearest_d then nearest,nearest_d=station,d end
      end
    end
    if nearest and nearest_d<=36*36 then
      local pair=storage.tech_priests and storage.tech_priests.pairs_by_station
        and storage.tech_priests.pairs_by_station[nearest.unit_number]
      local diag=pair and pair.emergency_facility_recipe_diagnostic_0357
      if diag then
        diagnostic=tostring(diag.recipe)..":"..tostring(diag.phase)..
          ":"..tostring(diag.reason)
      end
    end
    emit("MINER_MACHINE unit="..tostring(machine.unit_number)..
      " recipe_diag="..diagnostic..
      " recipe="..tostring(selected)..
      " ore_output="..tostring(output)..
      " coal_output="..tostring(coal_output)..
      " energy="..energy.." status="..status)
  end
  -- Runtime-only readback of the real copper/electronics production chain.
  -- No inventory mutation, recipe assignment, or acceptance relaxation.
  for _,spec in ipairs(stations) do
    local station=surface.find_entities_filtered{
      name=spec.name,position={spec.x,spec.y},radius=2,
      force=game.forces.player
    }[1]
    if station and station.valid then
      local chest=station.get_inventory(defines.inventory.chest)
      local function stock(item)
        return chest and chest.valid and chest.get_item_count(item) or 0
      end
      emit("ELECTRONICS_STOCK rank="..spec.name..
        " copper_ore="..stock("copper-ore")..
        " copper_plate="..stock("copper-plate")..
        " copper_cable="..stock("copper-cable")..
        " iron_plate="..stock("iron-plate")..
        " iron_gear="..stock("iron-gear-wheel")..
        " science_pack="..stock("automation-science-pack")..
        " normal_lab_item="..stock("lab")..
        " circuit="..stock("electronic-circuit"))
      -- Diagnose why a physical workshop fails the canonical recipe gate.
      -- This is deliberately read-only: no recipe unlocks, inventory changes,
      -- machine configuration or artificial acceptance.
      local inspector=rawget(_G,"TechPriestsInfrastructureFirstGovernor0640")
      local tracked=storage.tech_priests and storage.tech_priests.pairs_by_station
        and storage.tech_priests.pairs_by_station[station.unit_number]
      local survey="owner-unavailable"
      if inspector and type(inspector.status_for_pair)=="function" and tracked then
        local ok,detail=pcall(inspector.status_for_pair,tracked)
        survey=ok and tostring(detail) or "inspection-error:"..tostring(detail)
      end
      local function recipe_state(name)
        local recipe=station.force and station.force.recipes
          and station.force.recipes[name]
        if not recipe then return "missing" end
        local ok,enabled=pcall(function()return recipe.enabled end)
        return ok and tostring(enabled) or "lookup-error"
      end
      local nearby_assembler=surface.find_entities_filtered{
        name="tech-priests-emergency-assembler",
        position=station.position,radius=36,force=station.force}
      local tagged=storage.tech_priests
        and storage.tech_priests.emergency_facility_doctrine_0343
      local ownership=tagged and tagged.by_station
        and tagged.by_station[station.unit_number] or {}
      local tagged_count=0
      for _ in pairs(ownership) do tagged_count=tagged_count+1 end
      emit("ELECTRONICS_INFRA rank="..spec.name..
        " circuit_enabled="..recipe_state("electronic-circuit")..
        " cable_enabled="..recipe_state("copper-cable")..
        " copper_smelting_enabled="..recipe_state("copper-plate")..
        " electronics_researched="..tostring(station.force.technologies
          and station.force.technologies["electronics"]
          and station.force.technologies["electronics"].researched)..
        " physical_copper_plates_made="..tostring(
          stats.get_input_count("copper-plate"))..
        " found_assemblers="..tostring(#nearby_assembler)..
        " facility_claims="..tostring(tagged_count)..
        " survey="..survey)
      -- Read-only reconciliation: distinguish copper-acquisition starvation
      -- from copper stock already held in real furnace source inventories.
      local pair=storage.tech_priests and storage.tech_priests.pairs_by_station
        and storage.tech_priests.pairs_by_station[station.unit_number]
      local current=pair and pair.direct_acquisition_task_0336
      local resource=pair and pair.bootstrap_mode_0637
      local pending=pair and pair.infrastructure_recipe_request_0647
      local plan=pair and pair.master_infrastructure_plan_0644
      emit("ELECTRONICS_CHAIN rank="..spec.name..
        " bootstrap="..tostring(resource and resource.item)..
        " direct="..tostring(current and current.output_item)..
        " custody="..tostring(pair and pair.direct_acquisition_custody_0513 and pair.direct_acquisition_custody_0513.item)..
        " gate="..tostring(pair and pair.local_infrastructure_gate_0640 and pair.local_infrastructure_gate_0640.item)..
        " pending="..tostring(pending and pending.item)..
        " missing="..tostring(pending and pending.missing)..
        " craft="..tostring(pair and pair.emergency_craft and pair.emergency_craft.output_item)..
        " machine_candidate="..tostring(pair and pair.machine_logistics_candidate_0528
          and pair.machine_logistics_candidate_0528.item)..
        ":"..tostring(pair and pair.machine_logistics_candidate_0528
          and pair.machine_logistics_candidate_0528.action)..
        " machine_phase="..tostring(pair and pair.machine_logistics_0528
          and pair.machine_logistics_0528.phase)..
        " plan_age="..tostring(plan and game.tick-plan.tick)..
        " selector_machine="..tostring(pair and pair.emergency_facility_recipe_diagnostic_0357
          and pair.emergency_facility_recipe_diagnostic_0357.machine)..
        " selector_tick="..tostring(pair and pair.emergency_facility_recipe_diagnostic_0357
          and pair.emergency_facility_recipe_diagnostic_0357.tick)..
        " selector_recipe="..tostring(pair and pair.emergency_facility_recipe_diagnostic_0357
          and pair.emergency_facility_recipe_diagnostic_0357.recipe)..
        " selector_phase="..tostring(pair and pair.emergency_facility_recipe_diagnostic_0357
          and pair.emergency_facility_recipe_diagnostic_0357.phase)..
        " selector_reason="..tostring(pair and pair.emergency_facility_recipe_diagnostic_0357
          and pair.emergency_facility_recipe_diagnostic_0357.reason))
      -- Read-only proof of science and energy: a research point is never
      -- credited because a laboratory merely exists. Report exact engine
      -- inventory, fuel, status, technology and recipe eligibility.
      local science_recipe=station.force.recipes
        and station.force.recipes["automation-science-pack"]
      local trigger_tech=station.force.technologies
        and station.force.technologies["automation-science-pack"]
      local vanilla_lab_recipe=station.force.recipes
        and station.force.recipes["lab"]
      emit("SCIENCE_TRIGGER rank="..spec.name..
        " technology_researched="..tostring(
          trigger_tech and trigger_tech.researched)..
        " technology_enabled="..tostring(trigger_tech and trigger_tech.enabled)..
        " vanilla_lab_recipe_enabled="..tostring(
          vanilla_lab_recipe and vanilla_lab_recipe.enabled)..
        " red_recipe_enabled="..tostring(science_recipe and science_recipe.enabled)..
        " physically_crafted_lab_count="..tostring(
          stats.get_input_count("lab")))
      local current_research=station.force.current_research
      local local_labs=surface.find_entities_filtered{
        type="lab",position=station.position,radius=36,force=station.force}
      for _,lab in ipairs(local_labs) do
        local science_input=lab.get_inventory(defines.inventory.lab_input)
        local fuel_input=lab.get_inventory(defines.inventory.fuel)
        local function laboratory_item(inv,item)
          return inv and inv.valid and inv.get_item_count(item) or 0
        end
        local energy=0
        pcall(function()energy=lab.energy or 0 end)
        local status="unknown"
        for name,identifier in pairs(defines.entity_status or {}) do
          if identifier==lab.status then status=name;break end
        end
        emit("SCIENCE_LAB rank="..spec.name..
          " unit="..tostring(lab.unit_number)..
          " energy="..tostring(energy)..
          " status="..tostring(status)..
          " red_input="..laboratory_item(science_input,"automation-science-pack")..
          " fuel_coal="..laboratory_item(fuel_input,"coal")..
          " current_research="..tostring(
            current_research and current_research.name)..
          " pack_recipe_enabled="..tostring(science_recipe
            and science_recipe.enabled))
      end
      local furnaces=surface.find_entities_filtered{
        type="furnace",position=station.position,radius=20,force=game.forces.player
      }
      for _,furnace in ipairs(furnaces) do
        local function stocked(id,item)
          local inventory=furnace.get_inventory(id)
          return inventory and inventory.valid and inventory.get_item_count(item) or 0
        end
        emit("ELECTRONICS_FURNACE rank="..spec.name..
          " unit="..tostring(furnace.unit_number)..
          " fuel_coal="..stocked(defines.inventory.fuel,"coal")..
          " burner_remaining="..tostring(furnace.burner
            and furnace.burner.remaining_burning_fuel or 0)..
          " status="..tostring(furnace.status)..
          " progress="..tostring(furnace.crafting_progress)..
          " source_iron_ore="..stocked(defines.inventory.furnace_source,"iron-ore")..
          " source_copper_ore="..stocked(defines.inventory.furnace_source,"copper-ore")..
          " result_iron_plate="..stocked(defines.inventory.furnace_result,"iron-plate")..
          " result_copper_plate="..stocked(defines.inventory.furnace_result,"copper-plate"))
      end
      local machines=surface.find_entities_filtered{
        name="tech-priests-emergency-assembler",position=station.position,
        radius=36,force=game.forces.player
      }
      for _,machine in ipairs(machines) do
        local recipe=nil
        pcall(function()
          local selected=machine.get_recipe and machine.get_recipe()
          recipe=type(selected)=="string" and selected or (selected and selected.name)
        end)
        local input=machine.get_inventory(defines.inventory.assembling_machine_input)
        local output=machine.get_inventory(defines.inventory.assembling_machine_output)
        local function amount(inv,item)
          return inv and inv.valid and inv.get_item_count(item) or 0
        end
        local fuel=nil
        pcall(function()fuel=machine.get_inventory(defines.inventory.fuel)end)
        local remaining,energy=0,0
        pcall(function()
          local burner=machine.burner
          remaining=burner and burner.remaining_burning_fuel or 0
          energy=machine.energy or 0
        end)
        local status_name="unknown"
        for name,identifier in pairs(defines.entity_status or {}) do
          if identifier==machine.status then status_name=name;break end
        end
        -- Observe exactly why a real completed cable batch is not returned
        -- through owned facility upkeep or the physical logistics dispatcher.
        -- No state, inventory, recipe, or movement owner is changed here.
        local dx=machine.position.x-station.position.x
        local dy=machine.position.y-station.position.y
        local machine_owned=false
        for key in pairs(ownership) do
          local rec=tagged and tagged.facilities and tagged.facilities[key]
          if rec and rec.entity==machine and rec.role=="assembler" then
            machine_owned=true
          end
        end
        local route=pair and pair.machine_logistics_0528
        local candidate=pair and pair.machine_logistics_candidate_0528
        local claim=pair and pair.emergency_facility_feed_custody_0357
        local feed=pair and pair.emergency_facility_input_diagnostic_0357
        local stock_authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
        local usable_cable="unavailable"
        if stock_authority and type(stock_authority.generic_item_count)=="function"
            and pair then
          local ok,n=pcall(stock_authority.generic_item_count,pair,"copper-cable")
          if ok then usable_cable=tostring(n) end
        end
        emit("ELECTRONICS_HANDOFF rank="..spec.name..
          " unit="..tostring(machine.unit_number)..
          " station_dist_sq="..tostring(dx*dx+dy*dy)..
          " owned="..tostring(machine_owned)..
          " strict="..tostring(pair and pair.emergency_craft
            and pair.emergency_craft.strict_recipe_0647)..
          " usable_cable="..usable_cable..
          " output_cable="..amount(output,"copper-cable")..
          " route_phase="..tostring(route and route.phase)..
          " route_action="..tostring(route and route.action)..
          " route_item="..tostring(route and route.item)..
          " route_blocker="..tostring(route and route.last_blocker)..
          " route_custody="..tostring(route and route.custody and route.custody.item)..
          " candidate_item="..tostring(candidate and candidate.item)..
          " pending_refund="..tostring(claim and claim.item)..
          " feed_tick="..tostring(feed and feed.tick)..
          " feed_machine="..tostring(feed and feed.machine)..
          " feed_recipe="..tostring(feed and feed.recipe)..
          " feed_phase="..tostring(feed and feed.phase)..
          " feed_request="..tostring(feed and feed.requested)..
          " feed_moved="..tostring(feed and feed.moved)..
          " feed_sequence="..tostring(feed and feed.sequence)..
          " settled_total="..tostring(tagged and tagged.stats
            and tagged.stats["local-electronics-output-settled-0357"] or 0)..
          " machine_service_total="..tostring(tagged and tagged.stats
            and tagged.stats["ongoing-production-machine-service"] or 0))
        -- Inspect real Factorio 2.0 ingredient prototypes and the same
        -- container-only source ledger used by the assembler feeder.
        -- Read-only: no transfers, reservations, recipes or movements.
        local actual_recipe
        pcall(function()actual_recipe=machine.get_recipe()end)
        local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
          or (package.loaded and package.loaded["scripts.core.storage_role_authority_0686"])
        local sources={}
        if authority and type(authority.generic_storage_sources)=="function"
            and pair then
          local ok,found=pcall(authority.generic_storage_sources,pair)
          if ok and type(found)=="table" then sources=found end
        end
        local ingredient_parts={}
        for _,ingredient in pairs(actual_recipe and actual_recipe.ingredients or {}) do
          local ingredient_name=ingredient.name
          local ingredient_amount=tonumber(ingredient.amount) or 1
          if ingredient_name and ingredient.type~="fluid" then
            local usable,eligible_source,blocked_source=0,0,0
            for _,record in ipairs(sources) do
              local entity,inv=record.entity,record.inv
              local n=(inv and inv.valid) and inv.get_item_count(ingredient_name) or 0
              if n>0 then
                if entity and entity.valid
                    and entity.surface==station.surface
                    and entity.force==station.force then
                  usable=usable+n
                  eligible_source=eligible_source+1
                else
                  blocked_source=blocked_source+n
                end
              end
            end
            local preflight=false
            if input and input.valid then
              local ok,fits=pcall(function()
                return input.can_insert({name=ingredient_name,count=ingredient_amount})
              end)
              preflight=ok and fits==true
            end
            ingredient_parts[#ingredient_parts+1]=ingredient_name..
              ":required="..tostring(ingredient_amount)..
              ":usable="..tostring(usable)..
              ":source_slots="..tostring(eligible_source)..
              ":blocked="..tostring(blocked_source)..
              ":can_insert="..tostring(preflight)
          end
        end
        emit("ELECTRONICS_FEED_PREFLIGHT rank="..spec.name..
          " unit="..tostring(machine.unit_number)..
          " recipe="..tostring(recipe)..
          " source_count="..tostring(#sources)..
          " ingredients="..table.concat(ingredient_parts,";"))
        emit("ELECTRONICS_MACHINE rank="..spec.name..
          " unit="..tostring(machine.unit_number)..
          " recipe="..tostring(recipe)..
          " fuel_coal="..amount(fuel,"coal")..
          " burner_remaining="..tostring(remaining)..
          " energy="..tostring(energy)..
          " status_name="..status_name..
          " input_copper_plate="..amount(input,"copper-plate")..
          " input_copper_cable="..amount(input,"copper-cable")..
          " input_iron_plate="..amount(input,"iron-plate")..
          " output_copper_cable="..amount(output,"copper-cable")..
          " output_circuit="..amount(output,"electronic-circuit")..
          " output_laboratorium="..amount(output,"tech-priests-emergency-laboratorium")..
          " output_iron_gears="..amount(output,"iron-gear-wheel")..
          " output_transport_belt="..amount(output,"transport-belt")..
          " output_science="..amount(output,"automation-science-pack")..
          " output_normal_lab="..amount(output,"lab")..
          " status="..tostring(machine.status))
      end
    end
  end
  emit("FINAL tick="..game.tick.." ore="..ore.." plates="..plates..
    " circuits="..circuits.." science="..science..
    " completed_research="..completed_research)
  if counts.drills<1 then fail("ENDURANCE: no physical mining drill") end
  if ore<1 then fail("ENDURANCE: no mined iron/copper ore output") end
  if counts.furnaces<1 or plates<1 then fail("ENDURANCE: no physical smelting output") end
  if counts.assemblers<1 or circuits<1 then fail("ENDURANCE: no electronic-circuit production") end
  if counts.labs<1 or science<1 then fail("ENDURANCE: no laboratory/science-pack production") end
  if completed_research<1 then fail("ENDURANCE: no completed research") end
  if consumed_science<1 then
    fail("ENDURANCE: no genuine science packs consumed by laboratory research")
  end
  emit("PASS autonomous bootstrap-to-science tick="..game.tick)
end

-- Compare against the default engineer prototype independently of executor
-- timing. Only resources a player could hand-mine are eligible.
local function verify_laser_mining_rate()
  local direct=rawget(_G,"TechPriestsDirectAcquisitionExecutor0513")
  if not (direct and type(direct.laser_work_ticks)=="function") then
    fail("direct laser mining calibration unavailable")
  end
  local character=prototypes.entity.character
  local speed=character and character.mining_speed or 0.5
  if not (speed and speed>0) then fail("default engineer mining speed unavailable") end
  local count=0
  for _,name in ipairs({"iron-ore","copper-ore","coal","stone"}) do
    local proto=prototypes.entity[name]
    local mineable=proto and proto.mineable_properties
    local mining_time=mineable and mineable.mining_time
    if not (mining_time and mining_time>0) then fail("resource mining time unavailable: "..name) end
    local engineer_ticks=math.ceil(60*mining_time/speed)
    local laser_ticks=direct.laser_work_ticks(proto)
    -- The canonical dispatcher runs every five ticks; leave a complete cycle
    -- of headroom so a scheduled extraction is never slower than vanilla.
    if laser_ticks+5>engineer_ticks then
      fail("LASER_RATE slower than engineer for "..name..
        " laser_ticks="..laser_ticks.." player_ticks="..engineer_ticks)
    end
    count=count+1
    emit("LASER_RATE resource="..name.." player_ticks="..engineer_ticks..
      " laser_ticks="..laser_ticks.." speed="..speed)
  end
  emit("PASS laser mining player baseline resources="..count)
end

-- Duration-versus-assignment study. Checkpoints are observations of the
-- same world, never restarts or interventions. All values are engine counters,
-- real station inventories, and existing production-task ownership.
local DURATION_CHECKPOINTS={18000,36000,72000,108000}
local function duration_checkpoint(state,elapsed)
  local force=game.forces.player
  local surface=game.surfaces[1]
  local stats=force.get_item_production_statistics(surface)
  local industry=count_operational_industry(surface)
  local function made(item) return stats.get_input_count(item) end
  local snap={
    elapsed=elapsed, tick=game.tick,
    iron_ore=made("iron-ore"), copper_ore=made("copper-ore"),
    iron_plate=made("iron-plate"), copper_plate=made("copper-plate"),
    circuits=made("electronic-circuit"),
    gears=made("iron-gear-wheel"), belts=made("transport-belt"),
    vanilla_labs=made("lab"),
    science=made("automation-science-pack"),
    green_science=made("logistic-science-pack"),
    research=count_researched()-(state.initial_researched or 0),
    progress=force.research_progress or 0,
    labs=industry.labs, assemblers=industry.assemblers,
  }
  state.duration_checkpoints=state.duration_checkpoints or {}
  state.duration_checkpoints[elapsed]=snap
  emit("DURATION_CHECKPOINT elapsed="..elapsed..
    " iron_ore="..snap.iron_ore.." copper_ore="..snap.copper_ore..
    " iron_plates="..snap.iron_plate.." copper_plates="..snap.copper_plate..
    " circuits="..snap.circuits.." gears="..snap.gears..
    " belts="..snap.belts.." vanilla_lab_crafted="..snap.vanilla_labs..
    " emergency_labs="..snap.labs..
    " red_science="..snap.science.." green_science="..snap.green_science..
    " researches="..snap.research.." research_progress="..snap.progress)
  -- Compare actual engine-produced items, never assigned/planned recipes.
  -- Quantify pipeline throughput per 1000 ticks rather than guessing that
  -- extending the endurance window will resolve a missing physical handoff.
  local prior_tick=({[36000]=18000,[72000]=36000,[108000]=72000})[elapsed]
  local prior=prior_tick and state.duration_checkpoints[prior_tick] or nil
  if prior then
    local ticks=elapsed-prior_tick
    local function delta(key) return snap[key]-prior[key] end
    local function per_1000(n)
      return math.floor((n*100000/ticks)+0.5)/100
    end
    local ore=delta("iron_ore")+delta("copper_ore")
    local plates=delta("iron_plate")+delta("copper_plate")
    emit("PRODUCTION_EFFICIENCY from_tick="..prior_tick..
      " to_tick="..elapsed..
      " ore_delta="..ore.." plates_delta="..plates..
      " cable_dependency_gears_delta="..delta("gears")..
      " belts_delta="..delta("belts")..
      " circuits_delta="..delta("circuits")..
      " lab_delta="..delta("vanilla_labs")..
      " red_delta="..delta("science")..
      " green_delta="..delta("green_science")..
      " ore_per_1000_ticks="..per_1000(ore)..
      " plates_per_1000_ticks="..per_1000(plates)..
      " circuits_per_1000_ticks="..per_1000(delta("circuits"))..
      " labs_per_1000_ticks="..per_1000(delta("vanilla_labs"))..
      " red_per_1000_ticks="..per_1000(delta("science")))
  end
  for _,spec in ipairs(stations) do
    local station=surface.find_entities_filtered{
      name=spec.name,position={spec.x,spec.y},radius=2,force=force
    }[1]
    if station and station.valid then
      local chest=station.get_inventory(defines.inventory.chest)
      local function stored(item)
        return chest and chest.valid and chest.get_item_count(item) or 0
      end
      local pair=storage.tech_priests and storage.tech_priests.pairs_by_station
        and storage.tech_priests.pairs_by_station[station.unit_number]
      -- Lab unlock continuity must be measured at every checkpoint, not
      -- inferred from one final production count. Count only retrievable
      -- station-owned general storage (including managed stone caches), not
      -- an unrelated machine input, engine progress or another station.
      local stock_authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
        or (package.loaded and
          package.loaded["scripts.core.storage_role_authority_0686"])
      local function usable(item)
        if pair and stock_authority
            and type(stock_authority.generic_item_count)=="function" then
          local ok,n=pcall(stock_authority.generic_item_count,pair,item)
          if ok and type(n)=="number" then return n end
        end
        return stored(item)
      end
      local parent_chain={}
      local node=pair and pair.infrastructure_recipe_request_0647
      for _=1,6 do
        if type(node)~="table" then break end
        parent_chain[#parent_chain+1]=tostring(node.item)..":"..
          tostring(node.missing)
        node=node.parent_request_0647
      end
      local science_tech=station.force.technologies
        and station.force.technologies["automation-science-pack"]
      local workshop_owned=false
      local lab_owned=false
      local owned_root=storage.tech_priests
        and storage.tech_priests.emergency_facility_doctrine_0343
      for key in pairs(owned_root and owned_root.by_station
          and owned_root.by_station[station.unit_number] or {}) do
        local rec=owned_root.facilities and owned_root.facilities[key]
        if rec and rec.entity and rec.entity.valid
            and rec.entity.force==station.force
            and rec.entity.surface==station.surface then
          if rec.role=="assembler" then workshop_owned=true end
          if rec.role=="lab" then lab_owned=true end
          -- Read the actual owned engine buffers. The station stock alone
          -- cannot distinguish recipe starvation from a copper-filled
          -- furnace, buffered gears, stopped burner or a locked workshop.
          -- This fixture only observes; it never transfers or grants items.
          if rec.role=="smelter" or rec.role=="assembler" then
            local machine=rec.entity
            local function count(id,item)
              local ok,n=pcall(function()
                local inv=machine.get_inventory(id)
                return inv and inv.valid and inv.get_item_count(item) or 0
              end)
              return ok and tonumber(n) or 0
            end
            local selected="none"
            pcall(function()
              local recipe=machine.get_recipe and machine.get_recipe()
              selected=(type(recipe)=="string" and recipe)
                or (recipe and recipe.name) or "none"
            end)
            local progress,burning=0,0
            pcall(function() progress=machine.crafting_progress or 0 end)
            pcall(function()
              burning=machine.burner and machine.burner.remaining_burning_fuel or 0
            end)
            local inv=defines.inventory
            emit("OWNED_MACHINE_STAGE elapsed="..elapsed..
              " rank="..spec.name..
              " role="..rec.role..
              " name="..machine.name..
              " type="..machine.type..
              " recipe="..tostring(selected)..
              " status="..tostring(machine.status)..
              " progress="..tostring(progress)..
              " burning="..tostring(burning)..
              " fuel_coal="..count(inv.fuel,"coal")..
              " source_iron="..count(inv.furnace_source,"iron-ore")..
              " source_copper="..count(inv.furnace_source,"copper-ore")..
              " result_iron="..count(inv.furnace_result,"iron-plate")..
              " result_copper="..count(inv.furnace_result,"copper-plate")..
              " input_iron="..count(inv.assembling_machine_input,"iron-plate")..
              " input_gear="..count(inv.assembling_machine_input,"iron-gear-wheel")..
              " input_cable="..count(inv.assembling_machine_input,"copper-cable")..
              " input_circuits="..count(inv.assembling_machine_input,"electronic-circuit")..
              " output_gears="..count(inv.assembling_machine_output,"iron-gear-wheel")..
              " output_circuits="..count(inv.assembling_machine_output,"electronic-circuit"))
          end
        end
      end
      emit("LAB_CHAIN_STAGE elapsed="..elapsed..
        " rank="..spec.name..
        " circuits="..usable("electronic-circuit")..
        " gears="..usable("iron-gear-wheel")..
        " belts="..usable("transport-belt")..
        " iron_plates="..usable("iron-plate")..
        " iron_ore="..usable("iron-ore")..
        " coal="..usable("coal")..
        " workshop_owned="..tostring(workshop_owned)..
        " emergency_lab_owned="..tostring(lab_owned)..
        " science_technology="..tostring(science_tech
          and science_tech.researched)..
        " pending_chain="..table.concat(parent_chain,"->")..
        " active="..tostring(pair and pair.emergency_craft and
          (pair.emergency_craft.output_item or
            pair.emergency_craft.item_name))..
        " gate="..tostring(pair and pair.local_infrastructure_gate_0640
          and pair.local_infrastructure_gate_0640.item))
      local work=pair and pair.emergency_craft
      local pending=pair and pair.infrastructure_recipe_request_0647
      local gate=pair and pair.local_infrastructure_gate_0640
      local feed=pair and pair.emergency_facility_input_diagnostic_0357
      local offer=pair and pair.emergency_facility_workshop_offer_0357
      local workshop_phase=pair and
        pair.emergency_facility_workshop_service_phase_0357
      local selector=pair and
        pair.emergency_facility_assembler_recipe_diagnostic_0357
      local continuity=pair and
        pair.emergency_facility_continuity_diagnostic_0357
      local governor=rawget(_G,"TechPriestsInfrastructureFirstGovernor0640")
      local workshop_job,workshop_source=nil,"planner-unavailable"
      if pair and governor
          and type(governor.cooperative_workshop_for_pair)=="function" then
        local ok,item,source=pcall(governor.cooperative_workshop_for_pair,pair)
        if ok then
          workshop_job,workshop_source=item,source
        else
          workshop_source="planner-error:"..tostring(item)
        end
      end
      emit("DURATION_STATION elapsed="..elapsed.." rank="..spec.name..
        " planned_workshop="..tostring(workshop_job)..
        " planned_workshop_source="..tostring(workshop_source)..
        " workshop_offer="..tostring(offer and offer.proposal)..
        " workshop_offer_status="..tostring(offer and offer.status)..
        " workshop_offer_source="..tostring(offer and offer.assignment)..
        " workshop_offer_age="..tostring(offer and (game.tick-offer.tick))..
        " workshop_phase="..tostring(workshop_phase and workshop_phase.phase)..
        " workshop_phase_recipe="..tostring(workshop_phase and workshop_phase.recipe)..
        " workshop_phase_reason="..tostring(workshop_phase and workshop_phase.reason)..
        " workshop_phase_age="..tostring(workshop_phase
          and game.tick-workshop_phase.tick)..
        " selector_age="..tostring(selector and game.tick-selector.tick)..
        " continuity_age="..tostring(continuity and game.tick-continuity.tick)..
        " ore_copper="..stored("copper-ore")..
        " copper_plate="..stored("copper-plate")..
        " iron_plate="..stored("iron-plate")..
        " circuits="..stored("electronic-circuit")..
        " gears="..stored("iron-gear-wheel")..
        " belts="..stored("transport-belt")..
        " vanilla_lab="..stored("lab")..
        " craft="..tostring(work and (work.output_item or work.item_name))..
        " missing="..tostring(pending and pending.missing)..
        " gate="..tostring(gate and gate.state)..
        " feed_recipe="..tostring(feed and feed.recipe)..
        " feed_tick="..tostring(feed and feed.tick)..
        " feed_requested="..tostring(feed and feed.requested)..
        " feed_inserted="..tostring(feed and feed.moved)..
        " feed_calls="..tostring(feed and feed.sequence)..
        " assembler_selector="..
          tostring(pair and pair.emergency_facility_assembler_recipe_diagnostic_0357
            and pair.emergency_facility_assembler_recipe_diagnostic_0357.phase)..
        " assembler_selector_recipe="..
          tostring(pair and pair.emergency_facility_assembler_recipe_diagnostic_0357
            and pair.emergency_facility_assembler_recipe_diagnostic_0357.recipe)..
        " assembler_selector_reason="..
          tostring(pair and pair.emergency_facility_assembler_recipe_diagnostic_0357
            and pair.emergency_facility_assembler_recipe_diagnostic_0357.reason)..
        " labor_assignment="..tostring(pair and
          pair.cooperative_labor_assignment_0690
          and pair.cooperative_labor_assignment_0690.item)..
        " labor_source="..tostring(pair and
          pair.cooperative_labor_assignment_0690
          and pair.cooperative_labor_assignment_0690.source)..
        " labor_prior="..tostring(pair and
          pair.cooperative_labor_assignment_0690
          and pair.cooperative_labor_assignment_0690.previous)..
        " continuity_task="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.task)..
        " continuity_authorized="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.authorized)..
        " continuity_source="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.source)..
        " continuity_infrastructure="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.infrastructure)..
        " continuity_custody_ready="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.custody_ready)..
        " continuity_serviced="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.serviced)..
        " continuity_workshop_request="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.workshop_request)..
        " continuity_workshop_free="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.workshop_free)..
        " continuity_workshop_blocker="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.blocker)..
        " continuity_workshop_task_item="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.task_item)..
        " continuity_engine_recipe="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.selected_recipe)..
        " continuity_recipe_accepted="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.machine_accepted)..
        " labor_work_item="..tostring(pair and
          pair.cooperative_labor_work_order_0690
          and pair.cooperative_labor_work_order_0690.item)..
        " labor_work_recipe="..tostring(pair and
          pair.cooperative_labor_work_order_0690
          and pair.cooperative_labor_work_order_0690.recipe)..
        " labor_work_machine="..tostring(pair and
          pair.cooperative_labor_work_order_0690
          and pair.cooperative_labor_work_order_0690.machine_unit)..
        " labor_work_state="..tostring(pair and
          pair.cooperative_labor_work_order_0690
          and pair.cooperative_labor_work_order_0690.status)..
        " labor_work_age="..tostring(pair and
          pair.cooperative_labor_work_order_0690 and
          game.tick-pair.cooperative_labor_work_order_0690.tick)..
        " continuity_workshop="..tostring(pair and
          pair.emergency_facility_continuity_diagnostic_0357
          and pair.emergency_facility_continuity_diagnostic_0357.workshop)..
        " miner_output_settled_total="..tostring(
          storage.tech_priests and storage.tech_priests.emergency_facility_doctrine_0343
          and storage.tech_priests.emergency_facility_doctrine_0343.stats
          and storage.tech_priests.emergency_facility_doctrine_0343.stats["local-miner-output-settled-0357"] or 0))
    end
  end
end

local function duration_diagnosis(state)
  local samples=state.duration_checkpoints or {}
  local early,middle,late=samples[36000],samples[72000],samples[108000]
  if not (early and middle and late) then
    fail("DURATION_MISSING_CHECKPOINT: 36k,72k,108k required")
  end
  local function slope(field,a,b) return b[field]-a[field] end
  local delta_plates=slope("iron_plate",early,late)
    +slope("copper_plate",early,late)
  local delta_circuits=slope("circuits",early,late)
  local delta_labs=slope("vanilla_labs",early,late)
  local delta_science=slope("science",early,late)
  local verdict,reason
  if early.science==0 and late.science>0 then
    verdict="TIME_WINDOW_TOO_SHORT"
    reason="physical science appeared only after 36k without intervention"
  elseif early.science>0 then
    verdict="EARLY_SCIENCE_ALREADY_AVAILABLE"
    reason="36k was already sufficient to physically manufacture science"
  elseif delta_plates<=3 and delta_circuits<=1 and delta_labs==0 then
    verdict="PRODUCTION_STALL"
    reason="intermediate manufacturing nearly stopped across the 36k-to-108k interval"
  elseif delta_plates>3 and delta_circuits==0 then
    verdict="ASSEMBLY_EXECUTION_BLOCKED"
    reason="real plates continued but no circuits completed: inspect engine recipe, fuel, and ingredient custody"
  elseif delta_circuits>0 and delta_labs==0 then
    verdict="VANILLA_LAB_CHAIN_BLOCKED"
    reason="real circuits completed but no vanilla laboratory was crafted"
  elseif delta_labs>0 and delta_science==0 then
    verdict="SCIENCE_RECIPE_CHAIN_BLOCKED"
    reason="vanilla laboratories were manufactured but no real red science packs completed"
  elseif middle.science==0 and late.science==0 then
    verdict="ACTIVE_BUT_SCIENCE_BLOCKED"
    reason="extra simulation time created no science despite observed physical production"
  else
    verdict="INCONCLUSIVE"
    reason="the observed production trajectory does not determine causation"
  end
  emit("DURATION_DIAGNOSIS verdict="..verdict..
    " from_tick=36000 to_tick=108000"..
    " plate_delta="..delta_plates..
    " circuit_delta="..delta_circuits..
    " vanilla_lab_delta="..delta_labs..
    " science_delta="..delta_science..
    " first_36k_science="..early.science..
    " first_72k_science="..middle.science..
    " last_108k_science="..late.science..
    " reason="..reason)
end

-- Persist primitive identities only. This check does not add resources,
-- unlock research, change owners or rewrite an in-progress production task.
local function save_reload_checkpoint(state)
  local surface=game.surfaces[1]
  local pairs=storage.tech_priests and storage.tech_priests.pairs_by_station
  local snapshot={}
  for _,spec in ipairs(stations) do
    local station=surface.find_entities_filtered{
      name=spec.name,position={spec.x,spec.y},radius=2,
      force=game.forces.player}[1]
    local pair=station and pairs and pairs[station.unit_number]
    if not (station and station.valid and pair and pair.priest
        and pair.priest.valid and pair.station==station) then
      error("SAVE_RELOAD_PAIR_MISSING: "..spec.name)
    end
    snapshot[#snapshot+1]={
      name=spec.name,x=spec.x,y=spec.y,
      station_unit=station.unit_number,
      priest_unit=pair.priest.unit_number,
    }
  end
  if #snapshot~=#stations then
    error("SAVE_RELOAD_PAIR_COUNT: "..#snapshot)
  end
  state.save_reload_pairs=snapshot
  state.save_reload_requested=true
  state.save_reload_tick=game.tick
  local ok,err=pcall(function()
    game.auto_save("tech-priests-ci-persistence")
  end)
  if not ok then
    error("SAVE_RELOAD_ENGINE_SAVE_FAILED: "..tostring(err))
  end
  emit("SAVE_RELOAD_REQUESTED tick="..game.tick..
    " pairs="..#snapshot.." state=primitive-identities-preserved")
end

local function verify_save_reload_checkpoint(state)
  if not (state.save_reload_requested
      and type(state.save_reload_pairs)=="table"
      and #state.save_reload_pairs==#stations) then
    error("SAVE_RELOAD_PERSISTED_STATE_MISSING")
  end
  local surface=game.surfaces[1]
  local pairs=storage.tech_priests and storage.tech_priests.pairs_by_station
  for _,record in ipairs(state.save_reload_pairs) do
    local station=surface.find_entities_filtered{
      name=record.name,position={record.x,record.y},radius=2,
      force=game.forces.player}
    local found=nil
    for _,candidate in ipairs(station or {}) do
      if candidate.unit_number==record.station_unit then
        found=candidate
        break
      end
    end
    local pair=found and pairs and pairs[record.station_unit]
    if not (found and found.valid and pair and pair.station==found
        and pair.priest and pair.priest.valid
        and pair.priest.unit_number==record.priest_unit) then
      error("SAVE_RELOAD_PAIR_IDENTITY_CHANGED: "..record.name)
    end
  end
  state.save_reload_verified=true
  emit("PASS SAVE_RELOAD_VERIFIED tick="..game.tick..
    " pairs="..#state.save_reload_pairs..
    " source_save_tick="..tostring(state.save_reload_tick)..
    " persisted_stations=4 persisted_priests=4")
end

-- Real Factorio 2.0 engine-owned LuaInventory persistence probe (CI only).
-- This runs only in the isolated separate-process save/reload fixture, never
-- in the 123k industrial/combat benchmark or a distributed mod build.
-- A single real station item is temporarily inserted into the CI station's
-- actual chest, picked up by its living priest, persisted across an engine
-- save/restart, debited/refunded through the real cargo API, returned to the
-- same chest, and then removed as CI fixture stock. Net fixture delta = 0.
local CARGO_ENGINE_PROBE_ID="ci-cargo-persistence-0828"
local CARGO_ENGINE_PROBE_ITEM="junior-cogitator-station"
local function cargo_engine_context()
  local station=prestock_station(stations[1])
  local tp=storage.tech_priests
  local pair=station and tp.pairs_by_station
    and tp.pairs_by_station[station.unit_number]
  if not (station and station.valid and pair and pair.priest
      and pair.priest.valid and pair.station==station) then
    error("CARGO_ENGINE_PAIR_UNAVAILABLE")
  end
  local source=station.get_inventory(defines.inventory.chest)
  if not (source and source.valid) then error("CARGO_ENGINE_CHEST_UNAVAILABLE") end
  local rec={id=CARGO_ENGINE_PROBE_ID,station_item=CARGO_ENGINE_PROBE_ITEM,
    ghost_position={x=station.position.x,y=station.position.y}}
  return pair,source,rec
end
local function cargo_engine_at_station(pair)
  local a,b=pair.priest.position,pair.station.position
  return a and b and (a.x-b.x)^2+(a.y-b.y)^2<=25
end
local function cargo_engine_request_return(pair)
  if type(_G.return_to_station)=="function" then
    pcall(_G.return_to_station,pair.priest,pair.station)
  end
end
local function cargo_engine_prepare(state)
  if state.cargo_engine_prepared then return end
  local pair,source,rec=cargo_engine_context()
  if not cargo_engine_at_station(pair) then
    cargo_engine_request_return(pair)
    return
  end
  local Cargo=CARGO_ENGINE_0824
  if Cargo.has_record(rec) then error("CARGO_ENGINE_PREEXISTING_HOLD") end
  local before=source.get_item_count(rec.station_item)
  if source.insert{name=rec.station_item,count=1}~=1 then
    error("CARGO_ENGINE_FIXTURE_INSERT_REFUSED")
  end
  local ok,why=Cargo.pickup(pair,rec,source)
  if not ok then
    -- A failed pickup may have mutated either real inventory. Do not
    -- destroy or mint an item to hide a custody error.
    error("CARGO_ENGINE_PICKUP_FAILED: "..tostring(why))
  end
  local hold=Cargo.get(pair,rec)
  if not (hold and hold.inventory and hold.inventory.valid
      and hold.status=="carrying"
      and hold.inventory.get_item_count(rec.station_item)==1
      and source.get_item_count(rec.station_item)==before) then
    error("CARGO_ENGINE_PICKUP_ACCOUNTING_INVALID")
  end
  state.cargo_engine_prepared={
    station_unit=pair.station.unit_number,priest_unit=pair.priest.unit_number,
    prepared_tick=game.tick
  }
  emit("CARGO_ENGINE_PREPARED tick="..game.tick..
    " station="..pair.station.unit_number..
    " priest="..pair.priest.unit_number..
    " chest_delta=0 held=1")
end
local function cargo_engine_verify_after_reload(state)
  if state.cargo_engine_verified then return end
  local snapshot=state.cargo_engine_prepared
  if not snapshot then error("CARGO_ENGINE_PERSISTED_SNAPSHOT_MISSING") end
  local pair,source,rec=cargo_engine_context()
  if pair.station.unit_number~=snapshot.station_unit
      or pair.priest.unit_number~=snapshot.priest_unit then
    error("CARGO_ENGINE_OWNER_CHANGED_ACROSS_RELOAD")
  end
  local Cargo=CARGO_ENGINE_0824
  local hold,reason=Cargo.get(pair,rec)
  if not (hold and hold.inventory and hold.inventory.valid
      and hold.status=="carrying"
      and hold.inventory.get_item_count(rec.station_item)==1) then
    error("CARGO_ENGINE_HOLD_NOT_PERSISTED: "..tostring(reason))
  end
  if not cargo_engine_at_station(pair) then
    cargo_engine_request_return(pair)
    return
  end
  local source_before=source.get_item_count(rec.station_item)
  local started,why=Cargo.begin_build(pair,rec)
  if not started then error("CARGO_ENGINE_DEBIT_FAILED: "..tostring(why)) end
  if hold.inventory.get_item_count(rec.station_item)~=0 then
    error("CARGO_ENGINE_DEBIT_DID_NOT_REMOVE_ITEM")
  end
  local refunded,refund_reason=Cargo.build_failed(pair,rec)
  if not refunded then
    error("CARGO_ENGINE_REFUND_FAILED: "..tostring(refund_reason))
  end
  if hold.inventory.get_item_count(rec.station_item)~=1 then
    error("CARGO_ENGINE_REFUND_COUNT_INVALID")
  end
  local returned,return_reason=Cargo.return_unused(pair,rec,source)
  if not returned then
    error("CARGO_ENGINE_RETURN_FAILED: "..tostring(return_reason))
  end
  if Cargo.has_record(rec)
      or source.get_item_count(rec.station_item)~=source_before+1 then
    error("CARGO_ENGINE_RETURN_ACCOUNTING_INVALID")
  end
  -- Remove ONLY the extra CI fixture item, restoring the live chest count.
  if source.remove{name=rec.station_item,count=1}~=1
      or source.get_item_count(rec.station_item)~=source_before then
    error("CARGO_ENGINE_FIXTURE_CLEANUP_FAILED")
  end
  state.cargo_engine_verified=true
  emit("PASS CARGO_ENGINE_SAVE_RELOAD tick="..game.tick..
    " source_save_tick="..tostring(state.save_reload_tick)..
    " station="..snapshot.station_unit.." priest="..snapshot.priest_unit..
    " held=0 net_fixture_delta=0")
end

-- Isolated real-engine death/re-imprint custody probe (0830). This begins
-- only AFTER the independent save/reload cargo check has passed. The engine
-- kills a real priest, the canonical lifecycle must strand its real inventory,
-- and the newly re-imprinted priest must walk to the death site to reclaim it.
-- No artificial respawn, station item minting, or inventory ownership override.
local CARGO_DEATH_PROBE_ID="ci-cargo-death-0830"
local function cargo_death_record(pair)
  return {id=CARGO_DEATH_PROBE_ID,station_item=CARGO_ENGINE_PROBE_ITEM,
    ghost_position={x=pair.station.position.x,y=pair.station.position.y}}
end
local function cargo_engine_death_prepare(state)
  if state.cargo_engine_death_prepared then return end
  local pair,source=cargo_engine_context()
  if not cargo_engine_at_station(pair) then
    cargo_engine_request_return(pair)
    return
  end
  local Cargo=CARGO_ENGINE_0824
  local rec=cargo_death_record(pair)
  if Cargo.has_record(rec) then error("CARGO_DEATH_PREEXISTING_HOLD") end
  local before=source.get_item_count(rec.station_item)
  if source.insert{name=rec.station_item,count=1}~=1 then
    error("CARGO_DEATH_FIXTURE_INSERT_REFUSED")
  end
  local picked,reason=Cargo.pickup(pair,rec,source)
  if not picked then error("CARGO_DEATH_PICKUP_FAILED: "..tostring(reason)) end
  local hold=Cargo.get(pair,rec)
  if not (hold and hold.inventory and hold.inventory.valid
      and hold.inventory.get_item_count(rec.station_item)==1
      and source.get_item_count(rec.station_item)==before) then
    error("CARGO_DEATH_PICKUP_COUNT_INVALID")
  end
  local priest=pair.priest
  local old_unit=priest.unit_number
  local position={x=priest.position.x,y=priest.position.y}
  local observed,why=Cargo.observe_carrier(pair,rec)
  if not observed then error("CARGO_DEATH_POSITION_NOT_OBSERVED: "..tostring(why)) end
  -- Verify the *real engine* will deliver death to canonical 0499, not
  -- merely to an unrelated script handler or an overwritten dispatcher.
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local delivery=registry and registry.event_delivery_status
    and registry.event_delivery_status(defines.events.on_entity_died)
  local registered=false
  local routes=registry and registry.get_event_routes and registry.get_event_routes() or {}
  for _,route in ipairs(routes[tostring(defines.events.on_entity_died)] or {}) do
    if route.owner=="priest_lifecycle_authority_0499" then registered=true end
  end
  if not (delivery and delivery.verified and not delivery.filter_present
      and registered) then
    error("CARGO_DEATH_EVENT_DISPATCH_UNVERIFIED")
  end
  -- CI-only engine death; ordinary production priests remain protected.
  priest.destructible=true
  local died=priest.die(game.forces.enemy)
  if priest.valid or died==false then error("CARGO_DEATH_ENGINE_REFUSED") end
  local stranded=storage.tech_priests.station_cargo_0824[rec.id]
  if not (stranded and stranded.status=="stranded"
      and stranded.lost_priest_unit==old_unit
      and stranded.inventory and stranded.inventory.valid
      and stranded.inventory.get_item_count(rec.station_item)==1
      and stranded.stranded_position) then
    error("CARGO_DEATH_LIFECYCLE_DID_NOT_STRAND_ITEM")
  end
  if source.get_item_count(rec.station_item)~=before then
    error("CARGO_DEATH_SOURCE_COUNT_CHANGED")
  end
  state.cargo_engine_death_prepared={
    station_unit=pair.station.unit_number,old_priest_unit=old_unit,
    source_before=before,started_tick=game.tick,
    death_position=position,
  }
  -- Checkpoint the *stranded* engine-owned inventory before re-imprinting.
  -- The independent runner must restart Factorio from this exact save.
  local saved,save_error=pcall(function()
    game.auto_save("tech-priests-ci-stranded")
  end)
  if not saved then
    error("CARGO_DEATH_STRANDED_SAVE_REFUSED: "..tostring(save_error))
  end
  state.cargo_engine_death_save_requested=true
  emit("CARGO_ENGINE_DEATH_SAVE_REQUESTED tick="..game.tick..
    " old_priest="..old_unit.." held=1")
  emit("CARGO_ENGINE_DEATH_STRANDED tick="..game.tick..
    " station="..pair.station.unit_number.." old_priest="..old_unit..
    " held=1 chest_delta=0")
end
local function cargo_engine_verify_stranded_reload(state)
  if state.cargo_engine_death_save_verified then return end
  local snapshot=state.cargo_engine_death_prepared
  if not (snapshot and state.cargo_engine_death_save_requested) then
    error("CARGO_DEATH_STRANDED_SAVE_STATE_MISSING")
  end
  local station=prestock_station(stations[1])
  local tp=storage.tech_priests
  local pair=station and tp.pairs_by_station
    and tp.pairs_by_station[station.unit_number]
  local hold=tp.station_cargo_0824
    and tp.station_cargo_0824[CARGO_DEATH_PROBE_ID]
  local source=station and station.get_inventory(defines.inventory.chest)
  if not (station and station.valid
      and station.unit_number==snapshot.station_unit
      and pair and pair.station==station
      and hold and hold.status=="stranded"
      and hold.lost_priest_unit==snapshot.old_priest_unit
      and hold.inventory and hold.inventory.valid
      and hold.inventory.get_item_count(CARGO_ENGINE_PROBE_ITEM)==1
      and hold.stranded_position and source and source.valid
      and source.get_item_count(CARGO_ENGINE_PROBE_ITEM)==snapshot.source_before) then
    error("CARGO_DEATH_STRANDED_RELOAD_CUSTODY_INVALID")
  end
  state.cargo_engine_death_save_verified=true
  emit("PASS CARGO_ENGINE_STRANDED_RELOAD tick="..game.tick..
    " station="..snapshot.station_unit..
    " old_priest="..snapshot.old_priest_unit..
    " held=1 chest_delta=0")
end

local function cargo_engine_death_recover(state)
  if state.cargo_engine_death_verified then return end
  local snapshot=state.cargo_engine_death_prepared
  if not snapshot then error("CARGO_DEATH_SNAPSHOT_MISSING") end
  local station=prestock_station(stations[1])
  local tp=storage.tech_priests
  local pair=station and tp.pairs_by_station
    and tp.pairs_by_station[station.unit_number]
  if not (station and station.valid and pair and pair.station==station
      and station.unit_number==snapshot.station_unit) then
    error("CARGO_DEATH_STATION_IDENTITY_CHANGED")
  end
  if not (pair.priest and pair.priest.valid) then return end
  if pair.priest.unit_number==snapshot.old_priest_unit then
    error("CARGO_DEATH_OLD_PRIEST_REUSED")
  end
  if pair.reimprint_0298 and pair.reimprint_0298.active then return end
  local source=station.get_inventory(defines.inventory.chest)
  if not (source and source.valid) then error("CARGO_DEATH_CHEST_MISSING") end
  local Cargo=CARGO_ENGINE_0824
  local rec=cargo_death_record(pair)
  if not state.cargo_engine_death_reclaimed then
    local site,reason=Cargo.stranded_for(pair,rec)
    if not site then error("CARGO_DEATH_STRANDED_CUSTODY_LOST: "..tostring(reason)) end
    local pos=pair.priest.position
    if (pos.x-site.x)^2+(pos.y-site.y)^2>25 then
      -- Negative engine assertion: custody cannot transfer across distance.
      local premature,denial=Cargo.reclaim_stranded(pair,rec)
      if premature or denial~="replacement-priest-not-at-death-site" then
        error("CARGO_DEATH_REMOTE_RECLAIM_ACCEPTED: "..tostring(denial))
      end
      local command={type=defines.command.go_to_location,destination=site,
        radius=2,distraction=defines.distraction.none}
      if type(issue_priest_command)=="function" then
        issue_priest_command(pair.priest,command)
      else
        pair.priest.set_command(command)
      end
      return
    end
    local reclaimed,why=Cargo.reclaim_stranded(pair,rec)
    if not reclaimed then error("CARGO_DEATH_RECLAIM_FAILED: "..tostring(why)) end
    state.cargo_engine_death_reclaimed=true
  end
  local hold=Cargo.get(pair,rec)
  if not (hold and hold.status=="carrying" and hold.inventory.valid
      and hold.inventory.get_item_count(rec.station_item)==1) then
    error("CARGO_DEATH_RECLAIM_COUNT_INVALID")
  end
  if not cargo_engine_at_station(pair) then
    cargo_engine_request_return(pair)
    return
  end
  local returned,return_reason=Cargo.return_unused(pair,rec,source)
  if not returned then error("CARGO_DEATH_RETURN_FAILED: "..tostring(return_reason)) end
  if Cargo.has_record(rec)
      or source.get_item_count(rec.station_item)~=snapshot.source_before+1 then
    error("CARGO_DEATH_RETURN_COUNT_INVALID")
  end
  if source.remove{name=rec.station_item,count=1}~=1
      or source.get_item_count(rec.station_item)~=snapshot.source_before then
    error("CARGO_DEATH_FIXTURE_CLEANUP_FAILED")
  end
  state.cargo_engine_death_verified=true
  emit("PASS CARGO_ENGINE_DEATH_REIMPRINT tick="..game.tick..
    " station="..snapshot.station_unit..
    " old_priest="..snapshot.old_priest_unit..
    " new_priest="..pair.priest.unit_number..
    " held=0 net_fixture_delta=0")
end


-- 0835: exercise the live 0256 executor against two isolated, genuine
-- paired Junior stations. Setup stations are CI fixtures, NOT resource-acquisition
-- credit. The recovered item must come exclusively from LuaEntity.mine into the
-- worker's engine-owned inventory, then be spent at a real ghost. The old
-- station's living priest must be rebound to the newly constructed station.
local RELOCATION_ENGINE_ID="ci-physical-station-recycling-0835"
local RELOCATION_ENGINE_PARENT={x=512,y=0}
local RELOCATION_ENGINE_CHILD={x=524,y=0}
local RELOCATION_ENGINE_TARGET={x=532.5,y=0.5}
local function relocation_engine_place(state)
  if state.relocation_engine then return end
  local surface=game.surfaces[1]
  surface.request_to_generate_chunks({x=522,y=0},3)
  surface.force_generate_chunk_requests()
  local area={{496,-16},{552,16}}
  for _,entity in pairs(surface.find_entities_filtered{area=area}) do
    if entity.valid and (entity.type=="resource" or entity.type=="tree"
        or entity.type=="simple-entity" or entity.type=="cliff") then
      entity.destroy()
    elseif entity.valid and entity.force==game.forces.player then
      error("RELOCATION_ENGINE_SETUP_AREA_OCCUPIED: "..entity.name)
    end
  end
  local tiles={}
  for x=496,551 do for y=-16,15 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  local parent=surface.create_entity{
    name=CARGO_ENGINE_PROBE_ITEM,position=RELOCATION_ENGINE_PARENT,
    force=game.forces.player,raise_built=true}
  local child=surface.create_entity{
    name=CARGO_ENGINE_PROBE_ITEM,position=RELOCATION_ENGINE_CHILD,
    force=game.forces.player,raise_built=true}
  if not (parent and parent.valid and child and child.valid) then
    error("RELOCATION_ENGINE_SETUP_STATIONS_NOT_BUILT")
  end
  -- Reserve this actual 0256 construction writ before ordinary planning
  -- can allocate the newly created worker. No item or station is credited.
  -- The executor cannot run the writ until real pairing and custody pass.
  local expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not (expansion and type(expansion.ensure_state)=="function") then
    error("RELOCATION_ENGINE_WRIT_INITIALIZER_UNAVAILABLE")
  end
  -- The 0256 registries are normally initialized lazily by the first
  -- planner/executor call. This worker must be reserved BEFORE that call;
  -- initialize through the canonical 0256 owner, not parallel CI tables.
  expansion.ensure_state()
  local tp=storage.tech_priests
  if not (tp and type(tp.station_expansion_0256)=="table"
      and type(tp.station_expansion_by_worker_0256)=="table"
      and type(tp.station_expansion_next_id_0256)=="number") then
    error("RELOCATION_ENGINE_WRIT_REGISTRY_UNAVAILABLE")
  end
  if tp.station_expansion_by_worker_0256[parent.unit_number] then
    error("RELOCATION_ENGINE_WORKER_BUSY_AT_SETUP")
  end
  local reservation_id=tp.station_expansion_next_id_0256
  tp.station_expansion_next_id_0256=reservation_id+1
  tp.station_expansion_0256[reservation_id]={
    id=reservation_id,status="awaiting-pairing",
    requester_station_unit=parent.unit_number,
    worker_station_unit=parent.unit_number,
    station_item=CARGO_ENGINE_PROBE_ITEM,
    station_entity=CARGO_ENGINE_PROBE_ITEM,
    blocked_item="ci-physical-relocation",
    phase="awaiting-fixture-pairing",
    created_tick=game.tick,updated_tick=game.tick}
  tp.station_expansion_by_worker_0256[parent.unit_number]=reservation_id
  state.relocation_engine={
    phase="pairing",parent_unit=parent.unit_number,old_station_unit=child.unit_number,
    record_id=reservation_id,placed_tick=game.tick,
    ghost_position={x=RELOCATION_ENGINE_TARGET.x,y=RELOCATION_ENGINE_TARGET.y}}
  emit("RELOCATION_ENGINE_WORKER_RESERVED tick="..game.tick..
    " worker="..parent.unit_number.." writ="..reservation_id)
  emit("RELOCATION_ENGINE_SETUP tick="..game.tick..
    " parent="..parent.unit_number.." old_station="..child.unit_number..
    " source=ci-station-fixture-not-production-credit")
end
local function relocation_engine_service(state)
  local test=state.relocation_engine
  if not test or test.phase=="complete" then return end
  if game.tick-test.placed_tick>60*150 then
    error("RELOCATION_ENGINE_TIMEOUT phase="..tostring(test.phase)..
      " executor="..tostring(test.last_phase))
  end
  local tp=storage.tech_priests
  local pairs=tp.pairs_by_station or {}
  local parent=pairs[test.parent_unit]
  if test.phase=="pairing" then
    local child=pairs[test.old_station_unit]
    if not (parent and parent.station and parent.station.valid
        and parent.priest and parent.priest.valid and child
        and child.station and child.station.valid
        and child.priest and child.priest.valid) then return end
    local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
    local recovery=rawget(_G,"TechPriestsStationRecycling0822")
    local relocation=rawget(_G,"TechPriestsStationRelocation0823")
    if not (hierarchy and recovery and relocation) then
      error("RELOCATION_ENGINE_CANONICAL_AUTHORITY_MISSING")
    end
    hierarchy.rebuild("forced")
    local peers=hierarchy.peers(parent)
    local peer=false
    for _,pair in ipairs(peers) do if pair==child then peer=true end end
    if not peer then error("RELOCATION_ENGINE_PEER_LINK_MISSING") end
    local proxy=child.proxy
    if not (proxy and proxy.valid and proxy.unit_number) then
      error("RELOCATION_ENGINE_PRIEST_PROXY_NOT_OBSERVABLE")
    end
    test.old_proxy_unit=proxy.unit_number
    emit("RELOCATION_ENGINE_HELPER_CUSTODY proxy="..test.old_proxy_unit..
      " requester="..tostring(child.logistic_requester and child.logistic_requester.valid)..
      " return_cache="..tostring(child.logistic_return_cache and child.logistic_return_cache.valid))
    local safe,reason=recovery.check_candidate(parent,child,CARGO_ENGINE_PROBE_ITEM)
    if not safe then error("RELOCATION_ENGINE_PREFLIGHT_REFUSED: "..tostring(reason)) end
    local source=parent.station.get_inventory(defines.inventory.chest)
    if not (source and source.valid and
        source.get_item_count(CARGO_ENGINE_PROBE_ITEM)==0) then
      error("RELOCATION_ENGINE_SOURCE_NOT_EMPTY")
    end
    local ghost=parent.station.surface.create_entity{
      name="entity-ghost",inner_name=CARGO_ENGINE_PROBE_ITEM,
      position=test.ghost_position,force=parent.station.force,expires=false}
    if not (ghost and ghost.valid and ghost.ghost_name==CARGO_ENGINE_PROBE_ITEM) then
      error("RELOCATION_ENGINE_GHOST_NOT_CREATED")
    end
    -- Factorio may align a station ghost to its actual entity grid. The
    -- relocation lease must reference that observed physical entity, not
    -- the requested placement coordinates. Refuse an unexpected displacement.
    local requested=test.ghost_position
    local observed=ghost.position
    local offset_sq=(observed.x-requested.x)^2+(observed.y-requested.y)^2
    if offset_sq>2.25 then
      error("RELOCATION_ENGINE_GHOST_UNEXPECTED_DISPLACEMENT: "..tostring(offset_sq))
    end
    if ghost.surface~=parent.station.surface or ghost.force~=parent.station.force then
      error("RELOCATION_ENGINE_GHOST_WRONG_AUTHORITY")
    end
    local actual_ghost_position={x=observed.x,y=observed.y}
    test.ghost_position=actual_ghost_position
    emit("RELOCATION_ENGINE_GHOST_POSITION_VERIFIED tick="..game.tick..
      " ghost="..ghost.unit_number.." offset_sq="..offset_sq)
    local id=test.record_id
    local rec=tp.station_expansion_0256 and tp.station_expansion_0256[id]
    if not (rec and rec.id==id and rec.status=="awaiting-pairing"
        and rec.worker_station_unit==test.parent_unit
        and rec.requester_station_unit==test.parent_unit
        and tp.station_expansion_by_worker_0256[test.parent_unit]==id) then
      error("RELOCATION_ENGINE_RESERVATION_STOLEN")
    end
    -- Activate only after the actual Junior-peer hierarchy and the complete
    -- 0822 custody preflight pass. Never overwrite another worker's writ.
    rec.status="active"
    rec.requester_rank=1
    rec.required_worker_rank=1
    rec.commander_bootstrap=true
    rec.ghost_unit=ghost.unit_number
    rec.ghost_position={x=actual_ghost_position.x,y=actual_ghost_position.y}
    rec.phase="assigned"
    rec.updated_tick=game.tick
    rec.next_retry_tick=game.tick+900
    -- Reserve the already-preflighted real leaf BEFORE ordinary 0640 planning
    -- can assign new ingredient-acquisition work on the following tick.
    -- The reservation is not permission to mine a busy or occupied station.
    rec.recycling_candidate_unit_0822=child.station.unit_number
    rec.recycling_preflight_0822="eligible-for-lifecycle-lease"
    rec.next_recycle_probe_tick_0822=game.tick+recovery.probe_interval
    if recovery.reservation_for(child)~=rec then
      error("RELOCATION_ENGINE_CANDIDATE_RESERVATION_NOT_VISIBLE")
    end
    emit("RELOCATION_ENGINE_CANDIDATE_RESERVED tick="..game.tick..
      " candidate="..child.station.unit_number.." writ="..id)
    -- Exercise the live 0640 authority before it can schedule a competing
    -- 0647 material request on the construction worker (distinct from leaf).
    local governor=rawget(_G,"TechPriestsInfrastructureFirstGovernor0640")
    if not (governor and type(governor.service_pair)=="function") then
      error("RELOCATION_ENGINE_BUILDER_GOVERNOR_MISSING")
    end
    local assigned,block_reason=governor.service_pair(
      parent,"physical-relocation-worker-reservation-engine")
    if assigned or block_reason~="physical-station-builder-reserved"
        or parent.infrastructure_recipe_request_0647~=nil then
      error("RELOCATION_ENGINE_BUILDER_NOT_RESERVED_BEFORE_MINE: "..
        tostring(block_reason))
    end
    emit("RELOCATION_ENGINE_BUILDER_RESERVED tick="..game.tick..
      " stage=preflight worker="..test.parent_unit.." writ="..id)
    parent.station_expansion_0256=rec
    test.old_priest_unit=child.priest.unit_number
    local dx=parent.priest.position.x-child.station.position.x
    local dy=parent.priest.position.y-child.station.position.y
    if dx*dx+dy*dy<=25 then error("RELOCATION_ENGINE_REMOTE_NEGATIVE_NOT_APPLICABLE") end
    local mined,denial=relocation.try_recover_carried(parent,child,rec,ghost)
    if mined or denial~="worker-not-at-recovery-site"
        or not child.station.valid or CARGO_ENGINE_0824.has_record(rec) then
      error("RELOCATION_ENGINE_REMOTE_MINE_NOT_DENIED: "..tostring(denial))
    end
    test.phase="active"
    emit("RELOCATION_ENGINE_PREFLIGHT_PASS tick="..game.tick..
      " old_station="..test.old_station_unit..
      " old_priest="..test.old_priest_unit.." ghost="..ghost.unit_number..
      " worker="..test.parent_unit.." writ="..id..
      " remote_mining_denied=true")
    return
  end
  if not (parent and parent.station and parent.station.valid
      and parent.priest and parent.priest.valid) then
    error("RELOCATION_ENGINE_WORKER_LOST")
  end
  local rec=tp.station_expansion_0256 and tp.station_expansion_0256[test.record_id]
  if not rec then error("RELOCATION_ENGINE_WRIT_LOST") end
  local executor=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not (executor and executor.service_station_expansion_assignment) then
    error("RELOCATION_ENGINE_EXECUTOR_MISSING")
  end
  executor.service_station_expansion_assignment(parent)
  if rec.phase~=test.last_phase then
    test.last_phase=rec.phase
    emit("RELOCATION_ENGINE_PHASE tick="..game.tick.." phase="..tostring(rec.phase))
    if rec.phase=="station-recovery-blocked" then
      local blocked=pairs[rec.recycling_candidate_unit_0822]
      emit("RELOCATION_ENGINE_RECOVERY_REFUSAL tick="..game.tick..
        " candidate="..tostring(rec.recycling_candidate_unit_0822)..
        " reason="..tostring(rec.recycling_preflight_0822)..
        " candidate_mode="..tostring(blocked and blocked.mode)..
        " direct_acquisition="..tostring(blocked and blocked.direct_acquisition_task_0336~=nil)..
        " active_task="..tostring(blocked and blocked.active_task~=nil))
    end
  end
  -- The fixture deliberately has zero spare station items. Once physical
  -- recovery has been selected, an acquisition fallback is a test failure,
  -- not a legitimate alternative to carrying the original mined item.
  if rec.phase=="moving-to-physical-station-recovery" then
    test.recovery_move_observed=true
  end
  if not test.mined and test.recovery_move_observed
      and rec.phase=="acquiring-station-item" then
    error("RELOCATION_ENGINE_STARVED_RECOVERY_FELL_BACK_TO_ACQUISITION")
  end
  if rec.status=="failed" then error("RELOCATION_ENGINE_EXECUTOR_FAILED: "..tostring(rec.phase)) end
  local lease=rawget(_G,"TechPriestsStationRelocation0823")
  local cargo=CARGO_ENGINE_0824.get(parent,rec)
  if not test.mined and not pairs[test.old_station_unit]
      and cargo and cargo.inventory and cargo.inventory.valid
      and cargo.inventory.get_item_count(CARGO_ENGINE_PROBE_ITEM)==1 then
    local survivor=tp.pairs_by_priest and tp.pairs_by_priest[test.old_priest_unit]
    if not (survivor and survivor.priest and survivor.priest.valid
        and survivor.priest.unit_number==test.old_priest_unit
        and lease.pending_for_record(rec)) then
      error("RELOCATION_ENGINE_MINED_PRIEST_OR_LEASE_LOST")
    end
    local dx=parent.priest.position.x-RELOCATION_ENGINE_CHILD.x
    local dy=parent.priest.position.y-RELOCATION_ENGINE_CHILD.y
    if dx*dx+dy*dy>25 then error("RELOCATION_ENGINE_REMOTE_ITEM_TRANSFER") end
    test.mined=true
    emit("RELOCATION_ENGINE_MINED tick="..game.tick..
      " old_station="..test.old_station_unit.." old_priest="..test.old_priest_unit..
      " carried=1")
  end
  if test.mined and not test.carrier_guard_verified
      and rec.recycling_candidate_unit_0822==nil then
    -- The 0822 candidate has disappeared after real mining; the persistent
    -- engine-owned 0824 cargo must continue to reserve this same builder.
    local governor=rawget(_G,"TechPriestsInfrastructureFirstGovernor0640")
    local assigned,reason=governor.service_pair(
      parent,"physical-relocation-carrier-reservation-engine")
    if assigned or reason~="physical-station-builder-reserved"
        or parent.infrastructure_recipe_request_0647~=nil then
      error("RELOCATION_ENGINE_CARRIER_SCHEDULER_STOLE_WRIT: "..tostring(reason))
    end
    test.carrier_guard_verified=true
    emit("RELOCATION_ENGINE_BUILDER_RESERVED tick="..game.tick..
      " stage=carrying worker="..test.parent_unit.." writ="..test.record_id)
  end
  if test.mined and game.tick-(test.last_carrier_trace_tick or 0)>=600 then
    test.last_carrier_trace_tick=game.tick
    local target=rec.ghost_position or test.ghost_position
    local position=parent.priest.position
    local dx=position.x-target.x
    local dy=position.y-target.y
    emit("RELOCATION_ENGINE_CARRIER_PROGRESS tick="..game.tick..
      " phase="..tostring(rec.phase)..
      " distance_sq="..tostring(dx*dx+dy*dy)..
      " worker_mode="..tostring(parent.mode)..
      " 0647="..tostring(parent.infrastructure_recipe_request_0647~=nil)..
      " held="..tostring(cargo and cargo.inventory and cargo.inventory.valid
        and cargo.inventory.get_item_count(CARGO_ENGINE_PROBE_ITEM) or "unobserved"))
  end
  if rec.status~="complete" then return end
  local built=parent.station.surface.find_entities_filtered{
    name=CARGO_ENGINE_PROBE_ITEM,position=test.ghost_position,radius=1,
    force=parent.station.force}[1]
  local rebound=built and pairs[built.unit_number]
  local source=parent.station.get_inventory(defines.inventory.chest)
  if not (test.mined and built and built.valid
      and built.unit_number~=test.old_station_unit
      and rebound and rebound.station==built
      and rebound.priest and rebound.priest.valid
      and rebound.priest.unit_number==test.old_priest_unit
      and rebound.proxy and rebound.proxy.valid
      and rebound.proxy.unit_number==test.old_proxy_unit
      and pairs[test.old_station_unit]==nil
      and source and source.valid
      and source.get_item_count(CARGO_ENGINE_PROBE_ITEM)==0
      and not CARGO_ENGINE_0824.has_record(rec)
      and not lease.pending_for_record(rec)) then
    error("RELOCATION_ENGINE_REBIND_OR_ACCOUNTING_FAILED")
  end
  local old_sites=parent.station.surface.find_entities_filtered{
    name=CARGO_ENGINE_PROBE_ITEM,position=RELOCATION_ENGINE_CHILD,
    radius=1,force=parent.station.force}
  local ghosts=parent.station.surface.find_entities_filtered{
    name="entity-ghost",ghost_name=CARGO_ENGINE_PROBE_ITEM,
    position=test.ghost_position,radius=1,force=parent.station.force}
  local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not (hierarchy and hierarchy.rebuild and hierarchy.peers) then
    error("RELOCATION_ENGINE_HIERARCHY_AUTHORITY_LOST")
  end
  hierarchy.rebuild("forced")
  local peer_rebound=false
  for _,peer in ipairs(hierarchy.peers(parent)) do
    if peer==rebound then peer_rebound=true end
  end
  if #old_sites~=0 or #ghosts~=0 or not peer_rebound then
    error("RELOCATION_ENGINE_OLD_SITE_GHOST_OR_PEER_LEAK")
  end
  local dx=parent.priest.position.x-test.ghost_position.x
  local dy=parent.priest.position.y-test.ghost_position.y
  if dx*dx+dy*dy>25 then error("RELOCATION_ENGINE_BUILDER_NOT_AT_GHOST") end
  test.phase="complete"
  emit("PASS RELOCATION_ENGINE_PHYSICAL tick="..game.tick..
    " old_station="..test.old_station_unit.." new_station="..built.unit_number..
    " priest="..test.old_priest_unit.." held=0 net_station_delta=0")
end


-- CI-only Method I ore-return probe. Stations below are physical test
-- fixtures, NOT evidence of autonomous station construction. Ore is selected
-- exclusively from untouched, naturally generated terrain; no ore is spawned.
-- The production 0820 hierarchy and 0837 courier remain the only authorities
-- for route verification, mining, movement, and counted inventory transfers.
local ORE_ENGINE_STATIONS={
  "planetary-magos-cogitator-station","senior-cogitator-station",
  "intermediate-cogitator-station","junior-cogitator-station"}
local ORE_ENGINE_DIRECTIONS={{1,0},{-1,0},{0,1},{0,-1}}
-- The ore-courier and relocation probes run concurrently in the same
-- isolated Factorio save. Never let a new ore-chain Junior become an extra
-- peer/dependent of the leaf being physically recovered. That would make
-- the real 0822 custody preflight (correctly) refuse the mine.
-- The canonical 0480 hierarchy links Juniors within max_link_distance,
-- even if they belong to otherwise independent fixture missions. The old
-- 160-tile guard was inside its 220-tile peer radius and caused the real 0822
-- leaf-recovery preflight to refuse an unexpected third peer. Derive a
-- buffered boundary from the installed hierarchy rather than guessing.
local function ore_engine_isolation_sq()
  local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local peer_reach=hierarchy and tonumber(hierarchy.max_link_distance)
  if not (peer_reach and peer_reach>0) then
    error("ORE_ENGINE_HIERARCHY_PEER_REACH_UNAVAILABLE")
  end
  return math.ceil(peer_reach+128)^2,peer_reach
end
local function ore_engine_relocation_separation_sq(pos)
  local nearest=math.huge
  for _,site in ipairs({
      RELOCATION_ENGINE_PARENT,RELOCATION_ENGINE_CHILD,RELOCATION_ENGINE_TARGET}) do
    local dx,dy=pos.x-site.x,pos.y-site.y
    nearest=math.min(nearest,dx*dx+dy*dy)
  end
  return nearest
end
local function ore_engine_place(state)
  if state.ore_engine then return end
  -- Negative controls: the isolation guard must reject every recovery
  -- authority site, not merely emit a reassuring separation marker.
  for _,site in ipairs({
      RELOCATION_ENGINE_PARENT,RELOCATION_ENGINE_CHILD,RELOCATION_ENGINE_TARGET}) do
    if ore_engine_relocation_separation_sq(site)~=0 then
      error("ORE_ENGINE_RELOCATION_ISOLATION_NEGATIVE_CONTROL_FAILED")
    end
  end
  local required_sq,peer_reach=ore_engine_isolation_sq()
  if required_sq<=peer_reach*peer_reach then
    error("ORE_ENGINE_ISOLATION_WITHIN_PEER_REACH")
  end
  -- Negative boundary control: a foreign Junior positioned at the
  -- hierarchy's exact peer reach must be rejected by the site guard.
  -- This would have caught the former 160-tile/220-tile mismatch.
  for _,site in ipairs({
      RELOCATION_ENGINE_PARENT,RELOCATION_ENGINE_CHILD,RELOCATION_ENGINE_TARGET}) do
    local within_peer={x=site.x+peer_reach,y=site.y}
    if ore_engine_relocation_separation_sq(within_peer)>=required_sq then
      error("ORE_ENGINE_PEER_BOUNDARY_NEGATIVE_CONTROL_FAILED")
    end
  end
  local surface=game.surfaces[1]
  -- The earlier single 768/256 search area was exhausted when the real
  -- 0480 Junior-peer separation increased to 348 tiles. Search a bounded
  -- set of distant, naturally generated sectors instead of weakening 0822.
  -- Generate one sector at a time: do not flood the map if the first works.
  local search_regions={
    {x=1536,y=512,radius=10},{x=1536,y=-512,radius=10},
    {x=2304,y=512,radius=10},{x=2304,y=-512,radius=10},
  }
  -- Bound both the number and size of generated sectors. A future edit
  -- must not turn this engine fixture into unbounded world generation.
  if #search_regions~=4 then error("ORE_ENGINE_SEARCH_REGION_COUNT_INVALID") end
  local seen_regions={}
  for _,region in ipairs(search_regions) do
    if region.radius<1 or region.radius>10 then
      error("ORE_ENGINE_SEARCH_REGION_RADIUS_UNBOUNDED")
    end
    local key=region.x..":"..region.y
    if seen_regions[key] then error("ORE_ENGINE_SEARCH_REGION_DUPLICATED") end
    seen_regions[key]=true
  end
  local chosen,sites,chosen_region
  local regions_checked,ore_candidates=0,0
  for region_index,region in ipairs(search_regions) do
    if chosen then break end
    regions_checked=regions_checked+1
    surface.request_to_generate_chunks({x=region.x,y=region.y},region.radius)
    surface.force_generate_chunk_requests()
    local extent=region.radius*32
    local ore_list=surface.find_entities_filtered{
      name="iron-ore",type="resource",
      area={{region.x-extent,region.y-extent},
            {region.x+extent,region.y+extent}},limit=4000}
    for _,ore in ipairs(ore_list) do
      if ore.valid and ore.amount and ore.amount>=4 then
        ore_candidates=ore_candidates+1
        for _,dir in ipairs(ORE_ENGINE_DIRECTIONS) do
          local trial={}
          local clear=true
          for i=1,4 do
            -- Keep the terminal inside the smallest valid operating
            -- radius (8 tiles). The former 15-tile offset placed the
            -- real ore outside short-range Junior mining authority.
            -- Three upstream stations remain 17 tiles apart.
            local offset=6+(4-i)*17
            local pos={x=math.floor(ore.position.x)+dir[1]*offset,
                       y=math.floor(ore.position.y)+dir[2]*offset}
            trial[i]=pos
            if ore_engine_relocation_separation_sq(pos)<required_sq
                or not surface.can_place_entity{
                  name=ORE_ENGINE_STATIONS[i],position=pos,
                  force=game.forces.player} then
              clear=false
              break
            end
          end
          if clear then
            chosen=ore
            sites=trial
            chosen_region=region_index
            break
          end
        end
      end
      if chosen then break end
    end
  end
  if not chosen then
    error("ORE_ENGINE_NO_NATURAL_ORE_WITH_BUILDABLE_ROUTE regions="..
      regions_checked.." natural_ore_candidates="..ore_candidates)
  end
  emit("ORE_ENGINE_SITE_SEARCH regions_checked="..regions_checked..
    " natural_ore_candidates="..ore_candidates..
    " chosen_region="..chosen_region.." bounded=true")
  local units={}
  local min_relocation_separation_sq=math.huge
  for i,name in ipairs(ORE_ENGINE_STATIONS) do
    local entity=surface.create_entity{
      name=name,position=sites[i],force=game.forces.player,raise_built=true}
    if not (entity and entity.valid and entity.unit_number) then
      error("ORE_ENGINE_FIXTURE_STATION_PLACEMENT_FAILED rank="..i)
    end
    local separation_sq=ore_engine_relocation_separation_sq(entity.position)
    if separation_sq<required_sq then
      error("ORE_ENGINE_FIXTURE_STATION_INTRUDES_RELOCATION_AUTHORITY rank="..i)
    end
    min_relocation_separation_sq=math.min(
      min_relocation_separation_sq,separation_sq)
    units[i]=entity.unit_number
  end
  emit("ORE_ENGINE_SITE_ISOLATED tick="..game.tick..
    " min_relocation_separation_sq="..min_relocation_separation_sq..
    " required_sq="..required_sq..
    " hierarchy_peer_reach="..peer_reach)
  state.ore_engine={
    phase="pairing",units=units,ore_position={
      x=chosen.position.x,y=chosen.position.y},
    ore_amount_before=chosen.amount,started_tick=game.tick,
    last_hop=0,last_reason="",last_phase="",
  }
  emit("ORE_ENGINE_NATURAL_TARGET_SELECTED tick="..game.tick..
    " resource=iron-ore amount="..chosen.amount..
    " magos="..units[1].." senior="..units[2]..
    " intermediate="..units[3].." junior="..units[4]..
    " fixture_stations_not_construction_credit=true")
end
local function ore_engine_inventory(pair)
  local inv=pair.station.get_inventory(defines.inventory.chest)
  if not (inv and inv.valid) then error("ORE_ENGINE_STATION_INVENTORY_MISSING") end
  return inv
end
local function ore_engine_service(state)
  local test=state.ore_engine
  if not test or test.phase=="complete" then return end
  if game.tick-test.started_tick>60*240 then
    error("ORE_ENGINE_TIMEOUT phase="..tostring(test.phase)..
      " reason="..tostring(test.last_reason))
  end
  local pairs=storage.tech_priests.pairs_by_station or {}
  local chain={}
  for i,id in ipairs(test.units) do
    local pair=pairs[id]
    if not (pair and pair.station and pair.station.valid
        and pair.priest and pair.priest.valid
        and pair.station.unit_number==id) then return end
    chain[i]=pair
  end
  local magos=chain[1]
  if test.phase=="pairing" then
    local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
    if not (hierarchy and hierarchy.rebuild) then
      error("ORE_ENGINE_HIERARCHY_AUTHORITY_MISSING")
    end
    hierarchy.rebuild("forced")
    -- Check the real rebuilt peer graph, not just geometric intent. A
    -- foreign Junior peer would invalidate the unrelated physical 0822
    -- recovery; never suppress that recovery safety refusal.
    local recovery=state.relocation_engine
      and pairs[state.relocation_engine.old_station_unit]
    if recovery and recovery.station and recovery.station.valid then
      for _,peer in ipairs(hierarchy.peers(chain[4]) or {}) do
        if peer==recovery then error("ORE_ENGINE_JUNIOR_PEER_COLLISION") end
      end
      for _,peer in ipairs(hierarchy.peers(recovery) or {}) do
        if peer==chain[4] then error("ORE_ENGINE_JUNIOR_PEER_COLLISION") end
      end
    end
    for i=2,4 do
      if not (hierarchy.is_direct_subordinate
          and hierarchy.is_direct_subordinate(chain[i-1],chain[i])) then
        error("ORE_ENGINE_PHYSICAL_HIERARCHY_NOT_LINKED edge="..(i-1))
      end
      chain[i].remote_resource_assignment_0820={
        root_station_unit=test.units[1],parent_station_unit=test.units[i-1],
        segment=i-1}
    end
    local initial={}
    for i,pair in ipairs(chain) do
      initial[i]=ore_engine_inventory(pair).get_item_count("iron-ore")
    end
    test.initial_counts=initial
    magos.resource_expansion_0259=magos.resource_expansion_0259 or {}
    if magos.resource_expansion_0259.chain_0820 then
      error("ORE_ENGINE_FIXTURE_MAGOS_ALREADY_OWNS_MISSION")
    end
    magos.resource_expansion_0259.chain_0820={
      status="reached-resource",root_station_unit=test.units[1],
      current_station_unit=test.units[4],segments=3,
      route_station_units=test.units,need="iron-ore",
      resource_name="iron-ore",target=test.ore_position}
    local route,reason=ORE_ENGINE_CHAIN.return_route(magos)
    if not (route and #route==4 and route[1]==test.units[4]
        and route[4]==test.units[1]) then
      error("ORE_ENGINE_RETURN_ROUTE_NOT_VERIFIED: "..tostring(reason))
    end
    test.phase="courier"
    emit("ORE_ENGINE_ROUTE_VERIFIED tick="..game.tick..
      " junior="..route[1].." intermediate="..route[2]..
      " senior="..route[3].." magos="..route[4])
  end
  -- The fourth, independent Factorio process must read the original
  -- engine-owned ore hold BEFORE any resumed courier movement or deposit.
  -- Only the isolated CI mod copy enables this flag after its ore autosave.
  if rawget(_G,"TP_CI_COURIER_RELOAD_PROBE")==true
      and test.carry_save_requested and not test.carry_reload_verified then
    local saved=magos.resource_expansion_0259.chain_0820
      and magos.resource_expansion_0259.chain_0820.return_courier_0837
    local worker=chain[4]
    if not (saved and saved.phase=="carrying"
        and saved.hop_index==nil and (saved.hops_completed or 0)==0
        and saved.source_station_unit==test.carry_save_source_unit
        and saved.destination_station_unit==test.carry_save_destination_unit
        and saved.carrier_priest_unit==test.carry_save_priest_unit
        and worker.priest.unit_number==test.carry_save_priest_unit
        and saved.inventory and saved.inventory.valid
        and saved.inventory.get_item_count("iron-ore")==1
        and saved.inventory.get_item_count()==1
        and (saved.delivered_count or 0)==0) then
      error("ORE_ENGINE_CARRIED_RELOAD_CUSTODY_INVALID")
    end
    test.carry_reload_verified=true
    emit("PASS ORE_ENGINE_CARRIER_RELOAD tick="..game.tick..
      " source="..saved.source_station_unit..
      " destination="..saved.destination_station_unit..
      " priest="..saved.carrier_priest_unit..
      " held=1 hop=1 prior_receipts=0")
  end
  local ok,reason=ORE_ENGINE_COURIER.service(magos)
  local mission=magos.resource_expansion_0259.chain_0820
  local courier=mission.return_courier_0837
  if reason=="terminal-priest-has-existing-duty" then
    -- Actual Factorio arbitration proof: the courier has not moved or
    -- debited ore, but has reserved FUTURE scheduling while a real duty
    -- remains authoritative. A missing reservation must fail immediately.
    if not (courier and courier.phase=="awaiting-terminal-duty"
        and courier.inventory==nil
        and ORE_ENGINE_COURIER.worker_reserved(chain[4])) then
      error("ORE_ENGINE_TERMINAL_DUTY_RESERVATION_MISSING")
    end
    local terminal=chain[4]
    if not test.terminal_duty_wait_observed then
      test.terminal_duty_wait_observed=true
      emit("ORE_ENGINE_TERMINAL_DUTY_WAIT tick="..game.tick..
        " station="..terminal.station.unit_number..
        " priest="..terminal.priest.unit_number..
        " mode="..tostring(terminal.mode)..
        " active_task="..tostring(type(terminal.active_task)=="table"
          and terminal.active_task.kind or type(terminal.active_task))..
        " custody_hold=0 future_work_reserved=true")
    end
    -- Preserve actionable evidence if the courier is still waiting after
    -- additional ticks: a stale mode, a real manufacturing duty, a direct
    -- acquisition alias and a held inventory require different repairs.
    -- This observes pair state only; it never cancels any such obligation.
    if game.tick >= (test.next_courier_duty_diag_tick or 0) then
      test.next_courier_duty_diag_tick=game.tick+1800
      local recipe=terminal.infrastructure_recipe_request_0647
      local direct=terminal.direct_acquisition_task_0336
      emit("ORE_ENGINE_DUTY_DIAG tick="..game.tick..
        " mode="..tostring(terminal.mode)..
        " recipe_missing="..tostring(recipe and recipe.missing)..
        " emergency_craft="..tostring(terminal.emergency_craft~=nil)..
        " active_task="..tostring(terminal.active_task~=nil)..
        " direct_task="..tostring(direct and direct.item or direct~=nil)..
        " active_acquisition="..tostring(terminal.active_acquisition_0333~=nil)..
        " construction_task="..tostring(terminal.construction_task_0338~=nil)..
        " station_expansion="..tostring(terminal.station_expansion_0256
          and terminal.station_expansion_0256.status)..
        " repair_custody="..tostring(terminal.repair_pack_custody_0516~=nil)..
        " logistics_custody="..tostring(terminal.machine_logistics_custody_0528~=nil))
    end
  end
  if reason~=test.last_reason then
    test.last_reason=reason
    emit("ORE_ENGINE_COURIER_PROGRESS tick="..game.tick..
      " reason="..tostring(reason)..
      " phase="..tostring(courier and courier.phase))
  end
  if not courier then return end
  if (reason=="upstream-priest-has-existing-duty"
      or reason=="upstream-priest-has-existing-custody")
      and courier.phase=="first-hop-delivered" then
    local next_index=4-(courier.hop_index or 1)
    local waiting=chain[next_index]
    if waiting then
      if not ORE_ENGINE_COURIER.worker_reserved(waiting) then
        error("ORE_ENGINE_UPSTREAM_FUTURE_RESERVATION_MISSING")
      end
      if game.tick>=(test.next_upstream_diag_tick or 0) then
        test.next_upstream_diag_tick=game.tick+1800
        local recipe=waiting.infrastructure_recipe_request_0647
        local direct=waiting.direct_acquisition_task_0336
        emit("ORE_ENGINE_UPSTREAM_DUTY_DIAG tick="..game.tick..
          " station="..waiting.station.unit_number..
          " priest="..waiting.priest.unit_number..
          " reason="..reason.." mode="..tostring(waiting.mode)..
          " recipe_missing="..tostring(recipe and recipe.missing)..
          " active_task="..tostring(waiting.active_task~=nil)..
          " current_task="..tostring(waiting.current_task~=nil)..
          " emergency_craft="..tostring(waiting.emergency_craft~=nil)..
          " active_acquisition="..tostring(waiting.active_acquisition_0333~=nil)..
          " direct_task="..tostring(direct and direct.item or direct~=nil)..
          " inventory_transfer="..tostring(waiting.inventory_transfer_custody_0687~=nil)..
          " construction_task="..tostring(waiting.construction_task_0338~=nil)..
          " station_expansion="..tostring(waiting.station_expansion_0256
            and waiting.station_expansion_0256.status)..
          " direct_custody="..tostring(waiting.direct_acquisition_custody_0513~=nil)..
          " logistics_custody="..tostring(waiting.machine_logistics_custody_0528~=nil)..
          " future_work_reserved=true")
      end
    end
  end
  if courier.phase=="custody-blocked" then
    error("ORE_ENGINE_CUSTODY_BLOCKED: "..tostring(courier.last_reason))
  end
  if courier.phase=="carrying" then
    -- Only the physical hold is the courier's property. Other Cogitators
    -- can autonomously mine and store ore without inventing courier credit.
    if not (courier.inventory and courier.inventory.valid
        and courier.inventory.get_item_count("iron-ore")==1) then
      error("ORE_ENGINE_CARRIER_REAL_INVENTORY_NOT_CONSERVED")
    end
    if (courier.hops_completed or 0)~=(courier.hop_index or 1)-1 then
      error("ORE_ENGINE_CARRIER_HOP_SEQUENCE_INVALID")
    end
  end
  if reason=="physical-upstream-item-picked-up" then
    local idx=courier.hop_index and 5-courier.hop_index
    local before=courier.pickup_source_before
    if not (idx and idx>=2 and idx<=3 and before and before>=1
        and ore_engine_inventory(chain[idx]).get_item_count("iron-ore")
          ==before-1 and courier.inventory and courier.inventory.valid
        and courier.inventory.get_item_count("iron-ore")==1) then
      error("ORE_ENGINE_PHYSICAL_UPSTREAM_PICKUP_UNVERIFIED")
    end
  end
  if courier.quantity==1 and not test.mined then
    local ore=magos.station.surface.find_entities_filtered{
      name="iron-ore",position=test.ore_position,radius=0.5,limit=1}[1]
    local amount=ore and ore.valid and ore.amount or 0
    if amount>=test.ore_amount_before then
      error("ORE_ENGINE_NATURAL_RESOURCE_NOT_DEPLETED")
    end
    if not (courier.inventory and courier.inventory.valid
        and courier.inventory.get_item_count("iron-ore")==1) then
      error("ORE_ENGINE_REAL_MINED_CARGO_NOT_HELD")
    end
    test.mined=true
    emit("ORE_ENGINE_MINED tick="..game.tick..
      " natural_before="..test.ore_amount_before..
      " natural_after="..amount.." held=1")
    if SAVE_RELOAD_SMOKE and not test.carry_save_requested then
      -- Save a genuinely mined item while its physical courier still owns it.
      -- The runner restarts Factorio from this CRC-verified autosave.
      test.carry_save_requested=true
      test.carry_save_source_unit=courier.source_station_unit
      test.carry_save_destination_unit=courier.destination_station_unit
      test.carry_save_priest_unit=courier.carrier_priest_unit
      local saved,save_error=pcall(function()
        game.auto_save("tech-priests-ci-ore-carried")
      end)
      if not saved then
        error("ORE_ENGINE_CARRIED_SAVE_REFUSED: "..tostring(save_error))
      end
      emit("ORE_ENGINE_CARRIER_SAVE_REQUESTED tick="..game.tick..
        " source="..courier.source_station_unit..
        " destination="..courier.destination_station_unit..
        " priest="..courier.carrier_priest_unit..
        " held=1 hop=1 prior_receipts=0")
    end
  end
  local hop=courier.hops_completed or 0
  if hop>test.last_hop then
    if hop~=test.last_hop+1 or hop>3 then
      error("ORE_ENGINE_UPSTREAM_HOP_SKIPPED")
    end
    local dest_index=4-hop
    local actual=ore_engine_inventory(chain[dest_index])
      .get_item_count("iron-ore")
    local before=courier.receipt_destination_before
    local after=courier.receipt_destination_after
    if not (courier.receipt_hop==hop and tonumber(before)
        and tonumber(after) and before>=0 and after==before+1
        and actual==after and courier.delivered_count==1
        and courier.delivered_station_unit==test.units[dest_index]
        and courier.inventory==nil) then
      error("ORE_ENGINE_PHYSICAL_RECEIPT_UNVERIFIED hop="..hop..
        " actual="..tostring(actual).." before="..tostring(before)..
        " after="..tostring(after))
    end
    test.last_hop=hop
    emit("ORE_ENGINE_HOP tick="..game.tick.." hop="..hop..
      " from="..test.units[5-hop].." to="..test.units[4-hop]..
      " counted=1 receipt_before="..before.." receipt_after="..after)
  end
  if courier.phase=="magos-delivered" then
    if not (test.mined and test.last_hop==3
        and mission.delivered_to_magos_count==1
        and courier.inventory==nil) then
      error("ORE_ENGINE_MAGOS_RECEIPT_UNVERIFIED")
    end
    test.phase="complete"
    emit("PASS ORE_ENGINE_COUNTED_MAGOS_RETURN tick="..game.tick..
      " natural_mined=1 physical_hops=3 magos_received=1 held=0")
  end
end


-- CI-only preliminary Method I five-station reversal fixture. This is NOT
-- reversal completion: it places real stations as explicit test fixtures,
-- uses untouched naturally generated ore, and validates the live 0480 ranked
-- hierarchy plus a genuine no-spare-item material deficit. No station item,
-- ore, delivery or construction success is invented by this probe.
local REVERSAL_ENGINE_NAMES={
  "planetary-magos-cogitator-station","senior-cogitator-station",
  "intermediate-cogitator-station","junior-cogitator-station",
  "junior-cogitator-station"}
-- Unlike Nauvis, this isolated material-starvation lane has no map-generated
-- enemy bases. Original Nauvis biter combat and 0248 attack priorities remain
-- entirely untouched. Ore is still 100% Factorio map-generated, not spawned.
local REVERSAL_ENGINE_SURFACE_NAME="tech-priests-five-station-ci"
local REVERSAL_ENGINE_REGIONS={
  {x=0,y=0,radius=16},{x=960,y=0,radius=16},
  {x=0,y=960,radius=16}}
local function reversal_engine_surface()
  local existing=game.surfaces[REVERSAL_ENGINE_SURFACE_NAME]
  if existing then return existing end
  local source=game.surfaces[1]
  if not(source and source.valid and game.create_surface) then
    error("REVERSAL_ENGINE_CI_SURFACE_CREATION_UNAVAILABLE")
  end
  local settings=source.map_gen_settings
  -- Keep source ore autoplace and normal terrain. Only the isolated CI
  -- surface disables *generation* of enemy bases. Do not change forces,
  -- peaceful mode, combat scripts, or any pre-existing surface.
  settings.seed=1342025
  settings.autoplace_controls=settings.autoplace_controls or {}
  settings.autoplace_controls["enemy-base"]={
    frequency=0,size=0,richness=0}
  local made=game.create_surface(REVERSAL_ENGINE_SURFACE_NAME,settings)
  if not(made and made.valid) then
    error("REVERSAL_ENGINE_CI_SURFACE_NOT_CREATED")
  end
  emit("REVERSAL_ENGINE_ISOLATED_NATURAL_SURFACE surface="..made.name..
    " seed=1342025 original_nauvis_unchanged=true"..
    " physical_items_created=0 ore_entities_created=0")
  return made
end
-- 0248's actual survival probe scans hostile force entities inside each
-- priest's operating square. Station recovery cannot be the priority while
-- a real biter, nest or other combat threat is present; preserve production
-- attack priority and choose a genuinely quiet CI recovery test site instead.
local REVERSAL_ENGINE_HOSTILE_CLEARANCE=110
local function reversal_engine_has_hostiles(surface,position,clearance)
  local radius=clearance or REVERSAL_ENGINE_HOSTILE_CLEARANCE
  local enemies=surface.find_entities_filtered{
    force="enemy",limit=1,
    area={{position.x-radius,position.y-radius},
          {position.x+radius,position.y+radius}}}
  return enemies and enemies[1] and enemies[1].valid or false
end
local function reversal_engine_place(state)
  if state.reversal_engine then return end
  if not REVERSAL_ENGINE_0850 then error("REVERSAL_ENGINE_MODULE_UNAVAILABLE") end
  local surface,force=reversal_engine_surface(),game.forces.player
  local ore,sites,region_index
  local terrain_rejections,hostile_rejections=0,0
  for index,region in ipairs(REVERSAL_ENGINE_REGIONS) do
    surface.request_to_generate_chunks({x=region.x,y=region.y},region.radius)
    surface.force_generate_chunk_requests()
    -- Every candidate's entire 365-tile wrong-way line must stay inside
    -- the generated chunks. A wide search previously counted thousands
    -- of ungenerated-tile rejections as ordinary terrain failures.
    local width=region.radius*32-370
    local candidates=surface.find_entities_filtered{
      name="iron-ore",type="resource",limit=4000,
      area={{region.x-width,region.y-width},
            {region.x+width,region.y+width}}}
    for _,candidate in ipairs(candidates) do
      if candidate.valid and candidate.amount and candidate.amount>=4 then
        for _,direction in ipairs(ORE_ENGINE_DIRECTIONS) do
          local positions,clear={},true
          for i,name in ipairs(REVERSAL_ENGINE_NAMES) do
            -- 0480 links peers AND assigns rank-1 direct subordinates
            -- throughout a 220-tile network. A tightly spaced chain
            -- incorrectly gives the Intermediate both Juniors, making
            -- the legitimate 0850 reversal preflight refuse. Place the
            -- direct Junior 180 tiles past Intermediate, and its terminal
            -- peer 240 tiles past Intermediate: direct Junior remains
            -- inside 220, terminal peer lies outside Intermediate's
            -- authority yet stays 60 tiles from its Junior peer.
            local offsets={85,105,125,305,365}
            local offset=offsets[i]
            local pos={x=math.floor(candidate.position.x)
                      +direction[1]*offset,
                       y=math.floor(candidate.position.y)
                      +direction[2]*offset}
            positions[i]=pos
            if not surface.can_place_entity{
                name=name,position=pos,force=force} then
              terrain_rejections=terrain_rejections+1
              clear=false
              break
            end
          end
          if clear then
            -- Do not fabricate combat peace or ignore real attacks. The
            -- next 0248 priority check MUST remain able to interrupt
            -- recovery if hostiles arrive later.
            for _,pos in ipairs(positions) do
              if reversal_engine_has_hostiles(surface,pos) then
                hostile_rejections=hostile_rejections+1
                clear=false
                break
              end
            end
          end
          if clear then
            ore,sites,region_index=candidate,positions,index
            break
          end
        end
      end
      if ore then break end
    end
    if ore then break end
  end
  if not (ore and sites and #sites==5) then
    error("REVERSAL_ENGINE_NATURAL_ORE_WRONG_WAY_SITE_UNAVAILABLE"..
      " hostile_rejections="..hostile_rejections..
      " terrain_rejections="..terrain_rejections)
  end
  emit("REVERSAL_ENGINE_QUIET_SITE_SELECTED region="..region_index..
    " hostile_rejections="..hostile_rejections..
    " terrain_rejections="..terrain_rejections..
    " clearance="..REVERSAL_ENGINE_HOSTILE_CLEARANCE..
    " enemy_entities_deleted=0")
  local units={}
  local empty_components={
    "junior-cogitator-station","intermediate-cogitator-station",
    "senior-cogitator-station","iron-plate","copper-plate",
    "electronic-circuit"}
  for i,name in ipairs(REVERSAL_ENGINE_NAMES) do
    local station=surface.create_entity{
      name=name,position=sites[i],force=force,raise_built=true}
    if not(station and station.valid and station.unit_number) then
      error("REVERSAL_ENGINE_FIXTURE_STATION_CREATION_FAILED rank="..i)
    end
    local inv=station.get_inventory(defines.inventory.chest)
    if not(inv and inv.valid) then
      error("REVERSAL_ENGINE_FIXTURE_INVENTORY_MISSING rank="..i)
    end
    for _,item in ipairs(empty_components) do
      if inv.get_item_count(item)~=0 then
        error("REVERSAL_ENGINE_FIXTURE_NOT_STARVED rank="..i..
          " item="..item)
      end
    end
    units[i]=station.unit_number
  end
  state.reversal_engine={
    phase="pairing",units=units,surface_index=surface.index,
    started_tick=game.tick,
    natural_ore={x=ore.position.x,y=ore.position.y},
    initial_ore_amount=ore.amount,region_index=region_index}
  emit("REVERSAL_ENGINE_FIVE_STATION_PLACED tick="..game.tick..
    " region="..region_index.." surface="..surface.name..
    " natural_ore_amount="..ore.amount..
    " magos="..units[1].." senior="..units[2]..
    " intermediate="..units[3].." junior="..units[4]..
    " peer="..units[5].." station_spares=0 components=0")
end
local function reversal_engine_verify(state)
  local test=state.reversal_engine
  if not test or test.phase~="pairing" then return end
  if game.tick-test.started_tick>12000 then
    error("REVERSAL_ENGINE_LIVE_HIERARCHY_TIMEOUT")
  end
  local tp=storage.tech_priests
  local pairs=tp and tp.pairs_by_station or {}
  local chain={}
  for i,unit in ipairs(test.units) do
    local p=pairs[unit]
    if not(p and p.station and p.station.valid
        and p.priest and p.priest.valid
        and p.station.unit_number==unit
        and p.station.name==REVERSAL_ENGINE_NAMES[i]) then return end
    chain[i]=p
  end
  local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not(hierarchy and hierarchy.rebuild and hierarchy.rank
      and hierarchy.is_direct_subordinate and hierarchy.peers) then
    error("REVERSAL_ENGINE_HIERARCHY_AUTHORITY_UNAVAILABLE")
  end
  hierarchy.rebuild("forced")
  for i,p in ipairs(chain) do
    local wanted=i<=4 and (5-i) or 1
    if tonumber(hierarchy.rank(p))~=wanted then
      error("REVERSAL_ENGINE_RANK_MISMATCH rank="..i)
    end
  end
  for i=1,3 do
    if not hierarchy.is_direct_subordinate(chain[i],chain[i+1]) then
      error("REVERSAL_ENGINE_HIERARCHY_EDGE_MISSING edge="..i)
    end
    local slate=chain[i].command_hierarchy_0480
    if not(slate and #slate.direct_subordinate_units==1
        and slate.direct_subordinate_units[1]==test.units[i+1]) then
      error("REVERSAL_ENGINE_EXTRA_DIRECT_SUBORDINATE rank="..i..
        " count="..tostring(slate and #slate.direct_subordinate_units))
    end
  end
  local junior_slate=chain[4].command_hierarchy_0480
  local peer_slate=chain[5].command_hierarchy_0480
  if not(junior_slate and #junior_slate.direct_subordinate_units==0
      and #junior_slate.peer_units==1
      and peer_slate and peer_slate.superior_unit==nil
      and #peer_slate.peer_units==1) then
    error("REVERSAL_ENGINE_JUNIOR_PEER_HIERARCHY_AMBIGUOUS")
  end
  local forward,back=false,false
  for _,p in ipairs(hierarchy.peers(chain[4])) do
    if p==chain[5] then forward=true end
  end
  for _,p in ipairs(hierarchy.peers(chain[5])) do
    if p==chain[4] then back=true end
  end
  if not(forward and back) then
    error("REVERSAL_ENGINE_JUNIOR_PEER_LINK_MISSING")
  end
  -- The selected path must still be non-hostile when 0248 first queries
  -- the freshly paired Magos. Compare with its actual refreshed radius,
  -- not a guessed constant or a disabled combat handler.
  for i,pair in ipairs(chain) do
    local radius=refresh_pair_radius and refresh_pair_radius(pair)
      or pair.radius or 20
    if reversal_engine_has_hostiles(pair.station.surface,
        pair.station.position,math.max(radius+24,1)) then
      error("REVERSAL_ENGINE_HOSTILE_SITE_INTRUSION rank="..i..
        " true_combat_priority_retained=true")
    end
  end
  -- A geometric enemy exclusion is not equivalent to the production
  -- survival arbiter. Prove the actual 0248 decision is idle for ALL five
  -- before claiming that this is a physical-recovery-only experiment.
  -- Never suppress an attack, repair or consecration priority to pass CI.
  if type(tech_priests_0248_higher_priority_probe)~="function" then
    error("REVERSAL_ENGINE_0248_PRIORITY_AUTHORITY_UNAVAILABLE")
  end
  for i,pair in ipairs(chain) do
    local ok,priority=pcall(tech_priests_0248_higher_priority_probe,pair)
    if not(ok and type(priority)=="table"
        and priority.priority=="idle") then
      local target=ok and type(priority)=="table" and priority.target or nil
      local pos=target and target.valid and target.position or nil
      error("REVERSAL_ENGINE_STARTING_SURVIVAL_PRIORITY"..
        " rank="..i..
        " priority="..tostring(ok and type(priority)=="table"
          and priority.priority or priority)..
        " target="..tostring(target and target.valid
          and target.name or "none")..
        " target_x="..tostring(pos and pos.x)..
        " target_y="..tostring(pos and pos.y))
    end
  end
  emit("REVERSAL_ENGINE_PRODUCTION_IDLE_VERIFIED tick="..game.tick..
    " ranks=4-3-2-1-1 priority=idle"..
    " attack_priority_suppressed=false")
  local magos=chain[1]
  local point=test.natural_ore
  local source=magos.station.position
  local terminal=chain[5].station.position
  local dot=(terminal.x-source.x)*(point.x-source.x)
    +(terminal.y-source.y)*(point.y-source.y)
  if dot>=0 then error("REVERSAL_ENGINE_CHAIN_NOT_OPPOSED_TO_ORE") end
  -- A natural patch already inside the original Magos operating area is
  -- not a legitimate resource-starvation reason to reverse its hierarchy.
  local root_radius=ORE_ENGINE_CHAIN and
    ORE_ENGINE_CHAIN.operating_radius(magos)
  local dx,dy=source.x-point.x,source.y-point.y
  if not(root_radius and dx*dx+dy*dy>root_radius*root_radius) then
    error("REVERSAL_ENGINE_ORE_ALREADY_WITHIN_MAGOS_RADIUS")
  end
  local actual_ore=magos.station.surface.find_entities_filtered{
    name="iron-ore",type="resource",position=point,radius=0.5}[1]
  if not(actual_ore and actual_ore.valid and actual_ore.amount>=4) then
    error("REVERSAL_ENGINE_NATURAL_RESOURCE_NOT_PRESENT")
  end
  -- Test the real preflight: hierarchy correctness alone is not enough.
  -- Existing duties may delay eligibility; never clear or impersonate work.
  local ok,plan,reason=pcall(REVERSAL_ENGINE_0850.preflight,
    magos,point,"senior-cogitator-station")
  if not ok then
    error("REVERSAL_ENGINE_PREFLIGHT_EXCEPTION: "..tostring(plan))
  end
  if not plan then
    if game.tick-(test.last_denial_tick or 0)>=600 then
      test.last_denial_tick=game.tick
      local leaf=chain[5]
      emit("REVERSAL_ENGINE_PREFLIGHT_WAIT tick="..game.tick..
        " reason="..tostring(reason)..
        " leaf_mode="..tostring(leaf.mode)..
        " leaf_task="..tostring(leaf.active_task and leaf.active_task.kind)..
        " leaf_cargo="..tostring(leaf.inventory_transfer_custody_0687~=nil)..
        " leaf_mission="..tostring(leaf.resource_expansion_0259~=nil))
    end
    return
  end
  if not(plan.status=="leaf-first-preflight-only"
      and #plan.stages==4 and plan.stages[1].station_unit==test.units[5]
      and plan.stages[2].station_unit==test.units[4]
      and plan.stages[3].station_unit==test.units[3]
      and plan.stages[4].station_unit==test.units[2]) then
    error("REVERSAL_ENGINE_PREFLIGHT_STAGE_ORDER_INVALID")
  end
  test.phase="preflight-verified"
  test.pair_priest_units={}
  for i,p in ipairs(chain) do
    test.pair_priest_units[i]=p.priest.unit_number
  end
  emit("PASS REVERSAL_ENGINE_FIVE_STATION_FIXTURE tick="..game.tick..
    " hierarchy=4-3-2-1-1 natural_ore=true wrong_direction=true"..
    " station_spares=0 components=0 original_priests=5"..
    " preflight_ready=true"..
    " preflight_reason="..tostring(reason)..
    " fixture_only=true no_station_mine_claim=true")
end


-- The production 0256 request gives the Magos a real entity ghost and
-- reserves its construction writ. The fixture supplies an iron-ore goal,
-- never materials, station items, movement or a simulated mine event.
local function reversal_engine_first_depot(state)
  local test=state.reversal_engine
  if not test or (test.phase~="preflight-verified"
      and test.phase~="first-recovery") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  if not(magos and magos.station and magos.station.valid
      and magos.priest and magos.priest.valid
      and magos.priest.unit_number==test.pair_priest_units[1]) then
    error("REVERSAL_ENGINE_MAGOS_IDENTITY_LOST")
  end
  local executor=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(executor and type(executor.request_station_expansion)=="function"
      and type(executor.service_station_expansion_assignment)=="function") then
    error("REVERSAL_ENGINE_PRODUCTION_EXECUTOR_UNAVAILABLE")
  end
  if test.phase=="preflight-verified" then
    if magos.resource_expansion_0259
        and magos.resource_expansion_0259.chain_0820 then
      error("REVERSAL_ENGINE_EXISTING_RESOURCE_MISSION_MUST_NOT_BE_STOLEN")
    end
    if (tp.station_expansion_by_worker_0256
          and tp.station_expansion_by_worker_0256[test.units[1]])
        or magos.station_expansion_0256 then
      error("REVERSAL_ENGINE_EXISTING_CONSTRUCTION_WRIT_MUST_NOT_BE_STOLEN")
    end
    local stock=magos.station.get_inventory(defines.inventory.chest)
    if not(stock and stock.valid
        and stock.get_item_count("senior-cogitator-station")==0) then
      error("REVERSAL_ENGINE_MAGOS_NOT_STATION_STARVED")
    end
    magos.resource_expansion_0259=magos.resource_expansion_0259 or {}
    -- Populate the same serializable fields as 0820.start rather than
    -- a partial synthetic mission. Otherwise the real 0820 periodic owner
    -- can see an active chain without a pending writ or numeric segments,
    -- issue a conflicting ghost, or fault on nil comparisons.
    magos.resource_expansion_0259.chain_0820={
      status="building-station",root_station_unit=test.units[1],
      current_station_unit=test.units[1],current_rank=4,
      resource_name="iron-ore",need="iron-ore",
      target={x=test.natural_ore.x,y=test.natural_ore.y},
      segments=0,pending_expansion_id=nil,
      route_station_units={test.units[1]},
      created_tick=game.tick,updated_tick=game.tick,
      next_tick=game.tick+ORE_ENGINE_CHAIN.service_interval,
      last_reason="ci-physical-station-writ-initializing"}
    local origin=magos.station.position
    local angle=math.atan(test.natural_ore.y-origin.y,
      test.natural_ore.x-origin.x)
    local created=executor.request_station_expansion(
      magos,"resource:iron-ore",nil,"ci-first-junior-recovery",angle)
    local id=tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[test.units[1]]
    local rec=id and tp.station_expansion_0256
      and tp.station_expansion_0256[id]
    if not(created and rec and rec.status=="active"
        and rec.worker_station_unit==test.units[1]
        and rec.station_item=="senior-cogitator-station"
        and rec.reversal_plan_0850
        and rec.reversal_plan_0850.stages[1].station_unit==test.units[5]
        and rec.ghost_unit and rec.ghost_position) then
      error("REVERSAL_ENGINE_PRODUCTION_WRIT_NOT_CREATED")
    end
    -- This is the ID of the real 0256 record just accepted above, never
    -- a fabricated completion or substitute construction registration.
    local mission=magos.resource_expansion_0259.chain_0820
    mission.pending_expansion_id=id
    mission.last_reason="physical-child-station-requested"
    mission.updated_tick=game.tick
    if not(mission.segments==0
        and mission.route_station_units[1]==test.units[1]
        and #mission.route_station_units==1
        and mission.pending_expansion_id==rec.id
        and mission.next_tick>game.tick) then
      error("REVERSAL_ENGINE_REAL_MISSION_WRIT_NOT_LINKED")
    end
    test.writ_id=id
    test.phase="first-recovery"
    test.first_recovery_tick=game.tick
    emit("REVERSAL_ENGINE_REAL_WRIT_ASSIGNED tick="..game.tick..
      " id="..tostring(id).." root="..test.units[1]..
      " station_stock=0 ghost="..rec.ghost_unit)
  end
  if game.tick-test.first_recovery_tick>15000 then
    error("REVERSAL_ENGINE_FIRST_DEPOT_TIMEOUT phase="..
      tostring(test.last_phase))
  end
  local rec=tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  if not(rec and rec.status=="active"
      and rec.worker_station_unit==test.units[1]
      and tp.station_expansion_by_worker_0256
        and tp.station_expansion_by_worker_0256[test.units[1]]==test.writ_id) then
    error("REVERSAL_ENGINE_RECOVERY_WRIT_LOST")
  end
  executor.service_station_expansion_assignment(magos)
  if rec.phase~=test.last_phase then
    test.last_phase=rec.phase
    emit("REVERSAL_ENGINE_RECOVERY_PHASE tick="..game.tick..
      " phase="..tostring(rec.phase)..
      " route_denial="..tostring(rec.reversal_route_denial_0870))
  end
  if game.tick-(test.last_recovery_observation_tick or 0)>=600 then
    test.last_recovery_observation_tick=game.tick
    local first=rec.reversal_plan_0850 and rec.reversal_plan_0850.stages
      and rec.reversal_plan_0850.stages[1]
    local worker=first and tp.pairs_by_station[first.parent_station_unit]
    local terminal=first and tp.pairs_by_station[first.station_unit]
    local priority="unavailable"
    if type(tech_priests_0248_higher_priority_probe)=="function" then
      local ok,probe=pcall(tech_priests_0248_higher_priority_probe,magos)
      if ok and probe then priority=tostring(probe.priority) end
    end
    local function work(pair)
      if not pair then return "missing" end
      if pair.active_task then return "active:"..tostring(pair.active_task.kind) end
      if pair.infrastructure_recipe_request_0647 then
        return "recipe:"..tostring(pair.infrastructure_recipe_request_0647.item)
      end
      if pair.direct_acquisition_task_0336 then return "acquisition" end
      if pair.inventory_transfer_custody_0687 then return "transfer" end
      return "none"
    end
    emit("REVERSAL_ENGINE_RECOVERY_WAIT tick="..game.tick..
      " phase="..tostring(rec.phase)..
      " priority="..priority..
      " magos_mode="..tostring(magos.mode)..
      " magos_work="..work(magos)..
      " worker_mode="..tostring(worker and worker.mode)..
      " worker_work="..work(worker)..
      " leaf_mode="..tostring(terminal and terminal.mode)..
      " leaf_work="..work(terminal)..
      " stage="..tostring(rec.reversal_stage_0851
        and rec.reversal_stage_0851.phase))
    -- 0876: distinguish accepted-but-stalled transport from rejected
    -- routing. Observe only; never move the priest, alter a real item,
    -- extend the test deadline, or reset a controller lease here.
    if worker and worker.priest and worker.priest.valid then
      local pos=worker.priest.position
      local goal=magos.station.position
      local req=worker.movement_request_0418
      local final=req and (req.ground_route_final_destination or req)
      local status_fn=rawget(_G,"tech_priests_movement_status_0418")
      local status=nil
      if type(status_fn)=="function" then
        local ok,result=pcall(status_fn,worker,
          req and req.owner or "station-recovery-0851")
        if ok and type(result)=="table" then status=result end
      end
      local function coordinate(point)
        if not(point and type(point.x)=="number"
            and type(point.y)=="number") then return "none" end
        return string.format("%.2f,%.2f",point.x,point.y)
      end
      local dx,dy=pos.x-goal.x,pos.y-goal.y
      local dist=math.sqrt(dx*dx+dy*dy)
      emit("REVERSAL_ENGINE_TRANSIT_OBSERVE tick="..game.tick..
        " priest="..tostring(worker.priest.unit_number)..
        " position="..coordinate(pos)..
        " magos="..coordinate(goal)..
        " remaining="..string.format("%.2f",dist)..
        " request_owner="..tostring(req and req.owner)..
        " request_reason="..tostring(req and req.reason)..
        " request_priority="..tostring(req and req.priority)..
        " request_waypoint="..coordinate(req)..
        " request_final="..coordinate(final)..
        " request_expires="..tostring(req and req.expires_tick)..
        " last_command_tick="..tostring(req and req.last_command_tick)..
        " last_motion_tick="..tostring(req and req.recovery_last_motion_tick)..
        " recovery_blocker="..tostring(req and req.last_recovery_blocker)..
        " controller_state="..tostring(worker.movement_controller_state_0418)..
        " controller_clamp="..tostring(worker.movement_controller_clamp_0418)..
        " status="..tostring(status and status.status)..
        " status_active="..tostring(status and status.active)..
        " route_denial="..tostring(rec.reversal_route_denial_0870))
    end
  end
  local stage=rec.reversal_stage_0851
  if not(stage and stage.phase=="in-magos-depot") then return end
  local stored,why=REVERSAL_DEPOT_0852.get_staged(magos,stage)
  local survivor=tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[5]]
  if not(stored and stored.inventory and stored.inventory.valid
      and stored.inventory.get_item_count("junior-cogitator-station")==1
      and survivor and survivor.priest and survivor.priest.valid
      and survivor.priest.unit_number==test.pair_priest_units[5]
      and tp.pairs_by_station[test.units[5]]==nil) then
    error("REVERSAL_ENGINE_FIRST_DEPOT_OR_PRIEST_LOST:"..tostring(why))
  end
  test.phase="first-depot-verified"
  emit("PASS REVERSAL_ENGINE_FIRST_PHYSICAL_DEPOT tick="..game.tick..
    " old_station="..test.units[5]..
    " priest="..test.pair_priest_units[5]..
    " stored_junior=1 magos="..test.units[1]..
    " further_stages_not_claimed=true")
end


-- Second independently counted recovery: the Intermediate must mine its
-- now-childless Junior subordinate using the existing 0853 authority.
-- The first real terminal-Junior item stays in its distinct Magos depot.
local function reversal_engine_second_depot(state)
  local test=state.reversal_engine
  if not test or (test.phase~="first-depot-verified"
      and test.phase~="second-recovery") then return end
  local tp=storage and storage.tech_priests
  local registry=tp and tp.pairs_by_station
  local magos=registry and registry[test.units[1]]
  if not(magos and magos.station and magos.station.valid
      and magos.priest and magos.priest.valid
      and magos.priest.unit_number==test.pair_priest_units[1]) then
    error("REVERSAL_ENGINE_SECOND_MAGOS_LOST")
  end
  local rec=tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  if not(rec and rec.status=="active"
      and rec.worker_station_unit==test.units[1]
      and tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[test.units[1]]==test.writ_id) then
    error("REVERSAL_ENGINE_SECOND_WRIT_OR_OWNER_LOST")
  end
  local first=rec.reversal_stage_0851
  local first_item,first_why=first
    and REVERSAL_DEPOT_0852.get_staged(magos,first)
  if not(first_item and first_item.inventory
      and first_item.inventory.valid
      and first_item.inventory.get_item_count("junior-cogitator-station")==1
      and first.leaf_station_unit==test.units[5]) then
    error("REVERSAL_ENGINE_FIRST_DEPOT_NOT_PRESERVED:"..tostring(first_why))
  end
  if test.phase=="first-depot-verified" then
    test.phase="second-recovery"
    test.second_recovery_tick=game.tick
    emit("REVERSAL_ENGINE_SECOND_STAGE_STARTED tick="..game.tick..
      " first_stored=1 original_priest="..test.pair_priest_units[5])
  end
  if game.tick-test.second_recovery_tick>15000 then
    error("REVERSAL_ENGINE_SECOND_DEPOT_TIMEOUT phase="..
      tostring(test.last_phase))
  end
  local executor=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(executor and type(executor.service_station_expansion_assignment)=="function") then
    error("REVERSAL_ENGINE_SECOND_EXECUTOR_MISSING")
  end
  executor.service_station_expansion_assignment(magos)
  if rec.phase~=test.last_phase then
    test.last_phase=rec.phase
    emit("REVERSAL_ENGINE_RECOVERY_PHASE tick="..game.tick..
      " phase="..tostring(rec.phase)..
      " route_denial="..tostring(rec.reversal_route_denial_0870))
  end
  -- 0878: observe the second-stage dependency instead of relaxing 0822.
  -- The hidden turret is equipment attached to the original living priest;
  -- its live identity, target, ownership, attachment, and any competing work
  -- determine whether the existing destructive-mine preflight can proceed.
  if game.tick-(test.last_second_observation_tick or 0)>=600 then
    test.last_second_observation_tick=game.tick
    local step=rec.reversal_plan_0850 and rec.reversal_plan_0850.stages
      and rec.reversal_plan_0850.stages[2]
    local candidate=step and registry[step.station_unit]
    local worker=step and registry[step.parent_station_unit]
    local proxy=candidate and candidate.proxy
    local function inspect(entity,key)
      local ok,value=pcall(function()
        if entity and entity.valid then return entity[key] end
      end)
      return ok and tostring(value) or "unobservable"
    end
    local d2="unobservable"
    if proxy and proxy.valid and candidate
        and candidate.priest and candidate.priest.valid then
      local ok,result=pcall(function()
        local a,b=proxy.position,candidate.priest.position
        return (a.x-b.x)^2+(a.y-b.y)^2
      end)
      if ok and type(result)=="number" then
        d2=string.format("%.3f",result)
      end
    end
    -- 0888: capture the actual intermediate recovery transit rather than
    -- guessing the 0418 movement owner from a timeout's high-level phase.
    -- Read-only; never issue, cancel or renew a physical route here.
    local move=worker and worker.movement_request_0418
    local final=move and (move.ground_route_final_destination or move)
    local controller=rawget(_G,"tech_priests_movement_status_0418")
    local status=nil
    if worker and type(controller)=="function" then
      local ok,value=pcall(controller,worker,
        move and move.owner or "station-recovery-0853")
      if ok and type(value)=="table" then status=value end
    end
    local function coord(pos)
      local ok,out=pcall(function()
        if pos and type(pos.x)=="number" and type(pos.y)=="number" then
          return string.format("%.2f,%.2f",pos.x,pos.y)
        end
      end)
      return ok and out or nil
    end
    emit("REVERSAL_ENGINE_SECOND_TRANSIT_OBSERVE tick="..game.tick..
      " worker_position="..tostring(coord(worker and worker.priest
        and worker.priest.valid and worker.priest.position))..
      " worker_station="..tostring(coord(worker and worker.station
        and worker.station.valid and worker.station.position))..
      " junior_goal="..tostring(coord(candidate and candidate.station
        and candidate.station.valid and candidate.station.position))..
      " request_owner="..tostring(move and move.owner)..
      " request_reason="..tostring(move and move.reason)..
      " request_priority="..tostring(move and move.priority)..
      " request_waypoint="..tostring(coord(move))..
      " request_final="..tostring(coord(final))..
      " controller_state="..tostring(worker
        and worker.movement_controller_state_0418)..
      " controller_clamp="..tostring(worker
        and worker.movement_controller_clamp_0418)..
      " status="..tostring(status and status.status)..
      " status_active="..tostring(status and status.active)..
      " route_denial="..tostring(rec.reversal_ancestor_route_denial_0874)..
      " delegated_work_deferred="..tostring(worker and
        worker.reversal_deferred_delegations_0885))
    local shared=0
    if proxy and proxy.valid then
      for _,pair in pairs(registry) do
        if pair~=candidate and pair.proxy==proxy then shared=shared+1 end
      end
    end
    local function duties(pair)
      if not pair then return "missing" end
      local fields={"active_task","current_task","construction_task",
        "build_task","repair_target","combat_target","consecration_target",
        "direct_acquisition_task_0336","active_acquisition_0333",
        "inventory_transfer_custody_0687","station_crafting_task_0337"}
      local active={}
      for _,key in ipairs(fields) do
        if pair[key]~=nil and pair[key]~=false then
          active[#active+1]=key
        end
      end
      return #active>0 and table.concat(active,",") or "none"
    end
    emit("REVERSAL_ENGINE_SECOND_PREFLIGHT_OBSERVE tick="..game.tick..
      " phase="..tostring(rec.phase)..
      " worker_mode="..tostring(worker and worker.mode)..
      " worker_duties="..duties(worker)..
      -- 0882: distinguish a legitimately active emergency commitment from
      -- indefinite fresh assignments that starve an existing real recovery
      -- writ. These are read-only diagnostics, not CI cancellation privileges.
      " worker_active_kind="..tostring(worker and worker.active_task
        and (worker.active_task.kind or worker.active_task.type))..
      " worker_task_started_tick="..tostring(worker and worker.active_task
        and worker.active_task.started_tick)..
      " worker_task_owner="..tostring(worker and worker.active_task
        and worker.active_task.owner_system)..
      " worker_direct_custody="..tostring(worker
        and worker.direct_acquisition_custody_0513 ~= nil)..
      " worker_emergency_current="..tostring(worker and worker.emergency_craft
        and worker.emergency_craft.current
        and worker.emergency_craft.current.kind)..
      " worker_future_reserved="..tostring(worker and
        REVERSAL_ENGINE_0850 and
        REVERSAL_ENGINE_0850.future_worker_reserved(worker))..
      " candidate_recovery_alignment_tick="..tostring(candidate
        and candidate.last_proxy_recovery_alignment_0881
        and candidate.last_proxy_recovery_alignment_0881.tick)..
      " candidate_mode="..tostring(candidate and candidate.mode)..
      " candidate_duties="..duties(candidate)..
      " proxy_valid="..tostring(proxy and proxy.valid)..
      " proxy_name="..inspect(proxy,"name")..
      " proxy_unit="..inspect(proxy,"unit_number")..
      " proxy_force="..inspect(proxy,"force")..
      " priest_force="..inspect(candidate and candidate.priest,"force")..
      " proxy_surface="..inspect(proxy,"surface")..
      " priest_surface="..inspect(candidate and candidate.priest,"surface")..
      " proxy_distance_sq="..d2..
      " proxy_shooting_target="..inspect(proxy,"shooting_target")..
      " proxy_shared="..shared..
      " last_alignment="..tostring(candidate and
        candidate.last_proxy_alignment_0430 and
        candidate.last_proxy_alignment_0430.reason)..
      " last_alignment_failed="..tostring(candidate and
        candidate.last_proxy_alignment_0430 and
        candidate.last_proxy_alignment_0430.failed))
  end
  local second=rec.reversal_stage_0853
  if not(second and second.phase=="in-magos-depot") then return end
  local second_item,why=REVERSAL_DEPOT_0852.get_staged(magos,second)
  local original=tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[4]]
  local leaf=tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[5]]
  if not(second.reversal_stage_index==2
      and second.station_item=="junior-cogitator-station"
      and second.leaf_station_unit==test.units[4]
      and second.worker_station_unit==test.units[3]
      and second_item and second_item.inventory and second_item.inventory.valid
      and second_item.inventory~=first_item.inventory
      and second_item.inventory.get_item_count("junior-cogitator-station")==1
      and first_item.inventory.get_item_count("junior-cogitator-station")==1
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[4]
      and leaf and leaf.priest and leaf.priest.valid
      and leaf.priest.unit_number==test.pair_priest_units[5]
      and registry[test.units[4]]==nil
      and registry[test.units[5]]==nil) then
    error("REVERSAL_ENGINE_SECOND_DEPOT_OR_PRIEST_LOST:"..tostring(why))
  end
  test.phase="second-depot-verified"
  test.second_depot_tick=game.tick
  emit("PASS REVERSAL_ENGINE_SECOND_PHYSICAL_DEPOT tick="..game.tick..
    " first="..test.units[5].." second="..test.units[4]..
    " preserved_priests=2 independent_junior_depots=2"..
    " stored_juniors=2 further_stages_not_claimed=true")
end


-- 0876: proceed with the third and fourth genuinely mined station items.
-- Each stage is advanced by the SAME production 0256 executor. All earlier
-- inventories and original priests must survive with exactly one real item;
-- a bare Lua counter or ghost never authorizes the next milestone.
local function reversal_engine_later_depots(state)
  local test=state.reversal_engine
  if not test or (test.phase~="second-depot-verified"
      and test.phase~="third-recovery"
      and test.phase~="third-depot-verified"
      and test.phase~="fourth-recovery") then return end
  local cases={
    {index=3,before="second-depot-verified",active="third-recovery",
      finished="third-depot-verified",key="reversal_stage_0854",
      item="intermediate-cogitator-station",old_index=3,
      worker_index=2,timeout="REVERSAL_ENGINE_THIRD_DEPOT_TIMEOUT"},
    {index=4,before="third-depot-verified",active="fourth-recovery",
      finished="fourth-depot-verified",key="reversal_stage_0855",
      item="senior-cogitator-station",old_index=2,
      worker_index=1,timeout="REVERSAL_ENGINE_FOURTH_DEPOT_TIMEOUT"}
  }
  local tp=storage and storage.tech_priests
  local registry=tp and tp.pairs_by_station
  local magos=registry and registry[test.units[1]]
  if not(magos and magos.station and magos.station.valid
      and magos.priest and magos.priest.valid
      and magos.priest.unit_number==test.pair_priest_units[1]) then
    error("REVERSAL_ENGINE_LATER_MAGOS_IDENTITY_LOST")
  end
  local rec=tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local executor=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(rec and rec.status=="active"
      and rec.worker_station_unit==test.units[1]
      and tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[test.units[1]]==test.writ_id
      and executor
      and type(executor.service_station_expansion_assignment)=="function") then
    error("REVERSAL_ENGINE_LATER_WRIT_OR_EXECUTOR_LOST")
  end
  local all={
    {key="reversal_stage_0851",item="junior-cogitator-station",old_index=5},
    {key="reversal_stage_0853",item="junior-cogitator-station",old_index=4},
    {key="reversal_stage_0854",item="intermediate-cogitator-station",old_index=3},
    {key="reversal_stage_0855",item="senior-cogitator-station",old_index=2}
  }
  for _,spec in ipairs(cases) do
    if test.phase==spec.before or test.phase==spec.active then
      if test.phase==spec.before then
        test.phase=spec.active
        test["stage_"..spec.index.."_started_tick"]=game.tick
        emit("REVERSAL_ENGINE_LATER_STAGE_STARTED tick="..game.tick..
          " index="..spec.index.." next_item="..spec.item)
      end
      local started=test["stage_"..spec.index.."_started_tick"]
      if type(started)~="number" or game.tick-started>15000 then
        error(spec.timeout.." phase="..tostring(rec.phase)..
          " last_observed="..tostring(test.last_phase))
      end
      -- Verify custody of every predecessor before proceeding.
      local inventories={}
      for index=1,spec.index-1 do
        local prior=all[index]
        local stage=rec[prior.key]
        local entry,why=stage and REVERSAL_DEPOT_0852.get_staged(magos,stage)
        local survivor=tp.pairs_by_priest
          and tp.pairs_by_priest[test.pair_priest_units[prior.old_index]]
        if not(stage and stage.phase=="in-magos-depot"
            and stage.leaf_station_unit==test.units[prior.old_index]
            and entry and entry.inventory and entry.inventory.valid
            and entry.inventory.get_item_count(prior.item)==1
            and not inventories[entry.inventory]
            and survivor and survivor.priest and survivor.priest.valid
            and survivor.priest.unit_number==test.pair_priest_units[prior.old_index]
            and registry[test.units[prior.old_index]]==nil) then
          error("REVERSAL_ENGINE_PRIOR_DEPOT_OR_PRIEST_LOST index="..index..
            " reason="..tostring(why))
        end
        inventories[entry.inventory]=true
      end
      executor.service_station_expansion_assignment(magos)
      -- 0889: after three counted physical depots, expose the *exact*
      -- fourth-stage Magos readiness predicate. Read-only engine telemetry;
      -- never clear a duty, alter a mode or grant a movement/item shortcut.
      if spec.index==4 and game.tick-
          (test.last_fourth_availability_observation_tick or 0)>=600 then
        test.last_fourth_availability_observation_tick=game.tick
        local reason=REVERSAL_SENIOR_0855
          and REVERSAL_SENIOR_0855.availability_blocker_0889(magos,rec)
        local active=magos.active_task
        emit("REVERSAL_ENGINE_FOURTH_AVAILABILITY_OBSERVE tick="..game.tick..
          " blocker="..tostring(reason)..
          " magos_mode="..tostring(magos.mode)..
          " active_kind="..tostring(type(active)=="table"
            and (active.kind or active.type))..
          " active_started="..tostring(type(active)=="table"
            and active.started_tick)..
          " active_owner="..tostring(type(active)=="table"
            and active.owner_system)..
          " expansion_is_writ="..tostring(magos.station_expansion_0256==rec)..
          " expansion_op="..tostring(magos.station_expansion_op_0256~=nil)..
          " emergency_kind="..tostring(magos.emergency_craft
            and magos.emergency_craft.current
            and magos.emergency_craft.current.kind)..
          " direct_custody="..tostring(magos.direct_acquisition_custody_0513~=nil)..
          " future_reserved="..tostring(REVERSAL_ENGINE_0850
            and REVERSAL_ENGINE_0850.future_worker_reserved(magos)))
      end
      if rec.phase~=test.last_phase then
        test.last_phase=rec.phase
        emit("REVERSAL_ENGINE_RECOVERY_PHASE tick="..game.tick..
          " phase="..tostring(rec.phase)..
          " later_index="..spec.index..
          " third_route_denial="..tostring(rec.reversal_intermediate_route_denial_0875)..
          " fourth_route_denial="..tostring(rec.reversal_senior_route_denial_0875))
      end
      local stage=rec[spec.key]
      if not(stage and stage.phase=="in-magos-depot") then return end
      local entry,why=REVERSAL_DEPOT_0852.get_staged(magos,stage)
      local priest=tp.pairs_by_priest
        and tp.pairs_by_priest[test.pair_priest_units[spec.old_index]]
      if not(stage.reversal_stage_index==spec.index
          and stage.station_item==spec.item
          and stage.leaf_station_unit==test.units[spec.old_index]
          and stage.worker_station_unit==test.units[spec.worker_index]
          and entry and entry.inventory and entry.inventory.valid
          and entry.inventory.get_item_count(spec.item)==1
          and not inventories[entry.inventory]
          and priest and priest.priest and priest.priest.valid
          and priest.priest.unit_number==test.pair_priest_units[spec.old_index]
          and registry[test.units[spec.old_index]]==nil) then
        error("REVERSAL_ENGINE_LATER_DEPOT_OR_PRIEST_LOST index="..
          spec.index.." reason="..tostring(why))
      end
      test.phase=spec.finished
      emit("PASS REVERSAL_ENGINE_PHYSICAL_DEPOT tick="..game.tick..
        " index="..spec.index.." station="..test.units[spec.old_index]..
        " original_priest="..test.pair_priest_units[spec.old_index]..
        " counted_real_item=1 separate_depots="..spec.index)
      if spec.index==4 then
        local audit=require("scripts.core.station_starvation_rebuild_0867")
        local proof,reason=audit.audit(magos,rec)
        if not(proof and proof.stage_count==4) then
          error("REVERSAL_ENGINE_FOUR_DEPOT_AUDIT_FAILED:"..tostring(reason))
        end
        test.phase="four-depot-audited"
        emit("PASS REVERSAL_ENGINE_FOUR_DEPOT_AUDIT tick="..game.tick..
          " independent_real_items=4 original_priests=4"..
          " outward_rebuild_not_yet_verified=true")
      end
      return
    end
  end
end

-- Separate post-production hostile wave. Real supplied turrets, ammunition,
-- wall pieces and repair packs enter only the CI-owned station chests.
-- ONLY the combat-only fixture pre-unlocks the two basic defense technologies
-- AFTER the unchanged 108k industry and science acceptance has passed.
-- This deliberate CI-only unlock is not autonomous research evidence.
-- No other research, recipe ingredients, priest role or enemy AI is changed.
local COMBAT_TARGETS={
  "intermediate-cogitator-station","planetary-magos-cogitator-station",
}
local function combat_station(name)
  for _,spec in ipairs(stations) do
    if spec.name==name then
      return prestock_station(spec)
    end
  end
end
local function combat_supply_depot(station)
  local surface=station.surface
  for dy=15,23 do
    for dx=-14,14,4 do
      local pos={x=station.position.x+dx,y=station.position.y+dy}
      if surface.can_place_entity{
          name="steel-chest",position=pos,force=station.force} then
        local depot=surface.create_entity{
          name="steel-chest",position=pos,force=station.force,
          raise_built=true}
        if depot and depot.valid then return depot end
      end
    end
  end
  error("COMBAT_OVERFLOW_DEPOT_SITE_UNAVAILABLE: "..station.name)
end

local function physically_prestock_defense(station,inventory,supply)
  -- The industrial run already manufactured genuine inventory. The combat
  -- fixture contributes only the DEFICIT against the requested physical
  -- defense stock. Counting owned items twice could fill the station and
  -- falsely abort the experiment before the first hostile attack.
  local floor={}
  for _,order in ipairs(supply) do floor[order[1]]=order[2] end
  local depot=nil
  local moved_total,staged_total=0,0
  local function depot_inventory()
    if not depot then depot=combat_supply_depot(station) end
    local inv=depot.get_inventory(defines.inventory.chest)
    if not (inv and inv.valid) then
      error("COMBAT_OVERFLOW_CHEST_INVALID: "..station.name)
    end
    return inv
  end
  for _,order in ipairs(supply) do
    local item,target=order[1],order[2]
    if not prototypes.item[item] then
      error("COMBAT_PRESTOCK_MISSING_ITEM: "..item)
    end
    local before=inventory.get_item_count(item)
    local required=math.max(0,target-before)
    local inserted=required>0
      and inventory.insert{name=item,count=required} or 0
    local staged=0
    local tries=0
    while inserted+staged<required and tries<32 do
      tries=tries+1
      local candidate=nil
      for _,entry in pairs(inventory.get_contents() or {}) do
        local name=type(entry)=="table" and entry.name or nil
        local quantity=type(entry)=="table" and tonumber(entry.count) or 0
        local quality=type(entry)=="table" and entry.quality or "normal"
        local quality_name=type(quality)=="string" and quality
          or (quality and quality.name) or "normal"
        -- Preserve ALL combat minimums. Existing support commodities may
        -- only be moved when their genuinely held stock EXCEEDS the floor.
        local transferable=math.max(0,quantity-(floor[name] or 0))
        if name and transferable>0 and quality_name=="normal"
            and (not candidate or transferable>candidate.count) then
          candidate={name=name,count=transferable}
        end
      end
      if not candidate then
        -- Turrets, ammunition, walls and repair packs must be in the station
        -- inventory where the real defense planner can spend them. Secondary
        -- iron/fuel reserves may instead be staged in a genuine nearby chest,
        -- not erased or misrepresented as immediately usable station stock.
        if item~="iron-plate" and item~="coal" then
          error("COMBAT_OVERFLOW_NO_UNRESERVED_STACK: "..station.name..
            " item="..item.." remaining="..(required-inserted-staged))
        end
        local wanted=required-inserted-staged
        local accepted=depot_inventory().insert{name=item,count=wanted}
        staged=staged+accepted
        staged_total=staged_total+accepted
        if accepted~=wanted then
          error("COMBAT_OVERFLOW_CAPACITY_EXHAUSTED: "..station.name..
            " item="..item)
        end
        break
      end
      local output=depot_inventory()
      local old_station=inventory.get_item_count(candidate.name)
      local old_depot=output.get_item_count(candidate.name)
      local moved=inventory.remove{
        name=candidate.name,count=candidate.count}
      local deposited=output.insert{
        name=candidate.name,count=moved}
      if deposited~=moved then
        local returned=inventory.insert{
          name=candidate.name,count=moved-deposited}
        if returned~=moved-deposited then
          error("COMBAT_OVERFLOW_RESTITUTION_FAILED: "..candidate.name)
        end
        error("COMBAT_OVERFLOW_CAPACITY_EXHAUSTED: "..station.name)
      end
      if inventory.get_item_count(candidate.name)
          +output.get_item_count(candidate.name)~=old_station+old_depot then
        error("COMBAT_OVERFLOW_ACCOUNTING_LOSS: "..candidate.name)
      end
      moved_total=moved_total+moved
      inserted=inserted+inventory.insert{
        name=item,count=required-inserted-staged}
    end
    if inserted+staged~=required
        or inventory.get_item_count(item)<math.min(target,before+inserted) then
      error("COMBAT_PRESTOCK_REFUSED: "..station.name.." item="..item..
        " inserted="..inserted.." staged="..staged.." needed="..required)
    end
  end
  emit("COMBAT_PHYSICAL_SUPPLY rank="..station.name..
    " overflow_chest="..tostring(depot and depot.unit_number)..
    " previous_items_relocated="..moved_total..
    " physically_staged_support="..staged_total..
    " equipment_types="..#supply)
end

-- Exposed only by the CI-only harness for deterministic inventory regression.
M.test_prestock_defense=physically_prestock_defense

-- Factorio 2.x moved unit commands from LuaEntity to LuaCommandable.
-- Attack orders still travel through the real engine AI; the fixture merely
-- gives the newly spawned biter an actual hostile station target.
local function command_biter_attack(unit,station)
  local commandable=unit and unit.commandable
  if not (commandable and commandable.valid) then
    error("COMBAT_SPAWNED_UNIT_NOT_COMMANDABLE: "..tostring(unit and unit.name))
  end
  commandable.set_command{
    type=defines.command.attack,target=station,
    -- Keep a commanded biter on its genuine physical target.
    distraction=defines.distraction.none,
  }
end
M.test_command_biter_attack=command_biter_attack

-- Spend an actual pre-stocked wall item to build a vulnerable, player-owned
-- forward screen. Biters must damage a real entity before any AI-defense
-- acceptance can pass; event injection, synthetic damage and scripted
-- technology changes are prohibited by this fixture.
local function combat_attack_wall(station,station_inventory,index,axis_x,axis_y)
  local surface=station.surface
  axis_x=axis_x or 1
  axis_y=axis_y or 0
  -- Keep targets near the legal perimeter so constructed turrets can cover them.
  local pair=storage and storage.tech_priests
      and storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[station.unit_number]
  local radius=tonumber(pair and (pair.radius or pair.base_radius)) or 28
  if pair and type(_G.refresh_pair_radius)=="function" then
    local ok,r=pcall(_G.refresh_pair_radius,pair)
    if ok and tonumber(r) then radius=tonumber(r) end
  end
  local screen_distance=math.max(8,math.min(95,radius)-6)
  -- The wall is physically built at the selected attack flank, just INSIDE
  -- the station's planned wall ring. The index spreads targets tangentially.
  local offset=(index-2)*4
  local pos={x=station.position.x+screen_distance*axis_x-axis_y*offset,
    y=station.position.y+screen_distance*axis_y+axis_x*offset}
  if not surface.can_place_entity{
      name="stone-wall",position=pos,force=station.force} then
    error("COMBAT_PHYSICAL_WALL_SITE_BLOCKED: "..station.name..
      " index="..index)
  end
  local consumed=station_inventory.remove{name="stone-wall",count=1}
  if consumed~=1 then
    error("COMBAT_PHYSICAL_WALL_NOT_OWNED: "..station.name)
  end
  local wall=surface.create_entity{
    name="stone-wall",position=pos,force=station.force,raise_built=true}
  if not (wall and wall.valid) then
    local returned=station_inventory.insert{name="stone-wall",count=1}
    if returned~=1 then error("COMBAT_WALL_ITEM_RESTITUTION_FAILED") end
    error("COMBAT_WALL_ENGINE_PLACEMENT_FAILED: "..station.name)
  end
  return wall
end
M.test_combat_attack_wall=combat_attack_wall

local function combat_preset_defense_research(force)
  if not (LATE_COMBAT_SMOKE and force and force.technologies
      and force.recipes) then
    error("COMBAT_TECH_PRESET_OUTSIDE_LATE_FIXTURE")
  end
  local unlocked={}
  for _,name in ipairs({"gun-turret","stone-wall"}) do
    local tech=force.technologies[name]
    local recipe=force.recipes[name]
    if not tech or not recipe then
      error("COMBAT_TECH_PRESET_MISSING_PROTOTYPE: "..name)
    end
    if tech.researched~=true then
      -- Fixture-specific research preset. Factorio applies the technology's
      -- actual recipe unlock; do not independently force-enable a recipe.
      tech.researched=true
      unlocked[#unlocked+1]=name
    end
    if tech.researched~=true or recipe.enabled~=true then
      error("COMBAT_TECH_PRESET_ENGINE_RECIPE_LOCKED: "..name)
    end
  end
  emit("COMBAT_TECH_PRESET gun_turret="..
    tostring(force.technologies["gun-turret"].researched)..
    " wall="..tostring(force.technologies["stone-wall"].researched)..
    " recipes_engine_unlocked=true"..
    " newly_preset="..table.concat(unlocked,",")..
    " after_industry_acceptance=true")
  return true
end
M.test_combat_preset_defense_research=combat_preset_defense_research

local function combat_wave(state)
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local damage_key=tostring(defines.events.on_entity_damaged)
  local routes=registry and registry.event_routes
      and registry.event_routes[damage_key] or {}
  local installed=false
  local observer=false
  for _,entry in ipairs(routes) do
    if entry.owner=="combat_defense_reaction_0816"
        and entry.route=="hostile-entity-damaged" then installed=true end
    if entry.owner=="ci_ground_rank_harness"
        and entry.route=="combat-physical-damage-observer" then observer=true end
  end
  local status=registry and registry.event_delivery_status
      and registry.event_delivery_status(defines.events.on_entity_damaged)
  emit("COMBAT_ENGINE_DAMAGE_HANDLER installed="..
    tostring(status and status.installed)..
    " verified="..tostring(status and status.verified)..
    " restricted_filter="..tostring(status and status.filter_present)..
    " rebindings="..tostring(status and status.rebindings))
  if not (status and status.verified and not status.filter_present) then
    error("COMBAT_DAMAGE_HANDLER_NOT_DELIVERABLE: registered routes have no unrestricted Factorio engine dispatcher")
  end
  if not (installed and observer) then
    error("COMBAT_DAMAGE_EVENT_ROUTES_MISSING: ledger="..
      tostring(installed).." observer="..tostring(observer))
  end
  emit("COMBAT_DAMAGE_ROUTES ledger="..tostring(installed)..
    " observer="..tostring(observer).." total="..tostring(#routes))
  -- Production/science acceptance has already completed at 108000 ticks.
  -- Only now permit the intentional combat technology fixtures.
  combat_preset_defense_research(game.forces.player)
  state.combat_sites={}
  local supply={
    {"gun-turret",5},{"firearm-magazine",160},
    {"stone-wall",70},{"repair-pack",36},
    {"iron-plate",80},{"coal",40},
  }
  for _,name in ipairs(COMBAT_TARGETS) do
    local station=combat_station(name)
    local pair=station and storage.tech_priests
      and storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[station.unit_number]
    if not (station and station.valid and pair and pair.priest
        and pair.priest.valid) then
      error("COMBAT_STATION_PAIR_MISSING: "..name)
    end
    local inv=station.get_inventory(defines.inventory.chest)
    if not (inv and inv.valid) then
      error("COMBAT_STATION_INVENTORY_INVALID: "..name)
    end
    physically_prestock_defense(station,inv,supply)
    local perimeter=pair.defense_perimeter_0259 or {}
    local baseline=perimeter.turrets_built or 0
    -- Two deliberately different real approaches. Industrial acceptance,
    -- actual damage, build inventory and enemy AI are otherwise unchanged.
    local attack_side=name=="intermediate-cogitator-station"
      and "north" or "east"
    local attack_dx=attack_side=="east" and 1 or 0
    local attack_dy=attack_side=="north" and -1 or 0
    local attackers,targets,target_units,target_positions={},{},{},{}
    for i=1,3 do
      local wall=combat_attack_wall(
        station,inv,i,attack_dx,attack_dy)
      -- Spawn OUTSIDE the attacked wall on the incoming side.
      local pos={x=wall.position.x+1.5*attack_dx,
        y=wall.position.y+1.5*attack_dy}
      if not station.surface.can_place_entity{
          name="small-biter",position=pos,force=game.forces.enemy} then
        error("COMBAT_BITER_SITE_BLOCKED: "..name.." unit="..i)
      end
      local unit=station.surface.create_entity{
        name="small-biter",position=pos,force=game.forces.enemy}
      if not (unit and unit.valid) then
        error("COMBAT_SPAWN_FAILED: "..name.." unit="..i)
      end
      local commanded,err=pcall(function()
        command_biter_attack(unit,wall)
      end)
      if not commanded then
        error("COMBAT_ATTACK_COMMAND_FAILED: "..tostring(err))
      end
      attackers[#attackers+1]=unit.unit_number
      targets[#targets+1]=wall
      target_units[#target_units+1]=wall.unit_number
      target_positions[#target_positions+1]={
        x=wall.position.x,y=wall.position.y}
    end
    state.combat_sites[name]={
      station_unit=station.unit_number,turrets_before=baseline,
      attack_side=attack_side,attack_dx=attack_dx,attack_dy=attack_dy,
      created_biter_units=attackers,physical_attack_targets=targets,
      physical_attack_target_units=target_units,
      physical_attack_target_positions=target_positions,
      damage_started=false,observed_engine_damage=0,
      wall_health_history={},wall_transitions=0,
    }
    emit("COMBAT_WAVE_START rank="..name..
      " approach="..attack_side..
      " biters="..#attackers.." prestock_turrets=5"..
      " prestock_magazines=160 prestock_walls=70"..
      " turrets_before="..baseline)
  end
  state.combat_started_tick=game.tick
end

-- Actual per-entity health and lifetime: if a purchased fixture wall
-- vanishes without a damage/death event, distinguish script removal from
-- normal Factorio combat instead of attributing an invented biter hit.
local function combat_watch_targets(state)
  for name,record in pairs(state.combat_sites or {}) do
    for i,unit_number in ipairs(record.physical_attack_target_units or {}) do
      local wall=record.physical_attack_targets
          and record.physical_attack_targets[i]
      local hist=record.wall_health_history[unit_number] or {}
      local living=wall and wall.valid==true
      local health=living and wall.health or nil
      if not hist.initialized then
        hist.initialized=true
        hist.alive=living
        hist.health=health
      elseif hist.alive and not living then
        emit("COMBAT_WALL_VANISHED rank="..name..
          " unit="..tostring(unit_number)..
          " tick="..tostring(game.tick)..
          " last_health="..tostring(hist.health)..
          " engine_damage_events="..tostring(record.observed_engine_damage or 0))
        hist.alive=false
      elseif living and health~=hist.health then
        record.wall_transitions=(record.wall_transitions or 0)+1
        if record.wall_transitions<=12 then
          emit("COMBAT_WALL_HEALTH_CHANGE rank="..name..
            " unit="..tostring(unit_number)..
            " tick="..tostring(game.tick)..
            " prior="..tostring(hist.health)..
            " now="..tostring(health)..
            " engine_damage_events="..tostring(record.observed_engine_damage or 0))
        end
        hist.health=health
      end
      record.wall_health_history[unit_number]=hist
    end
  end
end

-- Only real Factorio small biters are used for the post-construction
-- engagement proof. They are ordered against the same physical screen
-- AFTER the Cogitator has already built and armed its directional turret.
-- No scripted damage, forced deaths, ammunition or new technology is added.
local function combat_reassault(state)
  if state.reassault_started_tick then return end
  for _,name in ipairs(COMBAT_TARGETS) do
    local record=state.combat_sites and state.combat_sites[name]
    local station=combat_station(name)
    local pair=station and storage.tech_priests.pairs_by_station[record.station_unit]
    if not (record and station and station.valid and pair) then
      error("COMBAT_REASSAULT_PAIR_MISSING: "..name)
    end
    local defense=pair.defense_perimeter_0259 or {}
    local baseline=defense.turrets_built_at_first_hostile_hit_0816
      or record.turrets_before or 0
    if (defense.turrets_built or 0)<=baseline then
      error("COMBAT_REASSAULT_NO_NEW_TURRET: "..name)
    end
    local armed=false
    for _,incident in ipairs(defense.hostile_incidents_0817 or {}) do
      if incident.station_unit==station.unit_number
          and incident.defense_position then
        local nearby=station.surface.find_entities_filtered{
          force=station.force,name="gun-turret",
          position=incident.defense_position,radius=9}
        for _,turret in ipairs(nearby or {}) do
          if turret.valid then
            local inventory=turret.get_inventory(defines.inventory.turret_ammo)
            if inventory and inventory.valid
                and inventory.get_item_count("firearm-magazine")>0 then
              armed=true;break
            end
          end
        end
      end
    end
    if not armed then
      error("COMBAT_REASSAULT_TURRET_UNARMED: "..name)
    end
    record.reassault_units={}
    record.reassault_turret_hits=0
    record.reassault_turret_damage=0
    record.reassault_enemy_deaths=0
    for i,wall in ipairs(record.physical_attack_targets or {}) do
      if not (wall and wall.valid) then
        error("COMBAT_REASSAULT_PHYSICAL_WALL_LOST: "..name.." index="..i)
      end
      local pos={
        x=wall.position.x+1.5*record.attack_dx,
        y=wall.position.y+1.5*record.attack_dy,
      }
      if not station.surface.can_place_entity{
          name="small-biter",position=pos,force=game.forces.enemy} then
        error("COMBAT_REASSAULT_BITER_SITE_BLOCKED: "..name.." index="..i)
      end
      local unit=station.surface.create_entity{
        name="small-biter",position=pos,force=game.forces.enemy}
      if not (unit and unit.valid) then
        error("COMBAT_REASSAULT_SPAWN_FAILED: "..name.." index="..i)
      end
      command_biter_attack(unit,wall)
      record.reassault_units[#record.reassault_units+1]=unit.unit_number
    end
    emit("COMBAT_REASSAULT_START rank="..name..
      " approach="..record.attack_side..
      " actual_biters="..#record.reassault_units..
      " turret_built="..tostring(defense.turrets_built-baseline)..
      " armed_before_attack=true")
  end
  state.reassault_started_tick=game.tick
end

local function combat_checkpoint(state,final)
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local stats=registry and registry.stats or {}
  local route_key="event:"..tostring(defines.events.on_entity_damaged)..":"
  local ledger=stats[route_key.."combat_defense_reaction_0816:hostile-entity-damaged"] or {}
  local observer=stats[route_key.."ci_ground_rank_harness:combat-physical-damage-observer"] or {}
  emit("COMBAT_EVENT_DISPATCH tick="..tostring(game.tick)..
    " ledger_calls="..tostring(ledger.calls or 0)..
    " ledger_errors="..tostring(ledger.errors or 0)..
    " observer_calls="..tostring(observer.calls or 0)..
    " observer_errors="..tostring(observer.errors or 0)..
    " registry_handler_errors="..tostring(stats.handler_errors or 0))
  local seen_damage,seen_raw=0,0
  local completed_response=0
  for _,name in ipairs(COMBAT_TARGETS) do
    local record=state.combat_sites and state.combat_sites[name]
    local station=combat_station(name)
    local pair=station and station.valid and storage.tech_priests
      and storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[record.station_unit]
    if not (pair and pair.station and pair.station.valid
        and pair.priest and pair.priest.valid) then
      error("COMBAT_PAIR_LOST: "..name)
    end
    local defense=pair.defense_perimeter_0259 or {}
    local hit_count=defense.hostile_hits_0816 or 0
    local incidents=defense.hostile_incidents_0817 or {}
    local retained=0
    local incident_details={}
    for _,incident in ipairs(incidents) do
      if incident.station_unit==station.unit_number
          and incident.expires_at and incident.expires_at>game.tick then
        retained=retained+1
        incident_details[#incident_details+1]=
          tostring(incident.id)..":"..tostring(incident.status)..
          ":hits="..tostring(incident.hit_count)..
          ":active="..tostring(incident.active_until)..
          ":expiry="..tostring(incident.expires_at)
      end
    end
    if hit_count>0 and retained==0 then
      error("COMBAT_LEDGER_FORGOT_ATTACK_SITE: "..name)
    end
    -- Canonical dispatcher catches exceptions to keep Factorio alive.
    -- That is NOT an acceptance pass: fail on any swallowed construction
    -- error even when a turret was already erected and armed correctly.
    local failure=pair.defense_dispatch_failure_0818
    if final and failure and (failure.count or 0)>0 then
      error("COMBAT_DEFENSE_DISPATCH_ERRORS: "..name..
        " count="..tostring(failure.count)..
        " reason="..tostring(failure.reason))
    end
    local built=defense.turrets_built or 0
    local after_attack=built-
      (defense.turrets_built_at_first_hostile_hit_0816 or record.turrets_before)
    -- Combat turrets are erected at the station's PERIMETER, not inside
    -- a fixed 32-tile circle around its center. Require physical coverage
    -- of the attacked incident waypoint and deduplicate overlapping scans.
    local turrets,seen_turret={},{}
    local matching_front_incidents=0
    for _,incident in ipairs(incidents) do
      if incident.station_unit==station.unit_number
          and incident.expires_at and incident.expires_at>game.tick
          and incident.defense_position then
        -- Only classify incidents physically near the test's real walls as
        -- proof of this attack direction. Other legitimate incidents are
        -- retained without being mislabeled by the fixture.
        local is_fixture_attack=false
        for _,wall_pos in ipairs(record.physical_attack_target_positions or {}) do
          if incident.origin_position then
            local dx=wall_pos.x-incident.origin_position.x
            local dy=wall_pos.y-incident.origin_position.y
            if dx*dx+dy*dy<=144 then is_fixture_attack=true;break end
          end
        end
        if is_fixture_attack then
          matching_front_incidents=matching_front_incidents+1
          local px=incident.defense_position.x-station.position.x
          local py=incident.defense_position.y-station.position.y
          local radial=math.sqrt(px*px+py*py)
          local along=px*record.attack_dx+py*record.attack_dy
          local operating=tonumber(pair.radius or pair.base_radius) or 28
          if type(_G.refresh_pair_radius)=="function" then
            local ok,range=pcall(_G.refresh_pair_radius,pair)
            if ok and tonumber(range) then operating=tonumber(range) end
          end
          local planned_radius=math.max(8,math.min(96,operating))-1
          if along<radial*0.75 or math.abs(radial-planned_radius)>2 then
            error("COMBAT_ATTACK_DIRECTION_MISCLASSIFIED: "..name..
              " expected="..record.attack_side..
              " actual="..tostring(incident.defense_position.x)..","..
                tostring(incident.defense_position.y)..
              " ring="..tostring(planned_radius))
          end
        end
        local covered=station.surface.find_entities_filtered{
          force=station.force,name="gun-turret",
          position=incident.defense_position,radius=9}
        for _,candidate in ipairs(covered or {}) do
          if candidate.valid and not seen_turret[candidate.unit_number] then
            seen_turret[candidate.unit_number]=true
            turrets[#turrets+1]=candidate
          end
        end
      end
    end
    local live_targets=0
    for _,wall in ipairs(record.physical_attack_targets or {}) do
      if wall and wall.valid then live_targets=live_targets+1 end
    end
    local spawned_live=0
    local biter_details={}
    local nearby=station.surface.find_entities_filtered{
      force=game.forces.enemy,type="unit",
      position=station.position,radius=110}
    local tracked={}
    for _,unit_number in ipairs(record.created_biter_units or {}) do
      tracked[unit_number]=true
    end
    for _,unit in ipairs(nearby or {}) do
      if unit.valid and tracked[unit.unit_number] then
        spawned_live=spawned_live+1
        local cmd=nil
        local commandable=unit.commandable
        pcall(function() cmd=commandable and commandable.command end)
        biter_details[#biter_details+1]=unit.unit_number..":"..
          tostring(math.floor(unit.position.x*10)/10)..","..
          tostring(math.floor(unit.position.y*10)/10)..
          ":command="..tostring(cmd and cmd.type)..
          ":health="..tostring(unit.health)
      end
    end
    local loaded,armed_correct_flank=0,0
    local operating=tonumber(pair.radius or pair.base_radius) or 28
    if type(_G.refresh_pair_radius)=="function" then
      local ok,range=pcall(_G.refresh_pair_radius,pair)
      if ok and tonumber(range) then operating=tonumber(range) end
    end
    local ring=math.max(8,math.floor(operating-1))
    for _,turret in ipairs(turrets) do
      if turret.valid then
        local inventory=turret.get_inventory(defines.inventory.turret_ammo)
        local count=inventory and inventory.valid
          and inventory.get_item_count("firearm-magazine") or 0
        loaded=loaded+count
        local dx=turret.position.x-station.position.x
        local dy=turret.position.y-station.position.y
        local radial=math.sqrt(dx*dx+dy*dy)
        local forward=dx*record.attack_dx+dy*record.attack_dy
        if count>0 and radial>=math.max(4,ring-6)
            and radial<=operating+0.5 and forward>=radial*0.75 then
          armed_correct_flank=armed_correct_flank+1
        end
      end
    end
    if (record.observed_engine_damage or 0)>0 then seen_raw=seen_raw+1 end
    if hit_count>0 then seen_damage=seen_damage+1 end
    if hit_count>0 and matching_front_incidents>0
        and after_attack>0 and armed_correct_flank>0 then
      completed_response=completed_response+1
    end
    local bridge=rawget(_G,"TechPriestsDefensePerimeter0259")
    local dispatcher_root=storage.tech_priests.single_dispatcher_0510 or {}
    local broker_root=storage.tech_priests.runtime_tick_broker_0600 or {}
    local service=broker_root.service_stats and
      broker_root.service_stats.single_dispatcher_0510 or {}
    local inventory=station.get_inventory(defines.inventory.chest)
    emit("COMBAT_DEFENSE_DISPATCH rank="..name..
      " bridge="..tostring(bridge~=nil)..
      " has_pending="..tostring(bridge and bridge.has_pending(pair))..
      " last_bridge_tick="..tostring(defense.last_dispatcher_service_tick_0818)..
      " bridge_probe_tick="..tostring(defense.last_defense_dispatch_probe_tick_0818)..
      " bridge_entry_tick="..tostring(defense.last_defense_bridge_entry_tick_0818)..
      " handoff_error_count="..tostring(
        pair.defense_dispatch_failure_0818 and pair.defense_dispatch_failure_0818.count or 0)..
      " handoff_error="..tostring(
        pair.defense_dispatch_failure_0818 and pair.defense_dispatch_failure_0818.reason or "none")..
      " single_dispatcher_pairs="..tostring(
        dispatcher_root.stats and dispatcher_root.stats.pairs_processed or 0)..
      " broker_single_run="..tostring(service and service.run or 0)..
      " canonical_family="..tostring(
        pair.canonical_action_0744 and pair.canonical_action_0744.family)..
      " dispatcher_action="..tostring(pair.dispatcher_0510 and pair.dispatcher_0510.action)..
      " custody_direct="..tostring(pair.direct_acquisition_custody_0513~=nil)..
      " custody_machine="..tostring(pair.machine_logistics_custody_0528~=nil)..
      " custody_feed="..tostring(pair.emergency_facility_feed_custody_0357~=nil)..
      " turret_in_station="..tostring(inventory and inventory.get_item_count("gun-turret") or 0)..
      " ammo_in_station="..tostring(inventory and inventory.get_item_count("firearm-magazine") or 0))
    emit("COMBAT_STAGE rank="..name..
      " tick="..game.tick.." hits="..hit_count..
      " turret_new_after_hit="..after_attack..
      " turret_alive="..#turrets.." ammunition_loaded="..loaded..
      " approach="..record.attack_side..
      " matching_front_incidents="..matching_front_incidents..
      " armed_correct_flank="..armed_correct_flank..
      " post_build_turret_hits="..tostring(record.reassault_turret_hits or 0)..
      " post_build_turret_damage="..tostring(record.reassault_turret_damage or 0)..
      " post_build_enemy_deaths="..tostring(record.reassault_enemy_deaths or 0)..
      " physical_attack_walls_alive="..live_targets..
      " spawned_biters_alive="..spawned_live..
      " physical_damage_events="..tostring(record.observed_engine_damage or 0)..
      " retained_incidents="..retained..
      " incident_details="..table.concat(incident_details,";")..
      " biter_positions="..table.concat(biter_details,";")..
      " threats="..tostring(defense.threats and #defense.threats or 0)..
      " active_task="..tostring(pair.defense_task_0259
        and pair.defense_task_0259.type)..
      " last_reason="..tostring(defense.last_reason))
  end
  if final then
    if seen_raw<#COMBAT_TARGETS then
      error("COMBAT_NO_ENGINE_DAMAGE_ON_TARGET: both attacked stations require real wall hits")
    end
    if seen_damage<#COMBAT_TARGETS then
      error("COMBAT_LEDGER_REJECTED_ENGINE_DAMAGE: both stations must retain real hostile damage")
    end
    if completed_response<#COMBAT_TARGETS then
      error("COMBAT_DIRECTIONAL_DEFENSE_NOT_ESTABLISHED: each attacked station must build and arm a perimeter turret on its actual attack flank")
    end
    for _,name in ipairs(COMBAT_TARGETS) do
      local record=state.combat_sites[name]
      if not record.reassault_units or #record.reassault_units<1 then
        error("COMBAT_POST_BUILD_REASSAULT_MISSING: "..name)
      end
      if (record.reassault_turret_hits or 0)<1 then
        error("COMBAT_TURRET_DID_NOT_ENGAGE_REASSAULT: "..name)
      end
    end
    emit("PASS hostile turret engagement under renewed actual biter assaults ranks=2")
    emit("PASS hostile-damage defensive establishment attacked="..
      seen_damage.." armed_after_attack="..completed_response..
      " north_and_east_physical_flanks_verified=true")
  end
end

-- Observe actual Factorio damage on the fixture's purchased, constructed
-- walls. No damage is dealt by this observer and it cannot satisfy the ledger
-- or alter the autonomous defense response.
local function combat_damage_observe(event)
  if not LATE_COMBAT_SMOKE then return end
  local victim=event and event.entity
  if not (victim and victim.valid and victim.unit_number) then return end
  local tp=storage and storage.tech_priests or {}
  local state=tp.ci_ground_rank_test
  if not (state and state.combat_sites) then return end
  for name,record in pairs(state.combat_sites) do
    for _,biter_unit in ipairs(record.reassault_units or {}) do
      if victim.unit_number==biter_unit then
        local attacker=(event.cause and event.cause.valid and event.cause)
          or (event.source and event.source.valid and event.source)
        if attacker and attacker.name=="gun-turret"
            and attacker.force==game.forces.player then
          record.reassault_turret_hits=(record.reassault_turret_hits or 0)+1
          record.reassault_turret_damage=(record.reassault_turret_damage or 0)
              +(tonumber(event.final_damage_amount) or 0)
          if record.reassault_turret_hits<=5 then
            emit("COMBAT_REASSAULT_TURRET_HIT rank="..name..
              " biter_unit="..tostring(biter_unit)..
              " turret_unit="..tostring(attacker.unit_number)..
              " real_damage="..tostring(event.final_damage_amount))
          end
        end
        return
      end
    end
    for _,target_unit in ipairs(record.physical_attack_target_units or {}) do
      if victim.unit_number==target_unit then
        record.observed_engine_damage=(record.observed_engine_damage or 0)+1
        if record.observed_engine_damage<=8 then
          local cause=event.cause
          local source=event.source
          local attack_force=event.force
          local pair=tp.pairs_by_station
              and tp.pairs_by_station[record.station_unit]
          local defense=pair and pair.defense_perimeter_0259 or {}
          emit("COMBAT_RAW_DAMAGE rank="..name..
            " tick="..tostring(game.tick)..
            " target="..tostring(victim.name)..
            " target_unit="..tostring(target_unit)..
            " damage="..tostring(event.final_damage_amount)..
            " force="..tostring(attack_force and attack_force.name or "none")..
            " cause="..tostring(cause and cause.valid and cause.name or "none")..
            " source="..tostring(source and source.valid and source.name or "none")..
            " ledger_hits="..tostring(defense.hostile_hits_0816 or 0))
        end
        return
      end
    end
  end
end
M.test_combat_damage_observe=combat_damage_observe

-- Read-only observer for genuine enemy deaths in the combat-only fixture.
local function combat_biter_died(event)
  if not LATE_COMBAT_SMOKE then return end
  local victim=event and event.entity
  if not (victim and victim.unit_number) then return end
  local state=storage and storage.tech_priests
      and storage.tech_priests.ci_ground_rank_test
  for name,record in pairs(state and state.combat_sites or {}) do
    for _,unit_number in ipairs(record.physical_attack_target_units or {}) do
      if victim.unit_number==unit_number then
        local attacker=event.cause
        emit("COMBAT_WALL_DEATH rank="..name..
          " unit="..tostring(unit_number)..
          " killer="..tostring(attacker and attacker.valid and attacker.name or "none")..
          " force="..tostring(event.force and event.force.name or "none")..
          " tick="..tostring(game.tick))
        return
      end
    end
    for _,unit_number in ipairs(record.reassault_units or {}) do
      if victim.unit_number==unit_number then
        record.reassault_enemy_deaths=(record.reassault_enemy_deaths or 0)+1
        local attacker=event.cause
        emit("COMBAT_REASSAULT_ENEMY_DEATH rank="..name..
          " biter_unit="..tostring(unit_number)..
          " cause="..tostring(attacker and attacker.valid and attacker.name or "none"))
        return
      end
    end
    for _,unit_number in ipairs(record.created_biter_units or {}) do
      if victim.unit_number==unit_number then
        local attacker=event.cause
        emit("COMBAT_BITER_DEATH rank="..name..
          " unit="..tostring(unit_number)..
          " killer="..tostring(attacker and attacker.valid and attacker.name or "none")..
          " tick="..tostring(game.tick))
        return
      end
    end
  end
end

local function initialize_fixture()
  storage.tech_priests=storage.tech_priests or {}
  local state=storage.tech_priests.ci_ground_rank_test or {}
  storage.tech_priests.ci_ground_rank_test=state
  if state.started_tick or state.failed then return end
  local ok,err=pcall(function()
    setup_fixture()
    prestock_fixture(state)
    verify_laser_mining_rate()
    -- CI-only safety probe: opt into the historically disabled raw-resource
    -- governor in this isolated mod copy; production defaults remain unchanged.
    local raw=rawget(_G,"TechPriestsBootstrapResourceGovernor0637")
    if not (raw and type(raw.root)=="function") then
      error("raw-resource governor not installed")
    end
    local raw_state=raw.root()
    raw_state.enabled=true
    emit("TEST_ONLY_RAW_GOVERNOR_ENABLED=true")
    state.started_tick=game.tick
    state.initial_researched=count_researched()
    emit("START integrated fixture tick="..game.tick..
      " pre-stocked-machinery=true empty-control=junior")
  end)
  if not ok then
    state.failed=tostring(err)
    emit("FAIL "..state.failed)
  end
end

local function pulse()
  storage.tech_priests=storage.tech_priests or {}
  local key="ci_ground_rank_test"
  local state=storage.tech_priests[key] or {}
  storage.tech_priests[key]=state
  if state.finished or state.failed then return {processed=0,acted=0,detail="fixture-complete"} end
  local ok,err=pcall(function()
    if not state.started_tick then error("fixture on_init did not run") end
    local elapsed=game.tick-state.started_tick
    if elapsed>=900 and not state.pairs_verified then
      verify_pairs()
      state.pairs_verified=true
    end
    if elapsed>=1200 and not state.recovery_verified then
      verify_recovery()
      state.recovery_verified=true
    end
    if SAVE_RELOAD_SMOKE then
      if elapsed>=900 and not state.cargo_engine_prepared then
        cargo_engine_prepare(state)
      end
      if elapsed>=1800 and not state.cargo_engine_prepared then
        error("CARGO_ENGINE_PRE_SAVE_PICKUP_TIMEOUT")
      end
      if elapsed>=2700 and state.save_reload_requested
          and state.save_reload_verified
          and not state.cargo_engine_verified then
        cargo_engine_verify_after_reload(state)
      end
      if elapsed>=3000 and state.cargo_engine_verified
          and not state.cargo_engine_death_prepared then
        cargo_engine_death_prepare(state)
      end
      if elapsed>=3300 and state.cargo_engine_death_prepared
          and not state.cargo_engine_death_save_verified then
        cargo_engine_verify_stranded_reload(state)
      end
      if elapsed>=3000 and state.cargo_engine_death_prepared
          and state.cargo_engine_death_save_verified
          and not state.cargo_engine_death_verified then
        cargo_engine_death_recover(state)
      end
      if elapsed>=9000 and state.cargo_engine_death_verified
          and not state.relocation_engine then
        relocation_engine_place(state)
      end
      if state.relocation_engine then
        relocation_engine_service(state)
      end
      if elapsed>=4500 and state.cargo_engine_death_verified
          and not state.ore_engine then
        ore_engine_place(state)
      end
      if state.ore_engine then
        ore_engine_service(state)
      end
      if state.ore_engine and state.ore_engine.phase=="complete"
          and state.relocation_engine
          and state.relocation_engine.phase=="complete"
          and not state.reversal_engine then
        reversal_engine_place(state)
      end
      if state.reversal_engine then
        reversal_engine_verify(state)
        reversal_engine_first_depot(state)
        reversal_engine_second_depot(state)
        reversal_engine_later_depots(state)
      end
      if elapsed>=21000 and not (state.ore_engine
          and state.ore_engine.phase=="complete") then
        error("ORE_ENGINE_COUNTED_RETURN_TIMEOUT")
      end
      if elapsed>=18000 and not (state.relocation_engine
          and state.relocation_engine.phase=="complete") then
        error("RELOCATION_ENGINE_PHYSICAL_TIMEOUT")
      end
      if elapsed>=11000 and not state.cargo_engine_death_verified then
        error("CARGO_ENGINE_DEATH_REIMPRINT_TIMEOUT")
      end
      if elapsed>=1800 and state.pairs_verified
          and not state.save_reload_requested then
        save_reload_checkpoint(state)
      end
      if elapsed>=2700 and state.save_reload_requested
          and not state.save_reload_verified then
        verify_save_reload_checkpoint(state)
      end
    end
    if elapsed>=900 and elapsed%900<60 then emit_industry() end
    for _,mark in ipairs({900,3600,9000,18000,36000,72000,108000}) do
      if elapsed>=mark and not (state.prestock_checked
          and state.prestock_checked[mark]) then
        prestock_checkpoint(state,mark)
        state.prestock_checked=state.prestock_checked or {}
        state.prestock_checked[mark]=true
      end
    end
    if (elapsed>=900 and not state.probe_900) then
      bootstrap_probe()
      state.probe_900=true
    end
    if elapsed>=3600 and not state.probe_3600 then
      bootstrap_probe()
      state.probe_3600=true
    end
    if elapsed>=9000 and not state.probe_9000 then
      bootstrap_probe()
      state.probe_9000=true
    end
    -- Capture real progress in the same world at each elapsed milestone.
    -- Never fail or inject science at the historical 36k boundary.
    for _,checkpoint in ipairs(DURATION_CHECKPOINTS) do
      if elapsed>=checkpoint and not (state.duration_checkpoints
          and state.duration_checkpoints[checkpoint]) then
        duration_checkpoint(state,checkpoint)
        bootstrap_probe()
      end
    end
    if elapsed>=108000 and not state.industry_verified then
      duration_diagnosis(state)
      verify_final(state)
      state.industry_verified=true
      if not LATE_COMBAT_SMOKE then state.finished=true end
    end
    if LATE_COMBAT_SMOKE and state.industry_verified then
      if elapsed>=108060 and not state.combat_started_tick then
        combat_wave(state)
      end
      if state.combat_started_tick then combat_watch_targets(state) end
      if elapsed>=112000 and state.combat_started_tick
          and not state.reassault_started_tick then
        combat_reassault(state)
      end
      for _,mark in ipairs({110400,114000,118800}) do
        if elapsed>=mark and not (state.combat_marks and state.combat_marks[mark]) then
          combat_checkpoint(state,false)
          state.combat_marks=state.combat_marks or {}
          state.combat_marks[mark]=true
        end
      end
      if elapsed>=122400 and not state.finished then
        combat_checkpoint(state,true)
        state.finished=true
      end
    end
  end)
  if not ok then
    state.failed=tostring(err)
    emit("FAIL "..state.failed)
  end
  return {processed=1,acted=0,failed=state.failed and 1 or 0,detail=state.failed or "integrated-ground-rank-recovery"}
end

function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not (registry and type(registry.on_init)=="function") then
    error("[TP-GROUND-RANK-TEST] FAIL canonical on_init registry unavailable")
  end
  local registered=registry.on_init(initialize_fixture,{
    owner="ci_ground_rank_harness",route="initialize",
    category="diagnostics",priority="last"
  })
  if not registered then error("[TP-GROUND-RANK-TEST] FAIL canonical on_init registration") end
  if LATE_COMBAT_SMOKE then
    local observed=registry.on_event(defines.events.on_entity_damaged,
      combat_damage_observe,nil,{
        owner="ci_ground_rank_harness",route="combat-physical-damage-observer",
        category="diagnostics",priority=1100,
      })
    if not observed then error("COMBAT_DAMAGE_OBSERVER_REGISTRATION_FAILED") end
    local died=registry.on_event(defines.events.on_entity_died,
      combat_biter_died,nil,{
        owner="ci_ground_rank_harness",route="combat-biter-death-observer",
        category="diagnostics",priority=1100,
      })
    if not died then error("COMBAT_BITER_DEATH_OBSERVER_REGISTRATION_FAILED") end
  end
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not broker then broker=require("scripts.core.runtime_tick_broker") end
  if not (broker and type(broker.register_service)=="function") then
    error("[TP-GROUND-RANK-TEST] FAIL runtime broker unavailable")
  end
  local service,reason=broker.register_service({
    name="ci_ground_rank_bootstrap_endurance",
    category="diagnostics", interval=60, priority=1100, budget=1,
    fn=pulse, note="CI-only one-mod empty-infrastructure recovery acceptance"
  })
  if not service then error("[TP-GROUND-RANK-TEST] FAIL broker registration: "..tostring(reason)) end
  log("[TP-GROUND-RANK-TEST] installed inside Tech-Priests")
  return true
end
return M
