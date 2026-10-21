-- CI-only ground-rank recovery test, executed INSIDE the Tech-Priests mod.
-- No secondary mod, no shared cross-mod storage and no fabricated machines.
-- Copied into an isolated test installation, never packaged for players.
local M={}
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
    emit("MINER_MACHINE unit="..tostring(machine.unit_number)..
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
      local work=pair and pair.emergency_craft
      local pending=pair and pair.infrastructure_recipe_request_0647
      local gate=pair and pair.local_infrastructure_gate_0640
      local feed=pair and pair.emergency_facility_input_diagnostic_0357
      emit("DURATION_STATION elapsed="..elapsed.." rank="..spec.name..
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
        " feed_calls="..tostring(feed and feed.sequence))
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

local function initialize_fixture()
  storage.tech_priests=storage.tech_priests or {}
  local state=storage.tech_priests.ci_ground_rank_test or {}
  storage.tech_priests.ci_ground_rank_test=state
  if state.started_tick or state.failed then return end
  local ok,err=pcall(function()
    setup_fixture()
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
    emit("START integrated fixture tick="..game.tick.." zero-supplies=true")
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
    if elapsed>=900 and elapsed%900<60 then emit_industry() end
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
    if elapsed>=108000 and not state.finished then
      duration_diagnosis(state)
      verify_final(state)
      state.finished=true
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
