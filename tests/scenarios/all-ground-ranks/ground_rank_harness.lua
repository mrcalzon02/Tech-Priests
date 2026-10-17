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
      if e.type=="mining-drill" then counts.drills=counts.drills+1
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
        " iron_patch_amount="..amount..
        " plate_stock="..stock("iron-plate")..
        " drill_stock="..stock("burner-mining-drill")..
        " furnace_stock="..stock("stone-furnace")..
        " assembler_stock="..stock("assembling-machine-1")..
        " gate="..tostring(gate.state)..":"..tostring(gate.item)..
        " needed="..tostring(pair.infrastructure_recipe_request_0647 and pair.infrastructure_recipe_request_0647.missing)..
        " direct="..tostring(pair.dispatcher_direct_0513 and pair.dispatcher_direct_0513.phase)..
        " craft="..tostring(pair.dispatcher_emergency_production_0514 and pair.dispatcher_emergency_production_0514.phase)..
        " target="..tostring(current.output_item or current.item_name)..
        " ghost="..tostring(planner.entity_name)..":"..tostring(planner.status))
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

local function initialize_fixture()
  storage.tech_priests=storage.tech_priests or {}
  local state=storage.tech_priests.ci_ground_rank_test or {}
  storage.tech_priests.ci_ground_rank_test=state
  if state.started_tick or state.failed then return end
  local ok,err=pcall(function()
    setup_fixture()
    -- CI-only safety probe: opt into the historically disabled raw-resource
    -- governor in this isolated mod copy; production defaults remain unchanged.
    local raw=require("scripts.core.bootstrap_resource_governor_0637")
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
    if elapsed>=36000 and not state.finished then
      bootstrap_probe()
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
