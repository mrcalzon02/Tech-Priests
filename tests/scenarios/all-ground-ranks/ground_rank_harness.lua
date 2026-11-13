-- CI-only ground-rank recovery test, executed INSIDE the Tech-Priests mod.
-- No secondary mod, no shared cross-mod storage and no fabricated machines.
-- Copied into an isolated test installation, never packaged for players.
local M={}
local native_crafter_inventory_1277 = require("scripts.core.native_crafter_inventory_1277")
local function crafter_index_1277(role,family)
  return native_crafter_inventory_1277.index(defines and defines.inventory,role,family)
end
-- Enabled only by the separate CI headless-server installation.
-- The uninterrupted 108,600-tick benchmark remains unchanged.
local SAVE_RELOAD_SMOKE=rawget(_G,"TP_CI_SAVE_RELOAD_SMOKE")==true
local LATE_COMBAT_SMOKE=rawget(_G,"TP_CI_LATE_COMBAT")==true
-- Optional separate-run CI-only five-pair performance fixture.
local CI_FIVE_PROFILE_1291=rawget(_G,"TP_CI_FIVE_PROFILE_1291")==true
local CI_PROFILE_POPULATION_1291=rawget(_G,"TP_CI_PROFILE_POPULATION_1291") or 5
if CI_FIVE_PROFILE_1291 and CI_PROFILE_POPULATION_1291~=5
    and CI_PROFILE_POPULATION_1291~=25
    and CI_PROFILE_POPULATION_1291~=100 then
  error("CI_PROFILE_1291_UNSUPPORTED_POPULATION")
end
-- 1091: bind the mixed-defense audit at startup; Factorio forbids runtime
-- require() inside the periodic combat checkpoint.
local COMBAT_LAYER_AUDIT_1091=LATE_COMBAT_SMOKE
  and require("scripts.core.defense_layer_audit_1091") or nil
-- Factorio forbids require() during on_tick/service callbacks. Load the cargo
-- API only while control.lua is parsed, before the CI broker is registered.
local CARGO_ENGINE_0824=SAVE_RELOAD_SMOKE and require("scripts.core.station_cargo_0824") or nil
-- 1053: Factorio 2.0.77 forbids require() during on_tick. Prebind the
-- physical evacuation authority while control.lua is being parsed.
local EVAC_ENGINE_1048=SAVE_RELOAD_SMOKE and require("scripts.core.station_inventory_evacuation_1048") or nil
local ORE_ENGINE_CHAIN=SAVE_RELOAD_SMOKE and require("scripts.core.resource_station_chain_0820") or nil
local REVERSAL_ENGINE_0850=SAVE_RELOAD_SMOKE and require("scripts.core.station_starvation_reversal_0850") or nil
local REVERSAL_DEPOT_0852=SAVE_RELOAD_SMOKE and require("scripts.core.station_starvation_depot_0852") or nil
local REVERSAL_SENIOR_0855=SAVE_RELOAD_SMOKE and require("scripts.core.station_starvation_senior_0855") or nil
-- 0894: the fourth real depot must be audited during the live tick. Factorio
-- prohibits runtime require(), so bind the read-only audit during control parsing.
local REVERSAL_REBUILD_0867=SAVE_RELOAD_SMOKE and require("scripts.core.station_starvation_rebuild_0867") or nil
local REVERSAL_OUTBOUND_0895=SAVE_RELOAD_SMOKE and require("scripts.core.station_starvation_outbound_0895") or nil
local ORE_ENGINE_COURIER=SAVE_RELOAD_SMOKE and require("scripts.core.resource_return_courier_0837") or nil
-- 1041: bind the actual order owner during control parsing. Runtime require
-- is forbidden by Factorio and previously made this diagnostic always say
-- no-relay-plan instead of exposing the genuine 0469 refusal.
local ORE_ENGINE_ORDER_QUEUE=SAVE_RELOAD_SMOKE and require("scripts.core.order_queue_0469") or nil
-- Bind native construction authority before the Factorio runtime starts.
local ORE_ENGINE_NATIVE_1014=SAVE_RELOAD_SMOKE and require("scripts.core.remote_machine_drill_1011") or nil
-- Native Conclave module must be required at control parse time: Factorio
-- forbids adding new module dependencies during runtime/broker callbacks.
local CONCLAVE_NATIVE_OWNER_1192=LATE_COMBAT_SMOKE
  and require("scripts.core.conclave_center_0558") or nil
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

-- 0985: Real Factorio 2.0.77 mining-machine smoke, on NATURALLY
-- generated map ore outside the hand-seeded ground-rank fixture. A real
-- burner drill consumes counted vanilla coal and deposits mined ore into
-- a real chest. No ore, products, or mining counters are created by the
-- test. The physical source and destination survive process save/reload.
-- This is a machine-production gate, NOT a claim of remote relay delivery.
local function drill_engine_prepare_0985(state)
  if not SAVE_RELOAD_SMOKE or state.drill_engine_0985 then return end
  local surface=game.surfaces[1]
  local force=game.forces.player
  local chosen_drill,chosen_chest,chosen_position
  -- 0987: The original three distant squares were not guaranteed to contain
  -- natural iron on seed 907260. Search a bounded ring in all directions,
  -- including the nearby starting-resource belt, but never accept any tile
  -- inside the hand-seeded/cleared ground-rank fixture rectangle.
  local centers={
    {x=-160,y=-160},{x=-160,y=160},{x=160,y=-160},{x=160,y=160},
    {x=-320,y=0},{x=0,y=-320},{x=0,y=320},{x=320,y=0},
    {x=-320,y=-320},{x=-320,y=320},{x=320,y=-320},{x=320,y=320},
    {x=-512,y=-256},{x=-512,y=256},{x=512,y=-256},{x=512,y=256},
    {x=-256,y=-512},{x=256,y=-512},{x=-256,y=512},{x=256,y=512},
    {x=-640,y=0},{x=640,y=0},{x=0,y=-640},{x=0,y=640}}
  local regions_checked,natural_candidates,drill_sites,receiver_sites=0,0,0,0
  local fuel_failures,target_missing,target_wrong=0,0,0
  for _,center in ipairs(centers) do
    if chosen_drill then break end
    regions_checked=regions_checked+1
    surface.request_to_generate_chunks(center,3)
    surface.force_generate_chunk_requests()
    local ores=surface.find_entities_filtered{
      name="iron-ore",type="resource",
      area={{center.x-110,center.y-110},{center.x+110,center.y+110}},
      limit=300}
    for _,ore in ipairs(ores) do
      if chosen_drill then break end
      local base=ore.position
      local in_fixture=base.x>=-28 and base.x<=220
        and base.y>=-36 and base.y<=40
      if ore.valid and not in_fixture and ore.amount and ore.amount>=20 then
        natural_candidates=natural_candidates+1
        -- A 2x2 burner drill may be centered on any of the nine adjacent
        -- positions and still mine the same NATURAL tile. Test real placement
        -- and a connected receiver; never create or move an ore entity.
        for dx=-1,1 do for dy=-1,1 do
          if not chosen_drill then
            local pos={x=math.floor(base.x)+dx,
                       y=math.floor(base.y)+dy}
            for _,dir in ipairs({defines.direction.north,
                                 defines.direction.east,
                                 defines.direction.south,
                                 defines.direction.west}) do
              if chosen_drill then break end
              local spec={name="burner-mining-drill",position=pos,
                          direction=dir,force=force}
              -- 0989: natural ore must lie inside the real 2x2 drill footprint.
              local footprint_has_ore=math.abs(base.x-pos.x)<1
                and math.abs(base.y-pos.y)<1
              if footprint_has_ore and surface.can_place_entity(spec) then
                drill_sites=drill_sites+1
                local drill=surface.create_entity(spec)
                if drill and drill.valid then
                  local target=drill.mining_target
                  local correct_target=target and target.valid
                    and target.name=="iron-ore"
                  -- A placeable drill with no *active* iron target does not
                  -- prove the machine can mine. 0987 accepted nil targets,
                  -- yielding unchanged natural ore and an empty receiver.
                  if not target then target_missing=target_missing+1
                  elseif not correct_target then target_wrong=target_wrong+1 end
                  local drop=drill.drop_position
                  local chest
                  -- A fueled drill resolves mining_target on later live ticks.
                  -- Wrong targets fail now; nil requires later activation proof.
                  if (not target or correct_target) and drop then
                    -- LuaEntity.drop_position is an inserter coordinate,
                    -- not necessarily a tile-center build coordinate.
                    -- Snap the receiver to the actual 1x1 chest tile.
                    local chest_pos={x=math.floor(drop.x)+0.5,
                                     y=math.floor(drop.y)+0.5}
                    if surface.can_place_entity{
                        name="wooden-chest",position=chest_pos,force=force} then
                      chest=surface.create_entity{
                        name="wooden-chest",position=chest_pos,force=force}
                    end
                  end
                  if chest and chest.valid then receiver_sites=receiver_sites+1 end
                  local fuel=drill.get_inventory(defines.inventory.fuel)
                  if chest and chest.valid and fuel and fuel.valid
                      and fuel.insert{name="coal",count=5}==5 then
                    chosen_drill,chosen_chest,chosen_position=drill,chest,pos
                  else
                    if chest and chest.valid then chest.destroy() end
                    if not(fuel and fuel.valid) then
                      fuel_failures=fuel_failures+1
                    end
                    drill.destroy()
                  end
                end
              end
            end
          end
        end end
      end
    end
  end
  emit("DRILL_ENGINE_0987_SITE_SEARCH regions="..regions_checked..
    " natural_iron_candidates="..natural_candidates..
    " drill_sites="..drill_sites..
    " receiver_sites="..receiver_sites..
    " fuel_inventory_failures="..fuel_failures..
    " target_missing="..target_missing..
    " target_wrong="..target_wrong)
  if not(chosen_drill and chosen_drill.valid
      and chosen_chest and chosen_chest.valid) then
    error("DRILL_ENGINE_0985_NO_NATURAL_PATCH_OR_BUILDABLE_RECEIVER:"..
      " regions="..regions_checked.." natural="..natural_candidates..
      " drill="..drill_sites.." receiver="..receiver_sites..
      " fuel="..fuel_failures..
      " target_missing="..target_missing..
      " target_wrong="..target_wrong)
  end
  local nearby=surface.find_entities_filtered{
    name="iron-ore",type="resource",position=chosen_position,radius=3}
  local before=0
  for _,ore in ipairs(nearby) do
    if ore.valid then before=before+ore.amount end
  end
  local chest_inv=chosen_chest.get_inventory(defines.inventory.chest)
  if before<1 or not(chest_inv and chest_inv.valid)
      or chest_inv.get_item_count("iron-ore")~=0 then
    error("DRILL_ENGINE_0985_INVALID_INITIAL_PHYSICAL_SOURCE")
  end
  state.drill_engine_0985={
    drill=chosen_drill,chest=chosen_chest,position=chosen_position,
    surface_index=surface.index,ore_before=before,
    initial_fuel=5,created_tick=game.tick,
    initial_target_unit=chosen_drill.mining_target and
      chosen_drill.mining_target.unit_number,
    drill_unit=chosen_drill.unit_number,
    chest_unit=chosen_chest.unit_number}
  emit("DRILL_ENGINE_0985_PREPARED tick="..game.tick..
    " drill="..chosen_drill.unit_number..
    " chest="..chosen_chest.unit_number..
    " natural_ore_before="..before.." physical_coal=5"..
    " initial_target="..tostring(state.drill_engine_0985.initial_target_unit))
end

-- 0986: The first smoke server loads a save created before its CI-only
-- control.lua flag was injected. Factorio does not replay on_init for that
-- save. Prepare the real machine on the first live tick, exactly once,
-- and NEVER replace a missing record after a save/reload boundary.
local function drill_engine_first_process_attach_0986(state)
  return SAVE_RELOAD_SMOKE and not state.drill_engine_0985
    and not state.save_reload_requested
    and not state.save_reload_verified
    and not state.drill_engine_verified_0985
    and rawget(_G,"TP_CI_COURIER_RELOAD_PROBE")~=true
end

-- 0990: diagnostic ONLY. Do not grant progress or manufacture fuel/ore.
-- Observe actual persisted engine entities on the live tick when a drill is
-- still waiting for activation or physical output; bounded snapshots make a
-- headless runtime failure actionable without changing acceptance thresholds.
local function drill_engine_diagnostic_0990(state,reason)
  local record=state.drill_engine_0985
  if not record then return end
  local drill,chest=record.drill,record.chest
  if not(drill and drill.valid) then
    emit("DRILL_ENGINE_0990_LIVE_DIAG tick="..game.tick..
      " reason="..tostring(reason).." drill_valid=false")
    return
  end
  local target=drill.mining_target
  local inv=drill.get_inventory(defines.inventory.fuel)
  local fuel=inv and inv.valid and inv.get_item_count("coal") or nil
  local receiver=chest and chest.valid and
    chest.get_inventory(defines.inventory.chest)
  local iron=receiver and receiver.valid
    and receiver.get_item_count("iron-ore") or nil
  local drop=drill.drop_position
  local p=drill.position
  local nearby=drill.surface.find_entities_filtered{
    name="iron-ore",type="resource",position=p,radius=3}
  local nearby_amount=0
  for _,ore in ipairs(nearby) do
    if ore.valid then nearby_amount=nearby_amount+ore.amount end
  end
  emit("DRILL_ENGINE_0990_LIVE_DIAG tick="..game.tick..
    " reason="..tostring(reason)..
    " age="..tostring(game.tick-record.created_tick)..
    " drill="..tostring(drill.unit_number)..
    " status="..tostring(drill.status)..
    " target="..tostring(target and target.valid and target.name or "none")..
    " fuel_coal="..tostring(fuel)..
    " chest_iron="..tostring(iron)..
    " nearby_natural_iron="..tostring(nearby_amount)..
    " drop_x="..tostring(drop and drop.x)..
    " drop_y="..tostring(drop and drop.y)..
    " chest_x="..tostring(chest and chest.valid and chest.position.x)..
    " chest_y="..tostring(chest and chest.valid and chest.position.y))
end

-- 0989: observe real fueled mining-target activation on subsequent ticks.
local function drill_engine_observe_target_0989(state)
  local record=state.drill_engine_0985
  if not record then return end
  local drill=record.drill
  if not(drill and drill.valid) then return end
  local age=game.tick-record.created_tick
  if age==120 or age==600 or age==1200 then
    drill_engine_diagnostic_0990(state,"scheduled-physical-observation")
  end
  local target=drill.mining_target
  if target and target.valid then
    if target.name~="iron-ore" then
      error("DRILL_ENGINE_0989_WRONG_ACTIVATED_TARGET:"..target.name)
    end
    if not record.activated_target_tick then
      record.activated_target_tick=game.tick
      emit("DRILL_ENGINE_0989_ACTIVATED_TARGET tick="..game.tick..
        " drill="..tostring(record.drill_unit).." target="..target.name)
    end
  end
end

local function drill_engine_verify_0985(state)
  local record=state.drill_engine_0985
  if not record then error("DRILL_ENGINE_0985_MISSING_PERSISTENT_RECORD") end
  local drill,chest=record.drill,record.chest
  if not(drill and drill.valid and chest and chest.valid
      and drill.unit_number==record.drill_unit
      and chest.unit_number==record.chest_unit
      and drill.surface.index==record.surface_index
      and chest.surface==drill.surface
      and drill.force==chest.force
      and game.tick-record.created_tick>=1200) then
    error("DRILL_ENGINE_0985_ENTITY_IDENTITY_OR_RELOAD_INVALID")
  end
  if not(record.activated_target_tick and
      record.activated_target_tick>record.created_tick) then
    drill_engine_diagnostic_0990(state,"target-never-activated")
    error("DRILL_ENGINE_0989_TARGET_NEVER_ACTIVATED:"..
      " drill="..tostring(record.drill_unit))
  end
  local nearby=drill.surface.find_entities_filtered{
    name="iron-ore",type="resource",position=record.position,radius=3}
  local remaining=0
  for _,ore in ipairs(nearby) do
    if ore.valid then remaining=remaining+ore.amount end
  end
  local chest_inv=chest.get_inventory(defines.inventory.chest)
  local mined=chest_inv and chest_inv.valid
    and chest_inv.get_item_count("iron-ore") or 0
  if not(remaining<record.ore_before and mined>0
      and record.ore_before-remaining>=mined) then
    drill_engine_diagnostic_0990(state,"no-counted-real-output")
    error("DRILL_ENGINE_0985_NO_COUNTED_REAL_MACHINE_OUTPUT:"..
      " ore_before="..record.ore_before..
      " ore_after="..remaining.." chest="..mined)
  end
  state.drill_engine_verified_0985=true
  emit("PASS DRILL_ENGINE_0985_NATURAL_FUELED_MINING"..
    " tick="..game.tick..
    " drill="..record.drill_unit.." chest="..record.chest_unit..
    " ore_depleted="..(record.ore_before-remaining)..
    " chest_iron_ore="..mined.." fuel_initial="..record.initial_fuel..
    " real_entities=true independent_reload=pending")
end

-- Only the fourth separate Factorio process sets this runner probe. The
-- original engine entities and their mined chest stock must still exist
-- with identical unit numbers after a genuine save/exit/restart.
local function drill_engine_reload_0985(state)
  if state.drill_engine_reload_verified_0985 then return end
  if not state.drill_engine_verified_0985 then
    error("DRILL_ENGINE_0985_INITIAL_PROOF_MISSING_ON_RELOAD")
  end
  drill_engine_verify_0985(state)
  state.drill_engine_reload_verified_0985=true
  emit("PASS DRILL_ENGINE_0985_INDEPENDENT_RELOAD tick="..game.tick..
    " drill="..state.drill_engine_0985.drill_unit..
    " chest="..state.drill_engine_0985.chest_unit..
    " real_mined_stock_persisted=true")
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
        -- Identify every actual duplicate rather than attributing
        -- construction to a recipe request or a nearby planning ghost.
        local entities=surface.find_entities_filtered{
          name=name,position=station.position,radius=22,force=station.force}
        local physical={}
        for _,entity in ipairs(entities) do
          local owner="unclaimed"
          for station_id,keys in pairs(facility.by_station or {}) do
            for key in pairs(keys) do
              local rec=facility.facilities and facility.facilities[key]
              if rec and rec.entity==entity then
                owner=tostring(station_id)
                break
              end
            end
          end
          physical[#physical+1]=tostring(entity.unit_number).."@"..
            tostring(entity.position.x)..","..tostring(entity.position.y)..
            ":owner="..owner
        end
        table.sort(physical)
        local task=pair and pair.construction_task_0338
        local ghost=pair and pair.construction_bootstrap_ghost_0645
        fail("PRESTOCK_DUPLICATE rank="..spec.name.." machine="..name..
          " count="..present.." elapsed="..elapsed..
          " real_units="..table.concat(physical,";")..
          " in_flight="..tostring(task and task.entity_name or "none")..
          " ghost="..tostring(ghost and ghost.entity_name or "none"))
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
  -- 1154: diagnostic-only SPM factory readiness. Physical entity and
  -- force/surface production counter readbacks; no machine, research,
  -- stock, construction request, or counted ore is created or changed.
  -- The ordinary industry total is NOT proof of configured/supplied
  -- science; separate these quantities for the next native objective.
  local tp=storage and storage.tech_priests
  local original=nil
  local ranks={magos=0,senior=0,intermediate=0,junior=0}
  for _,p in pairs(tp and tp.pairs_by_station or {}) do
    if p and p.station and p.station.valid and p.priest
      and p.priest.valid and p.station.force==force
      and p.station.surface==surface then
      local n=p.station.name
      if n=="planetary-magos-cogitator-station" then
        ranks.magos=ranks.magos+1
        if not original or p.station.unit_number<
            original.station.unit_number then original=p end
      elseif n=="senior-cogitator-station" then
        ranks.senior=ranks.senior+1
      elseif n=="intermediate-cogitator-station" then
        ranks.intermediate=ranks.intermediate+1
      elseif n=="junior-cogitator-station" then
        ranks.junior=ranks.junior+1
      end
    end
  end
  local recipes={["iron-gear-wheel"]=0,
    ["automation-science-pack"]=0,
    ["logistic-science-pack"]=0,
    ["electronic-circuit"]=0}
  for _,machine in ipairs(surface.find_entities_filtered{
      force=force,type="assembling-machine",limit=512}) do
    if machine.valid and type(machine.get_recipe)=="function" then
      local ok,recipe=pcall(function()return machine.get_recipe()end)
      if ok and recipe and recipes[recipe.name]~=nil then
        recipes[recipe.name]=recipes[recipe.name]+1
      end
    end
  end
  local function native_spm(item)
    if not original or
        type(_G.tech_priests_1133_observe_science_spm)~="function" then
      return nil
    end
    local ok,measured=pcall(
      _G.tech_priests_1133_observe_science_spm,original,item)
    return ok and measured or nil
  end
  local request=original and original.construction_requested_item
  local receipt=original and original.factory_component_last_receipt_1150
  local feed=original and original.factory_component_feed_status_1153
  local next_feed=original and original.machine_logistics_candidate_0528
  emit("SCIENCE_FACTORY_1154_NATIVE_READINESS tick="..game.tick..
    " magos_pairs="..ranks.magos..
    " senior_pairs="..ranks.senior..
    " intermediate_pairs="..ranks.intermediate..
    " junior_pairs="..ranks.junior..
    " gear_machines="..recipes["iron-gear-wheel"]..
    " red_machines="..recipes["automation-science-pack"]..
    " green_machines="..recipes["logistic-science-pack"]..
    " circuit_machines="..recipes["electronic-circuit"]..
    " red_spm="..tostring(native_spm("automation-science-pack"))..
    " green_spm="..tostring(native_spm("logistic-science-pack"))..
    " planned_machine_recipe="..tostring(type(request)=="table"
      and request.factory_component_recipe_1150)..
    " built_machine_recipe="..tostring(receipt and receipt.recipe)..
    " built_recipe_verified="..tostring(receipt and receipt.configured)..
    " feed_offered="..tostring(feed and feed.candidate_offered)..
    " feed_reason="..tostring(feed and feed.reason)..
    " pending_feed_item="..tostring(next_feed
      and next_feed.source=="factory-component-feed-1153"
      and next_feed.item or nil))
  -- 1157: a native, read-only territorial snapshot of *actually paired*
  -- stations connected to the original Magos through 0480. No extra
  -- station, priest, ghost, technology, stock, or command reach is granted.
  -- Depth >3 from a Magos can arise only from Junior peer relays.
  local authority=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local coverage=nil
  if original and authority
      and type(authority.network_coverage_snapshot)=="function" then
    local ok,result=pcall(authority.network_coverage_snapshot,original)
    if ok and type(result)=="table" then coverage=result end
  end
  emit("PRIEST_NETWORK_1157_NATIVE_COVERAGE tick="..game.tick..
    " root_magos_unit="..tostring(original and original.station.unit_number)..
    " physically_paired_stations="..tostring(coverage and coverage.stations)..
    " connected_seniors="..tostring(coverage and coverage.by_rank
      and (coverage.by_rank[3] or 0))..
    " connected_intermediates="..tostring(coverage and coverage.by_rank
      and (coverage.by_rank[2] or 0))..
    " connected_juniors="..tostring(coverage and coverage.by_rank
      and (coverage.by_rank[1] or 0))..
    " furthest_ranked_depth="..tostring(coverage and coverage.deepest_grade)..
    " radial_envelope_tiles="..tostring(coverage
      and coverage.maximum_radial_extent))
  -- 1158: explain zero native SPM without asserting a diagnosis from
  -- missing configured machines. Read the existing Magos readiness state
  -- only; never create a planning operation during observation.
  local central=original and original.master_infrastructure_plan_0644
  local op=original and original.independent_emergency_operation_0184
  -- 1188: purely observational physical-capacity diagnostic. The previous
  -- native endurance run reported ratio-power without saying whether the
  -- Magos had zero poles or simply fewer than the target. It also hid the
  -- exact first science-component recipe/job the existing planner proposed.
  -- Do not dispatch a job, modify a recipe, grant power or infer 5 SPM.
  local ratio_plan=op and op.magos_ratio_plan_0257
  local candidate=ratio_plan
    and ratio_plan.factory_component_next_1150
  local blocked_candidate=ratio_plan
    and ratio_plan.factory_component_blocker_1150
  local power_poles=nil
  if original and type(_G.tech_priests_0257_count_group_entities)=="function" then
    local ok,observed=pcall(_G.tech_priests_0257_count_group_entities,
      original,"power")
    if ok and type(observed)=="number" then
      power_poles=observed
    end
  end
  emit("SCIENCE_FACTORY_1158_READINESS_GATE tick="..game.tick..
    " magos_mode="..tostring(original and original.mode)..
    " central_stage="..tostring(central and central.stage)..
    " ratio_phase="..tostring(op and op.magos_ratio_phase_0257)..
    " ratio_group="..tostring(op and op.magos_ratio_group_0257)..
    " ratio_have="..tostring(op and op.magos_ratio_have_0257)..
    " ratio_desired="..tostring(op and op.magos_ratio_desired_0257)..
    " ratio_item="..tostring(op and op.magos_ratio_item_0257)..
    " physical_local_power_poles="..tostring(power_poles)..
    " prerequisite_gap_1178="..tostring(
      op and op.magos_ratio_prerequisite_gap_1178)..
    " component_candidate_recipe="..tostring(candidate and candidate.recipe)..
    " component_candidate_phase="..tostring(candidate and candidate.phase)..
    " component_candidate_researched="..tostring(
      candidate and candidate.researched)..
    " component_candidate_machine="..tostring(
      candidate and candidate.machine_item)..
    " component_candidate_missing="..tostring(
      candidate and candidate.missing_machines)..
    " component_blocker_recipe="..tostring(
      blocked_candidate and blocked_candidate.recipe)..
    " component_blocker_phase="..tostring(
      blocked_candidate and blocked_candidate.phase)..
    " recipe_gap="..tostring(op and op.magos_ratio_recipe_gap_1142)..
    " component_dispatch="..tostring(
      op and op.magos_ratio_component_dispatch_1150)..
    " cooperative_science_overlap_1168="..tostring(
      op and op.magos_ratio_bootstrap_overlap_1168)..
    " requested_item="..tostring(type(request)=="table"
      and request.item_name or nil)..
    " active_physical_construction="..tostring(original
      and original.construction_task_0338~=nil)..
    " active_machine_courier="..tostring(original
      and original.machine_logistics_custody_0528~=nil))
  -- 1171: all measured red science / zero ratio-plan in the 123k native
  -- endurance run; inspect original 0255 entry gates without mutating them.
  local magos_op=original and original.independent_emergency_operation_0184
  local emergency_lab=false
  if original and original.station and original.station.valid then
    local ok,found=pcall(function()
      return original.station.surface.find_entities_filtered{
        name="tech-priests-emergency-laboratorium",
        force=original.station.force,position=original.station.position,
        radius=40,limit=1}
    end)
    emergency_lab=ok and type(found)=="table" and #found>0
  end
  emit("SCIENCE_FACTORY_1171_MAGOS_ENTRY_GATES tick="..game.tick..
    " op_present="..tostring(magos_op~=nil)..
    " op_enabled="..tostring(magos_op and magos_op.enabled)..
    " survival_objective="..tostring(magos_op and magos_op.last_item)..
    " survival_phase="..tostring(magos_op and magos_op.phase)..
    " op_construction="..tostring(magos_op
      and magos_op.construction~=nil)..
    " emergency_craft="..tostring(original
      and original.emergency_craft~=nil)..
    " scavenge="..tostring(original
      and original.scavenge~=nil)..
    " retry_due="..tostring(magos_op
      and game.tick>=(magos_op.magos_planner_next_tick_0255 or 0))..
    " retry_at="..tostring(magos_op
      and magos_op.magos_planner_next_tick_0255)..
    " local_emergency_lab="..tostring(emergency_lab)..
    " ratio_plan_present="..tostring(magos_op
      and magos_op.magos_ratio_plan_0257~=nil)..
    " independent_science_pulse_tick="..tostring(original
      and original.magos_science_last_result_1172
      and original.magos_science_last_result_1172.tick)..
    " independent_science_pulse_acted="..tostring(original
      and original.magos_science_last_result_1172
      and original.magos_science_last_result_1172.acted)..
    " independent_science_pulse_reason="..tostring(original
      and original.magos_science_last_result_1172
      and original.magos_science_last_result_1172.reason))
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
      local inventory=machine.get_inventory(crafter_index_1277("output","assembler"))
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
          " source_iron_ore="..stocked(crafter_index_1277("input","furnace"),"iron-ore")..
          " source_copper_ore="..stocked(crafter_index_1277("input","furnace"),"copper-ore")..
          " result_iron_plate="..stocked(crafter_index_1277("output","furnace"),"iron-plate")..
          " result_copper_plate="..stocked(crafter_index_1277("output","furnace"),"copper-plate"))
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
        local input=machine.get_inventory(crafter_index_1277("input","assembler"))
        local output=machine.get_inventory(crafter_index_1277("output"))
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
          " feed_source_item="..tostring(feed and feed.source_item)..
          " feed_source_stock="..tostring(feed and feed.source_stock)..
          " feed_source_slots="..tostring(feed and feed.source_slots)..
          " feed_input_available="..tostring(feed and feed.engine_input_available)..
          " feed_engine_accepts_one="..tostring(feed and feed.engine_accepts_one)..
          " feed_custody_blocked="..tostring(feed and feed.pending_feed_custody)..
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
  -- Prove custody after an independently loaded save, never in the same
  -- Factorio process immediately following its game.auto_save request.
  if rawget(_G,"TP_CI_STRANDED_RELOAD_PROBE")~=true then return end
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
-- 1056: create two vanilla *world entities* as isolated CI fixtures, then
-- physically mine them beside the original Junior priest into a real
-- LuaInventory. Transfer their actual mined stacks into its real station
-- inventory. No inventory.insert, synthetic ore, or production credit.
-- This deliberately exercises two separate remote evacuation journeys.
local RELOCATION_ENGINE_STOCK_ITEMS={"wooden-chest","iron-chest"}
local function relocation_engine_stock_child(test,child)
  if test.stock_prepared then error("RELOCATION_ENGINE_STOCK_DUPLICATE_SETUP") end
  local inv=child.station.get_inventory(defines.inventory.chest)
  if not(inv and inv.valid and #inv>=2) then
    error("RELOCATION_ENGINE_STOCK_INVENTORY_UNAVAILABLE")
  end
  local surface=child.station.surface
  local offsets={{0,4},{1,4},{-1,4},{0,-4},{1,-4},{-1,-4},
    {4,0},{-4,0},{4,1},{4,-1},{-4,1},{-4,-1}}
  for _,item in ipairs(RELOCATION_ENGINE_STOCK_ITEMS) do
    if inv.get_item_count(item)~=0 then
      error("RELOCATION_ENGINE_STOCK_NOT_EMPTY_BEFORE_NATIVE_MINE:"..item)
    end
    local chest
    for _,offset in ipairs(offsets) do
      local pos={x=math.floor(child.station.position.x)+0.5+offset[1],
        y=math.floor(child.station.position.y)+0.5+offset[2]}
      local dx=pos.x-child.priest.position.x
      local dy=pos.y-child.priest.position.y
      local spec={name=item,position=pos,force=child.station.force}
      if dx*dx+dy*dy<=25 and surface.can_place_entity(spec) then
        chest=surface.create_entity(spec)
        if chest and chest.valid then break end
      end
    end
    if not(chest and chest.valid) then
      error("RELOCATION_ENGINE_STOCK_NO_PHYSICAL_MINE_SITE:"..item)
    end
    local hold=game.create_inventory(1)
    if not(hold and hold.valid and #hold==1
        and hold.get_item_count()==0) then
      error("RELOCATION_ENGINE_STOCK_NATIVE_HOLD_UNAVAILABLE")
    end
    local mined=chest.mine{inventory=hold,force=false}
    if not(mined and not chest.valid and hold.get_item_count(item)==1) then
      error("RELOCATION_ENGINE_STOCK_NATIVE_MINE_FAILED:"..item)
    end
    local transferred=false
    for i=1,#inv do
      if not transferred and not inv[i].valid_for_read then
        local ok=inv[i].transfer_stack(hold[1],1)
        transferred=ok and hold.get_item_count()==0
          and inv.get_item_count(item)==1
      end
    end
    if not transferred then
      error("RELOCATION_ENGINE_STOCK_NATIVE_TRANSFER_FAILED:"..item)
    end
    hold.destroy()
  end
  test.stock_prepared=true
  test.stock_pickups={}
  test.stock_deposits={}
  emit("RELOCATION_ENGINE_STOCK_NATIVE_MINED tick="..game.tick..
    " source="..child.station.unit_number..
    " wooden=1 iron=1 native_mines=2 native_transfers=2 fixture_not_ore_credit=true")
end

-- 1060: Fill the parent with physically mined vanilla fixture entities.
-- No inserted items, artificial ore, or resource-acquisition credit.
local function relocation_engine_congest_parent(test,parent)
  local source=parent.station.get_inventory(defines.inventory.chest)
  local get=rawget(_G,"tech_priests_0358_station_sources_for_pair")
  local list=type(get)=="function" and get(parent)
  if not(list and #list==1 and list[1].owner==parent.station
      and list[1].inv==source and source and source.valid
      and #source>=3 and #source<=128
      and source.get_item_count("wooden-chest")==1
      and source.get_item_count("iron-chest")==0
      and source.get_item_count("stone-furnace")==0) then
    error("RELOCATION_ENGINE_CONGESTION_PARENT_SOURCE_INVALID")
  end
  local surface=parent.station.surface
  local position
  for _,offset in ipairs({{-7,0},{-7,5},{-7,-5},{0,7},{0,-7},{-10,0}}) do
    local pos={x=math.floor(parent.station.position.x)+offset[1],
      y=math.floor(parent.station.position.y)+offset[2]}
    if surface.can_place_entity{name="stone-furnace",position=pos,
        force=parent.station.force} then position=pos break end
  end
  if not position then error("RELOCATION_ENGINE_CONGESTION_SITE_UNAVAILABLE") end
  local filled=0
  for i=1,#source do
    if not source[i].valid_for_read then
      local entity=surface.create_entity{name="stone-furnace",
        position=position,force=parent.station.force,raise_built=false}
      if not(entity and entity.valid) then
        error("RELOCATION_ENGINE_CONGESTION_ENTITY_UNAVAILABLE")
      end
      local hold=game.create_inventory(1)
      if not(hold and hold.valid and #hold==1
          and entity.mine{inventory=hold,force=false}
          and not entity.valid and hold.get_item_count("stone-furnace")==1
          and source[i].transfer_stack(hold[1],1)
          and hold.get_item_count()==0 and source[i].name=="stone-furnace"
          and source[i].count==1) then
        error("RELOCATION_ENGINE_CONGESTION_NATIVE_TRANSFER_FAILED")
      end
      hold.destroy()
      filled=filled+1
    end
  end
  if filled<1 or source.get_item_count("stone-furnace")~=filled then
    error("RELOCATION_ENGINE_CONGESTION_COUNT_INVALID")
  end
  test.congestion_prepared=true
  test.congestion_fill_count=filled
  emit("RELOCATION_ENGINE_STOCK_PARENT_CONGESTED tick="..game.tick..
    " parent="..parent.station.unit_number.." slots="..filled..
    " filler=stone-furnace native_mines="..filled.." wooden=1 iron=0")
end
local function relocation_engine_observe_congestion(test,parent,child,rec,entry,source)
  if not test.congestion_prepared then
    if test.stock_deposits["wooden-chest"] then
      relocation_engine_congest_parent(test,parent)
    end
    return
  end
  if not test.congestion_block_verified then
    if not(test.stock_pickups["iron-chest"] and entry and entry.bag
        and entry.bag.valid and entry.bag.get_item_count("iron-chest")==1) then
      return
    end
    local dx=parent.priest.position.x-parent.station.position.x
    local dy=parent.priest.position.y-parent.station.position.y
    if dx*dx+dy*dy>25 then return end
    local child_inv=child and child.station and child.station.valid
      and child.station.get_inventory(defines.inventory.chest)
    local denied,why=EVAC_ENGINE_1048.service_remote(parent,child,rec,
      function() error("CONGESTION_MUST_NOT_ISSUE_MOVEMENT") end)
    if denied or why~="evacuation-parent-inventory-full"
        or entry.status~="evacuation-carrying-to-parent"
        or source.get_item_count("iron-chest")~=0
        or source.get_item_count("stone-furnace")~=test.congestion_fill_count
        or not(child_inv and child_inv.valid
          and child_inv.get_item_count("iron-chest")==0)
        or entry.bag.get_item_count("iron-chest")~=1 then
      error("RELOCATION_ENGINE_CONGESTION_REFUSAL_INVALID:"..tostring(why))
    end
    test.congestion_block_verified=true
    test.congestion_block_tick=game.tick
    emit("RELOCATION_ENGINE_STOCK_PARENT_FULL_DENIED tick="..game.tick..
      " parent="..parent.station.unit_number..
      " worker="..parent.priest.unit_number..
      " held_iron=1 parent_iron=0 filler="..test.congestion_fill_count)
    return
  end
  if test.congestion_released or game.tick<=test.congestion_block_tick then return end
  if not(entry and entry.bag and entry.bag.valid
      and entry.bag.get_item_count("iron-chest")==1
      and source.get_item_count("iron-chest")==0) then
    error("RELOCATION_ENGINE_CONGESTION_CARGO_LOST")
  end
  -- Free one native slot, retaining its fixture item in a persistent
  -- engine-owned hold. This never modifies the courier's real cargo.
  local reserve=game.create_inventory(1)
  local moved=false
  for i=1,#source do
    if not moved and source[i].valid_for_read
        and source[i].name=="stone-furnace" and source[i].count==1 then
      moved=reserve[1].transfer_stack(source[i],1)
    end
  end
  if not(moved and reserve.valid
      and reserve.get_item_count("stone-furnace")==1
      and source.get_item_count("stone-furnace")==test.congestion_fill_count-1
      and source.get_item_count("wooden-chest")==1) then
    error("RELOCATION_ENGINE_CONGESTION_RELEASE_FAILED")
  end
  test.congestion_reserve=reserve
  test.congestion_released=true
  emit("RELOCATION_ENGINE_STOCK_PARENT_SPACE_RESTORED tick="..game.tick..
    " parent="..parent.station.unit_number..
    " worker="..parent.priest.unit_number..
    " held_iron=1 released_filler=1 native_transfer=true")
end
local function relocation_engine_observe_stock(test,parent,child,rec)
  if not test.stock_prepared then return end
  local source=parent.station.get_inventory(defines.inventory.chest)
  if not(source and source.valid) then
    error("RELOCATION_ENGINE_STOCK_PARENT_INVENTORY_LOST")
  end
  local entry=child and EVAC_ENGINE_1048.remote_record(child)
  if entry and entry.bag and entry.bag.valid then
    local hold=entry.bag
    if hold.get_item_count()>0 then
      local carried=hold[1].name
      if carried~="wooden-chest" and carried~="iron-chest" then
        error("RELOCATION_ENGINE_STOCK_UNEXPECTED_CARGO:"..tostring(carried))
      end
      if not test.stock_pickups[carried] then
        test.stock_pickups[carried]=true
        emit("RELOCATION_ENGINE_STOCK_PICKUP tick="..game.tick..
          " item="..carried.." carrier="..parent.priest.unit_number..
          " held="..hold.get_item_count(carried))
        -- 1057: checkpoint the *actual* engine-owned carrier mid-journey.
        -- The next independent Factorio process must observe this same hold
        -- before the parent can receive the first fixture item.
        if carried=="wooden-chest" and not test.stock_save_requested then
          local child_inv=child.station.get_inventory(defines.inventory.chest)
          local dx=parent.priest.position.x-parent.station.position.x
          local dy=parent.priest.position.y-parent.station.position.y
          if not(child_inv and child_inv.valid
              and entry.status=="evacuation-carrying-to-parent"
              and entry.writ==rec.id
              and entry.parent_unit==parent.station.unit_number
              and entry.parent_priest==parent.priest.unit_number
              and entry.child_unit==child.station.unit_number
              and hold.get_item_count("wooden-chest")==1
              and child_inv.get_item_count("wooden-chest")==0
              and child_inv.get_item_count("iron-chest")==1
              and source.get_item_count("wooden-chest")==0
              and source.get_item_count("iron-chest")==0
              and dx*dx+dy*dy>25) then
            error("RELOCATION_ENGINE_STOCK_CARRY_SAVE_CUSTODY_INVALID")
          end
          test.stock_save_requested=true
          test.stock_save_tick=game.tick
          test.stock_save_worker=parent.priest.unit_number
          test.stock_save_writ=rec.id
          local ok,err=pcall(function()
            game.auto_save("tech-priests-ci-stock-carried")
          end)
          if not ok then
            error("RELOCATION_ENGINE_STOCK_CARRY_SAVE_REFUSED:"..tostring(err))
          end
          emit("RELOCATION_ENGINE_STOCK_CARRY_SAVE_REQUESTED tick="..game.tick..
            " child="..child.station.unit_number..
            " parent="..parent.station.unit_number..
            " worker="..parent.priest.unit_number..
            " writ="..rec.id.." held=1 parent_received=0 child_iron=1")
        end
      end
    end
  end
  for _,item in ipairs(RELOCATION_ENGINE_STOCK_ITEMS) do
    local delivered=source.get_item_count(item)
    if delivered>1 then
      error("RELOCATION_ENGINE_STOCK_DUPLICATE_PARENT_ITEM:"..item)
    end
    if delivered==1 and not test.stock_deposits[item] then
      -- 1211: this diagnostic runs on a later broker pulse. A genuine
      -- parent deposit can have completed and the courier walked away
      -- before the sample. Verify the mutation-time ENGINE receipt, not
      -- the priest's unrelated later position. Missing/remote/uncounted
      -- transfer evidence is still a fatal rejection.
      local proof=entry and entry.parent_deposits_1048
        and entry.parent_deposits_1048[item]
      local dx=parent.priest.position.x-parent.station.position.x
      local dy=parent.priest.position.y-parent.station.position.y
      local observed_distance_sq=dx*dx+dy*dy
      local at=proof and proof.worker_position
      local site=proof and proof.station_position
      local distance_at_deposit=at and site and
        (at.x-site.x)^2+(at.y-site.y)^2 or math.huge
      if not(proof and proof.item==item and proof.quantity==1
          and proof.parent_unit==parent.station.unit_number
          and proof.worker_unit==parent.priest.unit_number
          and proof.tick and proof.tick<=game.tick
          and distance_at_deposit<=25
          and site.x==parent.station.position.x
          and site.y==parent.station.position.y
          and proof.carried_before==1 and proof.carried_after==0
          and proof.parent_item_before==0
          and proof.parent_item_after==1
          and entry.moved and entry.moved[item]==1
          and entry.bag and entry.bag.valid
          and entry.bag.get_item_count(item)==0) then
        error("RELOCATION_ENGINE_STOCK_REMOTE_OR_UNPROVEN_CREDIT:"..
          item.." sample_distance_sq="..observed_distance_sq..
          " witness="..tostring(proof~=nil)..
          " transfer_distance_sq="..tostring(distance_at_deposit))
      end
      test.stock_deposits[item]=true
      emit("RELOCATION_ENGINE_STOCK_DEPOSIT tick="..game.tick..
        " transfer_tick="..proof.tick..
        " item="..item.." worker="..parent.priest.unit_number..
        " parent="..parent.station.unit_number..
        " transfer_distance_sq="..distance_at_deposit..
        " observer_distance_sq="..observed_distance_sq..
        " native_item_delta=1 held=0")
    end
  end
  relocation_engine_observe_congestion(test,parent,child,rec,entry,source)
  if child and child.station and child.station.valid then
    local old=child.station.get_inventory(defines.inventory.chest)
    if not(old and old.valid) then
      error("RELOCATION_ENGINE_STOCK_CHILD_INVENTORY_LOST")
    end
    for _,item in ipairs(RELOCATION_ENGINE_STOCK_ITEMS) do
      if old.get_item_count(item)+source.get_item_count(item)>1 then
        error("RELOCATION_ENGINE_STOCK_DUPLICATE_SOURCE_DEST:"..item)
      end
    end
  end
end
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
  -- This flag exists only in the isolated CI mod copy on the fifth engine
  -- process. Read the persisted LuaInventory before advancing the executor.
  if rawget(_G,"TP_CI_STOCK_RELOAD_PROBE")==true
      and test.stock_save_requested and not test.stock_reload_verified then
    local child=pairs[test.old_station_unit]
    local rec=tp.station_expansion_0256
      and tp.station_expansion_0256[test.record_id]
    local entry=child and EVAC_ENGINE_1048.remote_record(child)
    local parent_inv=parent and parent.station and parent.station.valid
      and parent.station.get_inventory(defines.inventory.chest)
    local child_inv=child and child.station and child.station.valid
      and child.station.get_inventory(defines.inventory.chest)
    if not(rec and rec.id==test.stock_save_writ
        and entry and entry.writ==rec.id
        and entry.parent_unit==test.parent_unit
        and entry.child_unit==test.old_station_unit
        and entry.parent_priest==test.stock_save_worker
        and parent and parent.priest and parent.priest.valid
        and parent.priest.unit_number==test.stock_save_worker
        and entry.status=="evacuation-carrying-to-parent"
        and entry.bag and entry.bag.valid
        and entry.bag.get_item_count()==1
        and entry.bag.get_item_count("wooden-chest")==1
        and parent_inv and parent_inv.valid
        and parent_inv.get_item_count("wooden-chest")==0
        and parent_inv.get_item_count("iron-chest")==0
        and child_inv and child_inv.valid
        and child_inv.get_item_count("wooden-chest")==0
        and child_inv.get_item_count("iron-chest")==1
        and test.stock_pickups and test.stock_pickups["wooden-chest"]
        and not(test.stock_deposits and test.stock_deposits["wooden-chest"])
        and game.tick>test.stock_save_tick) then
      error("RELOCATION_ENGINE_STOCK_CARRY_RELOAD_CUSTODY_INVALID")
    end
    test.stock_reload_verified=true
    emit("PASS RELOCATION_ENGINE_STOCK_CARRY_RELOAD tick="..game.tick..
      " child="..test.old_station_unit..
      " parent="..test.parent_unit..
      " worker="..test.stock_save_worker..
      " writ="..test.stock_save_writ..
      " held=1 parent_received=0 child_iron=1")
  end
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
    relocation_engine_stock_child(test,child)
    local empty,empty_reason=recovery.check_candidate(parent,child,CARGO_ENGINE_PROBE_ITEM)
    if empty or empty_reason~="station-inventory-not-empty" then
      error("RELOCATION_ENGINE_STOCK_EMPTY_MINE_NOT_DENIED:"..tostring(empty_reason))
    end
    local safe,reason=recovery.check_evacuable_candidate(
      parent,child,CARGO_ENGINE_PROBE_ITEM)
    if not safe then error("RELOCATION_ENGINE_EVAC_PREFLIGHT_REFUSED: "..tostring(reason)) end
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
    -- Native 2.0.77 denial proof: an unregistered foreign writ must never
    -- allocate a second engine inventory or command the reserved priest.
    local evac=EVAC_ENGINE_1048
    if not (evac and type(evac.service_remote)=="function") then
      error("RELOCATION_ENGINE_EVACUATION_AUTHORITY_NOT_PRELOADED")
    end
    local foreign={id=id+100000,status="active",
      worker_station_unit=test.parent_unit,
      recycling_candidate_unit_0822=test.old_station_unit,
      station_item=CARGO_ENGINE_PROBE_ITEM}
    local accepted,refusal=evac.service_remote(
      parent,child,foreign,function() return true end)
    if accepted or refusal~="evacuation-worker-writ-not-reserved"
        or evac.remote_record(child) then
      error("RELOCATION_ENGINE_FOREIGN_EVACUATION_WRIT_NOT_DENIED: "..
        tostring(refusal))
    end
    emit("PASS RELOCATION_ENGINE_FOREIGN_EVACUATION_WRIT_DENIED tick="..
      game.tick.." worker="..test.parent_unit..
      " candidate="..test.old_station_unit.." writ="..id..
      " denied_writ="..foreign.id.." held=0")
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
  relocation_engine_observe_stock(test,parent,pairs[test.old_station_unit],rec)
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
  local receipt=rec.inventory_evacuation_1048
  if not(test.stock_prepared and test.stock_reload_verified
       and test.congestion_prepared and test.congestion_block_verified
       and test.congestion_released and test.congestion_reserve
       and test.congestion_reserve.valid
       and test.congestion_reserve.get_item_count("stone-furnace")==1
       and source and source.valid
       and source.get_item_count("stone-furnace")==test.congestion_fill_count-1
      and receipt and receipt.physical_carrier
      and receipt.stack_transfers==2
      and receipt.item_counts["wooden-chest"]==1
      and receipt.item_counts["iron-chest"]==1
      and test.stock_pickups["wooden-chest"]
      and test.stock_pickups["iron-chest"]
      and test.stock_deposits["wooden-chest"]
      and test.stock_deposits["iron-chest"]
      and source and source.valid
      and source.get_item_count("wooden-chest")==1
      and source.get_item_count("iron-chest")==1) then
    error("RELOCATION_ENGINE_STOCK_EVACUATION_RECEIPT_INVALID")
  end
  emit("PASS RELOCATION_ENGINE_STOCK_CONGESTION tick="..game.tick..
    " parent="..parent.station.unit_number..
    " worker="..parent.priest.unit_number..
    " blocked=1 recovered=1 filler="..test.congestion_fill_count..
    " reserved_filler=1 parent_iron=1 held_iron=0")
  emit("PASS RELOCATION_ENGINE_STOCK_EVACUATION tick="..game.tick..
    " old_station="..test.old_station_unit..
    " worker="..parent.priest.unit_number..
    " wooden=1 iron=1 journeys=2 held=0 source_removed=true")
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
  -- The physical worker can legitimately leave after the real entity is
  -- built. Verify where it WAS at the synchronous 0824 one-item debit, not
  -- where an asynchronous post-build/reloaded observer finds it now.
  -- Reject a missing, stale, foreign or out-of-reach receipt: this does not
  -- relax any engine proximity, item-debit, pairing or custody requirement.
  local proof=rec.physical_build_receipt_1222
  local px=proof and proof.worker_position
  local gx=proof and proof.ghost_position
  local reach=px and gx and
    ((px.x-gx.x)^2+(px.y-gx.y)^2) or nil
  if not (proof and proof.writ_id==rec.id
      and proof.station_item==CARGO_ENGINE_PROBE_ITEM
      and proof.worker_station_unit==test.parent_unit
      and proof.worker_priest_unit==parent.priest.unit_number
      and proof.physical_item_debit==1
      and type(proof.tick)=="number" and proof.tick>=test.placed_tick
      and proof.tick<=game.tick
      and gx.x==test.ghost_position.x and gx.y==test.ghost_position.y
      and type(reach)=="number" and reach<=CARGO_ENGINE_0824.reach_sq
      and proof.distance_sq==reach) then
    error("RELOCATION_ENGINE_PHYSICAL_BUILD_RECEIPT_INVALID")
  end
  emit("RELOCATION_ENGINE_BUILD_REACH_VERIFIED tick="..game.tick..
    " debit_tick="..proof.tick.." distance_sq="..reach..
    " worker="..proof.worker_priest_unit.." writ="..proof.writ_id)
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

-- 0994: A SECOND ore-return leg must use the canonical 0528 logistics
-- receipt from a real, fueled mining drill and its connected chest. The
-- original direct-natural-ore engine leg remains intact as a baseline.
-- Only the isolated CI fixture supplies five counted vanilla coal items;
-- no ore or delivered inventory is created by this fixture.
local function ore_engine_machine_prepare_0994(test,chain)
  if test.machine_0994 then error("ORE_ENGINE_MACHINE_DUPLICATE_PREPARE") end
  local surface=chain[4].station.surface
  local force=chain[4].station.force
  local terminal=chain[4].station.position
  local candidates=surface.find_entities_filtered{
    name="iron-ore",type="resource",position=test.ore_position,radius=4}
  local drill,chest,position
  for _,ore in ipairs(candidates) do
    if drill then break end
    if ore.valid and ore.amount and ore.amount>=3 then
      for dx=-1,1 do for dy=-1,1 do
        if not drill then
          local pos={x=math.floor(ore.position.x)+dx,
                     y=math.floor(ore.position.y)+dy}
          if math.abs(ore.position.x-pos.x)<1
              and math.abs(ore.position.y-pos.y)<1 then
            for _,dir in ipairs({defines.direction.north,
                defines.direction.east,defines.direction.south,
                defines.direction.west}) do
              if drill then break end
              local spec={name="burner-mining-drill",position=pos,
                          direction=dir,force=force}
              if surface.can_place_entity(spec) then
                local candidate=surface.create_entity(spec)
                if candidate and candidate.valid then
                  local drop=candidate.drop_position
                  local receiver
                  if drop then
                    local cp={x=math.floor(drop.x)+0.5,
                              y=math.floor(drop.y)+0.5}
                    local tx,ty=cp.x-terminal.x,cp.y-terminal.y
                    -- The Junior's actual minimum command radius is 8.
                    if tx*tx+ty*ty<=64 and surface.can_place_entity{
                        name="wooden-chest",position=cp,force=force} then
                      receiver=surface.create_entity{
                        name="wooden-chest",position=cp,force=force}
                    end
                  end
                  local fuel=candidate.get_inventory(defines.inventory.fuel)
                  local inv=receiver and receiver.valid
                    and receiver.get_inventory(defines.inventory.chest)
                  if inv and inv.valid and inv.get_item_count()==0
                      and fuel and fuel.valid
                      and fuel.insert{name="coal",count=5}==5 then
                    drill,chest,position=candidate,receiver,pos
                  else
                    if receiver and receiver.valid then receiver.destroy() end
                    candidate.destroy()
                  end
                end
              end
            end
          end
        end
      end end
    end
  end
  if not(drill and drill.valid and chest and chest.valid) then
    error("ORE_ENGINE_MACHINE_NO_BUILDABLE_NATURAL_RECEIVER")
  end
  local before=0
  for _,ore in ipairs(surface.find_entities_filtered{
      name="iron-ore",type="resource",position=position,radius=3}) do
    if ore.valid then before=before+ore.amount end
  end
  if before<1 then error("ORE_ENGINE_MACHINE_NO_NATURAL_IRON") end
  test.machine_0994={
    drill=drill,chest=chest,drill_unit=drill.unit_number,
    chest_unit=chest.unit_number,position=position,
    natural_before=before,created_tick=game.tick}
  emit("ORE_ENGINE_MACHINE_PREPARED tick="..game.tick..
    " drill="..drill.unit_number.." chest="..chest.unit_number..
    " natural_before="..before.." physical_fixture_coal=5"..
    " fixture_station_construction_credit=false")
end

local function ore_engine_machine_wait_0994(test,chain,mission)
  local machine=test.machine_0994
  if not machine then error("ORE_ENGINE_MACHINE_RECORD_MISSING") end
  local drill,chest=machine.drill,machine.chest
  if not(drill and drill.valid and chest and chest.valid
      and drill.unit_number==machine.drill_unit
      and chest.unit_number==machine.chest_unit
      and drill.surface==chain[4].station.surface
      and chest.surface==drill.surface
      and drill.force==chain[4].station.force
      and chest.force==drill.force) then
    error("ORE_ENGINE_MACHINE_PHYSICAL_IDENTITY_LOST")
  end
  local remaining=0
  for _,ore in ipairs(drill.surface.find_entities_filtered{
      name="iron-ore",type="resource",position=machine.position,radius=3}) do
    if ore.valid then remaining=remaining+ore.amount end
  end
  -- 0997: inspect the real machine's receipts even when the courier
  -- refuses to claim them. A generic-stash receipt must fail immediately,
  -- rather than waiting 500 seconds with an empty terminal Cogitator.
  local matching_receipt
  for _,receipt in ipairs(chain[4].drill_output_receipts_0983 or {}) do
    if receipt.drill_unit==machine.drill_unit
        and receipt.receiver_unit==machine.chest_unit
        and (receipt.deposit_tick or 0)>=machine.created_tick then
      matching_receipt=receipt
    end
  end
  if matching_receipt and matching_receipt.station_only_0995~=true then
    error("ORE_ENGINE_MACHINE_RANKED_DEPOSIT_DIVERTED"..
      " drill="..machine.drill_unit..
      " receiver="..machine.chest_unit..
      " station_only="..tostring(matching_receipt.station_only_0995)..
      " source_debit="..tostring(matching_receipt.count)..
      " station_count="..ore_engine_inventory(chain[4])
        .get_item_count("iron-ore"))
  end
  -- 0999: select provenance for THIS physical drill, not the newest
  -- unrelated receipt at the terminal. A station-only deposit without a
  -- valid live drill/receiver connection is an immediate custody failure,
  -- not a 500-second timeout or permission to substitute another drill.
  local proof,proof_reason=ORE_ENGINE_COURIER.drill_source_receipt_0991(
    chain[4],mission,machine.drill_unit,machine.chest_unit)
  if matching_receipt and not proof then
    local drop=drill.drop_position
    local target=drill.drop_target
    error("ORE_ENGINE_MACHINE_RECEIPT_PROVENANCE_REJECTED"..
      " reason="..tostring(proof_reason)..
      " drill="..machine.drill_unit..
      " receiver="..machine.chest_unit..
      " receipt_priest="..tostring(matching_receipt.priest_unit)..
      " paired_priest="..tostring(chain[4].priest.unit_number)..
      " receipt_count="..tostring(matching_receipt.count)..
      " receipt_source_before="..tostring(matching_receipt.source_before)..
      " receipt_source_after="..tostring(matching_receipt.source_after)..
      " receipt_station_before="..tostring(matching_receipt.station_before_0984)..
      " receipt_station_after="..tostring(matching_receipt.station_after_0984)..
      " receipt_cargo_before="..tostring(matching_receipt.cargo_before_0984)..
      " receipt_cargo_after="..tostring(matching_receipt.cargo_after_0984)..
      " receipt_authority="..tostring(matching_receipt.deposit_authority)..
      " receipt_claimed="..tostring(matching_receipt.relay_claimed_count_0991)..
      " receipt_pickup_tick="..tostring(matching_receipt.pickup_tick)..
      " receipt_deposit_tick="..tostring(matching_receipt.deposit_tick)..
      " terminal_iron="..ore_engine_inventory(chain[4]).get_item_count("iron-ore")..
      " terminal_radius="..tostring(chain[4].radius or chain[4].base_radius)..
      " chest_station_distance_sq="..tostring(
        (chest.position.x-chain[4].station.position.x)^2+
        (chest.position.y-chain[4].station.position.y)^2)..
      " station_only="..tostring(matching_receipt.station_only_0995)..
      " drop_x="..tostring(drop and drop.x)..
      " drop_y="..tostring(drop and drop.y)..
      " chest_x="..tostring(chest.position.x)..
      " chest_y="..tostring(chest.position.y)..
      " drop_target_unit="..tostring(target and target.valid
        and target.unit_number or nil))
  end
  if proof and proof.count>=1 and proof.source_before>=1
      and remaining<machine.natural_before then
    -- Receipt was written by real 0528 physical receiver pickup AND
    -- canonical station deposit. Do not credit it directly to Magos.
    test.machine_receipt_count_0994=proof.count
    test.machine_natural_after_0994=remaining
    -- The natural batch was already counted; later autonomous batches can
    -- arrive before the harness observes the machine batch's final hop.
    test.machine_magos_count_before=mission.delivered_to_magos_count or 0
    test.machine_courier=true
    test.mined=false
    test.last_hop=0
    test.phase="machine-courier"
    -- Keep the completed natural courier ledger: 0996 must rearm it
    -- through its verified physical receipts, not a fixture reset.
    emit("ORE_ENGINE_MACHINE_0528_DEPOSIT tick="..game.tick..
      " drill="..machine.drill_unit.." chest="..machine.chest_unit..
      " receiver_debit="..proof.count..
      " station_deposit="..proof.count..
      " natural_before="..machine.natural_before..
      " natural_after="..remaining.." receipt_verified=true")
    return true
  end
  if game.tick>=(test.next_machine_diag_tick or 0) then
    test.next_machine_diag_tick=game.tick+1800
    local inv=chest.get_inventory(defines.inventory.chest)
    emit("ORE_ENGINE_MACHINE_WAIT tick="..game.tick..
      " chest_iron="..tostring(inv and inv.valid
        and inv.get_item_count("iron-ore"))..
      " terminal_iron="..ore_engine_inventory(chain[4])
        .get_item_count("iron-ore")..
      " natural_after="..remaining..
      " 0528_receipts="..tostring(chain[4].drill_output_receipts_0983
        and #chain[4].drill_output_receipts_0983 or 0)..
      " machine_logistics_phase="..tostring(
        chain[4].machine_logistics_0528
        and chain[4].machine_logistics_0528.phase)..
      " machine_logistics_blocker="..tostring(
        chain[4].machine_logistics_0528
        and chain[4].machine_logistics_0528.last_blocker)..
      " machine_receipt_station_only="..tostring(
        matching_receipt and matching_receipt.station_only_0995)..
      " machine_receipt_station_after="..tostring(
        matching_receipt and matching_receipt.station_container_after_0995))
  end
  return false
end

-- 1159: native engine may deliver MORE than one real machine-produced
-- item while a CI callback observes its first final Magos receipt. The
-- physical proof is the exact three-hop ledger and final engine inventory,
-- plus a monotonic Magos counter increment FROM the recorded machine phase.
-- A fixed cumulative total of two is not valid once repeat deliveries run.
function M.verify_magos_receipt_1159(test,mission,courier,magos_ore_count)
  if not (type(test)=="table" and type(mission)=="table"
      and type(courier)=="table" and type(test.units)=="table"
      and #test.units==4 and test.mined==true and test.last_hop==3
      and courier.phase=="magos-delivered"
      and courier.inventory==nil and courier.quantity==1
      and courier.hops_completed==3 and courier.receipt_hop==3
      and courier.delivered_count==1
      and courier.delivered_station_unit==test.units[1]
      and courier.item==mission.need) then
    return false,"courier-phase-identity-or-empty-hold-invalid"
  end
  local baseline=0
  if test.machine_courier then
    -- Do not coerce a MISSING mandatory machine baseline to zero.
    baseline=tonumber(test.machine_magos_count_before)
  end
  local total=tonumber(mission.delivered_to_magos_count)
  if not (baseline and baseline>=0 and baseline==math.floor(baseline)
      and total and total>=baseline+1 and total==math.floor(total)) then
    return false,"no-monotonic-counted-magos-delivery"
  end
  if test.machine_courier and not(
      courier.source_kind_0991=="drill-output"
      and courier.drill_receipt_claimed_0991==true
      and tonumber(test.machine_receipt_count_0994)
      and test.machine_receipt_count_0994>=1) then
    return false,"machine-source-physical-receipt-invalid"
  end
  local ledger=courier.receipts_0982
  if not (type(ledger)=="table" and #ledger==3) then
    return false,"complete-three-hop-ledger-absent"
  end
  local last_tick=-1
  for hop=1,3 do
    local rec=ledger[hop]
    if not (type(rec)=="table" and rec.hop==hop
        and rec.source_station_unit==test.units[5-hop]
        and rec.destination_station_unit==test.units[4-hop]
        and type(rec.carrier_priest_unit)=="number"
        and rec.item==mission.need and rec.quantity==1
        and type(rec.destination_before)=="number"
        and rec.destination_before>=0
        and rec.destination_after==rec.destination_before+1
        and type(rec.tick)=="number" and rec.tick>last_tick) then
      return false,"physical-ledger-identity-or-count-invalid-hop-"..hop
    end
    last_tick=rec.tick
  end
  local last=ledger[3]
  if not (tonumber(magos_ore_count)==last.destination_after
      and courier.receipt_destination_before==last.destination_before
      and courier.receipt_destination_after==last.destination_after) then
    return false,"last-receipt-not-in-real-magos-inventory"
  end
  return true,"three-physical-hops-and-monotonic-magos-receipt"
end

local function ore_engine_service(state)
  local test=state.ore_engine
  if not test or test.phase=="complete" then return end
  if game.tick-test.started_tick>60*500 then
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
  -- Preserve the first, priest-mined engine proof. After that counted
  -- Magos receipt, require a SECOND complete route from real drill output.
  if test.phase=="machine-prep" then
    ore_engine_machine_prepare_0994(test,chain)
    test.phase="machine-wait"
    return
  end
  if test.phase=="machine-wait" then
    local mission=magos.resource_expansion_0259.chain_0820
    if not ore_engine_machine_wait_0994(test,chain,mission) then return end
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
  -- 1152: pinpoint the particular denied movement proof in the full
  -- native log; this never invokes movement, mines, or debits cargo.
  if reason=="unverified-resource-courier-route-0953"
      and game.tick>=(test.next_courier_movement_diag_1152 or 0) then
    test.next_courier_movement_diag_1152=game.tick+1200
    local assigned=courier and courier.source_station_unit
    local worker=assigned and (storage.tech_priests.pairs_by_station
      or {})[assigned]
    local refusal=worker and worker.resource_return_movement_refusal_1152
    local inv=worker and worker.station and worker.station.valid
      and worker.station.get_inventory(defines.inventory.chest)
    local moving=worker and worker.movement_request_0418
    emit("ORE_ENGINE_1152_COURIER_MOVEMENT_DENIED tick="..game.tick..
      " stage="..tostring(test.phase)..
      " refusal="..tostring(refusal and refusal.reason)..
      " source_unit="..tostring(assigned)..
      " priest="..tostring(worker and worker.priest
        and worker.priest.unit_number)..
      " mode="..tostring(worker and worker.mode)..
      " live_task="..tostring(worker and worker.active_task~=nil)..
      " adopted_0285="..tostring(worker and worker.active_task_0285~=nil)..
      " direct_task="..tostring(worker and worker.direct_acquisition_task_0336~=nil)..
      " direct_custody="..tostring(worker and worker.direct_acquisition_custody_0513~=nil)..
      " machine_custody="..tostring(worker and worker.machine_logistics_custody_0528~=nil)..
      " current_task="..tostring(worker and worker.current_task~=nil)..
      " pending_order="..tostring(worker and worker.order_queue_0469
        and worker.order_queue_0469.current
        and worker.order_queue_0469.current.kind)..
      " station_ore="..tostring(inv and inv.valid
        and inv.get_item_count("iron-ore"))..
      " state_ore_custody_unit="..tostring(courier.station_custody_unit)..
      " courier_hop="..tostring(courier.hop_index)..
      " courier_quantity="..tostring(courier.quantity)..
      " request_owner="..tostring(moving and moving.owner)..
      " request_reason="..tostring(moving and moving.reason))
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
          " handoff_refusal="..tostring(courier.last_upstream_handoff_reason)..
          " order_kind="..tostring(waiting.order_queue_0469
            and waiting.order_queue_0469.current
            and waiting.order_queue_0469.current.kind)..
          " order_source="..tostring(waiting.order_queue_0469
            and waiting.order_queue_0469.current
            and waiting.order_queue_0469.current.source)..
          " order_item="..tostring(waiting.order_queue_0469
            and waiting.order_queue_0469.current
            and waiting.order_queue_0469.current.item)..
          " order_status="..tostring(waiting.order_queue_0469
            and waiting.order_queue_0469.current
            and waiting.order_queue_0469.current.status)..
          " recipe_item="..tostring(recipe and recipe.item)..
          " adopted_task_item="..tostring(waiting.active_task_0285 and
            (waiting.active_task_0285.item or waiting.active_task_0285.item_name
              or waiting.active_task_0285.output_item))..
          " adopted_task_owned="..tostring(waiting.active_task_0285~=nil
            and waiting.order_queue_0469~=nil
            and waiting.order_queue_0469.current~=nil
            and waiting.order_queue_0469.current.task==waiting.active_task_0285)..
          " adopted_task_target="..tostring(waiting.active_task_0285 and
            (waiting.active_task_0285.target~=nil
              or waiting.active_task_0285.entity~=nil))..
          " active_order="..tostring(waiting.active_order_0469~=nil)..
          " active_task_0285="..tostring(waiting.active_task_0285~=nil)..
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
    -- The first physical leg intentionally has nil hop_index for legacy
    -- save compatibility. Production treats nil as hop 1; verify that
    -- same physical leg rather than rejecting its valid terminal debit.
    local hop=courier.hop_index or 1
    local idx=5-hop
    local physical_source=chain[idx]
    local source_matches=physical_source and physical_source.station
      and physical_source.station.valid
      and courier.source_station_unit==physical_source.station.unit_number
    local before=courier.pickup_source_before
    -- 1003: The first drill-output pickup is a REAL debit at terminal
    -- chain[4], not an upstream relay pickup at chain[3] or chain[2].
    -- The previous fixture rejected this correct hop_index=1 transfer.
    -- Only a verified drill receipt with counted claim may use index 4.
    local machine_terminal_pickup=test.machine_courier and idx==4
      and courier.source_kind_0991=="drill-output"
      and courier.drill_receipt_claimed_0991==true
      and test.machine_receipt_count_0994>=1
    local relay_pickup=idx and idx>=2 and idx<=3
    local after=source_matches
      and ore_engine_inventory(physical_source).get_item_count("iron-ore")
    if not ((machine_terminal_pickup or relay_pickup)
        and source_matches and before and before>=1 and after==before-1
        and courier.inventory and courier.inventory.valid
        and courier.inventory.get_item_count("iron-ore")==1
        and courier.inventory.get_item_count()==1) then
      error("ORE_ENGINE_PHYSICAL_UPSTREAM_PICKUP_UNVERIFIED"..
        " source_index="..tostring(idx)..
        " hop_index="..tostring(courier.hop_index)..
        " source_station="..tostring(courier.source_station_unit)..
        " expected_station="..tostring(physical_source and physical_source.station
          and physical_source.station.unit_number)..
        " source_before="..tostring(before)..
        " source_after="..tostring(after)..
        " machine_terminal="..tostring(machine_terminal_pickup)..
        " source_kind="..tostring(courier.source_kind_0991)..
        " receipt_claimed="..tostring(courier.drill_receipt_claimed_0991))
    end
  end
  if courier and test.machine_courier
      and (courier.phase=="to-natural-ore"
        or (courier.source_kind_0991
          and courier.source_kind_0991~="drill-output")) then
    error("ORE_ENGINE_MACHINE_FALLBACK_TO_DIRECT_MINING_FORBIDDEN")
  end
  if courier.quantity==1 and not test.mined then
    if not (courier.inventory and courier.inventory.valid
        and courier.inventory.get_item_count("iron-ore")==1) then
      error("ORE_ENGINE_REAL_MINED_CARGO_NOT_HELD")
    end
    if test.machine_courier then
      if not (courier.source_kind_0991=="drill-output"
          and courier.drill_receipt_claimed_0991
          and test.machine_receipt_count_0994>=1) then
        error("ORE_ENGINE_MACHINE_CARGO_NOT_CANONICALLY_CLAIMED")
      end
      emit("ORE_ENGINE_MACHINE_PICKUP tick="..game.tick..
        " drill="..test.machine_0994.drill_unit..
        " chest="..test.machine_0994.chest_unit..
        " physical_station_debit=1 held=1")
    else
      local ore=magos.station.surface.find_entities_filtered{
        name="iron-ore",position=test.ore_position,radius=0.5,limit=1}[1]
      local amount=ore and ore.valid and ore.amount or 0
      if amount>=test.ore_amount_before then
        error("ORE_ENGINE_NATURAL_RESOURCE_NOT_DEPLETED")
      end
      emit("ORE_ENGINE_MINED tick="..game.tick..
        " natural_before="..test.ore_amount_before..
        " natural_after="..amount.." held=1")
    end
    test.mined=true
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
    emit((test.machine_courier and "ORE_ENGINE_MACHINE_HOP" or "ORE_ENGINE_HOP")..
      " tick="..game.tick.." hop="..hop..
      " from="..test.units[5-hop].." to="..test.units[4-hop]..
      " counted=1 receipt_before="..before.." receipt_after="..after)
  end
  if courier.phase=="magos-delivered" then
    local magos_ore=ore_engine_inventory(magos)
      .get_item_count("iron-ore")
    local accepted,why=M.verify_magos_receipt_1159(
      test,mission,courier,magos_ore)
    if not accepted then
      error("ORE_ENGINE_MAGOS_RECEIPT_UNVERIFIED reason="..
        tostring(why).." actual_magos_stock="..tostring(magos_ore)..
        " delivered_total="..tostring(mission.delivered_to_magos_count)..
        " baseline="..tostring(test.machine_courier
          and test.machine_magos_count_before or 0))
    end
    if test.machine_courier then
      if not (courier.source_kind_0991=="drill-output"
          and courier.drill_receipt_claimed_0991
          and test.machine_receipt_count_0994>=1) then
        error("ORE_ENGINE_MACHINE_MAGOS_SOURCE_NOT_VERIFIED")
      end
      test.phase="complete"
      emit("PASS ORE_ENGINE_MACHINE_MAGOS_RETURN tick="..game.tick..
        " machine_receipt_verified=true physical_hops=3"..
        " magos_received_total="..mission.delivered_to_magos_count..
        " baseline="..tostring(test.machine_magos_count_before)..
        " held=0 original_drill="..test.machine_0994.drill_unit)
    else
      test.natural_return_verified=true
      test.phase="machine-prep"
      emit("PASS ORE_ENGINE_COUNTED_MAGOS_RETURN tick="..game.tick..
        " natural_mined=1 physical_hops=3 magos_received=1 held=0")
    end
  end
end



-- 1014: exercise the REAL 0338 constructor and 0528 fuel carrier after the
-- separately verified fixture-driven machine-to-Magos proof. Recycle that
-- exact physical drill and receiver into the terminal's engine-owned chest.
-- CI can supply starting coal, but NEVER ore or a completed machine.
local function ore_engine_native_service_1014(state)
  local test=state.ore_engine
  if not(test and test.phase=="complete") then return end
  local pairs=storage.tech_priests.pairs_by_station or {}
  local chain={}
  for i,id in ipairs(test.units) do
    local pair=pairs[id]
    if not(pair and pair.station and pair.station.valid
        and pair.priest and pair.priest.valid) then
      error("ORE_ENGINE_NATIVE_CHAIN_IDENTITY_LOST")
    end
    chain[i]=pair
  end
  local magos,terminal=chain[1],chain[4]
  local mission=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(mission and mission.status=="reached-resource"
      and mission.current_station_unit==terminal.station.unit_number) then
    error("ORE_ENGINE_NATIVE_MISSION_NOT_PHYSICALLY_REACHED")
  end
  local native=test.native_1014
  if not native then
    local old=test.machine_0994
    local drill,receiver=old and old.drill,old and old.chest
    if not(drill and drill.valid and receiver and receiver.valid
        and drill.unit_number==old.drill_unit
        and receiver.unit_number==old.chest_unit) then
      error("ORE_ENGINE_NATIVE_OLD_MACHINE_IDENTITY_INVALID")
    end
    local stock=ore_engine_inventory(terminal)
    local drill_before=stock.get_item_count("burner-mining-drill")
    local chest_before=stock.get_item_count("wooden-chest")
    local iron_before=stock.get_item_count("iron-ore")
    -- The engine mines the old machine into a REAL inventory. The old
    -- machine's production receipt has already reached Magos; recycling
    -- does not create another ore credit.
    local mined=drill.mine{inventory=stock,raise_destroy=true}
    if not(mined and not drill.valid
        and stock.get_item_count("burner-mining-drill")==drill_before+1) then
      error("ORE_ENGINE_NATIVE_DRILL_RECOVERY_NOT_CONSERVED")
    end
    local output=receiver.get_inventory(defines.inventory.chest)
    if not(output and output.valid) then
      error("ORE_ENGINE_NATIVE_RECEIVER_INVENTORY_MISSING")
    end
    local iron=output.get_item_count("iron-ore")
    if output.get_item_count()~=iron then
      error("ORE_ENGINE_NATIVE_RECEIVER_HAS_UNACCOUNTED_ITEMS")
    end
    if iron>0 then
      local removed=output.remove{name="iron-ore",count=iron}
      if removed~=iron then
        error("ORE_ENGINE_NATIVE_RECEIVER_ORE_DEBIT_FAILED")
      end
      local inserted=stock.insert{name="iron-ore",count=iron}
      if inserted~=iron then
        local refunded=output.insert{name="iron-ore",count=removed}
        error("ORE_ENGINE_NATIVE_RECEIVER_ORE_TRANSFER_BLOCKED refunded="..
          tostring(refunded))
      end
    end
    if stock.get_item_count("iron-ore")~=iron_before+iron then
      error("ORE_ENGINE_NATIVE_RECEIVER_ORE_CONSERVATION_FAILED")
    end
    local receiver_mined=receiver.mine{inventory=stock,raise_destroy=true}
    if not(receiver_mined and not receiver.valid
        and stock.get_item_count("wooden-chest")==chest_before+1) then
      error("ORE_ENGINE_NATIVE_RECEIVER_RECOVERY_NOT_CONSERVED")
    end
    -- Starting supply is a labeled CI fixture, not mined ore, output,
    -- delivered cargo, or a free production grant. All later coal movement
    -- must be physically performed and receipted by the 0528 executor.
    local coal_before=stock.get_item_count("coal")
    local supplied=math.max(0,5-coal_before)
    if supplied>0 and stock.insert{name="coal",count=supplied}~=supplied then
      error("ORE_ENGINE_NATIVE_FIXTURE_COAL_STOCK_FULL")
    end
    if stock.get_item_count("coal")~=coal_before+supplied then
      error("ORE_ENGINE_NATIVE_FIXTURE_COAL_COUNT_INVALID")
    end
    if mission.remote_drill_1011~=nil then
      error("ORE_ENGINE_NATIVE_PREEXISTING_MISSION_NOT_OWNED")
    end
    native={started_tick=game.tick,phase="building",
      recovered_drill_unit=old.drill_unit,recovered_receiver_unit=old.chest_unit,
      drill_stock=drill_before+1,chest_stock=chest_before+1,
      coal_stock=coal_before+supplied,fixture_coal=supplied,
      recovered_receiver_iron=iron,drill_seen=false,receiver_seen=false}
    test.native_1014=native
    emit("ORE_ENGINE_NATIVE_RECOVERED tick="..game.tick..
      " drill="..old.drill_unit.." receiver="..old.chest_unit..
      " drill_item_delta=1 chest_item_delta=1"..
      " receiver_iron_transferred="..iron..
      " fixture_coal="..supplied.." no_ore_created=true")
  end
  if native.phase=="complete" then return end
  -- Construction retains its original bound; physically returning ore
  -- through ranked relays has a separate finite travel allowance.
  local deadline=native.phase=="ore-return" and 60*600 or 60*250
  if game.tick-native.started_tick>deadline then
    error("ORE_ENGINE_NATIVE_TIMEOUT phase="..tostring(
      mission.remote_drill_1011 and mission.remote_drill_1011.phase)..
      " reason="..tostring(native.last_reason))
  end
  local progressed,reason=ORE_ENGINE_NATIVE_1014.service_pair(magos)
  if reason~=native.last_reason then
    native.last_reason=reason
    emit("ORE_ENGINE_NATIVE_PROGRESS tick="..game.tick..
      " reason="..tostring(reason)..
      " phase="..tostring(mission.remote_drill_1011
        and mission.remote_drill_1011.phase))
  end
  local task=mission.remote_drill_1011
  if not task then return end
  if task.phase=="blocked" then
    error("ORE_ENGINE_NATIVE_BUILDER_REFUSED "..tostring(task.last_reason))
  end
  -- Diagnose the actual receiver approach without altering movement,
  -- custody, deadlines, item counts or any native acceptance assertion.
  if task.phase=="receiver-requested"
      and game.tick>=(native.next_receiver_observation_tick or 0) then
    native.next_receiver_observation_tick=game.tick+300
    local work=terminal.construction_task_0338 or {}
    local priest_pos=terminal.priest and terminal.priest.valid
      and terminal.priest.position or {}
    local stand=work.build_standoff_0338 or {}
    local remaining=stand.x and stand.y and priest_pos.x and priest_pos.y
      and math.sqrt((stand.x-priest_pos.x)^2+(stand.y-priest_pos.y)^2)
      or nil
    emit("ORE_ENGINE_NATIVE_RECEIVER_APPROACH tick="..game.tick..
      " work_phase="..tostring(work.phase)..
      " priest="..tostring(priest_pos.x)..","..tostring(priest_pos.y)..
      " contact="..tostring(stand.x)..","..tostring(stand.y)..
      " remaining="..tostring(remaining)..
      " best="..tostring(work.move_site_best_remaining_0338)..
      " progress_tick="..tostring(work.move_site_progress_tick_0338)..
      " replans="..tostring(work.move_site_replans_0338)..
      " movement_denials="..tostring(work.movement_denials_0338)..
      " carried="..tostring(work.carried and work.carried.count)..
      " priest_mode="..tostring(terminal.mode))
  end
  -- Observe the exact physical 0528 handoff at a bounded interval.
  -- Diagnostics never supply fuel, claim a machine or alter acceptance.
  if task.phase=="receiver-verified"
      and game.tick>=(native.next_fuel_observation_tick or 0) then
    native.next_fuel_observation_tick=game.tick+600
    local candidate=terminal.machine_logistics_candidate_0528 or {}
    local active=terminal.machine_logistics_0528 or {}
    local custody=terminal.machine_logistics_custody_0528 or {}
    local queued=terminal.order_queue_0469
      and terminal.order_queue_0469.current or {}
    emit("ORE_ENGINE_NATIVE_FUEL_OBSERVE tick="..game.tick..
      " station_coal="..ore_engine_inventory(terminal).get_item_count("coal")..
      " escrow_coal="..tostring(task.fuel_escrow_1037 and
        task.fuel_escrow_1037.valid and
        task.fuel_escrow_1037.get_item_count("coal"))..
      " offered="..tostring(task.fuel_candidate_offered_1016)..
      " offer_reason="..tostring(task.last_fuel_offer_1016)..
      " candidate_source="..tostring(candidate.source)..
      " candidate_machine="..tostring(candidate.machine
        and candidate.machine.unit_number)..
      " active_phase="..tostring(active.phase)..
      " active_action="..tostring(active.action)..
      " active_item="..tostring(active.item)..
      " active_updated_tick="..tostring(active.updated_tick)..
      " active_machine="..tostring(active.machine_unit)..
      " carried_coal="..tostring(custody.count)..
      " queued_kind="..tostring(queued.kind)..
      " priest_mode="..tostring(terminal.mode)..
      " last_blocker="..tostring(active.last_blocker)..
      " contact_attempt="..tostring(active.machine_contact_attempt_0528)..
      " contact_best="..tostring(active.machine_contact_best_remaining_0528)..
      " contact_progress_tick="..tostring(active.machine_contact_last_progress_tick_0528)..
      " contact_x="..tostring(active.machine_contact_0528
        and active.machine_contact_0528.x)..
      " contact_y="..tostring(active.machine_contact_0528
        and active.machine_contact_0528.y)..
      " priest_x="..tostring(terminal.priest.position.x)..
      " priest_y="..tostring(terminal.priest.position.y)..
      " movement_state="..tostring(terminal.movement_controller_state_0418)..
      " movement_owner="..tostring(terminal.movement_request_0418
        and terminal.movement_request_0418.owner)..
      " movement_reason="..tostring(terminal.movement_request_0418
        and terminal.movement_request_0418.reason)..
      " dispatcher_family="..tostring(terminal.canonical_action_0744
        and terminal.canonical_action_0744.family)..
      " dispatcher_detail="..tostring(terminal.canonical_action_0744
        and terminal.canonical_action_0744.detail)..
      " strict_craft="..tostring(terminal.emergency_craft
        and terminal.emergency_craft.strict_recipe_0647)..
      " direct_task="..tostring(terminal.direct_acquisition_task_0336~=nil)..
      " movement_clamp="..tostring(terminal.movement_controller_clamp_0418))
  end
  local stock=ore_engine_inventory(terminal)
  if task.drill_unit and not native.drill_seen then
    local receipt=terminal.construction_last_task_0338
    if not(receipt and receipt.phase=="complete"
        and receipt.request_value==task.request
        and receipt.built_entity and receipt.built_entity.valid
        and receipt.built_entity.unit_number==task.drill_unit
        and stock.get_item_count("burner-mining-drill")==native.drill_stock-1
        and task.drill_unit~=native.recovered_drill_unit) then
      error("ORE_ENGINE_NATIVE_0338_DRILL_RECEIPT_OR_ITEM_INVALID")
    end
    native.drill_seen=true
    emit("ORE_ENGINE_NATIVE_0338_DRILL tick="..game.tick..
      " built="..task.drill_unit.." recovered="..native.recovered_drill_unit..
      " physical_item_debit=1")
  end
  if task.receiver_unit and not native.receiver_seen then
    local receipt=terminal.construction_last_task_0338
    if not(native.drill_seen and receipt and receipt.phase=="complete"
        and receipt.request_value==task.receiver_request
        and receipt.built_entity and receipt.built_entity.valid
        and receipt.built_entity.unit_number==task.receiver_unit
        and stock.get_item_count("wooden-chest")==native.chest_stock-1
        and task.receiver_unit~=native.recovered_receiver_unit) then
      error("ORE_ENGINE_NATIVE_0338_RECEIVER_RECEIPT_OR_ITEM_INVALID")
    end
    native.receiver_seen=true
    emit("ORE_ENGINE_NATIVE_0338_RECEIVER tick="..game.tick..
      " built="..task.receiver_unit.." recovered="..
      native.recovered_receiver_unit.." physical_item_debit=1")
  end
  if task.phase=="fuel-verified" then
    local proof
    for _,receipt in ipairs(terminal.machine_fuel_receipts_1013 or {}) do
      if receipt.machine_unit==task.drill_unit
          and receipt.station_unit==terminal.station.unit_number
          and receipt.priest_unit==terminal.priest.unit_number
          and receipt.authority=="physical-machine-fuel-0528"
          and receipt.tick==task.fuel_receipt_tick then
        proof=receipt
      end
    end
    if not(native.drill_seen and native.receiver_seen
        and proof and proof.item=="coal" and proof.count>=1
        and proof.source_after==proof.source_before-proof.count
        and proof.destination_after==proof.destination_before+proof.count
        and task.fuel_count==proof.count
        and task.drill_unit~=native.recovered_drill_unit
        and task.receiver_unit~=native.recovered_receiver_unit) then
      error("ORE_ENGINE_NATIVE_0528_FUEL_RECEIPT_INVALID")
    end
    native.phase="ore-return"
    emit("PASS ORE_ENGINE_NATIVE_0338_0528 tick="..game.tick..
      " drill="..task.drill_unit.." receiver="..task.receiver_unit..
      " drill_item_debit=1 receiver_item_debit=1"..
      " fuel_station_debit="..proof.count..
      " fuel_drill_credit="..proof.count..
      " fixture_coal="..native.fixture_coal..
      " physical_builder=true physical_fuel=true")
  end
  if native.phase=="ore-return" and task.phase=="fuel-verified" then
    -- Exercise the actual 0837 ranked courier, not a test-only inventory
    -- transfer. Its source must be the newly constructed drill and chest.
    local moved,why=ORE_ENGINE_COURIER.service(magos)
    local courier=mission.return_courier_0837
    if courier and courier.phase=="custody-blocked" then
      error("ORE_ENGINE_NATIVE_COURIER_CUSTODY_BLOCKED:"..
        tostring(courier.last_reason))
    end
    if why~=native.last_courier_reason then
      native.last_courier_reason=why
      emit("ORE_ENGINE_NATIVE_ORE_RETURN_PROGRESS tick="..game.tick..
        " reason="..tostring(why)..
        " phase="..tostring(courier and courier.phase)..
        " source="..tostring(courier and courier.drill_receipt_drill_unit_0991))
    end
    -- Engine-only, bounded diagnostic for a real incumbent duty. The relay
    -- must never clear that duty to satisfy the native-machine timeout.
    if (why=="upstream-priest-has-existing-duty"
        or why=="upstream-priest-has-existing-custody") and courier
        and courier.phase=="first-hop-delivered"
        and game.tick>=(native.next_upstream_diag_tick or 0) then
      native.next_upstream_diag_tick=game.tick+1800
      local pairs=storage.tech_priests and storage.tech_priests.pairs_by_station
      local waiting=pairs and pairs[courier.pending_upstream_station_unit]
      local order=waiting and waiting.order_queue_0469
        and waiting.order_queue_0469.current
      local task0285=waiting and waiting.active_task_0285
      emit("ORE_ENGINE_NATIVE_UPSTREAM_DUTY_DIAG tick="..game.tick..
        " station="..tostring(courier.pending_upstream_station_unit)..
        " mode="..tostring(waiting and waiting.mode)..
        " hoover_phase="..tostring(waiting and waiting.ground_hoover_0529
          and waiting.ground_hoover_0529.phase)..
        " hoover_carried="..tostring(waiting and waiting.ground_hoover_0529
          and waiting.ground_hoover_0529.carried_count)..
        " ore_reserved="..tostring(waiting
          and ORE_ENGINE_COURIER.worker_reserved(waiting))..
        " handoff_refusal="..tostring(courier.last_upstream_handoff_reason)..
        " active_task="..tostring(waiting and waiting.active_task~=nil)..
        " task_alias="..tostring(waiting and waiting.active_task==task0285)..
        " task_0285="..tostring(task0285~=nil)..
        " task_item="..tostring(task0285 and (task0285.item
          or task0285.item_name or task0285.output_item))..
        " order_kind="..tostring(order and order.kind)..
        " order_source="..tostring(order and order.source)..
        " order_item="..tostring(order and order.item)..
        " order_status="..tostring(order and order.status)..
        " order_task_alias="..tostring(order and order.task==task0285)..
        " recipe_missing="..tostring(waiting
          and waiting.infrastructure_recipe_request_0647
          and waiting.infrastructure_recipe_request_0647.missing)..
        " emergency_craft="..tostring(waiting and waiting.emergency_craft~=nil)..
        " direct_task="..tostring(waiting
          and waiting.direct_acquisition_task_0336~=nil)..
        " direct_custody="..tostring(waiting
          and waiting.direct_acquisition_custody_0513~=nil)..
        " direct_custody_item="..tostring(waiting
          and waiting.direct_acquisition_custody_0513
          and waiting.direct_acquisition_custody_0513.item)..
        " direct_custody_count="..tostring(waiting
          and waiting.direct_acquisition_custody_0513
          and waiting.direct_acquisition_custody_0513.count)..
        " machine_custody="..tostring(waiting
          and waiting.machine_logistics_custody_0528~=nil)..
        " machine_phase="..tostring(waiting
          and waiting.machine_logistics_0528
          and waiting.machine_logistics_0528.phase)..
        " machine_action="..tostring(waiting
          and waiting.machine_logistics_0528
          and waiting.machine_logistics_0528.action)..
        " machine_item="..tostring(waiting
          and waiting.machine_logistics_0528
          and waiting.machine_logistics_0528.item)..
        " machine_cargo_count="..tostring(waiting
          and waiting.machine_logistics_custody_0528
          and waiting.machine_logistics_custody_0528.count)..
        " machine_last_blocker="..tostring(waiting
          and waiting.machine_logistics_0528
          and waiting.machine_logistics_0528.last_blocker)..
        " machine_unit="..tostring(waiting
          and waiting.machine_logistics_0528
          and waiting.machine_logistics_0528.machine_unit)..
        " machine_priest_x="..tostring(waiting and waiting.priest
          and waiting.priest.position.x)..
        " machine_priest_y="..tostring(waiting and waiting.priest
          and waiting.priest.position.y)..
        " feed_custody="..tostring(waiting
          and waiting.emergency_facility_feed_custody_0357~=nil)..
        " repair_custody="..tostring(waiting
          and waiting.repair_pack_custody_0516~=nil)..
        " refund_custody="..tostring(waiting
          and waiting.consecration_refund_custody_0515~=nil)..
        " expansion_status="..tostring(waiting
          and waiting.station_expansion_0256
          and waiting.station_expansion_0256.status)..
        " construction_custody="..tostring(waiting
          and waiting.construction_custody_0338~=nil)..
        " inventory_transfer="..tostring(waiting
          and waiting.inventory_transfer_custody_0687~=nil))
    end
    if courier and courier.source_kind_0991=="drill-output"
        and courier.phase~="magos-delivered"
        and (courier.drill_receipt_drill_unit_0991~=task.drill_unit
          or courier.drill_receipt_receiver_unit_0991~=task.receiver_unit) then
      error("ORE_ENGINE_NATIVE_COURIER_WRONG_MACHINE_SOURCE")
    end
  end
  if native.phase=="ore-return" and task.phase=="ore-delivered" then
    local courier=mission.return_courier_0837
    if not(courier and courier.phase=="magos-delivered"
        and courier.drill_receipt_drill_unit_0991==task.drill_unit
        and courier.drill_receipt_receiver_unit_0991==task.receiver_unit
        and task.ore_receipt_count_1024==
          mission.delivered_to_magos_count) then
      error("ORE_ENGINE_NATIVE_COUNTED_MAGOS_RETURN_INVALID")
    end
    native.phase="complete"
    emit("PASS ORE_ENGINE_NATIVE_MACHINE_MAGOS_RETURN tick="..game.tick..
      " drill="..task.drill_unit.." receiver="..task.receiver_unit..
      " physical_hops="..tostring(courier.hops_completed)..
      " counted_magos_total="..tostring(task.ore_receipt_count_1024)..
      " native_machine_source=true no_synthetic_ore=true")
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
    test.original_ghost_unit=rec.ghost_unit
    test.original_ghost_position={x=rec.ghost_position.x,y=rec.ghost_position.y}
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
    -- 0961: bounded read-only diagnosis of the real persisted request
    -- shape. A target/cargo reference is observed, never cleared or moved.
    local function request_shape(value)
      if type(value)~="table" then return type(value) end
      local keys={}
      for key,entry in pairs(value) do
        if type(key)=="string" and #keys<24 then
          local kind=type(entry)
          if kind=="string" then
            kind="string:"..entry:sub(1,48)
          elseif kind=="number" or kind=="boolean" then
            kind=kind..":"..tostring(entry)
          end
          keys[#keys+1]=key.."="..kind
        end
      end
      table.sort(keys)
      return table.concat(keys,",")
    end
    local function target_identity(value)
      if value==nil then return "nil" end
      local ok,id,valid=pcall(function()
        return value.unit_number,value.valid
      end)
      if not ok then return "unreadable:"..type(value) end
      return type(value)..":"..tostring(id)..":"..tostring(valid)
    end
    local marker=terminal and terminal.logistic_requested_item
    local supply=terminal and terminal.active_supply_request
    emit("REVERSAL_ENGINE_REQUEST_OWNERSHIP_0961 tick="..game.tick..
      " marker="..request_shape(marker)..
      " marker_target="..target_identity(type(marker)=="table" and marker.target)..
      " marker_source="..target_identity(type(marker)=="table" and marker.source)..
      " supply="..request_shape(supply)..
      " supply_target="..target_identity(type(supply)=="table" and supply.target)..
      " active_task="..request_shape(terminal and terminal.active_task_0285))
    emit("REVERSAL_ENGINE_RECOVERY_WAIT tick="..game.tick..
      " phase="..tostring(rec.phase)..
      " priority="..priority..
      " magos_mode="..tostring(magos.mode)..
      " magos_work="..work(magos)..
      " worker_mode="..tostring(worker and worker.mode)..
      " worker_work="..work(worker)..
      " leaf_mode="..tostring(terminal and terminal.mode)..
      " leaf_work="..work(terminal)..
      " leaf_logistic="..tostring(terminal and terminal.logistic_requested_item)..
      " leaf_requested="..tostring(terminal and terminal.requested_item)..
      " leaf_pending="..tostring(terminal and terminal.infrastructure_recipe_request_0647
        and terminal.infrastructure_recipe_request_0647.missing)..
      " leaf_gate="..tostring(terminal and terminal.local_infrastructure_gate_0640
        and terminal.local_infrastructure_gate_0640.state)..
      " leaf_supply="..tostring(terminal and terminal.active_supply_request
        and terminal.active_supply_request.kind)..
      " leaf_frustration="..tostring(terminal and terminal.logistic_frustration_kind)..
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
      -- 0906: a Senior item transferred before the independently observed
      -- fourth depot is a genuine engine failure, not a valid milestone.
      if spec.index==4
          and rec.phase=="reversal-senior-real-item-carried-outward" then
        error("REVERSAL_ENGINE_PREMATURE_SENIOR_OUTBOUND_BEFORE_FOUR_DEPOT_AUDIT")
      end
      -- 0965: the earlier engine observed only "worker-busy" at stage 3.
      -- Read-only worker ownership telemetry distinguishes a 0647 ingredient
      -- plan from real duties/cargo; never modify either in the test harness.
      if spec.index==3 and game.tick-
          (test.last_third_worker_observation_tick or 0)>=600 then
        test.last_third_worker_observation_tick=game.tick
        local worker=registry and registry[test.units[spec.worker_index]]
        local pending=worker and worker.infrastructure_recipe_request_0647
        local active=worker and worker.active_task
        emit("REVERSAL_ENGINE_THIRD_WORKER_OBSERVE tick="..game.tick..
          " mode="..tostring(worker and worker.mode)..
          " pending_item="..tostring(type(pending)=="table" and pending.item)..
          " pending_missing="..tostring(type(pending)=="table" and pending.missing)..
          " requested="..tostring(worker and worker.requested_item)..
          " logistic="..tostring(worker and worker.logistic_requested_item)..
          " active_kind="..tostring(type(active)=="table"
            and (active.kind or active.type))..
          " direct_custody="..tostring(worker
            and worker.direct_acquisition_custody_0513~=nil)..
          " combat="..tostring(worker and worker.combat_target~=nil)..
          " future_reserved="..tostring(worker
            and REVERSAL_ENGINE_0850.future_worker_reserved(worker)))
      end
      -- 0889: after three counted physical depots, expose the *exact*
      -- fourth-stage Magos readiness predicate. Read-only engine telemetry;
      -- never clear a duty, alter a mode or grant a movement/item shortcut.
      if spec.index==4 and game.tick-
          (test.last_fourth_availability_observation_tick or 0)>=600 then
        test.last_fourth_availability_observation_tick=game.tick
        local reason=REVERSAL_SENIOR_0855
          and REVERSAL_SENIOR_0855.availability_blocker_0889(magos,rec)
        local active=magos.active_task
        local eligible,planning_detail=REVERSAL_ENGINE_0850
          .idle_emergency_planning_yield_0890(magos)
        local emergency_op=tp.emergency_operation_by_station
          and tp.emergency_operation_by_station[magos.station.unit_number]
        emit("REVERSAL_ENGINE_FOURTH_AVAILABILITY_OBSERVE tick="..game.tick..
          " blocker="..tostring(reason)..
          " material_yield_1165="..tostring(rec.reversal_senior_material_yield_1165
            and rec.reversal_senior_material_yield_1165.reason)..
          " pending_0647_item="..tostring(magos.infrastructure_recipe_request_0647
            and magos.infrastructure_recipe_request_0647.item)..
          " pending_0647_missing="..tostring(magos.infrastructure_recipe_request_0647
            and magos.infrastructure_recipe_request_0647.missing)..
          " pending_0640_gate="..tostring(magos.local_infrastructure_gate_0640
            and magos.local_infrastructure_gate_0640.item)..
          " requested_item="..tostring(magos.requested_item)..
          " logistic_requested_item="..tostring(magos.logistic_requested_item)..
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
            and REVERSAL_ENGINE_0850.future_worker_reserved(magos))..
          " planning_yield="..tostring(eligible)..
          " planning_blocker="..tostring(eligible and nil or planning_detail)..
          " emergency_op_enabled="..tostring(emergency_op and emergency_op.enabled)..
          " emergency_op_same="..tostring(emergency_op
            and emergency_op==magos.independent_emergency_operation_0184)..
          " emergency_acquisition="..tostring(emergency_op
            and emergency_op.acquisition~=nil)..
          " emergency_construction="..tostring(emergency_op
            and emergency_op.construction~=nil))
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
        local audit=REVERSAL_REBUILD_0867
        local proof,reason=audit.audit(magos,rec)
        if not(proof and proof.stage_count==4) then
          error("REVERSAL_ENGINE_FOUR_DEPOT_AUDIT_FAILED:"..tostring(reason))
        end
        test.phase="four-depot-audited"
        test.four_depot_tick=game.tick
        emit("PASS REVERSAL_ENGINE_FOUR_DEPOT_AUDIT tick="..game.tick..
          " independent_real_items=4 original_priests=4"..
          " outward_rebuild_not_yet_verified=true")
      end
      return
    end
  end
end

-- 0895: the first real outbound item must leave the fourth protected depot
-- through the Magos's original engine-owned priest cargo. No outward station
-- is credited yet; the three other depots and all original priests remain.
local function reversal_engine_outbound_senior(state)
  local test=state.reversal_engine
  if not test or test.phase~="four-depot-audited" then return end
  if game.tick-(test.four_depot_tick or 30075)>6000 then
    error("REVERSAL_ENGINE_SENIOR_OUTBOUND_TIMEOUT phase="..
      tostring(test.last_outbound_phase))
  end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station
    and tp.pairs_by_station[test.units[1]]
  local rec=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local executor=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(magos and magos.station and magos.station.valid
      and magos.priest and magos.priest.valid
      and magos.priest.unit_number==test.pair_priest_units[1]
      and rec and rec.status=="active"
      and executor and executor.service_station_expansion_assignment) then
    error("REVERSAL_ENGINE_OUTBOUND_ORIGINAL_MAGOS_WRIT_LOST")
  end
  executor.service_station_expansion_assignment(magos)
  if rec.phase~=test.last_outbound_phase then
    test.last_outbound_phase=rec.phase
    emit("REVERSAL_ENGINE_OUTBOUND_PHASE tick="..game.tick..
      " phase="..tostring(rec.phase))
  end
  -- 0909: same-tick pickup can already have advanced to walking. Use the
  -- escrow-backed persistent receipt, then verify real inventories below.
  if not REVERSAL_OUTBOUND_0895.milestone_receipt_0909(rec,"pickup") then return end
  local stage=rec.reversal_stage_0855
  local outbound=rec.reversal_outbound_0895
  local source=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local cargo=CARGO_ENGINE_0824 and CARGO_ENGINE_0824.get(magos,rec)
  local original=tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[2]]
  local prior={}
  for i,key in ipairs({"reversal_stage_0851","reversal_stage_0853",
      "reversal_stage_0854"}) do
    local entry=REVERSAL_DEPOT_0852.get_staged(magos,rec[key])
    if not(entry and entry.inventory and entry.inventory.valid
        and entry.inventory.get_item_count(
          i==3 and "intermediate-cogitator-station"
            or "junior-cogitator-station")==1) then
      error("REVERSAL_ENGINE_OUTBOUND_PRIOR_DEPOT_LOST:"..i)
    end
    prior[entry.inventory]=true
  end
  local ghost_found=false
  for _,ghost in pairs(magos.station.surface.find_entities_filtered{
      name="entity-ghost",ghost_name="senior-cogitator-station",
      force=magos.station.force,
      area={{rec.ghost_position.x-0.5,rec.ghost_position.y-0.5},
        {rec.ghost_position.x+0.5,rec.ghost_position.y+0.5}}}) do
    if ghost.valid and ghost.unit_number==rec.ghost_unit then
      ghost_found=true
    end
  end
  -- The 0896 repair may replace an expired/vanished ghost, but only with
  -- a newly observed writ-owned ghost; the original station item stays real.
  local ghost_reconciled=outbound and outbound.restored_ghost_0896==true
  if outbound and outbound.replaced_owned_ghost_0899 then
    local p=test.original_ghost_position
    if not(p and ghost_reconciled and outbound.replanned_ghost_0897) then
      error("REVERSAL_ENGINE_OWNED_GHOST_REPLAN_PROOF_MISSING")
    end
    for _,old in pairs(magos.station.surface.find_entities_filtered{
        name="entity-ghost",force=magos.station.force,
        area={{p.x-0.75,p.y-0.75},{p.x+0.75,p.y+0.75}}}) do
      if old.valid and old.unit_number==test.original_ghost_unit then
        error("REVERSAL_ENGINE_OLD_OWNED_GHOST_STILL_PRESENT")
      end
    end
  end
  if not(test.original_ghost_unit and
      ((ghost_reconciled and rec.ghost_unit~=test.original_ghost_unit)
        or (not ghost_reconciled and
          rec.ghost_unit==test.original_ghost_unit))) then
    error("REVERSAL_ENGINE_OUTBOUND_GHOST_IDENTITY_UNACCOUNTED")
  end
  if not(outbound and outbound.phase=="senior-carried"
      and outbound.audited_source_before==1
      and outbound.audited_carrier_before==0
      and type(outbound.audited_tick_0906)=="number"
      and type(outbound.picked_tick)=="number"
      and outbound.picked_tick-outbound.audited_tick_0906>=120
      and source and source.status=="outbound"
      and source.inventory and source.inventory.valid
      and source.inventory.get_item_count("senior-cogitator-station")==0
      and not prior[source.inventory]
      and cargo and cargo.status=="carrying"
      and cargo.inventory and cargo.inventory.valid
      and cargo.inventory.get_item_count("senior-cogitator-station")==1
      and cargo.inventory~=source.inventory
      and not prior[cargo.inventory]
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[2]
      and tp.pairs_by_station[test.units[2]]==nil
      and ghost_found) then
    error("REVERSAL_ENGINE_SENIOR_OUTBOUND_CUSTODY_INVALID")
  end
  test.phase="senior-outbound-carried"
  test.outbound_carried_tick=game.tick
  emit("PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_PICKUP tick="..game.tick..
    " original_senior="..test.units[2]..
    " original_priest="..test.pair_priest_units[2]..
    " source_before=1 source_after=0 carrier_before=0 carrier_after=1"..
    " other_depots=3 ghost_preserved_or_reconciled=true station_not_built=true"..
    " ghost_reconciled_0896="..tostring(ghost_reconciled)..
    " owned_ghost_replaced_0899="..tostring(outbound.replaced_owned_ghost_0899==true))
end


-- 0907: independent engine proof of outward walking with the SAME real item.
-- This deliberately does not credit a newly built station or returned ore.
local function reversal_engine_outbound_transit(state)
  local test=state.reversal_engine
  if not test or test.phase~="senior-outbound-carried" then return end
  if game.tick-(test.outbound_carried_tick or game.tick)>7200 then
    error("REVERSAL_ENGINE_SENIOR_TRANSIT_TIMEOUT phase="..
      tostring(test.last_transit_phase))
  end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local rec=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local executor=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(magos and magos.station and magos.station.valid
      and magos.priest and magos.priest.valid
      and magos.priest.unit_number==test.pair_priest_units[1]
      and rec and rec.status=="active"
      and executor and executor.service_station_expansion_assignment) then
    error("REVERSAL_ENGINE_SENIOR_TRANSIT_MAGOS_OR_WRIT_LOST")
  end
  executor.service_station_expansion_assignment(magos)
  if rec.phase~=test.last_transit_phase then
    test.last_transit_phase=rec.phase
    emit("REVERSAL_ENGINE_TRANSIT_PHASE tick="..game.tick..
      " phase="..tostring(rec.phase))
  end
  -- 0909: arrival may advance to building-ghost before the observer runs.
  if not REVERSAL_OUTBOUND_0895.milestone_receipt_0909(rec,"arrival") then return end
  local stage=rec.reversal_stage_0855
  local source=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local cargo=CARGO_ENGINE_0824 and CARGO_ENGINE_0824.get(magos,rec)
  local outbound=rec.reversal_outbound_0895
  local p=rec.ghost_position
  local position=magos.priest.position
  local d2=p and position and (p.x-position.x)^2+(p.y-position.y)^2
    or math.huge
  local senior=tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[2]]
  local prior={}
  for i,key in ipairs({"reversal_stage_0851","reversal_stage_0853",
      "reversal_stage_0854"}) do
    local entry=REVERSAL_DEPOT_0852.get_staged(magos,rec[key])
    if not(entry and entry.inventory and entry.inventory.valid
        and entry.inventory.get_item_count(
          i==3 and "intermediate-cogitator-station"
            or "junior-cogitator-station")==1
        and not prior[entry.inventory]) then
      error("REVERSAL_ENGINE_TRANSIT_PRIOR_DEPOT_LOST:"..i)
    end
    prior[entry.inventory]=true
  end
  local ghost_found=false
  if p then
    for _,ghost in pairs(magos.station.surface.find_entities_filtered{
        name="entity-ghost",ghost_name="senior-cogitator-station",
        force=magos.station.force,
        area={{p.x-0.5,p.y-0.5},{p.x+0.5,p.y+0.5}}}) do
      if ghost.valid and ghost.unit_number==rec.ghost_unit then
        ghost_found=true
      end
    end
  end
  if not(outbound and (outbound.phase=="senior-carried"
          or outbound.phase=="senior-build-authorized")
      and outbound.transit_status=="arrived"
      and type(outbound.arrived_tick)=="number"
      and outbound.arrived_tick>=test.outbound_carried_tick
      and d2<=25
      and source and source.status=="outbound"
      and source.inventory and source.inventory.valid
      and source.inventory.get_item_count("senior-cogitator-station")==0
      and not prior[source.inventory]
      and cargo and cargo.status=="carrying"
      and cargo.inventory and cargo.inventory.valid
      and cargo.inventory.get_item_count("senior-cogitator-station")==1
      and cargo.inventory~=source.inventory
      and not prior[cargo.inventory]
      and senior and senior.priest and senior.priest.valid
      and senior.priest.unit_number==test.pair_priest_units[2]
      and tp.pairs_by_station[test.units[2]]==nil
      and ghost_found) then
    error("REVERSAL_ENGINE_SENIOR_TRANSIT_CUSTODY_INVALID")
  end
  test.phase="senior-outbound-at-ghost"
  emit("PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_TRANSIT tick="..game.tick..
    " original_senior="..test.units[2]..
    " original_priest="..test.pair_priest_units[2]..
    " magos_priest="..test.pair_priest_units[1]..
    " held=1 source=0 prior_depots=3 distance_sq="..
    string.format("%.3f",d2).." ghost_unit="..rec.ghost_unit)
end

-- 0908: independent Factorio proof that the same Senior item actually
-- became a new station, with the ORIGINAL surviving priest and legal 4>3
-- hierarchy edge. A build ghost or Lua counter alone never satisfies this.
local function reversal_engine_outbound_senior_build(state)
  local test=state.reversal_engine
  if not test or test.phase~="senior-outbound-at-ghost" then return end
  if game.tick-(test.outbound_carried_tick or game.tick)>7200 then
    error("REVERSAL_ENGINE_SENIOR_BUILD_TIMEOUT phase="..
      tostring(test.last_build_phase))
  end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local rec=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local executor=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not(magos and magos.station and magos.station.valid
      and magos.priest and magos.priest.valid
      and magos.priest.unit_number==test.pair_priest_units[1]
      and rec and executor and executor.service_station_expansion_assignment) then
    error("REVERSAL_ENGINE_SENIOR_BUILD_MAGOS_OR_WRIT_LOST")
  end
  if rec.status=="active" then executor.service_station_expansion_assignment(magos) end
  if rec.phase~=test.last_build_phase then
    test.last_build_phase=rec.phase
    emit("REVERSAL_ENGINE_BUILD_PHASE tick="..game.tick..
      " phase="..tostring(rec.phase))
  end
  if rec.status~="complete" then return end
  local stage=rec.reversal_stage_0855
  local source=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local p=rec.ghost_position
  local built=p and magos.station.surface.find_entities_filtered{
    name="senior-cogitator-station",force=magos.station.force,
    area={{p.x-0.5,p.y-0.5},{p.x+0.5,p.y+0.5}}} or {}
  local ghosts=p and magos.station.surface.find_entities_filtered{
    name="entity-ghost",ghost_name="senior-cogitator-station",
    force=magos.station.force,
    area={{p.x-0.5,p.y-0.5},{p.x+0.5,p.y+0.5}}} or {}
  local station=#built==1 and built[1] or nil
  local original=tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[2]]
  local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local prior={}
  for i,key in ipairs({"reversal_stage_0851","reversal_stage_0853",
      "reversal_stage_0854"}) do
    local entry,why=REVERSAL_DEPOT_0852.get_staged(magos,rec[key])
    if not(entry and entry.inventory and entry.inventory.valid
        and entry.inventory.get_item_count(
          i==3 and "intermediate-cogitator-station"
            or "junior-cogitator-station")==1
        and not prior[entry.inventory]) then
      -- 0914: never relax the three-depot acceptance requirement. If a
      -- same-tick follow-up has altered a depot, report the exact physical
      -- status and inventory readback rather than a generic lost-depot code.
      local stage=rec[key]
      local raw=stage and tp.station_reversal_depot_0852
        and tp.station_reversal_depot_0852[stage.id]
      local held="unavailable"
      if raw and raw.inventory and raw.inventory.valid then
        local ok,n=pcall(function() return raw.inventory.get_item_count(
          i==3 and "intermediate-cogitator-station"
            or "junior-cogitator-station") end)
        if ok then held=tostring(n) end
      end
      error("REVERSAL_ENGINE_BUILD_PRIOR_DEPOT_LOST:"..i..
        " reason="..tostring(why)..
        " stage="..tostring(stage and stage.id)..
        " status="..tostring(raw and raw.status)..
        " held="..held..
        " worker="..tostring(raw and raw.worker_station_unit)..
        " stage_worker="..tostring(stage and stage.worker_station_unit)..
        " rec_status="..tostring(rec.status))
    end
    prior[entry.inventory]=true
  end
  local original_priest=original and original.priest
  if not(station and station.valid and station.unit_number~=test.units[2]
      and original and original.station and original.station.valid
      and original.station.unit_number==station.unit_number
      and original_priest and original_priest.valid
      and original_priest.unit_number==test.pair_priest_units[2]
      and tp.pairs_by_station[station.unit_number]==original
      and tp.pairs_by_station[test.units[2]]==nil
      and source and source.status=="outbound"
      and source.inventory and source.inventory.valid
      and source.inventory.get_item_count("senior-cogitator-station")==0
      and not prior[source.inventory]
      and #ghosts==0
      and not (tp.station_cargo_0824 and tp.station_cargo_0824[rec.id])
      and rec.reversal_outbound_0895
      and rec.reversal_outbound_0895.phase=="senior-build-authorized"
      and hierarchy and type(hierarchy.is_direct_subordinate)=="function"
      and hierarchy.is_direct_subordinate(magos,original)==true) then
    error("REVERSAL_ENGINE_SENIOR_BUILD_PHYSICAL_OR_PRIEST_CUSTODY_INVALID")
  end
  test.phase="senior-outbound-built"
  test.senior_built_tick=game.tick
  emit("PASS REVERSAL_ENGINE_SENIOR_OUTBOUND_BUILD tick="..game.tick..
    " original_senior="..test.units[2]..
    " rebuilt_senior="..station.unit_number..
    " original_priest="..test.pair_priest_units[2]..
    " source=0 carrier=0 prior_depots=3 ghost=0"..
    " hierarchy=magos-to-original-senior")
end

-- 0911: the real rebuilt Senior must own the NEXT ranked construction ghost
-- while the original Intermediate item remains physically in its protected
-- Magos depot. This is a ghost/writ milestone, NOT item pickup or a build.
local function reversal_engine_intermediate_ghost(state)
  local test=state.reversal_engine
  if not(test and test.phase=="senior-outbound-built") then return end
  if game.tick-(test.senior_built_tick or game.tick)>2400 then
    local tp=storage and storage.tech_priests
    local root=tp and tp.station_expansion_0256
      and tp.station_expansion_0256[test.writ_id]
    error("REVERSAL_ENGINE_INTERMEDIATE_GHOST_TIMEOUT"..
      ":broker_last_reason="..tostring(root and root.reversal_intermediate_0924_last_reason)..
      ":broker_last_tick="..tostring(root and root.reversal_intermediate_0924_last_tick)..
      ":broker_cursor="..tostring(tp and tp.station_intermediate_broker_cursor_0924)..
      ":root_status="..tostring(root and root.status)..
      ":next_status="..tostring(root and root.reversal_next_0911
        and root.reversal_next_0911.status))
  end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  if not(magos and root and root.status=="complete") then
    error("REVERSAL_ENGINE_INTERMEDIATE_ORIGINAL_WRIT_LOST")
  end
  local next_step=root.reversal_next_0911
  if not next_step then return end
  if next_step.status=="quarantined" then
    error("REVERSAL_ENGINE_INTERMEDIATE_GHOST_QUARANTINED:"..
      tostring(next_step.reason))
  end
  local child=tp.station_expansion_0256[next_step.child_writ_id]
  local senior=tp.pairs_by_priest[test.pair_priest_units[2]]
  local original=tp.pairs_by_priest[test.pair_priest_units[3]]
  local stage=root.reversal_stage_0854
  local held,why=REVERSAL_DEPOT_0852.get_staged(magos,stage)
  local p=child and child.ghost_position
  local ghosts=p and magos.station.surface.find_entities_filtered{
    name="entity-ghost",ghost_name="intermediate-cogitator-station",
    force=magos.station.force,
    area={{p.x-1,p.y-1},{p.x+1,p.y+1}}} or {}
  local ghost
  for _,candidate in pairs(ghosts) do
    if candidate.valid and child and candidate.unit_number==child.ghost_unit then
      ghost=candidate
    end
  end
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local radius=senior and (refresh_pair_radius and refresh_pair_radius(senior)
    or senior.radius or 20) or 0
  local target=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
    and magos.resource_expansion_0259.chain_0820.target
  local d2=ghost and senior and senior.station
    and (ghost.position.x-senior.station.position.x)^2+
      (ghost.position.y-senior.station.position.y)^2 or math.huge
  local junior_items=0
  local seen={}
  for _,key in ipairs({"reversal_stage_0851","reversal_stage_0853"}) do
    local depot=REVERSAL_DEPOT_0852.get_staged(magos,root[key])
    if not(depot and depot.inventory and depot.inventory.valid
        and not seen[depot.inventory]
        and depot.inventory.get_item_count("junior-cogitator-station")==1) then
      error("REVERSAL_ENGINE_INTERMEDIATE_JUNIOR_DEPOT_LOST:"..key)
    end
    seen[depot.inventory]=true
    junior_items=junior_items+1
  end
  if not(child and child.status=="active" and child.reversal_followup_0911
      and child.reversal_followup_0911.root_writ_id==root.id
      and child.reversal_followup_0911.stage_id==stage.id
      and child.reversal_followup_0911.original_priest
        ==test.pair_priest_units[3]
      and child.station_item=="intermediate-cogitator-station"
      and child.station_entity==child.station_item
      and child.worker_station_unit==senior.station.unit_number
      and child.requester_station_unit==senior.station.unit_number
      and tp.station_expansion_by_worker_0256[senior.station.unit_number]
        ==child.id
      and senior and senior.station and senior.station.valid
      and senior.station.name=="senior-cogitator-station"
      and senior.priest and senior.priest.valid
      and senior.priest.unit_number==test.pair_priest_units[2]
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[3]
      and not tp.pairs_by_station[test.units[3]]
      and h and h.is_direct_subordinate(magos,senior)==true
      and held and held.inventory and held.inventory.valid
      and not seen[held.inventory]
      and held.inventory.get_item_count("intermediate-cogitator-station")==1
      and ghost and ghost.name=="entity-ghost"
      and ghost.ghost_name==child.station_item
      and ghost.unit_number==next_step.ghost_unit
      and d2<=radius*radius and target
      and (ghost.position.x-target.x)^2+(ghost.position.y-target.y)^2
        <(senior.station.position.x-target.x)^2+
          (senior.station.position.y-target.y)^2
      and not(tp.station_cargo_0824 and tp.station_cargo_0824[child.id])
      and junior_items==2) then
    error("REVERSAL_ENGINE_INTERMEDIATE_GHOST_OR_ITEM_CUSTODY_INVALID:"..
      tostring(why))
  end
  test.phase="intermediate-ghost-reserved"
  test.intermediate_ghost_tick=game.tick
  test.intermediate_depot_before=held.inventory.get_item_count("intermediate-cogitator-station")
  test.intermediate_carrier_before=0
  emit("PASS REVERSAL_ENGINE_INTERMEDIATE_GHOST tick="..game.tick..
    " rebuilt_senior="..senior.station.unit_number..
    " original_senior_priest="..test.pair_priest_units[2]..
    " original_intermediate_priest="..test.pair_priest_units[3]..
    " child_writ="..child.id.." ghost_unit="..ghost.unit_number..
    " intermediate_depot=1 junior_depots=2 carrier=0"..
    " rank=3-to-2 physical_build_not_yet_claimed=true")
end

-- 0913: the original Senior must physically visit the original Magos
-- depot and carry the recovered Intermediate item in its real 0824 inventory.
local function reversal_engine_intermediate_pickup(state)
  local test=state.reversal_engine
  if not(test and test.phase=="intermediate-ghost-reserved") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local next_step=root and root.reversal_next_0911
  local child=next_step and tp.station_expansion_0256[next_step.child_writ_id]
  local stage=root and root.reversal_stage_0854
  local source=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local senior=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[2]]
  local original=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[3]]
  local cargo=child and tp.station_cargo_0824 and tp.station_cargo_0824[child.id]
  local source_count=source and source.inventory and source.inventory.valid
    and source.inventory.get_item_count("intermediate-cogitator-station")
  local carrier_count=cargo and cargo.inventory and cargo.inventory.valid
    and cargo.inventory.get_item_count("intermediate-cogitator-station")
  if game.tick-(test.intermediate_ghost_tick or game.tick)>12000 then
    error("REVERSAL_ENGINE_INTERMEDIATE_PICKUP_TIMEOUT:"..
      " phase="..tostring(child and child.phase)..
      " source="..tostring(source_count)..
      " carrier="..tostring(carrier_count)..
      " senior_mode="..tostring(senior and senior.mode))
  end
  if source_count==1 and not cargo then return end
  local distance_sq=senior and senior.priest and senior.priest.valid
    and magos and magos.station and magos.station.valid
    and (senior.priest.position.x-magos.station.position.x)^2+
      (senior.priest.position.y-magos.station.position.y)^2 or math.huge
  local relocation=rawget(_G,"TechPriestsStationRelocation0823")
  local lease=stage and relocation
    and relocation.pending_for_record(stage)
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local seen={}
  if source and source.inventory then seen[source.inventory]=true end
  if cargo and cargo.inventory then seen[cargo.inventory]=true end
  local juniors=0
  for _,key in ipairs({"reversal_stage_0851","reversal_stage_0853"}) do
    local prior=root and REVERSAL_DEPOT_0852.get_staged(magos,root[key])
    if not(prior and prior.inventory and prior.inventory.valid
        and not seen[prior.inventory]
        and prior.inventory.get_item_count("junior-cogitator-station")==1) then
      error("REVERSAL_ENGINE_INTERMEDIATE_PICKUP_JUNIOR_DEPOT_LOST:"..key)
    end
    seen[prior.inventory]=true
    juniors=juniors+1
  end
  if not(magos and root and root.status=="complete"
      and next_step and next_step.status=="ghost-reserved"
      and child and child.status=="active"
      and child.reversal_followup_0911
      and child.reversal_followup_0911.root_writ_id==root.id
      and child.reversal_followup_0911.stage_id==stage.id
      and child.reversal_followup_0911.picked_tick
      and child.reversal_followup_0911.picked_tick>=test.intermediate_ghost_tick
      and child.worker_station_unit==senior.station.unit_number
      and child.reversal_followup_0911.original_senior_priest
        ==test.pair_priest_units[2]
      and source and source.status=="outbound"
      and source_count==0 and test.intermediate_depot_before==1
      and test.intermediate_carrier_before==0
      and cargo and cargo.status=="carrying" and carrier_count==1
      and cargo.record_id==child.id
      and cargo.station_unit==senior.station.unit_number
      and cargo.priest_unit==test.pair_priest_units[2]
      and cargo.item=="intermediate-cogitator-station"
      and cargo.inventory~=source.inventory
      and cargo.surface==senior.station.surface
      and cargo.force==senior.station.force
      and distance_sq<=25
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[3]
      and lease and lease.status=="staged"
      and lease.priest_unit==test.pair_priest_units[3]
      and not tp.pairs_by_station[test.units[3]]
      and h and h.is_direct_subordinate(magos,senior)==true
      and juniors==2) then
    error("REVERSAL_ENGINE_INTERMEDIATE_PICKUP_PHYSICAL_CUSTODY_INVALID:"..
      " source="..tostring(source_count)..
      " carrier="..tostring(carrier_count)..
      " distance_sq="..tostring(distance_sq))
  end
  test.phase="intermediate-real-item-picked-up"
  test.intermediate_pickup_tick=game.tick
  emit("PASS REVERSAL_ENGINE_INTERMEDIATE_PICKUP tick="..game.tick..
    " rebuilt_senior="..senior.station.unit_number..
    " original_senior_priest="..test.pair_priest_units[2]..
    " original_intermediate_priest="..test.pair_priest_units[3]..
    " child_writ="..child.id..
    " source_before=1 source_after=0 carrier_before=0 carrier_after=1"..
    " junior_depots=2 distance_sq="..string.format("%.3f",distance_sq)..
    " original_priest_staged=true")
end

-- 0915: independently verify that the original Senior reaches its owned
-- Intermediate ghost while still holding the same real recovered station item.
local function reversal_engine_intermediate_transit(state)
  local test=state.reversal_engine
  if not(test and test.phase=="intermediate-real-item-picked-up") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local next_step=root and root.reversal_next_0911
  local child=next_step and tp.station_expansion_0256[next_step.child_writ_id]
  local follow=child and child.reversal_followup_0911
  local senior=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[2]]
  local original=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[3]]
  local stage=root and root.reversal_stage_0854
  local source=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local cargo=child and tp.station_cargo_0824 and tp.station_cargo_0824[child.id]
  local ghosts=senior and child and senior.station.surface.find_entities_filtered{
    position=child.ghost_position,radius=1,name="entity-ghost"}
  local owned=nil
  for _,entity in pairs(ghosts or {}) do
    if entity.valid and entity.unit_number==child.ghost_unit
        and entity.ghost_name=="intermediate-cogitator-station" then
      if owned then error("REVERSAL_ENGINE_INTERMEDIATE_TRANSIT_AMBIGUOUS_GHOST") end
      owned=entity
    end
  end
  local source_count=source and source.inventory and source.inventory.valid
    and source.inventory.get_item_count("intermediate-cogitator-station")
  local held=cargo and cargo.inventory and cargo.inventory.valid
    and cargo.inventory.get_item_count("intermediate-cogitator-station")
  local d2=owned and senior and senior.priest and senior.priest.valid
    and (senior.priest.position.x-owned.position.x)^2+
      (senior.priest.position.y-owned.position.y)^2 or math.huge
  if game.tick-(test.intermediate_pickup_tick or game.tick)>12000 then
    error("REVERSAL_ENGINE_INTERMEDIATE_TRANSIT_TIMEOUT:"..
      " phase="..tostring(child and child.phase)..
      " source="..tostring(source_count).." carrier="..tostring(held)..
      " distance_sq="..tostring(d2))
  end
  if d2>25 then return end
  -- 0918: the independent harness can observe the real unit crossing the
  -- five-tile boundary before the production controller's next service.
  -- Do not falsely fail that legitimate ordering; equally, do not credit
  -- arrival without the controller's persistent receipt and actual item.
  -- A bounded wait is fatal if the controller never certifies arrival.
  if not(follow and type(follow.arrived_tick)=="number"
      and follow.transit_status=="arrived") then
    test.intermediate_first_physical_arrival_tick=
      test.intermediate_first_physical_arrival_tick or game.tick
    if source_count~=0 or held~=1 or not owned
        or game.tick-test.intermediate_first_physical_arrival_tick>600 then
      error("REVERSAL_ENGINE_INTERMEDIATE_ARRIVAL_RECEIPT_MISSING:"..
        " source="..tostring(source_count).." held="..tostring(held)..
        " distance_sq="..tostring(d2)..
        " arrived_tick="..tostring(follow and follow.arrived_tick)..
        " transit_status="..tostring(follow and follow.transit_status))
    end
    return
  end
  local relocation=rawget(_G,"TechPriestsStationRelocation0823")
  local lease=stage and relocation and relocation.pending_for_record(stage)
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local seen={}
  if source and source.inventory then seen[source.inventory]=true end
  if cargo and cargo.inventory then seen[cargo.inventory]=true end
  local juniors=0
  for _,key in ipairs({"reversal_stage_0851","reversal_stage_0853"}) do
    local prior=root and REVERSAL_DEPOT_0852.get_staged(magos,root[key])
    if not(prior and prior.inventory and prior.inventory.valid
        and not seen[prior.inventory]
        and prior.inventory.get_item_count("junior-cogitator-station")==1) then
      error("REVERSAL_ENGINE_INTERMEDIATE_TRANSIT_JUNIOR_DEPOT_LOST:"..key)
    end
    seen[prior.inventory]=true
    juniors=juniors+1
  end
  if not(root and root.status=="complete" and next_step
      and next_step.status=="ghost-reserved" and child and child.status=="active"
      and follow and follow.root_writ_id==root.id
      and follow.stage_id==stage.id and follow.picked_tick
      and follow.arrived_tick and follow.arrived_tick>=follow.picked_tick+120
      and follow.transit_status=="arrived"
      and follow.original_senior_priest==test.pair_priest_units[2]
      and follow.original_priest==test.pair_priest_units[3]
      and child.worker_station_unit==senior.station.unit_number
      and child.ghost_unit==next_step.ghost_unit
      and owned and owned.force==senior.station.force
      and owned.surface==senior.station.surface
      and source and source.status=="outbound" and source_count==0
      and cargo and cargo.status=="carrying" and held==1
      and cargo.record_id==child.id
      and cargo.priest_unit==test.pair_priest_units[2]
      and cargo.station_unit==senior.station.unit_number
      and cargo.inventory~=source.inventory
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[3]
      and lease and lease.status=="staged"
      and lease.priest_unit==test.pair_priest_units[3]
      and h and h.is_direct_subordinate(magos,senior)==true
      and juniors==2) then
    error("REVERSAL_ENGINE_INTERMEDIATE_TRANSIT_CUSTODY_INVALID:"..
      " source="..tostring(source_count).." held="..tostring(held)..
      " distance_sq="..tostring(d2)..
      " child_phase="..tostring(child and child.phase)..
      " child_status="..tostring(child and child.status)..
      " arrived_tick="..tostring(follow and follow.arrived_tick)..
      " transit_status="..tostring(follow and follow.transit_status)..
      " lease_status="..tostring(lease and lease.status)..
      " lease_priest="..tostring(lease and lease.priest_unit)..
      " cargo_status="..tostring(cargo and cargo.status)..
      " cargo_station="..tostring(cargo and cargo.station_unit)..
      " original_priest="..tostring(original and original.priest and original.priest.unit_number)..
      " junior_depots="..tostring(juniors))
  end
  test.phase="intermediate-real-item-at-ghost"
  test.intermediate_transit_tick=game.tick
  emit("PASS REVERSAL_ENGINE_INTERMEDIATE_TRANSIT tick="..game.tick..
    " rebuilt_senior="..senior.station.unit_number..
    " original_senior_priest="..test.pair_priest_units[2]..
    " original_intermediate_priest="..test.pair_priest_units[3]..
    " child_writ="..child.id..
    " held=1 source=0 junior_depots=2"..
    " distance_sq="..string.format("%.3f",d2)..
    " ghost_unit="..child.ghost_unit..
    " original_priest_staged=true")
end

-- 0916: independent Factorio engine proof of the ORIGINAL Intermediate
-- station item consumed exactly once, paired to the SAME staged priest.
local function reversal_engine_intermediate_build(state)
  local test=state.reversal_engine
  if not(test and test.phase=="intermediate-real-item-at-ghost") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local next_step=root and root.reversal_next_0911
  local child=next_step and tp.station_expansion_0256[next_step.child_writ_id]
  local follow=child and child.reversal_followup_0911
  local senior=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[2]]
  local original=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[3]]
  local stage=root and root.reversal_stage_0854
  local depot=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local cargo=child and tp.station_cargo_0824 and tp.station_cargo_0824[child.id]
  if game.tick-(test.intermediate_transit_tick or game.tick)>12000 then
    error("REVERSAL_ENGINE_INTERMEDIATE_BUILD_TIMEOUT:"..
      " phase="..tostring(child and child.phase)..
      " child_status="..tostring(child and child.status)..
      " build_authorized="..tostring(follow and follow.build_authorized_tick)..
      " carrier_status="..tostring(cargo and cargo.status))
  end
  if not(child and child.status=="complete") then return end
  local built=original and original.station
  local d2=built and built.valid and child.ghost_position and
    (built.position.x-child.ghost_position.x)^2+
      (built.position.y-child.ghost_position.y)^2 or math.huge
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local total=0
  if built and built.valid then
    local nearby=built.surface.find_entities_filtered{
      name="intermediate-cogitator-station",
      position=child.ghost_position,radius=1.5}
    for _,e in pairs(nearby) do
      if e.valid and (e.position.x-child.ghost_position.x)^2+
          (e.position.y-child.ghost_position.y)^2<=0.01 then
        total=total+1
      end
    end
  end
  local missing_ghost=false
  if senior and senior.station and senior.station.valid
      and child and child.ghost_position then
    missing_ghost=true
    for _,e in pairs(senior.station.surface.find_entities_filtered{
        name="entity-ghost",position=child.ghost_position,radius=1}) do
      if e.valid and e.unit_number==child.ghost_unit then
        missing_ghost=false
      end
    end
  end
  local count=depot and depot.inventory and depot.inventory.valid
    and depot.inventory.get_item_count("intermediate-cogitator-station")
  local inventory_seen={}
  if depot and depot.inventory then inventory_seen[depot.inventory]=true end
  local protected=0
  for _,key in ipairs({"reversal_stage_0851","reversal_stage_0853"}) do
    local earlier=root and root[key]
    local entry=earlier and REVERSAL_DEPOT_0852.get_staged(magos,earlier)
    if not(entry and entry.inventory and entry.inventory.valid
        and not inventory_seen[entry.inventory]
        and entry.inventory.get_item_count("junior-cogitator-station")==1) then
      error("REVERSAL_ENGINE_INTERMEDIATE_BUILD_JUNIOR_DEPOT_LOST:"..key)
    end
    inventory_seen[entry.inventory]=true
    protected=protected+1
  end
  local radius=senior and senior.radius or 0
  if not(root and root.status=="complete"
      and next_step and next_step.child_writ_id==child.id
      and follow and type(follow.arrived_tick)=="number"
      and type(follow.build_authorized_tick)=="number"
      and follow.build_authorized_tick>follow.arrived_tick
      and follow.original_senior_priest==test.pair_priest_units[2]
      and follow.original_priest==test.pair_priest_units[3]
      and child.station_item=="intermediate-cogitator-station"
      and child.worker_station_unit==senior.station.unit_number
      and senior.priest.unit_number==test.pair_priest_units[2]
      and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[3]
      and built and built.valid and built.name==child.station_item
      and built.unit_number~=test.units[3]
      and built.force==senior.station.force
      and built.surface==senior.station.surface
      and d2<0.01 and total==1 and missing_ghost
      and original.relocation_pending_0823==nil
      and tp.pairs_by_station[built.unit_number]==original
      and tp.pairs_by_station[test.units[3]]==nil
      and tp.station_by_priest[test.pair_priest_units[3]]==built.unit_number
      and not (tp.station_expansion_by_worker_0256
        and tp.station_expansion_by_worker_0256[senior.station.unit_number])
      and not (tp.station_cargo_0824 and tp.station_cargo_0824[child.id])
      and depot and depot.status=="outbound" and count==0
      and stage and stage.leaf_priest_unit==test.pair_priest_units[3]
      and stage.leaf_station_unit==test.units[3]
      and h and h.is_direct_subordinate(magos,senior)==true
      and h.is_direct_subordinate(senior,original)==true
      and protected==2) then
    error("REVERSAL_ENGINE_INTERMEDIATE_BUILD_IDENTITY_OR_CUSTODY_INVALID:"..
      " built="..tostring(built and built.unit_number)..
      " old="..tostring(test.units[3])..
      " priest="..tostring(original and original.priest
        and original.priest.unit_number)..
      " count="..tostring(count)..
      " carrier="..tostring(cargo and cargo.status)..
      " new_hierarchy="..tostring(h and h.is_direct_subordinate
        and h.is_direct_subordinate(senior,original))..
      " distance_sq="..tostring(d2))
  end
  test.phase="intermediate-real-station-built"
  emit("PASS REVERSAL_ENGINE_INTERMEDIATE_BUILD tick="..game.tick..
    " rebuilt_senior="..senior.station.unit_number..
    " original_senior_priest="..test.pair_priest_units[2]..
    " original_intermediate_priest="..test.pair_priest_units[3]..
    " child_writ="..child.id..
    " rebuilt_intermediate="..built.unit_number..
    " original_intermediate_station="..test.units[3]..
    " source=0 carrier=0 junior_depots=2"..
    " distance_sq="..string.format("%.3f",d2)..
    " ghost=0 hierarchy=senior-to-original-intermediate")
end

-- 0919: the original rebuilt Intermediate must physically reserve a Junior
-- ghost under its real command radius. The original first-Junior priest and
-- BOTH separately held recovered Junior items must remain untouched.
local function reversal_engine_first_junior_ghost(state)
  local test=state.reversal_engine
  if not(test and test.phase=="intermediate-real-station-built") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  if game.tick-(test.intermediate_transit_tick or game.tick)>15000 then
    local rebuilt=tp and tp.pairs_by_priest
      and tp.pairs_by_priest[test.pair_priest_units[3]]
    local pointer=rebuilt and rebuilt.reversal_junior_followup_0920
    error("REVERSAL_ENGINE_FIRST_JUNIOR_GHOST_TIMEOUT"..
      ":last_reason="..tostring(root and root.reversal_junior_0920_last_reason)..
      ":last_tick="..tostring(root and root.reversal_junior_0920_last_tick)..
      ":followup="..tostring(pointer and pointer.root_writ_id)..
      ":rebuilt_station="..tostring(rebuilt and rebuilt.station
        and rebuilt.station.unit_number)..
      ":magos="..tostring(magos and magos.station
        and magos.station.unit_number))
  end
  local next_step=root and root.reversal_junior_0919
  if not next_step then return end
  if next_step.status=="quarantined" then
    error("REVERSAL_ENGINE_FIRST_JUNIOR_GHOST_QUARANTINED:"..
      tostring(next_step.reason))
  end
  local child=tp.station_expansion_0256[next_step.child_writ_id]
  local intermediate=tp.pairs_by_priest[test.pair_priest_units[3]]
  local original=tp.pairs_by_priest[test.pair_priest_units[4]]
  local stage=root.reversal_stage_0853
  local first,first_why=REVERSAL_DEPOT_0852.get_staged(magos,stage)
  local second,second_why=REVERSAL_DEPOT_0852.get_staged(
    magos,root.reversal_stage_0851)
  local p=child and child.ghost_position
  local ghosts=p and magos.station.surface.find_entities_filtered{
    name="entity-ghost",ghost_name="junior-cogitator-station",
    force=magos.station.force,area={{p.x-1,p.y-1},{p.x+1,p.y+1}}} or {}
  local ghost
  for _,candidate in pairs(ghosts) do
    if candidate.valid and child and candidate.unit_number==child.ghost_unit then
      ghost=candidate
    end
  end
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local radius=intermediate and (refresh_pair_radius
    and refresh_pair_radius(intermediate) or intermediate.radius or 20) or 0
  local target=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
    and magos.resource_expansion_0259.chain_0820.target
  local d2=ghost and intermediate and intermediate.station
    and (ghost.position.x-intermediate.station.position.x)^2+
      (ghost.position.y-intermediate.station.position.y)^2 or math.huge
  if not(root and root.status=="complete"
      and next_step.status=="ghost-reserved"
      and child and child.status=="active"
      and child.reversal_junior_0919
      and child.reversal_junior_0919.root_writ_id==root.id
      and child.reversal_junior_0919.stage_id==stage.id
      and child.reversal_junior_0919.original_priest==test.pair_priest_units[4]
      and child.reversal_junior_0919.original_intermediate_priest
        ==test.pair_priest_units[3]
      and child.station_item=="junior-cogitator-station"
      and child.station_entity=="junior-cogitator-station"
      and child.worker_station_unit==intermediate.station.unit_number
      and child.requester_station_unit==intermediate.station.unit_number
      and tp.station_expansion_by_worker_0256[intermediate.station.unit_number]
        ==child.id
      and intermediate.station.valid
      and intermediate.station.name=="intermediate-cogitator-station"
      and intermediate.priest.valid
      and intermediate.priest.unit_number==test.pair_priest_units[3]
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[4]
      and not(tp.pairs_by_station[test.units[4]])
      and first and second and first.inventory~=second.inventory
      and first.inventory.valid and second.inventory.valid
      and first.inventory.get_item_count("junior-cogitator-station")==1
      and second.inventory.get_item_count("junior-cogitator-station")==1
      and ghost and ghost.name=="entity-ghost"
      and ghost.ghost_name==child.station_item
      and ghost.unit_number==next_step.ghost_unit
      and ghost.unit_number==child.ghost_unit
      and d2<=radius*radius and target
      and (ghost.position.x-target.x)^2+(ghost.position.y-target.y)^2
        <(intermediate.station.position.x-target.x)^2+
          (intermediate.station.position.y-target.y)^2
      and h and h.is_direct_subordinate(
        tp.pairs_by_priest[test.pair_priest_units[2]],intermediate)==true
      and not(tp.station_cargo_0824 and tp.station_cargo_0824[child.id])) then
    error("REVERSAL_ENGINE_FIRST_JUNIOR_GHOST_CUSTODY_INVALID:"..
      tostring(first_why)..":"..tostring(second_why)..
      ":child="..tostring(child and child.id)..
      ":distance_sq="..tostring(d2))
  end
  test.phase="first-junior-ghost-reserved"
  test.first_junior_ghost_tick=game.tick
  emit("PASS REVERSAL_ENGINE_FIRST_JUNIOR_GHOST tick="..game.tick..
    " rebuilt_intermediate="..intermediate.station.unit_number..
    " original_intermediate_priest="..test.pair_priest_units[3]..
    " original_junior_priest="..test.pair_priest_units[4]..
    " child_writ="..child.id.." ghost_unit="..ghost.unit_number..
    " junior_depots=2 carrier=0 rank=2-to-1 physical_build_not_yet_claimed=true")
end

-- 0934: require the first Junior item to be physically removed from its
-- original 0853 Magos depot and observed in the rebuilt Intermediate's
-- engine-owned 0824 carrier. A ghost or a Lua phase is NOT an item receipt.
-- The second Junior's independent 0851 item and both priest leases stay put.
local function reversal_engine_first_junior_pickup(state)
  local test=state.reversal_engine
  if not(test and test.phase=="first-junior-ghost-reserved") then return end
  local tp=storage and storage.tech_priests
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local step=root and root.reversal_junior_0919
  local child=step and tp.station_expansion_0256[step.child_writ_id]
  local magos=tp and tp.pairs_by_station
    and tp.pairs_by_station[test.units[1]]
  local intermediate=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[3]]
  local first_stage=root and root.reversal_stage_0853
  local second_stage=root and root.reversal_stage_0851
  local first=first_stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[first_stage.id]
  -- 0942: Lua 'and' discards additional return values. Retain the
  -- independently audited depot reason alongside its physical inventory.
  local second,second_why
  if second_stage then
    second,second_why=REVERSAL_DEPOT_0852.get_staged(magos,second_stage)
  end
  local cargo,cargo_why=child and intermediate and
    CARGO_ENGINE_0824.get(intermediate,child)
  local follow=child and child.reversal_junior_0919
  -- 0937: real engine runs timed out with first depot=1 and no carrier.
  -- Sample the ACTUAL original Intermediate, scheduler priority and pickup
  -- command receipt without moving a priest or changing the acceptance gate.
  if type(test.first_junior_ghost_tick)=="number"
      and (game.tick-test.first_junior_ghost_tick)%600==0 then
    local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
    local ok,priority=false,nil
    if intermediate and type(probe)=="function" then
      ok,priority=pcall(probe,intermediate)
    end
    local d2=intermediate and intermediate.priest and magos
      and magos.station and intermediate.priest.position
      and (intermediate.priest.position.x-magos.station.position.x)^2
        +(intermediate.priest.position.y-magos.station.position.y)^2
      or math.huge
    emit("REVERSAL_ENGINE_FIRST_JUNIOR_PICKUP_OBSERVE tick="..game.tick..
      " phase="..tostring(child and child.phase)..
      " distance_sq="..tostring(d2)..
      " worker_mode="..tostring(intermediate and intermediate.mode)..
      " worker_active_task="..tostring(intermediate
        and type(intermediate.active_task)=="table"
        and intermediate.active_task.kind)..
      " worker_current_task="..tostring(intermediate
        and type(intermediate.current_task)=="table"
        and intermediate.current_task.kind)..
      " worker_construction_task="..tostring(intermediate
        and intermediate.construction_task~=nil)..
      " worker_dead="..tostring(intermediate and intermediate.dead)..
      " worker_recalling="..tostring(intermediate and intermediate.recalling)..
      " priority="..tostring(ok and type(priority)=="table"
        and priority.priority)..
      " pickup_started="..tostring(follow and follow.pickup_started_tick)..
      " broker_reason="..tostring(root and root.reversal_junior_0937_last_reason)..
      " broker_tick="..tostring(root and root.reversal_junior_0937_last_tick)..
      " handoff_ok="..tostring(root and root.reversal_junior_0967_handoff
        and root.reversal_junior_0967_handoff.accepted)..
      " handoff_reason="..tostring(root and root.reversal_junior_0967_handoff
        and root.reversal_junior_0967_handoff.reason)..
      " pending_item="..tostring(intermediate
        and intermediate.infrastructure_recipe_request_0647
        and intermediate.infrastructure_recipe_request_0647.item)..
      " pending_missing="..tostring(intermediate
        and intermediate.infrastructure_recipe_request_0647
        and intermediate.infrastructure_recipe_request_0647.missing)..
      " requested="..tostring(intermediate and intermediate.requested_item)..
      " logistic="..tostring(intermediate and intermediate.logistic_requested_item)..
      " last_command="..tostring(follow and follow.last_pickup_command_tick)..
      " route_refusal="..tostring(follow and follow.pickup_command_refusal_0939)..
      " route_owner="..tostring(intermediate
        and intermediate.movement_request_0418
        and intermediate.movement_request_0418.owner)..
      " route_reason="..tostring(intermediate
        and intermediate.movement_request_0418
        and intermediate.movement_request_0418.reason)..
      " route_priority="..tostring(intermediate
        and intermediate.movement_request_0418
        and intermediate.movement_request_0418.priority)..
      " source="..tostring(first and first.inventory
        and first.inventory.get_item_count("junior-cogitator-station"))..
      " carrier="..tostring(cargo and cargo.status))
  end
  if game.tick-(test.first_junior_ghost_tick or game.tick)>15000 then
    error("REVERSAL_ENGINE_FIRST_JUNIOR_PICKUP_TIMEOUT:"..
      "phase="..tostring(child and child.phase)..
      ":source="..tostring(first and first.inventory
        and first.inventory.get_item_count("junior-cogitator-station"))..
      ":carrier="..tostring(cargo and cargo.status)..
      ":cargo_reason="..tostring(cargo_why)..
      ":second_reason="..tostring(second_why)..
      ":broker_reason="..tostring(root and root.reversal_junior_0937_last_reason)..
      ":broker_tick="..tostring(root and root.reversal_junior_0937_last_tick)..
      ":route_refusal="..tostring(follow and follow.pickup_command_refusal_0939)..
      ":route_owner="..tostring(intermediate
        and intermediate.movement_request_0418
        and intermediate.movement_request_0418.owner))
  end
  -- Still walking to the actual Magos depot: never turn an empty hold or
  -- a persisted status string into a successful pickup.
  if not(first and first.status=="outbound"
      and cargo and cargo.status=="carrying"
      and cargo.inventory and cargo.inventory.valid
      and cargo.inventory.get_item_count("junior-cogitator-station")==1) then
    return
  end
  local first_lease=first_stage and tp.station_relocation_0823
    and tp.station_relocation_0823[first_stage.leaf_station_unit]
  local second_lease=second_stage and tp.station_relocation_0823
    and tp.station_relocation_0823[second_stage.leaf_station_unit]
  local d2=intermediate and intermediate.priest and magos and magos.station
    and (intermediate.priest.position.x-magos.station.position.x)^2+
      (intermediate.priest.position.y-magos.station.position.y)^2 or math.huge
  if not(root and root.status=="complete" and step
      and step.status=="ghost-reserved"
      and child and child.status=="active"
      and step.child_writ_id==child.id
      and step.ghost_unit==child.ghost_unit
      and follow and follow.root_writ_id==root.id
      and follow.stage_id==first_stage.id
      and follow.original_priest==test.pair_priest_units[4]
      and follow.original_intermediate_priest==test.pair_priest_units[3]
      and type(follow.picked_tick)=="number"
      and type(test.first_junior_ghost_tick)=="number"
      and follow.picked_tick>=test.first_junior_ghost_tick+120
      and game.tick>=follow.picked_tick
      and intermediate and intermediate.station and intermediate.station.valid
      and intermediate.priest and intermediate.priest.valid
      and intermediate.station.unit_number==child.worker_station_unit
      and intermediate.priest.unit_number==test.pair_priest_units[3]
      and tp.pairs_by_station[intermediate.station.unit_number]==intermediate
      and first.record_id==first_stage.id
      and first.magos_station_unit==magos.station.unit_number
      and first.magos_priest_unit==magos.priest.unit_number
      and first.inventory and first.inventory.valid
      and first.inventory~=cargo.inventory
      and first.inventory.get_item_count("junior-cogitator-station")==0
      and second and second.inventory and second.inventory.valid
      and second.inventory~=first.inventory
      and second.inventory~=cargo.inventory
      and second.inventory.get_item_count("junior-cogitator-station")==1
      and cargo.record_id==child.id
      and cargo.station_unit==intermediate.station.unit_number
      and cargo.priest_unit==intermediate.priest.unit_number
      and cargo.item=="junior-cogitator-station"
      and first_lease and first_lease.status=="staged"
      and first_lease.priest_unit==test.pair_priest_units[4]
      and second_lease and second_lease.status=="staged"
      and second_lease.priest_unit==test.pair_priest_units[5]
      -- 0966: the carrier may already have departed the Magos depot.
      -- Prove physical proximity when 0824 debited the engine inventory.
      and cargo.pickup_station_unit==magos.station.unit_number
      and type(cargo.pickup_distance_sq)=="number"
      and cargo.pickup_distance_sq>=0 and cargo.pickup_distance_sq<=25
      and cargo.pickup_tick==follow.picked_tick) then
    error("REVERSAL_ENGINE_FIRST_JUNIOR_PICKUP_CUSTODY_INVALID:"..
      "source="..tostring(first and first.inventory
        and first.inventory.get_item_count("junior-cogitator-station"))..
      ":held="..tostring(cargo and cargo.inventory
        and cargo.inventory.get_item_count("junior-cogitator-station"))..
      ":second="..tostring(second and second.inventory
        and second.inventory.get_item_count("junior-cogitator-station"))..
      ":distance_sq="..tostring(d2)..
      ":pickup_distance_sq="..tostring(cargo and cargo.pickup_distance_sq)..
      ":pickup_station="..tostring(cargo and cargo.pickup_station_unit)..
      ":pickup_tick="..tostring(cargo and cargo.pickup_tick)..
      ":follow_tick="..tostring(follow and follow.picked_tick))
  end
  test.phase="first-junior-real-item-picked"
  emit("PASS REVERSAL_ENGINE_FIRST_JUNIOR_PICKUP tick="..game.tick..
    " rebuilt_intermediate="..intermediate.station.unit_number..
    " original_intermediate_priest="..test.pair_priest_units[3]..
    " original_junior_priest="..test.pair_priest_units[4]..
    " child_writ="..child.id..
    " source_before=1 source_after=0 carrier_before=0 carrier_after=1"..
    " second_depot=1 distance_sq="..string.format("%.3f",d2)..
    " pickup_distance_sq="..string.format("%.3f",cargo.pickup_distance_sq)..
    " pickup_station="..cargo.pickup_station_unit..
    " pickup_tick="..cargo.pickup_tick..
    " original_priest_staged=true")
end

-- 0935: independent live 2.0.77 outward transit proof. The original
-- Intermediate must carry the exact recovered FIRST Junior item from Magos
-- all the way to the genuine first-Junior ghost; merely seeing a ghost or
-- a persisted phase string cannot pass. The second Junior remains counted
-- in its distinct 0851 depot under original staged priest #5.
local function reversal_engine_first_junior_transit(state)
  local test=state.reversal_engine
  if not(test and test.phase=="first-junior-real-item-picked") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local step=root and root.reversal_junior_0919
  local child=step and tp.station_expansion_0256[step.child_writ_id]
  local follow=child and child.reversal_junior_0919
  local intermediate=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[3]]
  local original=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[4]]
  local first_stage=root and root.reversal_stage_0853
  local second_stage=root and root.reversal_stage_0851
  local first=first_stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[first_stage.id]
  -- 0942: Lua 'and' discards additional return values. Retain the
  -- independently audited depot reason alongside its physical inventory.
  local second,second_why
  if second_stage then
    second,second_why=REVERSAL_DEPOT_0852.get_staged(magos,second_stage)
  end
  local cargo,cargo_why=child and intermediate and
    CARGO_ENGINE_0824.get(intermediate,child)
  local p=child and child.ghost_position
  local ghosts=p and magos and magos.station.surface.find_entities_filtered{
    name="entity-ghost",force=magos.station.force,
    area={{p.x-1,p.y-1},{p.x+1,p.y+1}}} or {}
  local owned=nil
  for _,candidate in pairs(ghosts) do
    if candidate.valid and child and candidate.unit_number==child.ghost_unit
        and candidate.ghost_name=="junior-cogitator-station" then
      if owned then error("REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT_AMBIGUOUS_GHOST") end
      owned=candidate
    end
  end
  local held=cargo and cargo.inventory and cargo.inventory.valid
    and cargo.inventory.get_item_count("junior-cogitator-station")
  local source=first and first.inventory and first.inventory.valid
    and first.inventory.get_item_count("junior-cogitator-station")
  local second_count=second and second.inventory and second.inventory.valid
    and second.inventory.get_item_count("junior-cogitator-station")
  local d2=owned and intermediate and intermediate.priest
    and intermediate.priest.valid
    and (intermediate.priest.position.x-owned.position.x)^2+
      (intermediate.priest.position.y-owned.position.y)^2 or math.huge
  if game.tick-(test.first_junior_pickup_tick or game.tick)>12000 then
    error("REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT_TIMEOUT:"..
      " phase="..tostring(child and child.phase)..
      " held="..tostring(held).." source="..tostring(source)..
      " second="..tostring(second_count)..
      " distance_sq="..tostring(d2)..
      " transit_status="..tostring(follow and follow.transit_status))
  end
  if d2>25 then return end
  -- Native movement and the test harness execute in distinct schedulers.
  -- Permit the original controller a bounded 600 ticks to publish its
  -- arrival receipt after the real priest enters the five-tile boundary.
  if not(follow and follow.transit_status=="arrived"
      and type(follow.arrived_tick)=="number") then
    test.first_junior_first_physical_arrival_tick=
      test.first_junior_first_physical_arrival_tick or game.tick
    if not(owned and source==0 and held==1 and second_count==1)
        or game.tick-test.first_junior_first_physical_arrival_tick>600 then
      error("REVERSAL_ENGINE_FIRST_JUNIOR_ARRIVAL_RECEIPT_MISSING:"..
        " source="..tostring(source).." held="..tostring(held)..
        " second="..tostring(second_count)..
        " distance_sq="..tostring(d2)..
        " phase="..tostring(child and child.phase)..
        " arrived_tick="..tostring(follow and follow.arrived_tick))
    end
    return
  end
  local first_lease=first_stage and tp.station_relocation_0823
    and tp.station_relocation_0823[first_stage.leaf_station_unit]
  local second_lease=second_stage and tp.station_relocation_0823
    and tp.station_relocation_0823[second_stage.leaf_station_unit]
  local target=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
    and magos.resource_expansion_0259.chain_0820.target
  local radius=intermediate and (refresh_pair_radius
    and refresh_pair_radius(intermediate) or intermediate.radius or 20)
    or 0
  if not(root and root.status=="complete"
      and step and step.status=="ghost-reserved"
      and child and child.status=="active"
      and child.station_item=="junior-cogitator-station"
      and child.worker_station_unit==intermediate.station.unit_number
      and child.requester_station_unit==intermediate.station.unit_number
      and step.child_writ_id==child.id and step.ghost_unit==child.ghost_unit
      and follow and follow.root_writ_id==root.id
      and follow.stage_id==first_stage.id
      and follow.original_priest==test.pair_priest_units[4]
      and follow.original_intermediate_priest==test.pair_priest_units[3]
      and type(follow.picked_tick)=="number"
      and follow.picked_tick>=test.first_junior_ghost_tick+120
      and follow.transit_status=="arrived"
      and type(follow.transit_started_tick)=="number"
      and type(follow.transit_last_command_tick)=="number"
      and follow.transit_last_command_tick>=follow.transit_started_tick
      and follow.arrived_tick>=follow.transit_last_command_tick
      and follow.arrived_tick>=follow.picked_tick+120
      and follow.arrived_tick<=game.tick
      and follow.arrived_tick-follow.transit_started_tick<=7200
      and owned and owned.name=="entity-ghost"
      and owned.unit_number==child.ghost_unit
      and owned.force==intermediate.station.force
      and owned.surface==intermediate.station.surface
      and (owned.position.x-child.ghost_position.x)^2+
        (owned.position.y-child.ghost_position.y)^2<0.01
      and d2<=25 and d2<=radius*radius
      and target and (owned.position.x-target.x)^2+
        (owned.position.y-target.y)^2<
        (intermediate.station.position.x-target.x)^2+
        (intermediate.station.position.y-target.y)^2
      and first and first.status=="outbound" and source==0
      and second and second_count==1
      and first.inventory~=second.inventory
      and cargo and cargo.status=="carrying" and held==1
      and cargo.inventory~=first.inventory
      and cargo.inventory~=second.inventory
      and cargo.record_id==child.id
      and cargo.station_unit==intermediate.station.unit_number
      and cargo.priest_unit==test.pair_priest_units[3]
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[4]
      and tp.pairs_by_station[first_stage.leaf_station_unit]==nil
      and first_lease and first_lease.status=="staged"
      and first_lease.priest_unit==test.pair_priest_units[4]
      and second_lease and second_lease.status=="staged"
      and second_lease.priest_unit==test.pair_priest_units[5]
      and second_why=="depot-stored-physical-item-verified") then
    error("REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT_CUSTODY_INVALID:"..
      " source="..tostring(source).." held="..tostring(held)..
      " second="..tostring(second_count)..
      " second_why="..tostring(second_why)..
      " distance_sq="..tostring(d2)..
      " arrived_tick="..tostring(follow and follow.arrived_tick)..
      " transit_status="..tostring(follow and follow.transit_status)..
      " cargo_reason="..tostring(cargo_why)..
      " first_lease="..tostring(first_lease and first_lease.status)..
      " second_lease="..tostring(second_lease and second_lease.status))
  end
  test.phase="first-junior-real-item-at-ghost"
  test.first_junior_transit_tick=game.tick
  emit("PASS REVERSAL_ENGINE_FIRST_JUNIOR_TRANSIT tick="..game.tick..
    " rebuilt_intermediate="..intermediate.station.unit_number..
    " original_intermediate_priest="..test.pair_priest_units[3]..
    " original_junior_priest="..test.pair_priest_units[4]..
    " child_writ="..child.id..
    " held=1 source=0 second_depot=1 distance_sq="..
      string.format("%.3f",d2)..
    " ghost_unit="..owned.unit_number..
    " original_priest_staged=true")
end

-- 0936: only actual native station creation from the one physical first-
-- Junior 0824 cargo and exact 0823 original #4 priest claim can complete this
-- stage. Its second-Junior 0851 depot stays separately counted and usable.
local function reversal_engine_first_junior_build(state)
  local test=state.reversal_engine
  if not(test and test.phase=="first-junior-real-item-at-ghost") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local step=root and root.reversal_junior_0919
  local child=step and tp.station_expansion_0256[step.child_writ_id]
  local follow=child and child.reversal_junior_0919
  local intermediate=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[3]]
  local original=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[4]]
  local stage=root and root.reversal_stage_0853
  local second_stage=root and root.reversal_stage_0851
  local source=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  -- 0942: Lua 'and' discards additional return values. Retain the
  -- independently audited depot reason alongside its physical inventory.
  local second,second_why
  if second_stage then
    second,second_why=REVERSAL_DEPOT_0852.get_staged(magos,second_stage)
  end
  local cargo=child and tp.station_cargo_0824 and tp.station_cargo_0824[child.id]
  if game.tick-(test.first_junior_transit_tick or game.tick)>12000 then
    error("REVERSAL_ENGINE_FIRST_JUNIOR_BUILD_TIMEOUT:"..
      " phase="..tostring(child and child.phase)..
      " child_status="..tostring(child and child.status)..
      " build_authorized="..tostring(follow and follow.build_authorized_tick)..
      " carrier="..tostring(cargo and cargo.status)..
      " second_why="..tostring(second_why))
  end
  if not(child and child.status=="complete") then return end
  local built=original and original.station
  local d2=built and built.valid and child.ghost_position and
    (built.position.x-child.ghost_position.x)^2+
      (built.position.y-child.ghost_position.y)^2 or math.huge
  local count=source and source.inventory and source.inventory.valid
    and source.inventory.get_item_count("junior-cogitator-station")
  local second_count=second and second.inventory and second.inventory.valid
    and second.inventory.get_item_count("junior-cogitator-station")
  local total=0
  if built and built.valid then
    for _,entity in pairs(built.surface.find_entities_filtered{
        name="junior-cogitator-station",
        position=child.ghost_position,radius=1.5}) do
      if entity.valid and entity.position and
          (entity.position.x-child.ghost_position.x)^2+
          (entity.position.y-child.ghost_position.y)^2<=0.01 then
        total=total+1
      end
    end
  end
  local ghost_absent=true
  if intermediate and intermediate.station and intermediate.station.valid
      and child and child.ghost_position then
    for _,entity in pairs(intermediate.station.surface.find_entities_filtered{
        name="entity-ghost",position=child.ghost_position,radius=1}) do
      if entity.valid and entity.unit_number==child.ghost_unit then
        ghost_absent=false
      end
    end
  end
  local second_lease=second_stage and tp.station_relocation_0823
    and tp.station_relocation_0823[second_stage.leaf_station_unit]
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not(root and root.status=="complete"
      and step and step.status=="ghost-reserved"
      and step.child_writ_id==child.id and step.ghost_unit==child.ghost_unit
      and child and child.status=="complete"
      and child.station_item=="junior-cogitator-station"
      and child.worker_station_unit==intermediate.station.unit_number
      and child.requester_station_unit==intermediate.station.unit_number
      and child.relocation_old_station_unit_0823==test.units[4]
      and follow and follow.root_writ_id==root.id
      and follow.stage_id==stage.id
      and follow.original_priest==test.pair_priest_units[4]
      and follow.original_intermediate_priest==test.pair_priest_units[3]
      and type(follow.arrived_tick)=="number"
      and type(follow.build_authorized_tick)=="number"
      and follow.build_authorized_tick>=follow.arrived_tick+120
      and follow.build_authorized_tick<=game.tick
      and follow.build_ghost_unit==child.ghost_unit
      and intermediate and intermediate.priest and intermediate.priest.valid
      and intermediate.priest.unit_number==test.pair_priest_units[3]
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[4]
      and built and built.valid and built.name==child.station_item
      and built.unit_number~=test.units[4]
      and built.force==intermediate.station.force
      and built.surface==intermediate.station.surface
      and d2<0.01 and total==1 and ghost_absent
      and original.relocation_pending_0823==nil
      and tp.pairs_by_station[built.unit_number]==original
      and tp.pairs_by_station[test.units[4]]==nil
      and tp.station_by_priest[test.pair_priest_units[4]]==built.unit_number
      and tp.station_expansion_by_worker_0256
      and not tp.station_expansion_by_worker_0256[intermediate.station.unit_number]
      and not(tp.station_cargo_0824 and tp.station_cargo_0824[child.id])
      and source and source.status=="outbound" and count==0
      and second and second_count==1
      and second.inventory~=source.inventory
      and second_why=="depot-stored-physical-item-verified"
      and second_lease and second_lease.status=="staged"
      and second_lease.priest_unit==test.pair_priest_units[5]
      and tp.station_relocation_0823
      and tp.station_relocation_0823[stage.leaf_station_unit]==nil
      and stage.leaf_priest_unit==test.pair_priest_units[4]
      and stage.leaf_station_unit==test.units[4]
      and h and type(h.is_direct_subordinate)=="function"
      and h.is_direct_subordinate(intermediate,original)==true) then
    error("REVERSAL_ENGINE_FIRST_JUNIOR_BUILD_IDENTITY_OR_CUSTODY_INVALID:"..
      " phase="..tostring(child and child.phase)..
      " built="..tostring(built and built.unit_number)..
      " old="..tostring(test.units[4])..
      " priest="..tostring(original and original.priest
        and original.priest.unit_number)..
      " source="..tostring(count)..
      " cargo="..tostring(cargo and cargo.status)..
      " second="..tostring(second_count)..
      " second_why="..tostring(second_why)..
      " distance_sq="..tostring(d2)..
      " hierarchy="..tostring(h and h.is_direct_subordinate
        and h.is_direct_subordinate(intermediate,original)))
  end
  test.phase="first-junior-real-station-built"
  test.first_junior_build_tick=game.tick
  emit("PASS REVERSAL_ENGINE_FIRST_JUNIOR_BUILD tick="..game.tick..
    " rebuilt_intermediate="..intermediate.station.unit_number..
    " original_intermediate_priest="..test.pair_priest_units[3]..
    " original_junior_priest="..test.pair_priest_units[4]..
    " child_writ="..child.id..
    " rebuilt_junior="..built.unit_number..
    " original_junior_station="..test.units[4]..
    " source=0 carrier=0 second_depot=1 distance_sq="..
      string.format("%.3f",d2)..
    " ghost=0 hierarchy=intermediate-to-original-junior")
end


-- 0943: the second peer is only a REAL engine ghost, not a constructed
-- station or delivered ore. Its own item remains in the distinct 0851 depot.
local function reversal_engine_second_junior_ghost(state)
  local test=state.reversal_engine
  if not(test and test.phase=="first-junior-real-station-built") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local step=root and root.reversal_second_junior_0943
  if game.tick-(test.first_junior_build_tick or game.tick)>15000 then
    error("REVERSAL_ENGINE_SECOND_JUNIOR_GHOST_TIMEOUT:"..
      tostring(root and root.reversal_second_junior_0943_last_reason))
  end
  if not(step and step.status=="ghost-reserved") then return end
  local child=tp.station_expansion_0256[step.child_writ_id]
  local first_stage=root.reversal_stage_0853
  local second_stage=root.reversal_stage_0851
  local first=tp.pairs_by_priest[test.pair_priest_units[4]]
  local original=tp.pairs_by_priest[test.pair_priest_units[5]]
  local lease=tp.station_relocation_0823
    and tp.station_relocation_0823[second_stage.leaf_station_unit]
  local source=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[first_stage.id]
  local depot,why=REVERSAL_DEPOT_0852.get_staged(magos,second_stage)
  local ghost=child and first and first.station and first.station.valid
    and first.station.surface.find_entity("entity-ghost",child.ghost_position)
  local radius=first and first.radius or 0
  local target=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
    and magos.resource_expansion_0259.chain_0820.target
  local d2=ghost and first and first.station
    and (ghost.position.x-first.station.position.x)^2+
      (ghost.position.y-first.station.position.y)^2 or math.huge
  if not(child and child.status=="active"
      and child.reversal_second_junior_0943
      and child.reversal_second_junior_0943.root_writ_id==root.id
      and child.reversal_second_junior_0943.stage_id==second_stage.id
      and child.reversal_second_junior_0943.original_priest
        ==test.pair_priest_units[5]
      and child.worker_station_unit==first.station.unit_number
      and child.requester_station_unit==first.station.unit_number
      and child.requester_rank==1 and child.required_worker_rank==1
      and child.station_item=="junior-cogitator-station"
      and child.ghost_unit==step.ghost_unit
      and ghost and ghost.valid and ghost.unit_number==child.ghost_unit
      and ghost.name=="entity-ghost"
      and ghost.ghost_name=="junior-cogitator-station"
      and ghost.force==first.station.force
      and ghost.surface==first.station.surface
      and d2<=radius*radius and d2>0
      and target and
        (ghost.position.x-target.x)^2+(ghost.position.y-target.y)^2
          <(first.station.position.x-target.x)^2+
            (first.station.position.y-target.y)^2
      and first.priest.unit_number==test.pair_priest_units[4]
      and first.station.unit_number~=test.units[4]
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[5]
      and lease and lease.status=="staged"
      and lease.priest==original.priest
      and source and source.inventory and source.inventory.valid
      and source.inventory.get_item_count("junior-cogitator-station")==0
      and depot and depot.inventory and depot.inventory.valid
      and depot.inventory~=source.inventory
      and depot.inventory.get_item_count("junior-cogitator-station")==1
      and why=="depot-stored-physical-item-verified"
      and not(tp.station_cargo_0824 and tp.station_cargo_0824[child.id])) then
    error("REVERSAL_ENGINE_SECOND_JUNIOR_GHOST_CUSTODY_INVALID:"..
      " child="..tostring(child and child.id)..
      " second_depot="..tostring(depot and depot.inventory and
        depot.inventory.get_item_count("junior-cogitator-station"))..
      " reason="..tostring(why)..
      " distance_sq="..tostring(d2))
  end
  test.phase="second-junior-real-ghost-reserved"
  test.second_junior_ghost_tick=game.tick
  emit("PASS REVERSAL_ENGINE_SECOND_JUNIOR_GHOST tick="..game.tick..
    " original_first_priest="..test.pair_priest_units[4]..
    " original_second_priest="..test.pair_priest_units[5]..
    " child_writ="..child.id..
    " ghost_unit="..ghost.unit_number..
    " first_depot=0 second_depot=1 original_second_staged=true")
end

-- 0944: the second original Junior station item must physically leave
-- its independent Magos depot into the rebuilt first Junior's real hold.
local function reversal_engine_second_junior_pickup(state)
  local test=state.reversal_engine
  if not(test and test.phase=="second-junior-real-ghost-reserved") then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station and tp.pairs_by_station[test.units[1]]
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local step=root and root.reversal_second_junior_0943
  local child=step and tp.station_expansion_0256[step.child_writ_id]
  local first=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[4]]
  local original=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[5]]
  local stage=root and root.reversal_stage_0851
  local first_stage=root and root.reversal_stage_0853
  local first_depot=first_stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[first_stage.id]
  local second_depot=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local cargo=child and tp.station_cargo_0824
    and tp.station_cargo_0824[child.id]
  local lease=stage and tp.station_relocation_0823
    and tp.station_relocation_0823[stage.leaf_station_unit]
  if game.tick-(test.second_junior_ghost_tick or game.tick)>15000 then
    error("REVERSAL_ENGINE_SECOND_JUNIOR_PICKUP_TIMEOUT:"..
      tostring(root and root.reversal_second_junior_0944_last_reason)..
      ":depot="..tostring(second_depot and second_depot.inventory
        and second_depot.inventory.get_item_count("junior-cogitator-station"))..
      ":carrier="..tostring(cargo and cargo.inventory
        and cargo.inventory.get_item_count("junior-cogitator-station"))..
      ":worker_mode="..tostring(first and first.mode))
  end
  if not(cargo and cargo.status=="carrying") then return end
  -- The worker may already be walking toward the ghost when this periodic
  -- observer sees the real hold. Check the position captured at the actual
  -- physical depot debit, never the worker's later position.
  local pickup=child and child.reversal_second_junior_0943
  local pickup_d2=pickup and pickup.picked_distance_sq_0944
  local current_d2=first and first.priest and magos and magos.station
    and (first.priest.position.x-magos.station.position.x)^2+
      (first.priest.position.y-magos.station.position.y)^2 or math.huge
  if not(child and child.status=="active"
      and child.reversal_second_junior_0943
      and child.reversal_second_junior_0943.root_writ_id==root.id
      and child.reversal_second_junior_0943.stage_id==stage.id
      and child.reversal_second_junior_0943.original_priest
        ==test.pair_priest_units[5]
      and child.reversal_second_junior_0943.original_first_junior_priest
        ==test.pair_priest_units[4]
      and step.status=="ghost-reserved"
      and first and first.station and first.station.valid
      and first.priest and first.priest.valid
      and first.priest.unit_number==test.pair_priest_units[4]
      and first.station.unit_number~=test.units[4]
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[5]
      and lease and lease.status=="staged"
      and lease.priest==original.priest
      and first_depot and first_depot.status=="outbound"
      and first_depot.inventory and first_depot.inventory.valid
      and first_depot.inventory.get_item_count("junior-cogitator-station")==0
      and second_depot and second_depot.status=="outbound"
      and second_depot.inventory and second_depot.inventory.valid
      and second_depot.inventory~=first_depot.inventory
      and second_depot.inventory.get_item_count("junior-cogitator-station")==0
      and cargo.inventory and cargo.inventory.valid
      and cargo.inventory~=first_depot.inventory
      and cargo.inventory~=second_depot.inventory
      and cargo.inventory.get_item_count("junior-cogitator-station")==1
      and cargo.priest_unit==first.priest.unit_number
      and cargo.station_unit==first.station.unit_number
      and type(pickup_d2)=="number" and pickup_d2>=0
      and pickup_d2<=25
      and pickup.picked_station_unit_0944==magos.station.unit_number
      and pickup.picked_priest_unit_0944==first.priest.unit_number
      and type(child.reversal_second_junior_0943.picked_tick)=="number"
      -- The production 0944 escrow begins at actual ghost creation,
      -- not the later periodic acceptance observer's discovery tick.
      and type(step.created_tick)=="number"
      and type(pickup.picked_tick)=="number"
      and pickup.picked_tick>=step.created_tick+120
      and pickup.picked_tick<=game.tick
      and step.created_tick<=test.second_junior_ghost_tick) then
    error("REVERSAL_ENGINE_SECOND_JUNIOR_PICKUP_CUSTODY_INVALID:"..
      " first_depot="..tostring(first_depot and first_depot.inventory
        and first_depot.inventory.get_item_count("junior-cogitator-station"))..
      " second_depot="..tostring(second_depot and second_depot.inventory
        and second_depot.inventory.get_item_count("junior-cogitator-station"))..
      " held="..tostring(cargo.inventory and
        cargo.inventory.get_item_count("junior-cogitator-station"))..
      " pickup_distance_sq="..tostring(pickup_d2)..
      " current_distance_sq="..tostring(current_d2)..
      " created_tick="..tostring(step and step.created_tick)..
      " observed_ghost_tick="..tostring(test.second_junior_ghost_tick)..
      " picked_tick="..tostring(pickup and pickup.picked_tick)..
      " child_status="..tostring(child and child.status)..
      " step_status="..tostring(step and step.status)..
      " lease_status="..tostring(lease and lease.status)..
      " cargo_priest="..tostring(cargo and cargo.priest_unit)..
      " cargo_station="..tostring(cargo and cargo.station_unit)..
      " first_station="..tostring(first and first.station and first.station.unit_number))
  end
  test.phase="second-junior-real-item-picked-up"
  test.second_junior_pickup_tick=game.tick
  emit("PASS REVERSAL_ENGINE_SECOND_JUNIOR_PICKUP tick="..game.tick..
    " original_first_priest="..test.pair_priest_units[4]..
    " original_second_priest="..test.pair_priest_units[5]..
    " child_writ="..child.id..
    " first_depot=0 second_depot=0 carrier=1 distance_sq="..
      string.format("%.3f",pickup_d2)..
    " original_second_staged=true")
end


-- 0947: after real Magos pickup, the original first Junior must physically
-- carry the SAME engine-owned item to the original peer ghost. A mere nearby
-- position, unissued command, changed priest or vanished depot is not proof.
local function reversal_engine_second_junior_transit(state)
  local test=state.reversal_engine
  if not(test and test.phase=="second-junior-real-item-picked-up") then return end
  local tp=storage and storage.tech_priests
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local step=root and root.reversal_second_junior_0943
  local child=step and tp.station_expansion_0256[step.child_writ_id]
  local follow=child and child.reversal_second_junior_0943
  local first=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[4]]
  local original=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[5]]
  local stage=root and root.reversal_stage_0851
  local first_stage=root and root.reversal_stage_0853
  local first_depot=first_stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[first_stage.id]
  local second_depot=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local cargo=child and tp.station_cargo_0824
    and tp.station_cargo_0824[child.id]
  local lease=stage and tp.station_relocation_0823
    and tp.station_relocation_0823[stage.leaf_station_unit]
  if game.tick-(test.second_junior_pickup_tick or game.tick)>15000 then
    error("REVERSAL_ENGINE_SECOND_JUNIOR_TRANSIT_TIMEOUT:"..
      tostring(root and root.reversal_second_junior_0944_last_reason)..
      ":status="..tostring(follow and follow.transit_status)..
      ":worker_mode="..tostring(first and first.mode))
  end
  if not(follow and follow.transit_status=="arrived") then return end
  local ghost=child and first and first.station and first.station.valid
    and first.station.surface.find_entity("entity-ghost",child.ghost_position)
  local d2=ghost and first and first.priest
    and (first.priest.position.x-ghost.position.x)^2+
      (first.priest.position.y-ghost.position.y)^2 or math.huge
  if not(child and child.status=="active"
      and step and step.status=="ghost-reserved"
      and step.child_writ_id==child.id and step.ghost_unit==child.ghost_unit
      and follow.root_writ_id==root.id and follow.stage_id==stage.id
      and follow.original_priest==test.pair_priest_units[5]
      and follow.original_first_junior_priest==test.pair_priest_units[4]
      and first and first.station and first.station.valid
      and first.priest and first.priest.valid
      and first.priest.unit_number==test.pair_priest_units[4]
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[5]
      and lease and lease.status=="staged" and lease.priest==original.priest
      and ghost and ghost.valid and ghost.unit_number==child.ghost_unit
      and ghost.name=="entity-ghost"
      and ghost.ghost_name=="junior-cogitator-station"
      and ghost.force==first.station.force
      and ghost.surface==first.station.surface
      and d2<=25
      and first_depot and first_depot.status=="outbound"
      and first_depot.inventory and first_depot.inventory.valid
      and first_depot.inventory.get_item_count("junior-cogitator-station")==0
      and second_depot and second_depot.status=="outbound"
      and second_depot.inventory and second_depot.inventory.valid
      and second_depot.inventory~=first_depot.inventory
      and second_depot.inventory.get_item_count("junior-cogitator-station")==0
      and cargo and cargo.status=="carrying"
      and cargo.inventory and cargo.inventory.valid
      and cargo.inventory~=first_depot.inventory
      and cargo.inventory~=second_depot.inventory
      and cargo.inventory.get_item_count("junior-cogitator-station")==1
      and cargo.priest_unit==first.priest.unit_number
      and cargo.station_unit==first.station.unit_number
      and type(follow.picked_tick)=="number"
      -- A periodic observer discovers the real debit later. The pickup
      -- must precede observation and follow actual ghost-creation escrow.
      and type(test.second_junior_pickup_tick)=="number"
      and follow.picked_tick<=test.second_junior_pickup_tick
      and type(step.created_tick)=="number"
      and follow.picked_tick>=step.created_tick+120
      and type(follow.transit_started_tick)=="number"
      and type(follow.transit_last_command_tick)=="number"
      and type(follow.arrived_tick)=="number"
      and follow.transit_started_tick>=follow.picked_tick+120
      and follow.transit_last_command_tick>=follow.transit_started_tick
      and follow.arrived_tick>=follow.transit_last_command_tick
      and follow.arrived_tick>=follow.picked_tick+120
      and game.tick>=follow.arrived_tick
      and follow.arrived_tick-follow.transit_started_tick<=7200
      and not child.relocation_old_station_unit_0823) then
    error("REVERSAL_ENGINE_SECOND_JUNIOR_TRANSIT_CUSTODY_INVALID:"..
      " first_depot="..tostring(first_depot and first_depot.inventory
        and first_depot.inventory.get_item_count("junior-cogitator-station"))..
      " second_depot="..tostring(second_depot and second_depot.inventory
        and second_depot.inventory.get_item_count("junior-cogitator-station"))..
      " held="..tostring(cargo and cargo.inventory and
        cargo.inventory.get_item_count("junior-cogitator-station"))..
      " distance_sq="..tostring(d2)..
      " created_tick="..tostring(step and step.created_tick)..
      " pickup_tick="..tostring(follow and follow.picked_tick)..
      " observed_pickup_tick="..tostring(test.second_junior_pickup_tick)..
      " transit_started="..tostring(follow and follow.transit_started_tick)..
      " transit_command="..tostring(follow and follow.transit_last_command_tick)..
      " arrived_tick="..tostring(follow and follow.arrived_tick)..
      " transit_status="..tostring(follow and follow.transit_status)..
      " child_status="..tostring(child and child.status)..
      " lease_status="..tostring(lease and lease.status)..
      " ghost_unit="..tostring(ghost and ghost.unit_number)..
      " cargo_priest="..tostring(cargo and cargo.priest_unit)..
      " cargo_station="..tostring(cargo and cargo.station_unit))
  end
  test.phase="second-junior-real-item-at-ghost"
  test.second_junior_transit_tick=game.tick
  emit("PASS REVERSAL_ENGINE_SECOND_JUNIOR_TRANSIT tick="..game.tick..
    " original_first_priest="..test.pair_priest_units[4]..
    " original_second_priest="..test.pair_priest_units[5]..
    " child_writ="..child.id.." ghost_unit="..ghost.unit_number..
    " first_depot=0 second_depot=0 carrier=1 distance_sq="..
      string.format("%.3f",d2)..
    " original_second_staged=true command_issued=true")
end

-- 0948: after the same carried station item reaches the original peer
-- ghost, native 0256 must debit that real 0824 hold, construct exactly one
-- physical Junior, and reattach the original living #5 priest via 0823.
-- A ghost, nearby station or lease alone cannot pass this gate.
local function reversal_engine_second_junior_build(state)
  local test=state.reversal_engine
  if not(test and test.phase=="second-junior-real-item-at-ghost") then return end
  local tp=storage and storage.tech_priests
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[test.writ_id]
  local step=root and root.reversal_second_junior_0943
  local child=step and tp.station_expansion_0256[step.child_writ_id]
  local follow=child and child.reversal_second_junior_0943
  local first=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[4]]
  local original=tp and tp.pairs_by_priest
    and tp.pairs_by_priest[test.pair_priest_units[5]]
  local stage=root and root.reversal_stage_0851
  local first_stage=root and root.reversal_stage_0853
  local first_depot=first_stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[first_stage.id]
  local second_depot=stage and tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local cargo=child and tp.station_cargo_0824
    and tp.station_cargo_0824[child.id]
  if game.tick-(test.second_junior_transit_tick or game.tick)>15000 then
    error("REVERSAL_ENGINE_SECOND_JUNIOR_BUILD_TIMEOUT:"..
      " phase="..tostring(child and child.phase)..
      " status="..tostring(child and child.status)..
      " authorized="..tostring(follow and follow.build_authorized_tick)..
      " cargo="..tostring(cargo and cargo.status))
  end
  if not(child and child.status=="complete") then return end
  local built=original and original.station
  local d2=built and built.valid and child.ghost_position and
    (built.position.x-child.ghost_position.x)^2+
      (built.position.y-child.ghost_position.y)^2 or math.huge
  local first_count=first_depot and first_depot.inventory
    and first_depot.inventory.valid and first_depot.inventory.get_item_count(
      "junior-cogitator-station")
  local second_count=second_depot and second_depot.inventory
    and second_depot.inventory.valid and second_depot.inventory.get_item_count(
      "junior-cogitator-station")
  local built_count=0
  local ghost_absent=true
  if first and first.station and first.station.valid and child then
    for _,entity in pairs(first.station.surface.find_entities_filtered{
        name="junior-cogitator-station",
        position=child.ghost_position,radius=1.5}) do
      if entity.valid and entity.position and
          (entity.position.x-child.ghost_position.x)^2+
          (entity.position.y-child.ghost_position.y)^2<=0.01 then
        built_count=built_count+1
      end
    end
    for _,entity in pairs(first.station.surface.find_entities_filtered{
        name="entity-ghost",position=child.ghost_position,radius=1}) do
      if entity.valid and entity.unit_number==child.ghost_unit then
        ghost_absent=false
      end
    end
  end
  local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local peer=false
  if hierarchy and type(hierarchy.peers)=="function" and first then
    for _,candidate in ipairs(hierarchy.peers(first) or {}) do
      if candidate==original then peer=true;break end
    end
  end
  if not(root and root.status=="complete"
      and step and step.status=="ghost-reserved"
      and step.child_writ_id==child.id and step.ghost_unit==child.ghost_unit
      and child and child.status=="complete"
      and child.station_item=="junior-cogitator-station"
      and first and first.station and first.station.valid
      and first.priest and first.priest.valid
      and first.priest.unit_number==test.pair_priest_units[4]
      and child.worker_station_unit==first.station.unit_number
      and child.requester_station_unit==first.station.unit_number
      and child.relocation_old_station_unit_0823==test.units[5]
      and follow and follow.root_writ_id==root.id
      and follow.stage_id==stage.id
      and follow.original_first_junior_priest==test.pair_priest_units[4]
      and follow.original_priest==test.pair_priest_units[5]
      and type(follow.arrived_tick)=="number"
      and type(follow.build_authorized_tick)=="number"
      and follow.build_authorized_tick>=follow.arrived_tick+120
      and follow.build_authorized_tick<=game.tick
      and follow.build_ghost_unit==child.ghost_unit
      and original and original.priest and original.priest.valid
      and original.priest.unit_number==test.pair_priest_units[5]
      and built and built.valid and built.name==child.station_item
      and built.unit_number~=test.units[5]
      and built.force==first.station.force
      and built.surface==first.station.surface
      and d2<0.01 and built_count==1 and ghost_absent
      and original.relocation_pending_0823==nil
      and tp.pairs_by_station[built.unit_number]==original
      and tp.pairs_by_station[test.units[5]]==nil
      and tp.station_by_priest[test.pair_priest_units[5]]==built.unit_number
      and tp.station_expansion_by_worker_0256
      and not tp.station_expansion_by_worker_0256[first.station.unit_number]
      and not cargo
      and first_depot and first_depot.status=="outbound"
      and second_depot and second_depot.status=="outbound"
      and first_depot.inventory~=second_depot.inventory
      and first_count==0 and second_count==0
      and not(tp.station_relocation_0823
        and tp.station_relocation_0823[stage.leaf_station_unit])
      and peer) then
    error("REVERSAL_ENGINE_SECOND_JUNIOR_BUILD_IDENTITY_OR_CUSTODY_INVALID:"..
      " phase="..tostring(child and child.phase)..
      " built="..tostring(built and built.unit_number)..
      " old="..tostring(test.units[5])..
      " first_depot="..tostring(first_count)..
      " second_depot="..tostring(second_count)..
      " carrier="..tostring(cargo and cargo.status)..
      " peer="..tostring(peer)..
      " distance_sq="..tostring(d2))
  end
  test.phase="second-junior-real-station-built"
  test.second_junior_build_tick=game.tick
  emit("PASS REVERSAL_ENGINE_SECOND_JUNIOR_BUILD tick="..game.tick..
    " original_first_priest="..test.pair_priest_units[4]..
    " original_second_priest="..test.pair_priest_units[5]..
    " child_writ="..child.id..
    " rebuilt_second_junior="..built.unit_number..
    " original_second_station="..test.units[5]..
    " first_depot=0 second_depot=0 carrier=0 distance_sq="..
      string.format("%.3f",d2)..
    " ghost=0 hierarchy=original-junior-peer")
end

-- 0949: the SAME physically reconstructed five-station chain must mine
-- naturally generated ore and return one counted item through four actual
-- inventory hops to its original Magos. The existing 0820 and 0837 production
-- authorities own route verification, physical mining, movement and custody.
local function reversal_engine_natural_ore_return(state)
  local test=state.reversal_engine
  if not(test and (test.phase=="second-junior-real-station-built"
      or test.phase=="reversal-natural-ore-courier")) then return end
  local tp=storage and storage.tech_priests
  local magos=tp and tp.pairs_by_station
    and tp.pairs_by_station[test.units[1]]
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(magos and magos.station and magos.station.valid
      and magos.priest and magos.priest.valid
      and magos.priest.unit_number==test.pair_priest_units[1]
      and mission and mission.need=="iron-ore"
      and ORE_ENGINE_CHAIN and ORE_ENGINE_COURIER) then
    error("REVERSAL_ENGINE_ORE_ORIGINAL_MAGOS_OR_AUTHORITY_LOST")
  end
  if game.tick-(test.second_junior_build_tick or game.tick)>30000 then
    local courier=mission.return_courier_0837
    error("REVERSAL_ENGINE_NATURAL_ORE_RETURN_TIMEOUT:"..
      " mission="..tostring(mission.status)..
      " reason="..tostring(mission.last_reason)..
      " courier="..tostring(courier and courier.phase)..
      " courier_reason="..tostring(courier and courier.last_reason))
  end
  local function patch_amount()
    local p=test.natural_ore
    local amount=0
    for _,ore in pairs(magos.station.surface.find_entities_filtered{
        name="iron-ore",type="resource",
        area={{p.x-4,p.y-4},{p.x+4,p.y+4}}}) do
      if ore.valid then amount=amount+ore.amount end
    end
    return amount
  end
  local function magos_ore()
    local get=rawget(_G,"get_station_inventory")
    local inv=get and get(magos.station)
    if not(inv and inv.valid) then
      error("REVERSAL_ENGINE_MAGOS_REAL_ORE_INVENTORY_UNAVAILABLE")
    end
    return inv.get_item_count("iron-ore")
  end
  if test.phase=="second-junior-real-station-built" then
    local ok,reason=ORE_ENGINE_CHAIN.service_pair(magos)
    if mission.status~="reached-resource" then
      if game.tick-(test.last_ore_route_trace_tick or 0)>=600 then
        test.last_ore_route_trace_tick=game.tick
        local writ=tp.station_expansion_0256
          and tp.station_expansion_0256[mission.pending_expansion_id]
        emit("REVERSAL_ENGINE_ORE_ROUTE_WAIT tick="..game.tick..
          " reason="..tostring(reason)..
          " mission="..tostring(mission.status)..
          " mission_reason="..tostring(mission.last_reason)..
          " pending="..tostring(mission.pending_expansion_id)..
          " writ_status="..tostring(writ and writ.status)..
          " reversal_plan="..tostring(writ and writ.reversal_plan_0850~=nil))
      end
      return
    end
    local route,why=ORE_ENGINE_CHAIN.return_route(magos)
    if not(route and #route==5
        and route[5]==test.units[1]
        and mission.segments==4 and mission.pending_expansion_id==nil
        and mission.current_station_unit==route[1]) then
      error("REVERSAL_ENGINE_REBUILT_ROUTE_NOT_PHYSICAL:"..tostring(why))
    end
    local expected={1,2,3,4,5}
    local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
    for i=1,5 do
      local pair=tp.pairs_by_priest[test.pair_priest_units[i]]
      if not(pair and pair.station and pair.station.valid
          and pair.priest and pair.priest.valid
          and pair.priest.unit_number==test.pair_priest_units[i]
          and pair.station.unit_number==route[6-i]
          and h and h.rank(pair)==math.max(1,5-i)) then
        error("REVERSAL_ENGINE_ORE_ORIGINAL_PRIEST_ROUTE_CHANGED:"..i)
      end
    end
    test.reversal_ore_before=patch_amount()
    test.reversal_magos_before=magos_ore()
    if test.reversal_ore_before<1 then
      error("REVERSAL_ENGINE_NATURAL_ORE_DEPLETED_BEFORE_COURIER")
    end
    test.phase="reversal-natural-ore-courier"
    test.ore_route_verified_tick=game.tick
    emit("PASS REVERSAL_ENGINE_REBUILT_ORE_ROUTE tick="..game.tick..
      " magos="..route[5].." senior="..route[4]..
      " intermediate="..route[3].." junior="..route[2]..
      " peer="..route[1]..
      " original_priests=5 empty_recovery_depots=4"..
      " natural_ore_before="..test.reversal_ore_before..
      " magos_ore_before="..test.reversal_magos_before)
  end
  -- 1061: another autonomous priest can mine the SAME natural patch
  -- during the four-hop return. The earlier end-of-route patch == -1
  -- assertion confused that independent real mining with a forged courier.
  -- Instead require the courier's synchronous native mine to consume
  -- EXACTLY one world resource and produce exactly one engine-owned item.
  -- Keep all subsequent physical hop/receipt and Magos count gates.
  local patch_before_service=patch_amount()
  local ok,reason=ORE_ENGINE_COURIER.service(magos)
  local courier=mission.return_courier_0837
  if reason=="physical-ore-mined" then
    local patch_after_service=patch_amount()
    local held=courier and courier.inventory and courier.inventory.valid
      and courier.inventory.get_item_count("iron-ore")
    if test.reversal_atomic_mine_tick
        or patch_before_service-patch_after_service~=1
        or held~=1 or not courier or courier.quantity~=1
        or courier.source_kind_0991~="natural-ore"
        or type(courier.ore_amount_before)~="number"
        or courier.ore_amount_before<1 then
      error("REVERSAL_ENGINE_ATOMIC_NATURAL_MINE_INVALID:"..
        " before="..tostring(patch_before_service)..
        " after="..tostring(patch_after_service)..
        " held="..tostring(held))
    end
    test.reversal_atomic_mine_tick=game.tick
    test.reversal_atomic_patch_before=patch_before_service
    test.reversal_atomic_patch_after=patch_after_service
    emit("REVERSAL_ENGINE_ATOMIC_NATURAL_MINE tick="..game.tick..
      " patch_before="..patch_before_service..
      " patch_after="..patch_after_service..
      " held=1 source=natural-ore native_mine=true")
  end
  if game.tick-(test.last_ore_return_trace_tick or 0)>=600 then
    test.last_ore_return_trace_tick=game.tick
    local source=courier and storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[courier.source_station_unit]
    local request=source and source.movement_request_0418
    local priest=source and source.priest
    local relay=courier and courier.pending_upstream_station_unit
      and tp.pairs_by_station[courier.pending_upstream_station_unit]
    local relay_move=relay and relay.movement_request_0418
    local relay_recipe=relay and relay.infrastructure_recipe_request_0647
    -- 1039: report the canonical order owner's exact refusal rather than
    -- inferring idleness from a task alias or a missing movement lease.
    local pause_ok,pause_reason=false,"no-relay-plan"
    if relay and relay_recipe then
      local queue_owner=ORE_ENGINE_ORDER_QUEUE
      if queue_owner
          and type(queue_owner.can_pause_uncommitted_relay_0974)=="function" then
        local probed,eligible,why=pcall(
          queue_owner.can_pause_uncommitted_relay_0974,relay,relay_recipe)
        if probed then
          pause_ok,pause_reason=eligible,why
        else
          pause_reason="owner-probe-error"
        end
      else
        pause_reason="order-owner-unavailable"
      end
    end
    local family_task=relay and relay.item_family_logistics_0702
    local family_owner=rawget(_G,"TechPriestsItemFamilyLogistics0702")
    local family_ok,family_why=false,"family-owner-unavailable"
    if relay and family_owner
        and type(family_owner.can_yield_waiting_source_1042)=="function" then
      local probed,ok,why=pcall(family_owner.can_yield_waiting_source_1042,relay)
      if probed then family_ok,family_why=ok,why
      else family_why="family-probe-error" end
    end
    emit("REVERSAL_ENGINE_ORE_RETURN_PROGRESS tick="..game.tick..
      " phase="..tostring(courier and courier.phase)..
      " hop="..tostring(courier and courier.hops_completed)..
      " reason="..tostring(reason)..
      " priest_x="..tostring(priest and priest.valid and priest.position.x)..
      " priest_y="..tostring(priest and priest.valid and priest.position.y)..
      " station_x="..tostring(source and source.station
        and source.station.valid and source.station.position.x)..
      " movement_owner="..tostring(request and request.owner)..
      " movement_reason="..tostring(request and request.reason)..
      " movement_priority="..tostring(request and request.priority)..
      " movement_goal_x="..tostring(request and
        (request.ground_route_final_destination or request).x)..
      " movement_goal_y="..tostring(request and
        (request.ground_route_final_destination or request).y)..
      " waypoint_x="..tostring(request and request.x)..
      " waypoint_y="..tostring(request and request.y)..
      " ore_x="..tostring(mission.target and mission.target.x)..
      " ore_y="..tostring(mission.target and mission.target.y)..
      " station_y="..tostring(source and source.station
        and source.station.valid and source.station.position.y)..
      " last_command_tick="..tostring(request and request.last_command_tick)..
      " last_motion_tick="..tostring(request and request.recovery_last_motion_tick)..
      " recovery_blocker="..tostring(request and request.last_recovery_blocker)..
      " movement_state="..tostring(source
        and source.movement_controller_state_0418)..
      " movement_clamp="..tostring(source
        and source.movement_controller_clamp_0418)..
      " relay_unit="..tostring(relay and relay.station and relay.station.unit_number)..
      " relay_mode="..tostring(relay and relay.mode)..
      " relay_distance_sq="..tostring(relay and relay.priest
        and relay.priest.valid and relay.station and relay.station.valid
        and ((relay.priest.position.x-relay.station.position.x)^2+
          (relay.priest.position.y-relay.station.position.y)^2))..
      " relay_active_task="..tostring(relay and relay.active_task~=nil)..
      " relay_task_alias="..tostring(relay and relay.active_task~=nil
        and relay.active_task==relay.active_task_0285)..
      " relay_order_task_alias="..tostring(relay and relay.active_task~=nil
        and relay.order_queue_0469 and relay.order_queue_0469.current
        and relay.active_task==relay.order_queue_0469.current.task)..
      " relay_task_type="..tostring(relay and relay.active_task
        and relay.active_task.type)..
      " relay_task_item="..tostring(relay and relay.active_task
        and (relay.active_task.item or relay.active_task.item_name))..
      " relay_assignment_status="..tostring(relay and relay.active_task
        and relay.active_task.assignment and relay.active_task.assignment.status)..
      " relay_supply_source_type="..tostring(relay and relay.active_supply_request
        and type(relay.active_supply_request.source))..
      " relay_supply_source="..tostring(relay and relay.active_supply_request
        and relay.active_supply_request.source)..
      " relay_supply_target_unit="..tostring(relay and relay.active_supply_request
        and relay.active_supply_request.target_unit)..
      " relay_family_phase="..tostring(family_task and family_task.phase)..
      " relay_family_item="..tostring(family_task and family_task.item)..
      " relay_family_source="..tostring(family_task and family_task.source_entity~=nil)..
      " relay_family_cargo="..tostring(family_task and family_task.carried~=nil)..
      " relay_family_custody="..tostring(relay and relay.item_family_custody_0702~=nil)..
      " relay_family_yield="..tostring(family_ok)..
      " relay_family_yield_reason="..tostring(family_why)..
      " relay_logistic_requester="..tostring(relay and relay.logistic_requester
        and relay.logistic_requester.valid)..
      " relay_logistic_return_cache="..tostring(relay and relay.logistic_return_cache
        and relay.logistic_return_cache.valid)..
      " relay_cram="..tostring(relay and relay.cram~=nil)..
      " relay_scavenge="..tostring(relay and relay.scavenge~=nil)..
      " relay_supply_target="..tostring(relay and relay.active_supply_request
        and relay.active_supply_request.target~=nil)..
      " relay_inventory_scan="..tostring(relay and relay.inventory_scan~=nil)..
      " relay_emergency_craft="..tostring(relay and relay.emergency_craft~=nil)..
      " relay_task_source_type="..tostring(relay and relay.active_task
        and type(relay.active_task.source))..
      " relay_task_source_valid="..tostring(relay and relay.active_task
        and type(relay.active_task.source)=="table"
        and relay.active_task.source.valid)..
      " relay_task_position="..tostring(relay and relay.active_task
        and relay.active_task.position~=nil)..
      " relay_task_destination="..tostring(relay and relay.active_task
        and relay.active_task.destination~=nil)..
      " relay_order_pause_eligible="..tostring(pause_ok)..
      " relay_order_pause_reason="..tostring(pause_reason)..
      " relay_task_target="..tostring(relay and relay.active_task
        and relay.active_task.target~=nil)..
      " relay_direct_task="..tostring(relay
        and relay.direct_acquisition_task_0336~=nil)..
      " relay_current_task="..tostring(relay and relay.current_task~=nil)..
      " relay_recipe_item="..tostring(relay_recipe and relay_recipe.item)..
      " relay_recipe_missing="..tostring(relay_recipe and relay_recipe.missing)..
      " relay_handoff_refusal="..tostring(courier and courier.last_upstream_handoff_reason)..
      " relay_order_kind="..tostring(relay and relay.order_queue_0469
        and relay.order_queue_0469.current and relay.order_queue_0469.current.kind)..
      " relay_order_source="..tostring(relay and relay.order_queue_0469
        and relay.order_queue_0469.current and relay.order_queue_0469.current.source)..
      " relay_order_item="..tostring(relay and relay.order_queue_0469
        and relay.order_queue_0469.current and relay.order_queue_0469.current.item)..
      " relay_order_status="..tostring(relay and relay.order_queue_0469
        and relay.order_queue_0469.current and relay.order_queue_0469.current.status)..
      " relay_requested="..tostring(relay and relay.requested_item)..
      " relay_logistic_requested="..tostring(relay and relay.logistic_requested_item)..
      " relay_gate_item="..tostring(relay and relay.local_infrastructure_gate_0640
        and relay.local_infrastructure_gate_0640.item)..
      " relay_movement_status="..tostring(relay and relay.movement_controller_status_0418)..
      " relay_move_owner="..tostring(relay_move and relay_move.owner)..
      " relay_move_expires="..tostring(relay_move and relay_move.expires_tick)..
      " relay_combat="..tostring(relay and relay.combat_target~=nil)..
      " relay_construction="..tostring(relay and relay.construction_task~=nil)..
      " relay_direct_custody="..tostring(relay and relay.direct_acquisition_custody_0513~=nil)..
      " relay_expansion_status="..tostring(relay and relay.station_expansion_0256
        and relay.station_expansion_0256.status))
  end
  if not(courier and courier.phase=="magos-delivered") then return end
  local route=ORE_ENGINE_CHAIN.return_route(magos)
  if not(route and #route==5
      and courier.item=="iron-ore" and courier.quantity==1
      and courier.hops_completed==4 and courier.receipt_hop==4
      and courier.delivered_station_unit==test.units[1]
      and courier.receipt_destination_after
        ==courier.receipt_destination_before+1
      and mission.delivered_to_magos_count==1
      and magos_ore()==test.reversal_magos_before+1
      and type(test.reversal_atomic_mine_tick)=="number"
      and test.reversal_atomic_mine_tick>=test.ore_route_verified_tick
      and test.reversal_atomic_mine_tick<game.tick
      and test.reversal_atomic_patch_before<=test.reversal_ore_before
      and test.reversal_atomic_patch_before-test.reversal_atomic_patch_after==1
      and patch_amount()<=test.reversal_atomic_patch_after) then
    error("REVERSAL_ENGINE_NATURAL_ORE_CUSTODY_OR_COUNT_INVALID:"..
      " hop="..tostring(courier.hops_completed)..
      " magos="..tostring(magos_ore())..
      " ore_before="..tostring(test.reversal_ore_before)..
      " ore_after="..tostring(patch_amount()))
  end
  -- Audit all four original carriers and their adjacent rebuilt stations
  -- against persistent 0982 receipts before accepting Magos delivery.
  local receipts=courier.receipts_0982
  if not(receipts and #receipts==4
      and ORE_ENGINE_COURIER.validate_receipts_0982(courier,route)) then
    error("REVERSAL_ENGINE_FOUR_PHYSICAL_RECEIPTS_UNVERIFIED")
  end
  for i=1,4 do
    local r=receipts[i]
    if not(r and r.source_station_unit==route[i]
        and r.destination_station_unit==route[i+1]
        and r.carrier_priest_unit==test.pair_priest_units[6-i]
        and r.destination_after==r.destination_before+1) then
      error("REVERSAL_ENGINE_PHYSICAL_RECEIPT_IDENTITY_INVALID:"..i)
    end
  end
  test.phase="reversal-natural-ore-return-complete"
  test.reversal_ore_return_tick=game.tick
  emit("PASS REVERSAL_ENGINE_NATURAL_ORE_RETURN tick="..game.tick..
    " original_magos="..test.units[1]..
    " original_priests=5 physical_hops=4"..
    " courier_natural_ore_delta=-1"..
    " patch_ore_before="..test.reversal_ore_before..
    " patch_ore_after="..patch_amount()..
    " independent_patch_depletion="..
      (test.reversal_ore_before-patch_amount()-1)..
    " magos_inventory_delta=1"..
    " delivered_count=1 cargo_empty=true")
end

-- 1071: Observe actual paired-priest population in the native reversal
-- window. This is a read-only count of live, unique physical pairs across
-- all forces, NOT a five-priest-only scenario or a license to spawn units.
local function ci_live_paired_priest_population_1071()
  local tp=storage and storage.tech_priests
  local seen,total={},0
  for station_unit,pair in pairs(tp and tp.pairs_by_station or {}) do
    local station=pair and pair.station
    local priest=pair and pair.priest
    if station and station.valid and station.unit_number==station_unit
        and priest and priest.valid and priest.unit_number
        and not seen[priest.unit_number] then
      seen[priest.unit_number]=true
      total=total+1
    end
  end
  return total
end

-- CI-only read-only cumulative counters. The reversal runs among other
-- priests: these are mixed-population metrics, never per-priest or script time.
local function ci_activity_counters_1067()
  local tp=storage and storage.tech_priests or {}
  local broker=tp.runtime_tick_broker_0600 or {}
  local ext=broker.external_stats or {}
  local movement=tp.movement_controller_0419 or {}
  local ms=movement.stats or {}
  local processed,blocked=0,0
  for _,service in pairs(broker.service_stats or {}) do
    processed=processed+(tonumber(service.processed) or 0)
    blocked=blocked+(tonumber(service.blocked) or 0)
  end
  return {
    routed_scans=tonumber(ext.scans_attempted) or 0,
    direct_scans=tonumber(ext.direct_surface_scans) or 0,
    movement_requests=tonumber(ext.path_requests) or 0,
    movement_collapses=tonumber(ext.path_requests_collapsed) or 0,
    movement_priority_denials=tonumber(ms.lower_priority_retargets_denied) or 0,
    movement_stalled_repaths=tonumber(ms.stalled_repaths) or 0,
    broker_processed=processed,
    broker_blocked=blocked,
  }
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
    -- Iron and fuel are legitimate secondary support: if they were moved
    -- to the REAL depot earlier in this pass to free a defense slot,
    -- they still count as owned stock and must not be minted again.
    local support=(item=="iron-plate" or item=="coal")
    local already_staged=support and depot
      and depot_inventory().get_item_count(item) or 0
    local required=math.max(0,target-before-already_staged)
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
        -- Four mandatory military commodities must remain in reachable
        -- station inventory. Iron and coal are secondary support: transfer
        -- their ACTUAL stacks to the nearby real depot, even at their floor,
        -- when the narrow station inventory needs a defense slot.
        local support=(name=="iron-plate" or name=="coal")
        local transferable=support and quantity
          or math.max(0,quantity-(floor[name] or 0))
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
    local present=inventory.get_item_count(item)
    if support and depot then
      present=present+depot_inventory().get_item_count(item)
    end
    if inserted+staged~=required or present<target then
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
       last_observed_repair_packs_1100=tonumber(pair.repair_0516
         and pair.repair_0516.packs_used) or 0,
       confirmed_repair_packs_1100=0,
       confirmed_wall_heal_1100=0,
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
    local pair=storage and storage.tech_priests
      and storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[record.station_unit]
    local current_packs=tonumber(pair and pair.repair_0516
      and pair.repair_0516.packs_used) or 0
    local previous_packs=tonumber(record.last_observed_repair_packs_1100)
      or current_packs
    local new_physical_packs=math.max(0,current_packs-previous_packs)
    local same_wall_heal=0
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
        -- Compare the same genuine engine wall unit after a real tick.
        -- Replacement walls cannot provide this observation.
        if type(hist.health)=="number" and health>hist.health+0.001 then
          same_wall_heal=same_wall_heal+(health-hist.health)
        end
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
    -- 0516 pack debit and same-wall healing must be observed in the same
    -- interval. Source mocks and preexisting ammunition do not satisfy it.
    if new_physical_packs>0 and same_wall_heal>0 then
      record.confirmed_repair_packs_1100=
        (record.confirmed_repair_packs_1100 or 0)+new_physical_packs
      record.confirmed_wall_heal_1100=
        (record.confirmed_wall_heal_1100 or 0)+same_wall_heal
      emit("COMBAT_SAME_WALL_PHYSICAL_REPAIR_1100 rank="..name..
        " tick="..game.tick..
        " counted_0516_packs="..new_physical_packs..
        " original_wall_health_restored="..same_wall_heal..
        " total_packs="..record.confirmed_repair_packs_1100..
        " total_healed="..record.confirmed_wall_heal_1100)
    end
    record.last_observed_repair_packs_1100=current_packs
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

-- 1092: THIRD and deliberately larger real biter assault against the
-- same autonomous defenses. The original waves are 3 + 3 per rank;
-- this escalation attempts six additional genuine small biters per rank.
-- No weapon, oil, electricity, ammo, damage, or repairs are manufactured.
local function combat_escalation_wave_1092(state)
  if state.escalation_started_tick_1092 then return end
  for _,name in ipairs(COMBAT_TARGETS)do
    local record=state.combat_sites and state.combat_sites[name]
    local station=combat_station(name)
    if not(record and station and station.valid
      and state.reassault_started_tick)then
      error("COMBAT_ESCALATION_1092_EARLIER_WAVE_NOT_ESTABLISHED:"..name)
    end
    record.escalation_units_1092={}
    record.escalation_engagements_1092=0
    record.escalation_enemy_deaths_1092=0
    -- 1128: a tracked native death is a one-time physical event, regardless
    -- of which actual attacker caused it. Do not double count event replay.
    record.escalation_dead_units_1128={}
    record.escalation_spawn_refusals_1092=0
    for i=1,6 do
      local index=(i-1)%#record.physical_attack_target_positions+1
      local origin=record.physical_attack_target_positions[index]
      local wall=record.physical_attack_targets[index]
      -- Target the same REAL purchased wall if it survives, or the actual
      -- threatened station if previous biters physically destroyed it.
      local target=wall and wall.valid and wall or station
      local distance=2.5+math.floor((i-1)/3)*3
      local offsets={0,2,-2,4,-4}
      local spawned=nil
      for _,offset in ipairs(offsets)do
        local pos={x=origin.x+distance*record.attack_dx
            -offset*record.attack_dy,
          y=origin.y+distance*record.attack_dy
            +offset*record.attack_dx}
        local can=station.surface.can_place_entity{
          name="small-biter",position=pos,force=game.forces.enemy}
        if can then
          spawned=station.surface.create_entity{
            name="small-biter",position=pos,force=game.forces.enemy}
          if spawned and spawned.valid then
            command_biter_attack(spawned,target)
            break
          end
        end
      end
      if spawned and spawned.valid then
        record.escalation_units_1092[#record.escalation_units_1092+1]=
          spawned.unit_number
      else
        record.escalation_spawn_refusals_1092=
          record.escalation_spawn_refusals_1092+1
      end
    end
    emit("COMBAT_ESCALATION_1092_START rank="..name..
      " tick="..game.tick..
      " prior_assaults=2 requested_biters=6"..
      " actual_biters="..#record.escalation_units_1092..
      " geometry_refusals="..record.escalation_spawn_refusals_1092..
      " physical_targets=true no_script_damage=true")
  end
  state.escalation_started_tick_1092=game.tick
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
    -- Mixed-tier native audit: installed entities are not counted as
    -- fighting readiness unless their OWN real ammo, electrical energy, or
    -- accepted oil is present. Pure diagnostics, never a construction receipt.
    local observed_layer,layer=false,nil
    if COMBAT_LAYER_AUDIT_1091
        and type(COMBAT_LAYER_AUDIT_1091.inspect)=="function"then
      observed_layer,layer=pcall(COMBAT_LAYER_AUDIT_1091.inspect,
        station.surface,station.force,station.position,
        math.min(96,operating+8),pair)
    end
    if observed_layer and layer then
      -- Compare only the SAME live physical unit numbers across checkpoints.
      -- A newly placed/replaced turret or wall is not credited as resupply
      -- or repair of its predecessor.
      local previous=record.layer_snapshot_1091 or {}
      local ammo_added,wall_health_restored=0,0
      for unit,rounds in pairs(layer.gun_rounds_by_unit or {})do
        local old=previous.gun_rounds_by_unit
          and previous.gun_rounds_by_unit[unit]
        if type(old)=="number" and rounds>old then
          ammo_added=ammo_added+(rounds-old)
        end
      end
      for unit,health in pairs(layer.wall_health_by_unit or {})do
        local old=previous.wall_health_by_unit
          and previous.wall_health_by_unit[unit]
        if type(old)=="number" and health>old then
          wall_health_restored=wall_health_restored+(health-old)
        end
      end
      local actual_oil_refilled,actual_oil_consumed=0,0
      local same_laser_grid_operational=0
      for unit,volume in pairs(layer.flame_oil_by_unit or {})do
        local before=previous.flame_oil_by_unit
          and previous.flame_oil_by_unit[unit]
        local before_name=previous.flame_fluid_by_unit
          and previous.flame_fluid_by_unit[unit]
        local now_name=layer.flame_fluid_by_unit
          and layer.flame_fluid_by_unit[unit]
        -- Different fluids, newly built turrets and absent prior samples
        -- cannot support a continuous oil-delivery claim.
        if type(before)=="number" and before_name==now_name
          and now_name~="empty" then
          if volume>before+0.0001 then
            actual_oil_refilled=actual_oil_refilled+(volume-before)
          elseif volume<before-0.0001 then
            actual_oil_consumed=actual_oil_consumed+(before-volume)
          end
        end
      end
      for unit,energy in pairs(layer.laser_energy_by_unit or {})do
        local prior_energy=previous.laser_energy_by_unit
          and previous.laser_energy_by_unit[unit]
        local before_grid=previous.laser_grid_by_unit
          and previous.laser_grid_by_unit[unit]
        local current_grid=layer.laser_grid_by_unit
          and layer.laser_grid_by_unit[unit]
        local earlier_live=previous.laser_operational_by_unit
          and previous.laser_operational_by_unit[unit]
        local now_live=layer.laser_operational_by_unit
          and layer.laser_operational_by_unit[unit]
        if earlier_live==true and now_live==true
          and type(prior_energy)=="number" and prior_energy>0
          and energy>0 and type(before_grid)=="number"
          and before_grid>0 and before_grid==current_grid then
          same_laser_grid_operational=same_laser_grid_operational+1
        end
      end
      record.defense_fluid_refilled_1097=
        (record.defense_fluid_refilled_1097 or 0)+actual_oil_refilled
      record.defense_fluid_consumed_1097=
        (record.defense_fluid_consumed_1097 or 0)+actual_oil_consumed
      emit("COMBAT_LAYER_SUPPLY_CONTINUITY_1097 rank="..name..
        " tick="..game.tick..
        " same_flame_refilled="..tostring(actual_oil_refilled)..
        " cumulative_oil_refilled="..
          tostring(record.defense_fluid_refilled_1097)..
        " same_flame_consumed="..tostring(actual_oil_consumed)..
        " cumulative_oil_consumed="..
          tostring(record.defense_fluid_consumed_1097)..
        " same_laser_grid_present_both_samples="..
          tostring(same_laser_grid_operational))
      record.defense_magazines_restored_1091=
        (record.defense_magazines_restored_1091 or 0)+ammo_added
      record.defense_wall_health_restored_1091=
        (record.defense_wall_health_restored_1091 or 0)+wall_health_restored
      -- The canonical 0516 repair executor, not this observer, owns the
      -- repair-pack debit and health mutation. Attribute observed healing
      -- to the same priest only when its real 0516 pack count has risen.
      -- Other possible repair routes remain visibly "unattributed", not
      -- misreported as proof of physical 0516 pack custody.
      local pack_total=tonumber(pair.repair_0516
        and pair.repair_0516.packs_used) or 0
      local previous_total=tonumber(previous.repair_packs_used_0516)
        or pack_total
      local pack_delta=math.max(0,pack_total-previous_total)
      record.defense_repair_packs_applied_1096=
        (record.defense_repair_packs_applied_1096 or 0)+pack_delta
      record.layer_snapshot_1091={
        gun_rounds_by_unit=layer.gun_rounds_by_unit,
        wall_health_by_unit=layer.wall_health_by_unit,
        repair_packs_used_0516=pack_total,
        flame_oil_by_unit=layer.flame_oil_by_unit,
        flame_fluid_by_unit=layer.flame_fluid_by_unit,
        laser_energy_by_unit=layer.laser_energy_by_unit,
        laser_grid_by_unit=layer.laser_grid_by_unit,
        laser_operational_by_unit=layer.laser_operational_by_unit}
      emit("COMBAT_CANONICAL_REPAIR_PACKS_1096 rank="..name..
        " tick="..game.tick..
        " priest_packs_delta="..pack_delta..
        " priest_packs_total="..pack_total..
        " same_wall_health_restored="..wall_health_restored..
        " matching_period_pack_activity="..
          tostring(pack_delta>0 and wall_health_restored>0)..
        " health_increase_without_0516_pack="..
          tostring(wall_health_restored>0 and pack_delta==0))
      emit("COMBAT_LAYER_REPAIR_RESUPPLY_1091 rank="..name..
        " tick="..game.tick..
        " real_same_turret_round_increase="..tostring(ammo_added)..
        " cumulative_rearmed_rounds="..
          tostring(record.defense_magazines_restored_1091)..
        " same_wall_health_increase="..tostring(wall_health_restored)..
        " cumulative_wall_health_repaired="..
          tostring(record.defense_wall_health_restored_1091))
      emit("COMBAT_LAYER_AUDIT_1091 rank="..name..
        " tick="..game.tick..
        " gun="..tostring(layer.guns)..
        " loaded_guns="..tostring(layer.loaded_guns)..
        " magazines="..tostring(layer.gun_rounds)..
        " lasers="..tostring(layer.lasers)..
        " powered_lasers="..tostring(layer.energized_lasers)..
        " flamethrowers="..tostring(layer.flames)..
        " fueled_flamethrowers="..tostring(layer.fueled_flames)..
        " canonical_pipe_and_buffer_ready_0716="..
          tostring(layer.canonical_flames_ready_0716)..
        " canonical_pipe_disconnected_0716="..
          tostring(layer.canonical_flames_unconnected_0716)..
        " canonical_readiness_unknown_0716="..
          tostring(layer.canonical_flames_unknown_0716)..
        " oil="..tostring(layer.flamethrower_fuel)..
        " walls="..tostring(layer.walls)..
        " damaged_walls="..tostring(layer.damaged_walls)..
        " scan_truncated="..tostring(layer.truncated))
    else
      emit("COMBAT_LAYER_AUDIT_1091_UNAVAILABLE rank="..name..
        " tick="..game.tick..
        " reason="..tostring(layer))
    end
    -- Real native 3-wave tests proved gunfire but no same-wall healing in
    -- the previous run. Probe the existing 0517 selection without dispatching
    -- a task; 0516 remains the sole repair-pack and health-write owner.
    local doctrine=rawget(_G,"TechPriestsCombatRepairDoctrine0517")
    local action,action_error
    if doctrine and type(doctrine.recommend_action)=="function"then
      local ok,chosen=pcall(doctrine.recommend_action,pair)
      if ok then action=chosen else action_error=tostring(chosen) end
    end
    local combat_repair=pair.combat_repair_0517 or {}
    local physical_repair=pair.repair_0516 or {}
    -- Original physically purchased walls can be much farther from the
    -- priest than the local 0517 scan. Report each wall's real health,
    -- distance and production doctrine's refusal reason at checkpoints.
    local station_inventory=station.get_inventory(defines.inventory.chest)
    for _,wall in ipairs(record.physical_attack_targets or {}) do
      if wall and wall.valid then
        local accepted,context
        if doctrine and type(doctrine.inspect_wall_eligibility)=="function" then
          local ok,a,b=pcall(doctrine.inspect_wall_eligibility,pair,wall)
          if ok then accepted,context=a,b
          else context="probe-error:"..tostring(a) end
        end
        local dx=wall.position.x-pair.priest.position.x
        local dy=wall.position.y-pair.priest.position.y
        emit("COMBAT_WALL_REPAIR_ELIGIBILITY_1102 rank="..name..
          " tick="..game.tick..
          " wall_unit="..tostring(wall.unit_number)..
          " health="..tostring(wall.health)..
          " max="..tostring(wall.max_health)..
          " priest_distance="..tostring(math.sqrt(dx*dx+dy*dy))..
          " station_radius="..tostring(pair.radius or pair.base_radius)..
          " repair_stock="..tostring(station_inventory and
            station_inventory.get_item_count("repair-pack") or 0)..
          " accepted="..tostring(accepted)..
          " reason="..tostring(type(context)=="table"
            and ("cover="..tostring(context.covered)..
              ",incident="..tostring(context.hostile_incident_id))
            or context))
      end
    end
    emit("COMBAT_REPAIR_DIAG_1098 rank="..name..
      " tick="..game.tick..
      " doctrine_loaded="..tostring(doctrine~=nil)..
      " candidate="..tostring(action and action.kind)..
      " candidate_wall="..tostring(action and action.target
        and action.target.unit_number)..
      " probe_error="..tostring(action_error)..
      " tactical_phase="..tostring(combat_repair.phase)..
      " tactical_blocker="..tostring(combat_repair.last_blocker)..
      " repair_phase="..tostring(physical_repair.phase)..
      " repair_blocker="..tostring(physical_repair.last_blocker)..
      " physical_packs_applied="..tostring(physical_repair.packs_used)..
      " custody_held="..
        tostring(pair.repair_pack_custody_0516~=nil))
    emit("COMBAT_ESCALATION_1092_OBSERVE rank="..name..
      " tick="..game.tick..
      " third_wave_started="..tostring(state.escalation_started_tick_1092~=nil)..
      " actual_biters="..tostring(#(record.escalation_units_1092 or {}))..
      " defender_engagements="..tostring(record.escalation_engagements_1092 or 0)..
      " enemy_deaths="..tostring(record.escalation_enemy_deaths_1092 or 0)..
      " spawn_refusals="..tostring(record.escalation_spawn_refusals_1092 or 0))
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
    -- Escalated biter damage is an objective functional gate. A scheduled
    -- third-wave timer, spawned unit record, or a mere gun placement must NOT
    -- count as successful defense unless real Factorio weapon damage lands.
    if not state.escalation_started_tick_1092 then
      error("COMBAT_ESCALATION_1092_NOT_SPAWNED")
    end
    for _,name in ipairs(COMBAT_TARGETS)do
      local record=state.combat_sites and state.combat_sites[name]
      local enemies=record and record.escalation_units_1092 or {}
      if #enemies~=6 or (record.escalation_spawn_refusals_1092 or 0)~=0 then
        error("COMBAT_ESCALATION_1092_PHYSICAL_SPAWN_INCOMPLETE: "..name..
          " physical="..tostring(#enemies)..
          " blocked="..tostring(record and record.escalation_spawn_refusals_1092))
      end
      if (record.escalation_engagements_1092 or 0)<1 then
        error("COMBAT_ESCALATION_1092_NO_REAL_TURRET_DAMAGE: "..name)
      end
      emit("PASS COMBAT_ESCALATION_1092_NATIVE_HITS rank="..name..
        " biter_wave=6 real_turret_hits="..
          tostring(record.escalation_engagements_1092)..
        " deaths="..tostring(record.escalation_enemy_deaths_1092 or 0))
    end
    -- A live 0516 pack debit and increase in the SAME real attacked wall
    -- health are objective functional requirements at both rank fixtures.
    for _,name in ipairs(COMBAT_TARGETS) do
      local record=state.combat_sites and state.combat_sites[name]
      local packs=record and (record.confirmed_repair_packs_1100 or 0) or 0
      local restored=record and (record.confirmed_wall_heal_1100 or 0) or 0
      if packs<1 or restored<=0 then
        error("COMBAT_NO_SAME_WALL_PHYSICAL_REPAIR_1100 rank="..name..
          " counted_packs="..packs..
          " actual_health_restored="..restored..
          " engine_wall_hits="..
            tostring(record and record.observed_engine_damage or 0)..
          " wall_transitions="..
            tostring(record and record.wall_transitions or 0))
      end
      emit("PASS COMBAT_SAME_WALL_PHYSICAL_REPAIR_1100 rank="..name..
        " consumed_packs="..packs..
        " restored_health="..restored..
        " wall_identity_preserved=true")
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
    for _,unit_number in ipairs(record.escalation_units_1092 or {}) do
      if victim.unit_number==unit_number then
        -- 1128: the former second loop was unreachable: the first returned
        -- on EVERY matching enemy death, leaving enemy_deaths permanently 0.
        -- Count only this real Factorio death event, once per actual unit;
        -- separately attribute a turret kill only when its native attacker
        -- is a friendly real gun, laser or flamethrower turret.
        record.escalation_dead_units_1128=
          record.escalation_dead_units_1128 or {}
        if record.escalation_dead_units_1128[unit_number] then return end
        record.escalation_dead_units_1128[unit_number]=true
        record.escalation_enemy_deaths_1092=
          (record.escalation_enemy_deaths_1092 or 0)+1
        local attacker=(event.cause and event.cause.valid and event.cause)
          or (event.source and event.source.valid and event.source)
        if attacker and attacker.force==game.forces.player
          and (attacker.name=="gun-turret"
            or attacker.name=="laser-turret"
            or attacker.name=="flamethrower-turret")then
          record.escalation_engagements_1092=
            (record.escalation_engagements_1092 or 0)+1
          if record.escalation_engagements_1092<=6 then
            emit("COMBAT_ESCALATION_1092_DEFENDER_HIT rank="..name..
              " tick="..game.tick..
              " defender="..attacker.name..
              " enemy="..unit_number..
              " observed_native_kill=true")
          end
        end
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
-- Unit tests exercise the same read-only native death observer used by the
-- live CI event route, with mocked event delivery rather than fake combat.
M.test_combat_biter_died=combat_biter_died


-- S2 / 1071: real Factorio construction-robot event and physical network
-- inventory are the ONLY proof of a robot-built Senior. This separate CI
-- surface is created in the fifth engine process; it does not change the
-- 123k industrial/combat fixture or grant production construction authority.
local ROBOT_ENGINE_S2_SURFACE_1071="tp-ci-robot-network-1071"
local ROBOT_ENGINE_S2_ITEM_1071="senior-cogitator-station"
local ROBOT_ENGINE_S2_TARGET_1071={x=42,y=0}
local ROBOT_ENGINE_S2_CONTROL_TARGET_1074={x=38,y=12}
local ROBOT_FRONTIER_REMOTE_SITE_1111={x=64,y=0}
local ROBOT_FRONTIER_REMOTE_ITEM_1111="intermediate-cogitator-station"
local function robot_engine_s2_built_observe_1071(event)
  local state=storage and storage.tech_priests
    and storage.tech_priests.ci_ground_rank_test
  local test=state and state.robot_engine_s2_1071
  local entity=event.entity or event.created_entity
  local robot=event.robot
  -- The SAME canonical native robot event must prove the second ranked
  -- outpost. A scripted station entity or a completed ghost is insufficient.
  local remote=state and state.robot_frontier_native_1080
  if remote and not remote.remote_complete_1111 and entity and entity.valid
    and robot and robot.valid
    and entity.surface.name==ROBOT_ENGINE_S2_SURFACE_1071
    and entity.name==ROBOT_FRONTIER_REMOTE_ITEM_1111
    and math.abs(entity.position.x-ROBOT_FRONTIER_REMOTE_SITE_1111.x)<0.6
    and math.abs(entity.position.y-ROBOT_FRONTIER_REMOTE_SITE_1111.y)<0.6 then
    if remote.remote_robot_event_unit_1111 then
      error("ROBOT_FRONTIER_1111_DUPLICATE_NATIVE_ROBOT_BUILD")
    end
    remote.remote_robot_event_unit_1111=robot.unit_number
    remote.remote_robot_event_station_1111=entity.unit_number
    remote.remote_robot_event_tick_1111=game.tick
    emit("ROBOT_FRONTIER_1111_NATIVE_ROBOT_EVENT tick="..game.tick..
      " robot="..robot.unit_number.." station="..entity.unit_number)
  end
  if not(test and test.phase~="complete") then return end
  if entity and entity.valid
      and entity.surface.name==ROBOT_ENGINE_S2_SURFACE_1071 then
    test.robot_events_on_surface_1073=
      (test.robot_events_on_surface_1073 or 0)+1
    if entity.name=="steel-chest"
      and math.abs(entity.position.x-ROBOT_ENGINE_S2_CONTROL_TARGET_1074.x)<0.6
      and math.abs(entity.position.y-ROBOT_ENGINE_S2_CONTROL_TARGET_1074.y)<0.6
      and robot and robot.valid then
      test.control_robot_event_1074=game.tick
      test.control_robot_unit_1074=robot.unit_number
      emit("ROBOT_ENGINE_S2_CONTROL_ROBOT_EVENT_1074 tick="..game.tick..
        " robot="..tostring(robot.unit_number)..
        " station="..tostring(entity.unit_number)..
        " baseline=vanilla-steel-chest")
    end
  end
  if not(entity and entity.valid and robot and robot.valid
    and entity.surface.name==ROBOT_ENGINE_S2_SURFACE_1071
    and entity.name==ROBOT_ENGINE_S2_ITEM_1071) then return end
  if test.robot_event_station then
    error("ROBOT_ENGINE_S2_DUPLICATE_ROBOT_BUILD_EVENT")
  end
  test.robot_event_station=entity.unit_number
  test.robot_event_unit=robot.unit_number
  test.robot_event_tick=game.tick
  emit("ROBOT_ENGINE_S2_NATIVE_ROBOT_EVENT tick="..game.tick..
    " station="..tostring(entity.unit_number)..
    " robot="..tostring(robot.unit_number))
end
-- Reserve the explicit Method II strategy before the automatic 0259
-- discovery cadence can start a competing physical station-recycling writ.
-- The original 1076 executor must WAIT until the genuine robot-built Senior
-- and physically mined supplies exist; no station, ore or item is granted.
local function reserve_robot_frontier_intent_1122(pair)
  if not(pair and pair.station and pair.station.valid) then return end
  local old=pair.roboport_expansion_goal_1076
  if old then
    if old.root_station_unit~=pair.station.unit_number then
      error("ROBOT_FRONTIER_1122_FOREIGN_GOAL_ALREADY_OWNED")
    end
    return
  end
  pair.roboport_expansion_goal_1076={
    target={x=94,y=0},root_station_unit=pair.station.unit_number,
    surface_index=pair.station.surface.index,
    force_index=pair.station.force.index,
    remote_station_item_1076=ROBOT_FRONTIER_REMOTE_ITEM_1111,
    remote_station_position_1076={
      x=ROBOT_FRONTIER_REMOTE_SITE_1111.x,
      y=ROBOT_FRONTIER_REMOTE_SITE_1111.y},
    activation_pending_1076=true}
end
local function robot_engine_s2_place_1071(state)
  if state.robot_engine_s2_1071 then return end
  local settings=game.surfaces[1].map_gen_settings
  settings.seed=1071002
  settings.autoplace_controls=settings.autoplace_controls or {}
  settings.autoplace_controls["enemy-base"]={frequency=0,size=0,richness=0}
  -- 1121: fixed seed 1071002 had no natural iron inside the remote
  -- Intermediate's connected logistics coverage. Select a bounded seed
  -- before constructing anything, using only Factorio-generated resource
  -- entities outside the x<=66 cleared fixture corridor and away from the
  -- x-axis power/roboport build path. Never spawn, move or credit ore.
  local search=state.robot_engine_s2_seed_search_1121
  if not search then
    search={offset=0,awaiting_delete=false}
    state.robot_engine_s2_seed_search_1121=search
  end
  -- Factorio queues surface deletion for a future tick. Never reuse the
  -- canonical name until the engine actually removes the rejected surface.
  if search.awaiting_delete then
    if game.surfaces[ROBOT_ENGINE_S2_SURFACE_1071] then
      if game.tick-(search.delete_tick or game.tick)>600 then
        error("ROBOT_FRONTIER_1121_REJECTED_SURFACE_DELETE_TIMEOUT")
      end
      return
    end
    search.awaiting_delete=false
  end
  if game.surfaces[ROBOT_ENGINE_S2_SURFACE_1071] then
    error("ROBOT_FRONTIER_1121_UNOWNED_EXISTING_SURFACE")
  end
  if search.offset>=64 then
    error("ROBOT_FRONTIER_1121_NO_GENERATED_IRON_SEED_IN_64_ATTEMPTS")
  end
  local surface,selected_seed,selected_ore
  settings.seed=1071002+search.offset
  local candidate=game.create_surface(ROBOT_ENGINE_S2_SURFACE_1071,settings)
    if not(candidate and candidate.valid) then
      error("ROBOT_FRONTIER_1121_NATIVE_SURFACE_CREATION_FAILED")
    end
    candidate.request_to_generate_chunks({x=25,y=12},3)
    candidate.force_generate_chunk_requests()
    local ores=candidate.find_entities_filtered{
      name="iron-ore",type="resource",area={{70,-21},{102,21}}}
    for _,ore in ipairs(ores) do
      local y=math.abs(ore.position.y)
      local mineable=ore.prototype and ore.prototype.mineable_properties
      local iron_product=false
      for _,product in pairs(mineable and mineable.products or {}) do
        if product.name=="iron-ore" and product.type~="fluid" then
          iron_product=true;break
        end
      end
      if ore.valid and ore.amount>=2 and iron_product
        and y>=12 and y<=21 and ore.position.x>=70
        and ore.position.x<=101 then
        selected_ore={x=ore.position.x,y=ore.position.y}
        break
      end
    end
  if selected_ore then
    surface=candidate
    selected_seed=settings.seed
    state.robot_engine_s2_seed_search_1121=nil
  else
    if not game.delete_surface(candidate) then
      error("ROBOT_FRONTIER_1121_REJECTED_SURFACE_DELETE_REFUSED")
    end
    search.offset=search.offset+1
    search.awaiting_delete=true
    search.delete_tick=game.tick
    return
  end
  if not(surface and surface.valid and selected_seed and selected_ore) then
    error("ROBOT_FRONTIER_1121_NO_GENERATED_IRON_SEED_IN_64_ATTEMPTS")
  end
  emit("ROBOT_FRONTIER_1121_NATURAL_SEED_SELECTED tick="..game.tick..
    " seed="..selected_seed..
    " ore_x="..string.format("%.1f",selected_ore.x)..
    " ore_y="..string.format("%.1f",selected_ore.y)..
    " natural_generated=true")
  local area={{-12,-15},{66,42}}
  for _,entity in pairs(surface.find_entities_filtered{area=area}) do
    if entity.valid and (entity.type=="resource" or entity.type=="tree"
      or entity.type=="simple-entity" or entity.type=="cliff") then
      entity.destroy()
    elseif entity.valid then
      error("ROBOT_ENGINE_S2_SITE_NOT_EMPTY:"..entity.name)
    end
  end
  local tiles={}
  for x=-12,65 do for y=-15,41 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  local force=game.forces.player
  local function place(name,x,y,raise)
    local spec={name=name,position={x=x,y=y},force=force,
      raise_built=raise==true}
    if not surface.can_place_entity(spec) then
      error("ROBOT_ENGINE_S2_FIXTURE_SITE_BLOCKED:"..name..":"..x..":"..y)
    end
    local entity=surface.create_entity(spec)
    if not(entity and entity.valid) then
      error("ROBOT_ENGINE_S2_FIXTURE_ENTITY_MISSING:"..name)
    end
    return entity
  end
  -- These are real powered entities. No editor energy interface, synthetic
  -- robot, script-built target station or production stock grant is used.
  local power_source_1331=place("substation",18,8)
  place("substation",18,24)
  for _,x in ipairs({10,14,22,26}) do
    for _,y in ipairs({18,22,26,30}) do
      place("solar-panel",x,y)
    end
  end
  for _,x in ipairs({10,14,22,26}) do
    place("accumulator",x,10)
  end
  local port=place("roboport",18,0)
  local provider=place("passive-provider-chest",23,0)
  local provider_inv=provider.get_inventory(defines.inventory.chest)
  local robot_inv=port.get_inventory(defines.inventory.roboport_robot)
  if not(provider_inv and provider_inv.valid
    and robot_inv and robot_inv.valid
    and robot_inv.insert{name="construction-robot",count=3}==3) then
    error("ROBOT_ENGINE_S2_REAL_ROBOT_STOCK_UNAVAILABLE")
  end
  -- Produce the one supplied station item by mining a real temporary
  -- Senior entity directly into the actual provider chest inventory.
  -- It is fixture material, never ore-acquisition credit.
  local source=place(ROBOT_ENGINE_S2_ITEM_1071,55,25)
  local source_unit=source.unit_number
  local mined=source.mine{inventory=provider_inv}
  if not(mined and not source.valid
    and provider_inv.get_item_count(ROBOT_ENGINE_S2_ITEM_1071)==1) then
    error("ROBOT_ENGINE_S2_PHYSICAL_STATION_ITEM_MINING_FAILED")
  end
  -- A separate vanilla build control is diagnostic only. Its stock also
  -- originates in a genuinely placed and mined entity, never an item grant.
  -- Failure to prepare the control must not fail Method II or mutate its
  -- one-Senior physical accounting.
  local control_source=surface.create_entity{
    name="steel-chest",position={x=55,y=31},force=force}
  local control_ready=false
  if control_source and control_source.valid then
    local ok,mined=pcall(function()
      return control_source.mine{inventory=provider_inv}
    end)
    control_ready=ok and mined==true
      and provider_inv.get_item_count("steel-chest")==1
  end
  local magos=place("planetary-magos-cogitator-station",0,0,true)
  local registered=storage.tech_priests and storage.tech_priests.pairs_by_station
    and storage.tech_priests.pairs_by_station[magos.unit_number]
  reserve_robot_frontier_intent_1122(registered)
  state.robot_engine_s2_1071={
    phase="awaiting-powered-pair",surface=surface,magos=magos,
    port=port,provider=provider,source_unit=source_unit,
    power_source_1331=power_source_1331,
    control_ready_1074=control_ready,
    magos_unit=magos.unit_number,started_tick=game.tick}
  emit("ROBOT_ENGINE_S2_SOURCE_MINED tick="..game.tick..
    " source_unit="..tostring(source_unit)..
    " provider_unit="..provider.unit_number..
    " stock=1 physical_mine=true")
end
local function robot_engine_s2_service_1071(state)
  if not state.robot_engine_s2_1071 then
    robot_engine_s2_place_1071(state)
  end
  local test=state.robot_engine_s2_1071
  if not test then return end
  if test.phase=="complete" then return end
  if game.tick-test.started_tick>15000 then
    error("ROBOT_ENGINE_S2_TIMEOUT phase="..tostring(test.phase)..
      " robot_event="..tostring(test.robot_event_station)..
      " ghost_seen="..tostring(test.ghost_seen)..
      " last_observation={"..tostring(test.last_s2_diagnostic_1073).."}")
  end
  local tp=storage.tech_priests
  local root=tp.pairs_by_station and tp.pairs_by_station[test.magos_unit]
  local port,provider=test.port,test.provider
  if not(root and root.station==test.magos and root.priest
    and root.priest.valid and port and port.valid
    and provider and provider.valid) then return end
  if test.magos_priest and root.priest.unit_number~=test.magos_priest then
    error("ROBOT_ENGINE_S2_ORIGINAL_MAGOS_PRIEST_REPLACED")
  end
  -- Method II native negative: remove a genuine powered-network substation
  -- into an engine-owned inventory after the original Magos issues its request.
  -- A disconnected network must refuse the 0338 ghost without losing the
  -- requested item, ownership, identities, or introducing a second claim.
  -- Restore from that SAME mined substation item, not a supplied free item.
  -- 1350: sever the actual powering substation only AFTER a genuine
  -- construction robot has left the dock for the existing, original ghost.
  -- Both the ghost and the physical power-source item stay under custody
  -- through an engine-observed interruption. No second ghost or receipt.
  if test.phase=="midflight-power-cut-1350" then
    -- 1360: a sixth, independently launched Factorio process must read
    -- the SAME serialized ghost, pending 0338 task, original request and
    -- physically held substation before any power is restored. This probe
    -- does not create or debit an item, task, entity or construction receipt.
    if rawget(_G,"TP_CI_S2_MIDFLIGHT_RELOAD_PROBE")==true
        and not test.midflight_reload_passed_1360 then
      local active=root.robot_network_task_0338
      local hold=test.midflight_hold_1350
      local ghost=active and active.ghost
      local built=test.surface.find_entities_filtered{
        name=ROBOT_ENGINE_S2_ITEM_1071,
        position=ROBOT_ENGINE_S2_TARGET_1071,
        radius=1,force=root.station.force,limit=2}
      local ghosts=test.surface.find_entities_filtered{
        name="entity-ghost",position=ROBOT_ENGINE_S2_TARGET_1071,
        radius=2,force=root.station.force,limit=4}
      -- The exact engine robot observed at the power cut must survive
      -- serialization; another robot must not silently replace its custody.
      local original_robot=test.midflight_robot_1360
      if not(original_robot and original_robot.valid
        and original_robot.type=="construction-robot"
        and original_robot.unit_number==test.midflight_robot_unit_1360
        and original_robot.surface==test.surface
        and original_robot.force==root.station.force) then
        error("ROBOT_ENGINE_S2_MIDFLIGHT_RELOAD_ROBOT_LOST_1360")
      end
      if not(test.midflight_save_requested_1360
        and game.tick>=test.midflight_cut_tick_1350
        and hold and hold.valid and hold.get_item_count("substation")==1
        and test.power_source_1331 and not test.power_source_1331.valid
        and not port.is_connected_to_electric_network()
        and active and active==test.midflight_task_1350
        and active.phase=="awaiting-real-construction-robot"
        and ghost and ghost.valid and ghost==test.midflight_ghost_1350
        and #ghosts==1 and ghosts[1]==ghost and #built==0
        and root.robot_network_request_0338==test.midflight_request_1350
        and root.priest.unit_number==test.magos_priest
        and not test.robot_event_station
        and not active.robot_build_receipt_0338) then
        error("ROBOT_ENGINE_S2_MIDFLIGHT_RELOAD_CUSTODY_INVALID_1360")
      end
      test.midflight_reload_passed_1360=true
      emit("PASS ROBOT_ENGINE_S2_MIDFLIGHT_RELOAD_CUSTODY_1360 tick="..
        game.tick.." magos="..test.magos_unit..
        " priest="..test.magos_priest..
        " robot="..test.midflight_robot_unit_1360..
        " ghost=1 substation_held=1 power_disconnected=true"..
        " original_task_retained=true original_request_retained=true"..
        " built=0 native_build_event=0")
    end
    if game.tick-test.midflight_cut_tick_1350<120 then return end
    local hold=test.midflight_hold_1350
    local active=root.robot_network_task_0338
    local ghost=active and active.ghost
    local source=test.power_source_1331
    local built=test.surface.find_entities_filtered{
      name=ROBOT_ENGINE_S2_ITEM_1071,
      position=ROBOT_ENGINE_S2_TARGET_1071,
      radius=1,force=root.station.force,limit=2}
    if not(hold and hold.valid
      and hold.get_item_count("substation")==1
      and source and not source.valid
      and not port.is_connected_to_electric_network()
      and active and active==test.midflight_task_1350
      and ghost and ghost.valid
      and ghost==test.midflight_ghost_1350
      and active.phase=="awaiting-real-construction-robot"
      and root.robot_network_request_0338==test.midflight_request_1350
      and root.priest.unit_number==test.magos_priest
      and #built==0 and not test.robot_event_station
      and not active.robot_build_receipt_0338) then
      error("ROBOT_ENGINE_S2_MIDFLIGHT_POWER_CUSTODY_INVALID_1350")
    end
    local spec={name="substation",position={x=18,y=8},
      force=root.station.force}
    if not test.surface.can_place_entity(spec) then
      error("ROBOT_ENGINE_S2_MIDFLIGHT_RESTORE_SITE_BLOCKED_1350")
    end
    if hold.remove{name="substation",count=1}~=1 then
      error("ROBOT_ENGINE_S2_MIDFLIGHT_RESTORE_DEBIT_FAILED_1350")
    end
    local rebuilt=test.surface.create_entity(spec)
    if not(rebuilt and rebuilt.valid and rebuilt.name=="substation") then
      if hold.valid then hold.insert{name="substation",count=1} end
      error("ROBOT_ENGINE_S2_MIDFLIGHT_RESTORE_ENTITY_REFUSED_1350")
    end
    if hold.get_item_count("substation")~=0 then
      error("ROBOT_ENGINE_S2_MIDFLIGHT_RESTORE_ITEM_DISCREPANCY_1350")
    end
    hold.destroy()
    test.midflight_hold_1350=nil
    test.power_source_1331=rebuilt
    test.midflight_negative_passed_1350=true
    test.phase="awaiting-robot-construction"
    emit("PASS ROBOT_ENGINE_S2_NATIVE_MIDFLIGHT_POWER_RECOVERY_1350 tick="..
      game.tick.." magos="..test.magos_unit..
      " priest="..test.magos_priest..
      " ghost=1 native_build_event=0 substation_mined=1"..
      " substation_rebuilt=1 original_task_retained=true"..
      " original_request_retained=true")
    return
  end
  -- 1340: native missing-robot refusal. The same physical three robots
  -- are quarantined in a real LuaInventory for 180 simulation ticks.
  -- Neither ghost construction nor item spending may occur in that window.
  if test.phase=="robotless-request-1340" then
    if game.tick-test.robotless_cut_tick_1340<180 then return end
    local robot_inv=port.get_inventory(defines.inventory.roboport_robot)
    local hold=test.robotless_hold_1340
    local stock=provider.get_inventory(defines.inventory.chest)
    local cell_now=port.logistic_cell
    local net=cell_now and cell_now.logistic_network
    local ghosts=test.surface.find_entities_filtered{
      name="entity-ghost",position=ROBOT_ENGINE_S2_TARGET_1071,
      radius=2,force=root.station.force,limit=4}
    if not(hold and hold.valid and robot_inv and robot_inv.valid
        and stock and stock.valid and net and net.valid~=false
        and port.is_connected_to_electric_network()
        and net.available_construction_robots==0
        and net.all_construction_robots==0
        and robot_inv.get_item_count("construction-robot")==0
        and hold.get_item_count("construction-robot")==3
        and stock.get_item_count(ROBOT_ENGINE_S2_ITEM_1071)==1
        and root.robot_network_task_0338==nil
        and root.robot_network_request_0338==test.robotless_request_1340
        and root.priest.unit_number==test.magos_priest
        and #ghosts==0 and not test.robot_event_station) then
      error("ROBOT_ENGINE_S2_ROBOTLESS_REFUSAL_OR_CUSTODY_INVALID_1340")
    end
    if robot_inv.can_insert and not robot_inv.can_insert{
        name="construction-robot",count=3} then
      error("ROBOT_ENGINE_S2_ROBOT_RESTORE_INVENTORY_FULL_1340")
    end
    if hold.remove{name="construction-robot",count=3}~=3 then
      error("ROBOT_ENGINE_S2_ROBOT_RESTORE_DEBIT_FAILED_1340")
    end
    local restored=robot_inv.insert{name="construction-robot",count=3}
    if restored~=3 then
      if restored<3 then
        hold.insert{name="construction-robot",count=3-restored}
      end
      error("ROBOT_ENGINE_S2_ROBOT_RESTORE_PARTIAL_1340")
    end
    if hold.get_item_count("construction-robot")~=0
        or robot_inv.get_item_count("construction-robot")~=3 then
      error("ROBOT_ENGINE_S2_ROBOT_RESTORE_COUNT_INVALID_1340")
    end
    hold.destroy()
    test.robotless_hold_1340=nil
    test.robotless_negative_passed_1340=true
    emit("PASS ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_REFUSAL_1340 tick="..
      game.tick.." magos="..test.magos_unit..
      " priest="..test.magos_priest..
      " ghost=0 claim=0 station_stock=1 removed_robots=3 restored_robots=3"..
      " request_retained=true item_conserved=true")
    -- Following the robotless recovery, test the existing real power cut
    -- against the identical, still-unclaimed original ranked request.
    local power_hold=game.create_inventory(1)
    local source=test.power_source_1331
    if not(power_hold and power_hold.valid and source and source.valid
      and source.name=="substation"
      and source.mine{inventory=power_hold}==true
      and not source.valid
      and power_hold.get_item_count("substation")==1
      and stock.get_item_count(ROBOT_ENGINE_S2_ITEM_1071)==1) then
      error("ROBOT_ENGINE_S2_PHYSICAL_POWER_CUT_FAILED_1331")
    end
    test.power_cut_hold_1331=power_hold
    test.power_request_1331=root.robot_network_request_0338
    test.power_cut_tick_1331=game.tick
    test.phase="power-cut-before-robot-ghost-1331"
    emit("ROBOT_ENGINE_S2_NATIVE_POWER_CUT_1331 tick="..game.tick..
      " magos="..test.magos_unit..
      " priest="..test.magos_priest..
      " substation_custody=1 station_stock=1")
    return
  end
  if test.phase=="power-cut-before-robot-ghost-1331" then
    if game.tick-test.power_cut_tick_1331<180 then return end
    local real_inventory=provider.get_inventory(defines.inventory.chest)
    local hold=test.power_cut_hold_1331
    if port.is_connected_to_electric_network()
      or root.robot_network_task_0338
      or root.robot_network_request_0338~=test.power_request_1331
      or not(hold and hold.valid
        and hold.get_item_count("substation")==1)
      or not(real_inventory and real_inventory.valid
        and real_inventory.get_item_count(ROBOT_ENGINE_S2_ITEM_1071)==1)
      or root.priest.unit_number~=test.magos_priest then
      error("ROBOT_ENGINE_S2_POWER_REFUSAL_CUSTODY_INVALID_1331")
    end
    local source_position={x=18,y=8}
    local spec={name="substation",position=source_position,
      force=root.station.force}
    if not test.surface.can_place_entity(spec) then
      error("ROBOT_ENGINE_S2_POWER_RESTORE_SITE_BLOCKED_1331")
    end
    if hold.remove{name="substation",count=1}~=1 then
      error("ROBOT_ENGINE_S2_POWER_RESTORE_PHYSICAL_DEBIT_FAILED_1331")
    end
    local rebuilt=test.surface.create_entity(spec)
    if not(rebuilt and rebuilt.valid and rebuilt.name=="substation") then
      error("ROBOT_ENGINE_S2_POWER_RESTORE_ENTITY_REFUSED_1331")
    end
    if hold.get_item_count("substation")~=0 then
      error("ROBOT_ENGINE_S2_POWER_RESTORE_ITEM_DISCREPANCY_1331")
    end
    hold.destroy()
    test.power_cut_hold_1331=nil
    test.power_source_1331=rebuilt
    test.power_negative_passed_1331=true
    test.phase="awaiting-canonical-ghost"
    emit("PASS ROBOT_ENGINE_S2_NATIVE_POWER_REFUSAL_1331 tick="..game.tick..
      " magos="..test.magos_unit..
      " priest="..test.magos_priest..
      " ghost=0 stock=1 substation_mined=1 substation_rebuilt=1"..
      " request_retained=true item_conserved=true")
    return
  end
  reserve_robot_frontier_intent_1122(root)
  local inv=provider.get_inventory(defines.inventory.chest)
  local cell=port.logistic_cell
  local network=cell and cell.logistic_network
  if not(inv and inv.valid and network and network.valid~=false) then return end
  if test.phase=="awaiting-powered-pair" then
    local connected=port.is_connected_to_electric_network()
    if not(connected and port.energy>10000
      and cell.is_in_construction_range(ROBOT_ENGINE_S2_TARGET_1071)
      and network.available_construction_robots>0
      and network.get_item_count(ROBOT_ENGINE_S2_ITEM_1071)==1) then
      return
    end
    if root.construction_task_0338 or root.construction_custody_0338 then
      error("ROBOT_ENGINE_S2_ROOT_CONSTRUCTION_ALREADY_OWNED")
    end
    test.magos_priest=root.priest.unit_number
    test.network_id=network.network_id
    root.robot_network_request_0338={
      root_station_unit=test.magos_unit,
      surface_index=test.surface.index,force_index=root.station.force.index,
      item_name=ROBOT_ENGINE_S2_ITEM_1071,
      entity_name=ROBOT_ENGINE_S2_ITEM_1071,
      position={x=ROBOT_ENGINE_S2_TARGET_1071.x,
        y=ROBOT_ENGINE_S2_TARGET_1071.y},
      site_reason="CI-S2-native-construction-robot-1071"}
    test.phase="awaiting-canonical-ghost"
    test.request_tick=game.tick
    emit("ROBOT_ENGINE_S2_REQUEST tick="..game.tick..
      " magos="..test.magos_unit.." priest="..test.magos_priest..
      " port="..port.unit_number..
      " powered=true robots="..network.available_construction_robots..
      " network_stock=1")
    -- Withdraw EXISTING real construction robot items from the docked
    -- powered roboport into a separate engine-owned inventory. No robots
    -- are spawned, destroyed, or credited by a script-side counter.
    local robot_inv=port.get_inventory(defines.inventory.roboport_robot)
    local hold=game.create_inventory(3)
    if not(robot_inv and robot_inv.valid and hold and hold.valid
      and robot_inv.get_item_count("construction-robot")==3
      and robot_inv.remove{name="construction-robot",count=3}==3
      and hold.insert{name="construction-robot",count=3}==3
      and robot_inv.get_item_count("construction-robot")==0
      and hold.get_item_count("construction-robot")==3
      and inv.get_item_count(ROBOT_ENGINE_S2_ITEM_1071)==1) then
      error("ROBOT_ENGINE_S2_PHYSICAL_ROBOT_WITHDRAWAL_FAILED_1340")
    end
    test.robotless_hold_1340=hold
    test.robotless_request_1340=root.robot_network_request_0338
    test.robotless_cut_tick_1340=game.tick
    test.phase="robotless-request-1340"
    emit("ROBOT_ENGINE_S2_NATIVE_ROBOTLESS_CUT_1340 tick="..game.tick..
      " magos="..test.magos_unit..
      " priest="..test.magos_priest..
      " removed_robots=3 station_stock=1 request_retained=true")
    return
  end
  local task=root.robot_network_task_0338
    or root.robot_network_last_task_0338
  if task and not test.ghost_seen
    and task.item_name==ROBOT_ENGINE_S2_ITEM_1071
    and task.network_stock_before==1 then
    test.ghost_seen=true
    test.ghost_tick=task.started_tick
    emit("ROBOT_ENGINE_S2_GHOST tick="..task.started_tick..
      " magos="..test.magos_unit.." magos_priest="..test.magos_priest..
      " port="..port.unit_number..
      " network_stock_before=1 ghost=1")
    test.phase="awaiting-robot-construction"
    -- Same genuine roboport, same provider, same robot dispatch window.
    -- This independent vanilla control can identify a general dispatch fault
    -- without ever satisfying Senior construction/receipt acceptance.
    if test.control_ready_1074 then
      local created,control=pcall(function()
        return test.surface.create_entity{
          name="entity-ghost",inner_name="steel-chest",
          position=ROBOT_ENGINE_S2_CONTROL_TARGET_1074,
          force=game.forces.player,expires=false,raise_built=true}
      end)
      if created and control and control.valid
        and control.name=="entity-ghost" then
        test.control_ghost_1074=control
        emit("ROBOT_ENGINE_S2_CONTROL_GHOST_1074 tick="..game.tick..
          " item=steel-chest physical_mined_supply=true")
      else
        emit("ROBOT_ENGINE_S2_CONTROL_UNAVAILABLE_1074 reason=ghost-create-refused")
      end
    else
      emit("ROBOT_ENGINE_S2_CONTROL_UNAVAILABLE_1074 reason=physical-source-mine-unavailable")
    end
  end
  -- 1350: wait for observable, flying construction robots serving the
  -- already-submitted ghost. The robot, not this fixture, must own and spend
  -- the station item; only a real power substation is mined/restored here.
  if test.phase=="awaiting-robot-construction"
    and test.ghost_seen and not test.midflight_negative_passed_1350
    and not test.robot_event_station then
    local active=root.robot_network_task_0338
    local ghost=active and active.ghost
    local flying=test.surface.find_entities_filtered{
      type="construction-robot",position=port.position,
      radius=64,force=root.station.force,limit=32}
    if ghost and ghost.valid and #flying>0 then
      local dispatched=flying[1]
      if not(dispatched and dispatched.valid
        and dispatched.unit_number and dispatched.type=="construction-robot"
        and dispatched.surface==test.surface
        and dispatched.force==root.station.force) then
        error("ROBOT_ENGINE_S2_MIDFLIGHT_ROBOT_IDENTITY_INVALID_1360")
      end
      local hold=game.create_inventory(1)
      local source=test.power_source_1331
      if not(hold and hold.valid and source and source.valid
        and source.name=="substation"
        and source.mine{inventory=hold}==true
        and not source.valid
        and hold.get_item_count("substation")==1) then
        error("ROBOT_ENGINE_S2_MIDFLIGHT_PHYSICAL_POWER_CUT_FAILED_1350")
      end
      test.midflight_hold_1350=hold
      test.midflight_robot_1360=dispatched
      test.midflight_robot_unit_1360=dispatched.unit_number
      test.midflight_task_1350=active
      test.midflight_ghost_1350=ghost
      test.midflight_request_1350=root.robot_network_request_0338
      test.midflight_cut_tick_1350=game.tick
      test.phase="midflight-power-cut-1350"
      emit("ROBOT_ENGINE_S2_MIDFLIGHT_POWER_CUT_1350 tick="..game.tick..
        " magos="..test.magos_unit..
        " priest="..test.magos_priest..
        " observed_flying_robots="..#flying..
        " robot="..test.midflight_robot_unit_1360..
        " ghost=1 substation_custody=1")
      -- Save the LIVE mid-dispatch native world, not a recreated fixture.
      -- The next Factorio process alone may accept the persisted custody.
      test.midflight_save_requested_1360=true
      local saved,reason=pcall(function()
        game.auto_save("tech-priests-ci-robot-midflight")
      end)
      if not saved then
        error("ROBOT_ENGINE_S2_MIDFLIGHT_SAVE_REFUSED_1360:"..tostring(reason))
      end
      emit("ROBOT_ENGINE_S2_MIDFLIGHT_SAVE_REQUESTED_1360 tick="..
        game.tick.." magos="..test.magos_unit..
        " priest="..test.magos_priest..
        " robot="..test.midflight_robot_unit_1360..
        " ghost=1 substation_custody=1")
      return
    end
  end
  -- 1073: bounded *read-only* native diagnostics following the real ghost.
  -- A source-level mock cannot tell whether Factorio dispatched a robot,
  -- fetched the item, built the target or lost the event. Never turn any of
  -- these observations into construction authority or a pass condition.
  if test.ghost_seen and (not test.next_s2_diagnostic_tick_1073
      or game.tick>=test.next_s2_diagnostic_tick_1073) then
    test.next_s2_diagnostic_tick_1073=game.tick+900
    local current=root.robot_network_task_0338
      or root.robot_network_last_task_0338
    local ghost=current and current.ghost
    local ghost_valid=ghost and ghost.valid==true or false
    local ghost_name=nil
    if ghost_valid then
      pcall(function() ghost_name=ghost.ghost_name end)
    end
    local actual=test.surface.find_entities_filtered{
      name=ROBOT_ENGINE_S2_ITEM_1071,
      position=ROBOT_ENGINE_S2_TARGET_1071,
      radius=1,force=game.forces.player,limit=2}
    local robots=test.surface.find_entities_filtered{
      type="construction-robot",
      position=port.position,radius=64,force=game.forces.player,limit=64}
    local port_robots=port.get_inventory(defines.inventory.roboport_robot)
    local control_built=test.surface.find_entities_filtered{
      name="steel-chest",position=ROBOT_ENGINE_S2_CONTROL_TARGET_1074,
      radius=1,force=game.forces.player,limit=2}
    local connected=port.is_connected_to_electric_network()
    local detail="tick="..game.tick..
      " phase="..tostring(test.phase)..
      " ghost_valid="..tostring(ghost_valid)..
      " ghost_name="..tostring(ghost_name)..
      " target_stations="..tostring(#actual)..
      " control_built="..tostring(#control_built)..
      " control_ghost_valid="..tostring(test.control_ghost_1074
        and test.control_ghost_1074.valid or false)..
      " control_robot_event="..tostring(test.control_robot_event_1074)..
      " control_provider_stock="..tostring(inv.get_item_count("steel-chest"))..
      " robot_event="..tostring(test.robot_event_station)..
      " robot_events_on_surface="..tostring(test.robot_events_on_surface_1073 or 0)..
      " robots_in_flight="..tostring(#robots)..
      " robots_docked="..tostring(port_robots and port_robots.valid
        and port_robots.get_item_count("construction-robot") or -1)..
      " robots_total="..tostring(network.all_construction_robots)..
      " robots_available="..tostring(network.available_construction_robots)..
      " provider_stock="..tostring(inv.get_item_count(ROBOT_ENGINE_S2_ITEM_1071))..
      " network_stock="..tostring(network.get_item_count(ROBOT_ENGINE_S2_ITEM_1071))..
      " network_id="..tostring(network.network_id)..
      " port_energy="..tostring(math.floor(port.energy))..
      " power_connected="..tostring(connected)..
      " cell_transmitting="..tostring(cell.transmitting)..
      " covered="..tostring(cell.is_in_construction_range(ROBOT_ENGINE_S2_TARGET_1071))..
      " task_phase="..tostring(current and current.phase)..
      " last_0338="..tostring(root.construction_last_event_0338
        and root.construction_last_event_0338.action)
    test.last_s2_diagnostic_1073=detail
    emit("ROBOT_ENGINE_S2_DIAGNOSTIC_1073 "..detail)
  end
  if not(root.robot_network_last_task_0338
    and root.robot_network_last_task_0338.phase=="complete"
    and test.robot_event_station and test.ghost_seen) then return end
  local last=root.robot_network_last_task_0338
  local built=last.built_entity
  local child=built and tp.pairs_by_station
    and tp.pairs_by_station[built.unit_number]
  local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local ghosts=test.surface.find_entities_filtered{
    name="entity-ghost",position=ROBOT_ENGINE_S2_TARGET_1071,
    radius=2,force=game.forces.player,limit=4}
  if not(built and built.valid and built.name==ROBOT_ENGINE_S2_ITEM_1071
    and built.unit_number==test.robot_event_station
    and last.child_station_unit==built.unit_number
    and child and child.station==built and child.priest and child.priest.valid
    and last.child_priest_unit==child.priest.unit_number
    and hierarchy and hierarchy.rank(root)==4
    and hierarchy.rank(child)==3
    and hierarchy.is_direct_subordinate(root,child)==true
    and inv.get_item_count(ROBOT_ENGINE_S2_ITEM_1071)==0
    and network.get_item_count(ROBOT_ENGINE_S2_ITEM_1071)==0
    and #ghosts==0 and test.robot_event_unit
    and test.robotless_negative_passed_1340==true
    and test.power_negative_passed_1331==true
    and test.midflight_negative_passed_1350==true
    and test.robot_event_tick>=test.ghost_tick) then
    error("ROBOT_ENGINE_S2_REAL_BUILD_CUSTODY_OR_RANK_INVALID")
  end
  test.phase="complete"
  test.built_unit=built.unit_number
  test.child_priest=child.priest.unit_number
  test.completed_tick=game.tick
  emit("PASS ROBOT_ENGINE_S2_PHYSICAL_BUILD tick="..game.tick..
    " magos="..test.magos_unit..
    " magos_priest="..test.magos_priest..
    " station="..test.built_unit.." priest="..test.child_priest..
    " robot="..test.robot_event_unit..
    " source_delta=1 network_delta=1 ghost=0"..
    " hierarchy=direct-senior robot_event=on_robot_built_entity")
end


-- 1080: real-engine proof that the brokered 1076 frontier causes the
-- original 0338 priest to build counted, grid-connected poles and a port.
-- Temporary source entities are physically mined into the Magos inventory;
-- they are fixture supplies, never mined-resource acquisition credit.

-- 1120: the native fixture supplies only an OBSERVED naturally generated ore
-- objective. The production 1076/0820/0837 authorities must independently
-- discover, mine, carry and deposit it. No fixture extraction, item insertion,
-- ghost completion or courier dispatch is permitted.
local function robot_frontier_native_ore_1120(state,root,test)
  if test.ore_complete_1120 then return end
  local tp=storage.tech_priests
  local child=tp.pairs_by_station and
    tp.pairs_by_station[test.remote_station_unit_1120]
  local senior=tp.pairs_by_station and
    tp.pairs_by_station[test.senior_station]
  if not(child and child.station and child.station.valid
    and child.priest and child.priest.valid
    and child.priest.unit_number==test.remote_priest_1120
    and senior and senior.priest and senior.priest.valid
    and senior.priest.unit_number==test.senior_priest
    and root.priest and root.priest.valid
    and root.priest.unit_number==test.priest) then
    error("ROBOT_FRONTIER_1120_ORIGINAL_PAIR_IDENTITY_LOST")
  end
  local goal=root.roboport_expansion_goal_1076
  local frontier=root.roboport_frontier_1076
  local port=frontier and frontier.source_port
  local cell=port and port.valid and port.logistic_cell
  local chain=rawget(_G,"TechPriestsResourceStationChain0820")
  local radius=chain and chain.operating_radius
  if not(goal and frontier and frontier.status=="complete"
    and cell and type(radius)=="function") then
    error("ROBOT_FRONTIER_1120_REAL_NETWORK_OR_RADIUS_UNAVAILABLE")
  end
  -- 1131: Real Factorio acceptance for the separate Tech-Priest territory
  -- network, not a roboport/logistic-radius surrogate. The robot-built
  -- Intermediate must add its OWN occupied geometric coverage beyond both
  -- parent station radii. No ore, station, priest or inventory is modified.
  if not test.grade_coverage_1131 then
    local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
    if not(h and type(h.network_coverage_members)=="function"
        and type(h.position_in_network)=="function")then
      error("PRIEST_COVERAGE_1131_LIVE_HIERARCHY_MISSING")
    end
    local members=h.network_coverage_members(root)
    local senior_link,intermediate_link=false,false
    for _,member in ipairs(members)do
      if member.station_unit==senior.station.unit_number
          and member.rank==3 and member.depth==1 then
        senior_link=true
      end
      if member.station_unit==child.station.unit_number
          and member.rank==2 and member.depth==2 then
        intermediate_link=true
      end
    end
    if not(senior_link and intermediate_link)then
      error("PRIEST_COVERAGE_1131_PAIRED_RANK_NETWORK_NOT_LINKED")
    end
    local root_radius,senior_radius,child_radius=
      radius(root),radius(senior),radius(child)
    local directions={{1,0},{0,1},{-1,0},{0,-1},
      {0.70710678,0.70710678},{0.70710678,-0.70710678},
      {-0.70710678,0.70710678},{-0.70710678,-0.70710678}}
    local gained=nil
    for _,dir in ipairs(directions)do
      local pos={x=child.station.position.x+dir[1]*(child_radius-1),
        y=child.station.position.y+dir[2]*(child_radius-1)}
      local rx=pos.x-root.station.position.x
      local ry=pos.y-root.station.position.y
      local sx=pos.x-senior.station.position.x
      local sy=pos.y-senior.station.position.y
      if rx*rx+ry*ry>root_radius*root_radius
          and sx*sx+sy*sy>senior_radius*senior_radius then
        local owns,info=h.position_in_network(root,pos)
        local directly=h.position_in_authority(root,pos)
        if owns and info
            and info.station_unit==child.station.unit_number
            and info.depth==2 and not directly then
          gained=pos
          break
        end
      end
    end
    if not gained then
      error("PRIEST_COVERAGE_1131_NO_REAL_DESCENDANT_ONLY_EXTENSION")
    end
    test.grade_coverage_1131=true
    emit("PASS PRIEST_COVERAGE_1131_REAL_GRADED_EXTENSION tick="..
      game.tick.." magos="..root.station.unit_number..
      " senior="..senior.station.unit_number..
      " intermediate="..child.station.unit_number..
      " members="..#members..
      " root_radius="..root_radius..
      " senior_radius="..senior_radius..
      " child_radius="..child_radius..
      " new_x="..string.format("%.1f",gained.x)..
      " new_y="..string.format("%.1f",gained.y)..
      " real_station_and_priest_pairs=true direct_command_scope_preserved=true")
  end
  if not test.ore_target_1120 then
    -- Read-only deterministic selection from the engine-generated surface.
    -- The cleared construction corridor ends at x=66; never script ore into
    -- that corridor or supply a fictional patch when none exists.
    local ores=child.station.surface.find_entities_filtered{
      name="iron-ore",type="resource",
      area={{60,-32},{98,32}}}
    local selected,selected_distance
    local root_radius=radius(root)
    local terminal_radius=radius(child)
    for _,ore in pairs(ores) do
      if ore.valid and ore.amount>=2
        and ore.surface==child.station.surface then
        local dx=ore.position.x-child.station.position.x
        local dy=ore.position.y-child.station.position.y
        local rx=ore.position.x-root.station.position.x
        local ry=ore.position.y-root.station.position.y
        local distance=dx*dx+dy*dy
        local mineable=ore.prototype and ore.prototype.mineable_properties
        local product=false
        for _,p in pairs(mineable and mineable.products or {}) do
          if p.name=="iron-ore" and p.type~="fluid" then
            product=true;break
          end
        end
        if product and distance<=terminal_radius*terminal_radius
          and rx*rx+ry*ry>root_radius*root_radius
          and cell.is_in_logistic_range(ore.position)
          and cell.is_in_construction_range(ore.position)
          and (not selected or distance<selected_distance
            or (distance==selected_distance
              and (ore.position.x<selected.position.x
                or (ore.position.x==selected.position.x
                  and ore.position.y<selected.position.y)))) then
          selected=ore;selected_distance=distance
        end
      end
    end
    if not selected then
      error("ROBOT_FRONTIER_1120_NO_NATURALLY_GENERATED_COVERED_IRON_ORE")
    end
    local inventory=root.station.get_inventory(defines.inventory.chest)
    if not(inventory and inventory.valid) then
      error("ROBOT_FRONTIER_1120_MAGOS_INVENTORY_UNAVAILABLE")
    end
    test.ore_entity_1120=selected
    -- Capture the exact real source identity BEFORE native LuaEntity.mine
    -- can destroy and invalidate its original LuaEntity reference.
    test.ore_unit_1120=selected.unit_number
    test.ore_surface_index_1171=selected.surface.index
    test.ore_target_1120={x=selected.position.x,y=selected.position.y}
    test.ore_before_1120=selected.amount
    test.magos_ore_before_1120=inventory.get_item_count("iron-ore")
    test.ore_started_tick_1120=game.tick
    goal.remote_resource_item_1076="iron-ore"
    goal.remote_resource_position_1076={
      x=selected.position.x,y=selected.position.y}
    emit("ROBOT_FRONTIER_1120_NATURAL_ORE_OBJECTIVE tick="..game.tick..
      " magos="..test.magos.." magos_priest="..test.priest..
      " senior="..test.senior_station..
      " senior_priest="..test.senior_priest..
      " remote_station="..test.remote_station_unit_1120..
      " remote_priest="..test.remote_priest_1120..
      " ore=iron-ore patch_before="..test.ore_before_1120..
      " magos_before="..test.magos_ore_before_1120..
      " natural_generated=true")
    return
  end
  local mission=root.resource_expansion_0259
    and root.resource_expansion_0259.chain_0820
  local courier=mission and mission.return_courier_0837
  -- Native 1125 evidence is read-only. In the failed previous engine run
  -- 0837 awaited the original Intermediate's active 0513 physical return.
  -- Show which exact existing duty/cargo is still live, plus the 0837
  -- handoff state; do not cancel it or force the priest idle.
  if courier and courier.phase=="awaiting-terminal-duty"
      and (not test.last_courier_duty_observe_tick_1125
        or game.tick-test.last_courier_duty_observe_tick_1125>=600) then
    test.last_courier_duty_observe_tick_1125=game.tick
    local return_authority=rawget(_G,"TechPriestsResourceReturnCourier0837")
    local needs_tick=return_authority
      and type(return_authority.incumbent_relay_duty_needs_tick_1125)=="function"
      and return_authority.incumbent_relay_duty_needs_tick_1125(child)
    local movement=child.movement_request_0418
    local dormant_ok,dormant_reason=false,"probe-unavailable"
    if return_authority
        and type(return_authority.probe_dormant_direct_relay_0973)=="function" then
      local ok,eligible,why=pcall(
        return_authority.probe_dormant_direct_relay_0973,child)
      dormant_ok=ok and eligible==true
      dormant_reason=ok and tostring(why) or tostring(eligible)
    end
    emit("ROBOT_FRONTIER_1125_TERMINAL_DUTY tick="..game.tick..
      " station="..child.station.unit_number..
      " priest="..child.priest.unit_number..
      " mode="..tostring(child.mode)..
      " reserved="..tostring(return_authority
        and return_authority.worker_reserved(child))..
      " incumbent_tick="..tostring(needs_tick)..
      " dormant_0973="..tostring(dormant_ok)..
      " dormant_reason_0973="..tostring(dormant_reason)..
      " handoff_reason_1126="..tostring(courier.last_terminal_handoff_reason_1126)..
      " 0513_custody="..tostring(child.direct_acquisition_custody_0513
        and (child.direct_acquisition_custody_0513.count or "held"))..
      " 0513_task="..tostring(child.direct_acquisition_task_0336
        and child.direct_acquisition_task_0336.phase)..
      " active_task="..tostring(child.active_task
        and (child.active_task.type or child.active_task.kind or "yes"))..
      " recipe="..tostring(child.infrastructure_recipe_request_0647
        and child.infrastructure_recipe_request_0647.item)..
      " movement="..tostring(movement and movement.reason)..
      " courier_phase="..courier.phase..
      " courier_started="..tostring(courier.started_tick))
  end
  -- 1137: native #1074 advanced the exact robot-built terminal to a
  -- counted FIRST physical handoff, then stalled before Senior pickup.
  -- Observe the original Senior's task, station ore and stored refusal;
  -- do not move/clear any orders, inventory or route to make a test pass.
  if courier and courier.phase=="first-hop-delivered"
      and (not test.last_upstream_duty_observe_tick_1137
        or game.tick-test.last_upstream_duty_observe_tick_1137>=600)then
    test.last_upstream_duty_observe_tick_1137=game.tick
    local auth=rawget(_G,"TechPriestsResourceReturnCourier0837")
    local inv=senior.station.get_inventory(defines.inventory.chest)
    local movement=senior.movement_request_0418
    local order=senior.order_queue_0469
      and senior.order_queue_0469.current
    emit("ROBOT_FRONTIER_1137_NEXT_UPSTREAM_DUTY tick="..game.tick..
      " first_delivery_station="..tostring(courier.delivered_station_unit)..
      " awaiting_unit="..tostring(courier.pending_upstream_station_unit)..
      " senior_unit="..senior.station.unit_number..
      " senior_priest="..senior.priest.unit_number..
      " counted_station_ore="..tostring(inv and inv.valid
        and inv.get_item_count("iron-ore"))..
      " senior_mode="..tostring(senior.mode)..
      " reserved="..tostring(auth and auth.worker_reserved(senior))..
      " incumbent_tick="..tostring(auth
        and auth.incumbent_relay_duty_needs_tick_1125(senior))..
      " refusal="..tostring(courier.last_upstream_handoff_reason)..
      " refusal_tick="..tostring(courier.last_upstream_handoff_tick)..
      " 0513_task="..tostring(senior.direct_acquisition_task_0336
        and senior.direct_acquisition_task_0336.phase)..
      " 0513_custody="..tostring(senior.direct_acquisition_custody_0513
        and senior.direct_acquisition_custody_0513.count)..
      " active_task="..tostring(senior.active_task
        and (senior.active_task.type or senior.active_task.kind or "yes"))..
      " task_0285="..tostring(senior.active_task_0285
        and (senior.active_task_0285.type
          or senior.active_task_0285.kind or "yes"))..
      " active_is_order_task="..tostring(order
        and senior.active_task~=nil and senior.active_task==order.task)..
      " task_0285_is_order_task="..tostring(order
        and senior.active_task_0285~=nil
        and senior.active_task_0285==order.task)..
      " active_has_target="..tostring(senior.active_task
        and (senior.active_task.target~=nil
          or senior.active_task.entity~=nil
          or senior.active_task.position~=nil
          or senior.active_task.destination~=nil))..
      " order_source="..tostring(order and order.source)..
      " order_item="..tostring(order and order.item)..
      " order_status="..tostring(order and order.status)..
      " order="..tostring(order and order.kind)..
      " ingredient="..tostring(senior.infrastructure_recipe_request_0647
        and senior.infrastructure_recipe_request_0647.missing)..
      " movement="..tostring(movement and movement.reason)..
      " courier_hop="..tostring(courier.hop_index)..
      " courier_receipts="..tostring(courier.receipts_0982
        and #courier.receipts_0982)..
      " root_0259_reason="..tostring(root.resource_expansion_0259
        and root.resource_expansion_0259.last_reason)..
      " root_action="..tostring(root.canonical_action_0744
        and root.canonical_action_0744.family)..
      " root_action_detail="..tostring(root.canonical_action_0744
        and root.canonical_action_0744.detail)..
      " root_active="..tostring(root.active_task
        and (root.active_task.type or root.active_task.kind or "yes"))..
      " root_machine_phase="..tostring(root.machine_logistics_0528
        and root.machine_logistics_0528.phase)..
      " remote_drill_phase="..tostring(mission and mission.remote_drill_1011
        and mission.remote_drill_1011.phase)..
      " root_dispatch_tick="..tostring(root.dispatcher_0510
        and root.dispatcher_0510.tick)..
      " root_dispatch_family="..tostring(root.dispatcher_0510
        and root.dispatcher_0510.family)..
      " root_dispatch_result="..tostring(root.dispatcher_0510
        and root.dispatcher_0510.result)..
      " root_1141_tick="..tostring(root.courier_owner_service_1141
        and root.courier_owner_service_1141.tick)..
      " root_1141_phase="..tostring(root.courier_owner_service_1141
        and root.courier_owner_service_1141.phase)..
      " root_1141_detail="..tostring(root.courier_owner_service_1141
        and root.courier_owner_service_1141.detail)..
      " root_1141_error="..tostring(root.courier_owner_failure_1141
        and root.courier_owner_failure_1141.reason)..
      " root_direct_custody="..tostring(root.direct_acquisition_custody_0513
        and root.direct_acquisition_custody_0513.count)..
      " root_defense="..tostring(root.defense_task_0259
        and root.defense_task_0259.kind))
  end
  local inventory=root.station.get_inventory(defines.inventory.chest)
  local ore=test.ore_entity_1120
  -- Read-only native diagnostic for the missing 0820 mission observed in
  -- run 41666700488. Report 0600's ACTUAL 1076 refusal without invoking
  -- construction, ore mining or the mutating mission-adoption authority.
  if not mission and (not test.last_adoption_observe_tick_1123
      or game.tick-test.last_adoption_observe_tick_1123>=1200) then
    test.last_adoption_observe_tick_1123=game.tick
    local broker=tp.roboport_expansion_broker_1076
    local attempt=broker and broker.last_attempt
    local receipt=senior.robot_network_last_task_0338
    emit("ROBOT_FRONTIER_1123_ADOPTION_OBSERVE tick="..game.tick..
      " broker_station="..tostring(attempt and attempt.station_unit)..
      " broker_tick="..tostring(attempt and attempt.tick)..
      " broker_detail="..tostring(attempt and attempt.detail)..
      " broker_failed="..tostring(attempt and attempt.failed)..
      " root_builder="..tostring(root.construction_task_0338
        and root.construction_task_0338.phase)..
      " root_custody="..tostring(root.construction_custody_0338
        and root.construction_custody_0338.count)..
      " remote_unit="..tostring(frontier.remote_station_unit_1076)..
      " receipt_phase="..tostring(receipt and receipt.phase)..
      " senior_robot_task="..tostring(senior.robot_network_task_0338
        and senior.robot_network_task_0338.phase)..
      " senior_robot_request="..tostring(senior.robot_network_request_0338
        and senior.robot_network_request_0338.site_reason)..
      " goal_resource="..tostring(goal.remote_resource_item_1076))
  end
  if mission and courier and courier.phase=="magos-delivered" then
    local receipts=courier.receipts_0982
    local a=receipts and receipts[1]
    local b=receipts and receipts[2]
    local before=test.ore_before_1120
    local after=ore and ore.valid and ore.amount
    local magos_after=inventory and inventory.valid
      and inventory.get_item_count("iron-ore")
    local source_auth=rawget(_G,"TechPriestsResourceReturnCourier0837")
    local source_ok,source_reason=source_auth
      and type(source_auth.verify_natural_ore_source_1171)=="function"
      and source_auth.verify_natural_ore_source_1171(
        courier,ore,before,test.ore_target_1120,
        test.ore_surface_index_1171)
    if not(mission.current_station_unit==test.remote_station_unit_1120
      and mission.root_station_unit==test.magos
      and mission.need=="iron-ore"
      and mission.target.x==test.ore_target_1120.x
      and mission.target.y==test.ore_target_1120.y
      and courier.source_kind_0991=="natural-ore"
      and courier.item=="iron-ore" and courier.quantity==1
      and courier.delivered_count==1
      and courier.hops_completed==2 and courier.inventory==nil
      and courier.delivered_station_unit==test.magos
      and (mission.delivered_to_magos_count or 0)==1
      and #receipts==2
      and a.hop==1 and a.source_station_unit==test.remote_station_unit_1120
      and a.destination_station_unit==test.senior_station
      and a.carrier_priest_unit==test.remote_priest_1120
      and a.item=="iron-ore" and a.quantity==1
      and a.destination_after==a.destination_before+1
      and b.hop==2 and b.source_station_unit==test.senior_station
      and b.destination_station_unit==test.magos
      and b.carrier_priest_unit==test.senior_priest
      and b.item=="iron-ore" and b.quantity==1
      and b.destination_after==b.destination_before+1
      and source_ok==true
      and magos_after==test.magos_ore_before_1120+1) then
      -- 1169: This is a HARD PHYSICAL acceptance failure, not a style
      -- metric. Keep every 1120 condition unchanged. Expose the exact
      -- persisted 0820/0837 receipt and native resource/station quantities
      -- so a later repair can be audited instead of guessing or waiving it.
      local auth=rawget(_G,"TechPriestsResourceReturnCourier0837")
      local route={test.remote_station_unit_1120,test.senior_station,
        test.magos}
      local ledger_ok,ledger_reason=auth
        and type(auth.validate_receipts_0982)=="function"
        and auth.validate_receipts_0982(courier,route)
      local function dump_receipt(r)
        if type(r)~="table" then return "missing" end
        return "hop:"..tostring(r.hop)..
          ",source:"..tostring(r.source_station_unit)..
          ",dest:"..tostring(r.destination_station_unit)..
          ",priest:"..tostring(r.carrier_priest_unit)..
          ",item:"..tostring(r.item)..
          ",qty:"..tostring(r.quantity)..
          ",before:"..tostring(r.destination_before)..
          ",after:"..tostring(r.destination_after)..
          ",tick:"..tostring(r.tick)
      end
      emit("ROBOT_FRONTIER_1169_CUSTODY_MISMATCH_READBACK tick="..game.tick..
        " mission_root="..tostring(mission.root_station_unit)..
        " mission_terminal="..tostring(mission.current_station_unit)..
        " expected_magos="..tostring(test.magos)..
        " expected_terminal="..tostring(test.remote_station_unit_1120)..
        " mission_need="..tostring(mission.need)..
        " target_x="..tostring(mission.target and mission.target.x)..
        " target_y="..tostring(mission.target and mission.target.y)..
        " expected_target_x="..tostring(test.ore_target_1120.x)..
        " expected_target_y="..tostring(test.ore_target_1120.y)..
        " source_kind="..tostring(courier.source_kind_0991)..
        " item="..tostring(courier.item)..
        " quantity="..tostring(courier.quantity)..
        " delivered_count="..tostring(courier.delivered_count)..
        " hops="..tostring(courier.hops_completed)..
        " inventory_empty="..tostring(courier.inventory==nil)..
        " delivered_station="..tostring(courier.delivered_station_unit)..
        " mission_delivery_count="..
          tostring(mission.delivered_to_magos_count)..
        " receipt_count="..tostring(#receipts)..
        " ledger_valid="..tostring(ledger_ok)..
        " ledger_reason="..tostring(ledger_reason)..
        " receipt_1="..dump_receipt(a)..
        " receipt_2="..dump_receipt(b)..
        " ore_before="..tostring(before)..
        " ore_valid="..tostring(ore and ore.valid)..
        " ore_after="..tostring(after)..
        " ore_origin_unit="..tostring(test.ore_unit_1120)..
        " courier_ore_unit="..tostring(courier.ore_unit)..
        " courier_ore_before="..tostring(courier.ore_amount_before)..
        " courier_source_name="..tostring(courier.ore_source_name_1171)..
        " courier_source_position="..tostring(courier.ore_source_position_1171
          and (courier.ore_source_position_1171.x..","..
            courier.ore_source_position_1171.y))..
        " courier_source_surface="..
          tostring(courier.ore_source_surface_index_1171)..
        " expected_source_surface="..tostring(test.ore_surface_index_1171)..
        " source_depletion_verified="..tostring(source_ok)..
        " source_depletion_reason="..tostring(source_reason)..
        " magos_before="..tostring(test.magos_ore_before_1120)..
        " magos_after="..tostring(magos_after)..
        " magos_receipt_after="..
          tostring(b and b.destination_after))
      error("ROBOT_FRONTIER_1120_NATURAL_ORE_IDENTITY_OR_CUSTODY_MISMATCH")
    end
    test.ore_complete_1120=true
    emit("PASS ROBOT_FRONTIER_1120_NATIVE_ORE_RETURN tick="..game.tick..
      " magos="..test.magos.." magos_priest="..test.priest..
      " senior="..test.senior_station..
      " senior_priest="..test.senior_priest..
      " remote_station="..test.remote_station_unit_1120..
      " remote_priest="..test.remote_priest_1120..
      " ore=iron-ore patch_before="..before..
      " patch_after="..tostring(after)..
      " magos_before="..test.magos_ore_before_1120..
      " magos_after="..magos_after..
      " source_depletion="..tostring(source_reason)..
      " hops=2 receipts=2 source=natural-ore custody=empty")
  elseif game.tick-test.ore_started_tick_1120>15000 then
    error("ROBOT_FRONTIER_1120_NATURAL_ORE_RETURN_TIMEOUT phase="..
      tostring(courier and courier.phase)..
      " reason="..tostring(courier and courier.last_reason)..
      " mission="..tostring(mission and mission.status)..
      " mission_need="..tostring(mission and mission.need)..
      " mission_created="..tostring(mission and mission.created_tick)..
      " mission_pending="..tostring(mission and mission.pending_expansion_id)..
      " mission_reason="..tostring(mission and mission.last_reason)..
      " chain="..tostring(frontier and frontier.status)..
      " broker_detail="..tostring(tp.roboport_expansion_broker_1076
        and tp.roboport_expansion_broker_1076.last_attempt
        and tp.roboport_expansion_broker_1076.last_attempt.detail)..
      " root_builder="..tostring(root.construction_task_0338
        and root.construction_task_0338.phase)..
      -- 1248: if the original 0513 duty never yields, expose the precise
      -- source-mode and ownership barrier without altering any work/cargo.
      " terminal_unit="..tostring(child and child.station
        and child.station.unit_number)..
      " terminal_mode="..tostring(child and child.mode)..
      " terminal_active_task="..tostring(child and child.active_task
        and (child.active_task.type or child.active_task.kind or "yes"))..
      " terminal_0285="..tostring(child and child.active_task_0285
        and (child.active_task_0285.type or child.active_task_0285.kind or "yes"))..
      " terminal_current_task="..tostring(child and child.current_task
        and (child.current_task.type or child.current_task.kind or "yes"))..
      " terminal_direct_task="..tostring(child and child.direct_acquisition_task_0336
        and child.direct_acquisition_task_0336.phase)..
      " terminal_direct_cargo="..tostring(child and child.direct_acquisition_custody_0513
        and child.direct_acquisition_custody_0513.count)..
      " terminal_recipe_item="..tostring(child and child.infrastructure_recipe_request_0647
        and child.infrastructure_recipe_request_0647.item)..
      " terminal_recipe_missing="..tostring(child and child.infrastructure_recipe_request_0647
        and child.infrastructure_recipe_request_0647.missing)..
      " terminal_requested="..tostring(child and child.requested_item)..
      " terminal_logistic="..tostring(child and child.logistic_requested_item)..
      " terminal_gate="..tostring(child and child.local_infrastructure_gate_0640
        and child.local_infrastructure_gate_0640.item)..
      " terminal_order="..tostring(child and child.order_queue_0469
        and child.order_queue_0469.current
        and child.order_queue_0469.current.status)..
      " terminal_move="..tostring(child and child.movement_request_0418
        and child.movement_request_0418.reason)..
      " terminal_move_expires="..tostring(child and child.movement_request_0418
        and child.movement_request_0418.expires_tick)..
      " terminal_handoff_refusal="..tostring(courier
        and courier.last_terminal_handoff_reason_1126)..
      " terminal_handoff_tick="..tostring(courier
        and courier.last_terminal_handoff_tick_1126))
  end
end

local function robot_frontier_native_1080(state)
  local s2=state.robot_engine_s2_1071
  if not(s2 and s2.phase=="complete") then return end
  local tp=storage.tech_priests
  local root=tp.pairs_by_station and tp.pairs_by_station[s2.magos_unit]
  if not(root and root.station==s2.magos and root.station.valid
    and root.priest and root.priest.valid
    and root.priest.unit_number==s2.magos_priest) then
    error("ROBOT_FRONTIER_1080_ORIGINAL_MAGOS_IDENTITY_LOST")
  end
  local test=state.robot_frontier_native_1080
  local stock=root.station.get_inventory(defines.inventory.chest)
  local senior=tp.pairs_by_station and tp.pairs_by_station[s2.built_unit]
  local senior_stock=senior and senior.station and senior.station.valid
    and senior.station.get_inventory(defines.inventory.chest)
  if not(stock and stock.valid and senior and senior.priest
    and senior.priest.valid and senior_stock and senior_stock.valid
    and senior.station.unit_number==s2.built_unit
    and senior.priest.unit_number==s2.child_priest) then
    error("ROBOT_FRONTIER_1080_ORIGINAL_MAGOS_OR_SENIOR_INVENTORY_UNAVAILABLE")
  end
  if not test then
    -- Do not steal a construction task with existing material custody.
    if root.construction_task_0338 or root.construction_custody_0338
      or root.construction_request or root.robot_network_task_0338
      or root.robot_network_request_0338 then return end
    local source=s2.port
    local cell=source and source.valid and source.logistic_cell
    local network=cell and cell.logistic_network
    if not(source and source.valid
      and source.is_connected_to_electric_network()
      and source.energy>0 and network and network.valid~=false
      and source.electric_network_id and source.electric_network_id>0) then
      return
    end
    -- A temporary roboport can invalidate the LuaLogisticNetwork handle
    -- during native mine/merge. Capture only the live electrical identity
    -- before mining; reacquire the native logistic network on a later tick.
    local original_grid=source.electric_network_id
    local before_poles=stock.get_item_count("medium-electric-pole")
    local before_ports=stock.get_item_count("roboport")
    local before_senior_poles=senior_stock.get_item_count("medium-electric-pole")
    local before_senior_ports=senior_stock.get_item_count("roboport")
    local surface=s2.surface
    local function mine_supply(name,destination)
      local pos={x=59,y=35}
      local spec={name=name,position=pos,force=root.station.force}
      if not surface.can_place_entity(spec) then
        error("ROBOT_FRONTIER_1080_PHYSICAL_SOURCE_BLOCKED:"..name)
      end
      local entity=surface.create_entity(spec)
      if not(entity and entity.valid) then
        error("ROBOT_FRONTIER_1080_SOURCE_ENTITY_UNAVAILABLE:"..name)
      end
      if not entity.mine{inventory=destination} or entity.valid then
        error("ROBOT_FRONTIER_1080_PHYSICAL_MINE_REFUSED:"..name)
      end
    end
    -- Multiple genuine port builds are required to validate an expanding
    -- frontier. Stock enters the actual inventory via physical entity mining.
    -- The original Magos can physically build the first port, but its
    -- 0418 territory cannot be widened to reach every later site. Supply
    -- the already-paired direct Senior with its OWN physically mined
    -- materials, not remote credits or an item transfer by script.
    -- Total fixture supply remains exactly 24 poles and 4 roboports.
    for _=1,12 do mine_supply("medium-electric-pole",stock) end
    for _=1,12 do mine_supply("medium-electric-pole",senior_stock) end
    for _=1,2 do mine_supply("roboport",stock) end
    for _=1,2 do mine_supply("roboport",senior_stock) end
    -- One additional genuine ranked station item enters the ORIGINAL
    -- provider chest by native entity mining. It is not an ore delivery
    -- or synthetic stock credit; robots must spend it at the remote site.
    local provider_inv=s2.provider.get_inventory(defines.inventory.chest)
    if not(provider_inv and provider_inv.valid
      and provider_inv.get_item_count(ROBOT_FRONTIER_REMOTE_ITEM_1111)==0) then
      error("ROBOT_FRONTIER_1111_PROVIDER_CUSTODY_UNAVAILABLE")
    end
    mine_supply(ROBOT_FRONTIER_REMOTE_ITEM_1111,provider_inv)
    if provider_inv.get_item_count(ROBOT_FRONTIER_REMOTE_ITEM_1111)~=1 then
      error("ROBOT_FRONTIER_1111_NATIVE_STATION_ITEM_MINE_REFUSED")
    end
    if stock.get_item_count("medium-electric-pole")~=before_poles+12
      or stock.get_item_count("roboport")~=before_ports+2
      or senior_stock.get_item_count("medium-electric-pole")~=before_senior_poles+12
      or senior_stock.get_item_count("roboport")~=before_senior_ports+2 then
      error("ROBOT_FRONTIER_1080_MINED_STOCK_NOT_CONSERVED")
    end
    -- Commit fixture custody before querying the potentially invalidated
    -- network. This phase prevents a second mining pass on a later tick.
    test={phase="awaiting-native-network-rebind",
      started_tick=game.tick,magos=s2.magos_unit,
      priest=s2.magos_priest,source_port=source.unit_number,
      source_position={x=source.position.x,y=source.position.y},
      grid=original_grid,network=nil,
      initial_poles=before_poles+12,initial_ports=before_ports+2,
      initial_senior_poles=before_senior_poles+12,
      initial_senior_ports=before_senior_ports+2,
      poles_by_builder={},ports_by_builder={},
      senior_station=s2.built_unit,senior_priest=s2.child_priest,
      pole_units={},port_units={},last_receipt=nil,
      remote_stock_initial_1111=1}
    state.robot_frontier_native_1080=test
    return
  end
  if test.phase=="awaiting-native-network-rebind" then
    -- Never retain a LuaLogisticNetwork reference across a real roboport
    -- build/mine. Native network objects can become invalid immediately.
    local source=s2.port
    local ok,grid_id,network_id=pcall(function()
      if not(source and source.valid
        and source.is_connected_to_electric_network()
        and source.energy>0) then return nil,nil end
      local cell=source.logistic_cell
      local network=cell and cell.logistic_network
      if not(network and network.valid) then return nil,nil end
      return source.electric_network_id,network.network_id
    end)
    if ok and grid_id==test.grid
      and type(network_id)=="number" and network_id>0 then
      test.network=network_id
      test.phase="active"
      -- The source port is at x=18. The FIRST hop is bounded to 36+9
      -- tiles from that source: its furthest x is <=63. A goal at x=94
      -- therefore remains >30 tiles beyond even the furthest first hop,
      -- OUTSIDE vanilla's 25-tile logistics radius. The existing native
      -- >=2 distinct 0338 port-receipt gate is now geometrically possible
      -- AND necessary, without artificially overriding runtime completion.
      local reserved=root.roboport_expansion_goal_1076
      if not(reserved and reserved.activation_pending_1076==true
        and reserved.root_station_unit==s2.magos_unit
        and reserved.surface_index==s2.surface.index
        and reserved.force_index==root.station.force.index) then
        error("ROBOT_FRONTIER_1122_EXPLICIT_GOAL_RESERVATION_LOST")
      end
      root.roboport_expansion_goal_1076={
        target={x=94,y=0},root_station_unit=s2.magos_unit,
        surface_index=s2.surface.index,
        force_index=root.station.force.index,
        remote_station_item_1076=ROBOT_FRONTIER_REMOTE_ITEM_1111,
        remote_station_position_1076={
          x=ROBOT_FRONTIER_REMOTE_SITE_1111.x,
          y=ROBOT_FRONTIER_REMOTE_SITE_1111.y}}
      emit("ROBOT_FRONTIER_1080_SOURCE tick="..game.tick..
        " magos="..test.magos.." priest="..test.priest..
        " port="..test.source_port.." poles=24 roboports=4"..
        " magos_poles=12 magos_ports=2 senior_poles=12 senior_ports=2"..
        " senior="..test.senior_station.." senior_priest="..test.senior_priest..
        " mined=true electric="..test.grid.." logistic="..test.network)
    elseif game.tick-test.started_tick>1800 then
      error("ROBOT_FRONTIER_1080_NATIVE_NETWORK_REBIND_TIMEOUT")
    end
    return
  end
  if test.complete then
    if test.remote_complete_1111 then
      robot_frontier_native_ore_1120(state,root,test)
      return
    end
    local frontier=root.roboport_frontier_1076
    local worker=tp.pairs_by_station
      and tp.pairs_by_station[test.senior_station]
    local receipt=worker and worker.robot_network_last_task_0338
    local child_unit=frontier and frontier.remote_station_unit_1076
    local child=child_unit and tp.pairs_by_station
      and tp.pairs_by_station[child_unit]
    local provider_inv=s2.provider.get_inventory(defines.inventory.chest)
    local remaining=provider_inv and provider_inv.valid
      and provider_inv.get_item_count(ROBOT_FRONTIER_REMOTE_ITEM_1111)
    local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
    if child and receipt and receipt.phase=="complete"
      and test.remote_robot_event_station_1111 then
      local ghost=s2.surface.find_entities_filtered{
        name="entity-ghost",position=ROBOT_FRONTIER_REMOTE_SITE_1111,
        radius=2,force=root.station.force,limit=4}
      local final_port=frontier.source_port
      local cell=final_port and final_port.valid and final_port.logistic_cell
      local network=cell and cell.logistic_network
      if not(child.station and child.station.valid
        and child.station.unit_number==test.remote_robot_event_station_1111
        and child.station.name==ROBOT_FRONTIER_REMOTE_ITEM_1111
        and child.station.force==root.station.force
        and child.station.surface==root.station.surface
        and child.priest and child.priest.valid
        and child.priest.unit_number==frontier.remote_station_priest_1076
        and receipt.built_entity==child.station
        and receipt.child_station_unit==child.station.unit_number
        and receipt.child_priest_unit==child.priest.unit_number
        and receipt.network_stock_before==1
        and receipt.stock_delta_verified==true
        and remaining==0 and #ghost==0
        and test.remote_robot_event_unit_1111
        and test.remote_robot_event_tick_1111>=receipt.started_tick
        and worker.priest and worker.priest.valid
        and worker.priest.unit_number==test.senior_priest
        and root.priest.unit_number==test.priest
        and hierarchy and hierarchy.rank(worker)==3
        and hierarchy.rank(child)==2
        and hierarchy.is_direct_subordinate(worker,child)==true
        and final_port.electric_network_id==test.grid
        and network and network.valid and network.force==root.station.force
        and cell.is_in_construction_range(ROBOT_FRONTIER_REMOTE_SITE_1111)
        and cell.is_in_logistic_range(ROBOT_FRONTIER_REMOTE_SITE_1111)) then
        error("ROBOT_FRONTIER_1111_REAL_BUILD_CUSTODY_OR_HIERARCHY_INVALID")
      end
      test.remote_station_unit_1120=child.station.unit_number
      test.remote_priest_1120=child.priest.unit_number
      test.remote_complete_1111=true
      emit("PASS ROBOT_FRONTIER_1111_REMOTE_ROBOT_OUTPOST tick="..game.tick..
        " magos="..test.magos.." magos_priest="..test.priest..
        " senior="..test.senior_station..
        " senior_priest="..test.senior_priest..
        " remote_station="..child.station.unit_number..
        " remote_priest="..child.priest.unit_number..
        " robot="..test.remote_robot_event_unit_1111..
        " physical_provider_delta=1 ghost=0"..
        " grid="..test.grid.." paired_rank=intermediate")
    elseif game.tick-(test.complete_tick_1080 or game.tick)>15000 then
      error("ROBOT_FRONTIER_1111_REMOTE_STATION_TIMEOUT phase="..
        tostring(frontier and frontier.status)..
        " request="..tostring(frontier and frontier.remote_station_request_1076)..
        " builder="..tostring(frontier and frontier.remote_station_builder_1076)..
        " event="..tostring(test.remote_robot_event_station_1111)..
        " receipt="..tostring(receipt and receipt.phase)..
        " provider_stock="..tostring(remaining))
    end
    return
  end
  if test.deferred_timeout_1094 then return end
  local frontier=root.roboport_frontier_1076
  -- The native timeout used to report only status=nil, hiding whether
  -- the 0600 broker was installed, selected this Magos, or refused a
  -- physical preflight. Observe the broker; never invoke its executor
  -- from the fixture or create a substitute construction receipt.
  if not test.last_frontier_diag_tick
    or game.tick-test.last_frontier_diag_tick>=1200 then
    test.last_frontier_diag_tick=game.tick
    local broker=tp.roboport_expansion_broker_1076
    local attempt=broker and broker.last_attempt
    -- Read-only native arbitration probe. The old 1080 timeout described
    -- a priest physically inside build reach while another work family
    -- prevented 0338 dispatch; capture the CURRENT classifier decision.
    local action,action_error
    local arbiter=rawget(_G,"TECH_PRIESTS_ACTION_STATE_ARBITER_0488")
    if arbiter and type(arbiter.action)=="function" then
      local ok,result=pcall(arbiter.action,root)
      if ok then action=result else action_error=tostring(result) end
    end
    local work=root.construction_task_0338
    local build_distance_sq=nil
    if work and work.position and root.priest.position then
      local dx=root.priest.position.x-work.position.x
      local dy=root.priest.position.y-work.position.y
      build_distance_sq=dx*dx+dy*dy
    end
    -- Diagnostic only: check the actual second-port exterior with each
    -- priest's own 0338/0418 authority. The source planner's synthetic x=44
    -- approval is not proof that the original Magos can reach this site.
    -- Do not dispatch, reserve, place a ghost or debit any inventory here.
    local second_site_magos="not-at-second-leg"
    local second_site_senior="not-at-second-leg"
    local senior=tp.pairs_by_station and tp.pairs_by_station[s2.built_unit]
    -- Native 41571820426: a first-port request x=48,y=1 waited across
    -- the whole reload while the Magos (not the actual Senior builder) was
    -- the only priest described. Sample the EXACT delegated request,
    -- discovery, real stock, dispatcher and custody, without executing
    -- or mutating ANY of them.
    local pending=frontier and frontier.pending
    local senior_work=senior and senior.construction_task_0338
    local senior_candidate=senior and senior.construction_candidate_0338
    local senior_request=senior and senior.construction_request
    local senior_last=senior and senior.construction_last_task_0338
    local senior_action,senior_action_error,senior_stock_roboports
    if senior and senior.station and senior.station.valid
      and senior.priest and senior.priest.valid then
      if arbiter and type(arbiter.action)=="function"then
        local ok,result=pcall(arbiter.action,senior)
        if ok then senior_action=result
        else senior_action_error=tostring(result) end
      end
      local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
      if authority and type(authority.generic_item_count)=="function"then
        local ok,count=pcall(authority.generic_item_count,senior,"roboport")
        if ok then senior_stock_roboports=count end
      end
    end
    local pending_senior_contact="no-live-pending-port"
    if pending and pending.kind=="port" and pending.position
      and senior and senior.station and senior.station.valid
      and senior.priest and senior.priest.valid then
      local physical=rawget(_G,"TechPriestsConstructionPlanner0338")
      if physical and type(physical.frontier_site_contact_0338)=="function"then
        local ok,stand,why=pcall(physical.frontier_site_contact_0338,
          senior,"roboport",pending.position)
        if ok then
          pending_senior_contact=stand
            and string.format("%.2f,%.2f",stand.x,stand.y)
            or tostring(why)
        else pending_senior_contact="contact-probe-error"end
      end
    end
    if frontier and (frontier.segments or 0)>=1 then
      local physical=rawget(_G,"TechPriestsConstructionPlanner0338")
      if physical and type(physical.frontier_site_contact_0338)=="function" then
        local probe={x=44,y=0}
        local ok,stand,why=pcall(physical.frontier_site_contact_0338,
          root,"roboport",probe)
        if ok then
          second_site_magos=stand
            and string.format("%.2f,%.2f",stand.x,stand.y)
            or tostring(why)
        else second_site_magos="contact-probe-error" end
        if senior and senior.station and senior.station.valid
          and senior.priest and senior.priest.valid then
          local permitted,contact,denial=pcall(
            physical.frontier_site_contact_0338,senior,"roboport",probe)
          if permitted then
            second_site_senior=contact
              and string.format("%.2f,%.2f",contact.x,contact.y)
              or tostring(denial)
          else second_site_senior="contact-probe-error" end
        else second_site_senior="no-live-senior-pair" end
      else
        second_site_magos="0338-contact-preflight-unavailable"
        second_site_senior="0338-contact-preflight-unavailable"
      end
    end
    local runtime=rawget(_G,"TechPriestsRuntimeTickBroker0600")
    local registered=false
    for _,entry in pairs(runtime and runtime.services or {}) do
      if entry.name=="roboport_expansion_frontier_1076" then
        registered=true;break
      end
    end
    emit("ROBOT_FRONTIER_1080_BROKER_OBSERVE tick="..game.tick..
      " registered="..tostring(registered)..
      " runtime_installed="..tostring(runtime and runtime.installed)..
      " goal="..tostring(root.roboport_expansion_goal_1076~=nil)..
      " second_site_x44_magos_contact="..second_site_magos..
      " second_site_x44_senior_contact="..second_site_senior..
      " senior_station="..tostring(senior and senior.station
        and senior.station.unit_number)..
      " pending_builder="..tostring(pending and pending.builder_station_unit)..
      " pending_kind="..tostring(pending and pending.kind)..
      " pending_age="..tostring(pending and (game.tick-pending.started_tick))..
      " pending_senior_contact="..pending_senior_contact..
      " senior_stock_roboports="..tostring(senior_stock_roboports)..
      " senior_request_matches="..tostring(pending and
        senior_request==pending.request)..
      " senior_request_item="..tostring(senior_request
        and senior_request.item_name)..
      " senior_candidate_item="..tostring(senior_candidate
        and senior_candidate.item_name)..
      " senior_candidate_field="..tostring(senior_candidate
        and senior_candidate.request_field)..
      " senior_candidate_matches="..tostring(senior_candidate
        and senior_candidate.request_value==senior_request)..
      " senior_bootstrap_item="..tostring(senior and
        senior.construction_bootstrap_ghost_0645
        and senior.construction_bootstrap_ghost_0645.item)..
      " senior_0338_blocker="..tostring(senior and
        senior.construction_blocked_reason_0338)..
      " senior_0338_cooldown="..tostring(senior and
        senior.construction_cooldown_0338)..
      " senior_task_phase="..tostring(senior_work and senior_work.phase)..
      " senior_task_item="..tostring(senior_work
        and senior_work.item_name)..
      " senior_task_matches="..tostring(pending and senior_work
        and senior_work.request_value==pending.request)..
      " senior_carried="..tostring(senior_work
        and senior_work.carried and senior_work.carried.count)..
      " senior_custody="..tostring(senior and
        senior.construction_custody_0338
        and senior.construction_custody_0338.count)..
      " senior_last_phase="..tostring(senior_last
        and senior_last.phase)..
      " senior_last_result="..tostring(senior_last
        and senior_last.result)..
      " senior_last_matches="..tostring(pending and senior_last
        and senior_last.request_value==pending.request)..
      " senior_action="..tostring(senior_action and senior_action.kind)..
      " senior_action_source="..tostring(senior_action
        and senior_action.source)..
      " senior_action_error="..tostring(senior_action_error)..
      " senior_dispatch="..tostring(senior and
        senior.dispatcher_0510 and senior.dispatcher_0510.family)..
      " senior_order="..tostring(senior and
        senior.order_queue_0469 and senior.order_queue_0469.current
        and senior.order_queue_0469.current.kind)..
      " senior_mode="..tostring(senior and senior.mode)..
      " senior_move_owner="..tostring(senior and
        senior.movement_request_0418
        and senior.movement_request_0418.owner)..
      " senior_x="..tostring(senior and senior.priest
        and senior.priest.position.x)..
      " senior_y="..tostring(senior and senior.priest
        and senior.priest.position.y)..
      " station="..tostring(root.station.unit_number)..
      " last_station="..tostring(attempt and attempt.station_unit)..
      " last_tick="..tostring(attempt and attempt.tick)..
      " last_detail="..tostring(attempt and attempt.detail)..
      " last_error="..tostring(broker and broker.last_failure
        and broker.last_failure.detail)..
      " frontier="..tostring(frontier and frontier.status)..
      " request="..tostring(root.construction_request
        and root.construction_request.entity_name)..
      " priest_x="..tostring(root.priest.position.x)..
      " priest_y="..tostring(root.priest.position.y)..
      " site_x="..tostring(root.construction_task_0338
        and root.construction_task_0338.position.x)..
      " site_y="..tostring(root.construction_task_0338
        and root.construction_task_0338.position.y)..
      " standoff_x="..tostring(root.construction_task_0338
        and root.construction_task_0338.build_standoff_0338
        and root.construction_task_0338.build_standoff_0338.x)..
      " move_denials="..tostring(root.construction_task_0338
        and root.construction_task_0338.movement_denials_0338)..
      " move_replans="..tostring(root.construction_task_0338
        and root.construction_task_0338.move_site_replans_0338)..
      " carried="..tostring(root.construction_task_0338
        and root.construction_task_0338.carried
        and root.construction_task_0338.carried.count)..
      " custody="..tostring(root.construction_custody_0338
        and root.construction_custody_0338.count)..
      " action_family="..tostring(root.canonical_action_0744
        and root.canonical_action_0744.family)..
      " dispatch_family="..tostring(root.dispatcher_0510
        and root.dispatcher_0510.family)..
      " order_kind="..tostring(root.order_queue_0469
        and root.order_queue_0469.current
        and root.order_queue_0469.current.kind)..
      " direct_bootstrap="..tostring(root.direct_acquisition_task_0336
        and root.direct_acquisition_task_0336.bootstrap_resource_0637)..
      " movement_owner="..tostring(root.movement_request_0418
        and root.movement_request_0418.owner)..
      " movement_reason="..tostring(root.movement_request_0418
        and root.movement_request_0418.reason)..
      " action_0488="..tostring(action and action.kind)..
      " action_source="..tostring(action and action.source)..
      " action_error="..tostring(action_error)..
      " build_distance_sq="..tostring(build_distance_sq)..
      " within_nominal_build_reach="..tostring(build_distance_sq
        and build_distance_sq<=4 or false)..
      " last_0338_event="..tostring(root.construction_last_event_0338
        and root.construction_last_event_0338.action)..
      " last_0338_phase="..tostring(root.construction_last_task_0338
        and root.construction_last_task_0338.phase)..
      " last_0338_field="..tostring(root.construction_last_task_0338
        and root.construction_last_task_0338.request_field)..
      " receipt_request_matches="..tostring(frontier and frontier.pending
        and root.construction_last_task_0338
        and root.construction_last_task_0338.request_value==
          frontier.pending.request)..
      " receipt_entity="..tostring(root.construction_last_task_0338
        and root.construction_last_task_0338.built_entity
        and root.construction_last_task_0338.built_entity.name)..
      " receipt_x="..tostring(root.construction_last_task_0338
        and root.construction_last_task_0338.built_entity
        and root.construction_last_task_0338.built_entity.position.x)..
      " receipt_y="..tostring(root.construction_last_task_0338
        and root.construction_last_task_0338.built_entity
        and root.construction_last_task_0338.built_entity.position.y)..
      " pending_x="..tostring(frontier and frontier.pending
        and frontier.pending.position.x)..
      " pending_y="..tostring(frontier and frontier.pending
        and frontier.pending.position.y))
  end
  if frontier and frontier.last_receipt
    and frontier.last_receipt~=test.last_receipt then
    local receipt=frontier.last_receipt
    local entity=receipt.built_entity
    if not(receipt.phase=="complete" and entity and entity.valid
      and receipt.request_value and
      receipt.request_value.frontier_root_unit_1076==test.magos
      and entity.surface==s2.surface
      and entity.force==root.station.force) then
      error("ROBOT_FRONTIER_1080_FORGED_OR_MISSING_0338_RECEIPT")
    end
    local kind=entity.name=="medium-electric-pole" and "pole"
      or entity.name=="roboport" and "port" or nil
    if not kind or entity.electric_network_id~=test.grid then
      error("ROBOT_FRONTIER_1080_RECEIPT_FOREIGN_GRID")
    end
    local seen=kind=="pole" and test.pole_units or test.port_units
    if seen[entity.unit_number] then
      error("ROBOT_FRONTIER_1080_DUPLICATE_PHYSICAL_RECEIPT")
    end
    seen[entity.unit_number]=true
    local builder=receipt.request_value.frontier_builder_unit_1076
    if builder~=test.magos and builder~=test.senior_station then
      error("ROBOT_FRONTIER_1080_FOREIGN_PHYSICAL_BUILDER")
    end
    local counts=kind=="pole" and test.poles_by_builder
      or test.ports_by_builder
    counts[builder]=(counts[builder]or 0)+1
    if kind=="port" then
      local goal=root.roboport_expansion_goal_1076
        and root.roboport_expansion_goal_1076.target
      local previous=test.last_port_distance_1080
      if not previous and goal then
        previous=math.sqrt((test.source_position.x-goal.x)^2+
          (test.source_position.y-goal.y)^2)
      end
      local remaining=goal and math.sqrt(
        (entity.position.x-goal.x)^2+(entity.position.y-goal.y)^2)
      if not(previous and remaining and remaining<=previous-5) then
        error("ROBOT_FRONTIER_1080_PORT_NOT_ADVANCING_COVERAGE")
      end
      test.last_port_distance_1080=remaining
      test.forward_port_receipts_1080=
        (test.forward_port_receipts_1080 or 0)+1
      emit("ROBOT_FRONTIER_1080_SEGMENT_PROGRESS tick="..game.tick..
        " segment="..test.forward_port_receipts_1080..
        " port="..entity.unit_number..
        " remaining_tiles="..string.format("%.2f",remaining)..
        " previous_tiles="..string.format("%.2f",previous)..
        " item_debit=0338-native-receipt")
    end
    test.last_receipt=receipt
    emit("ROBOT_FRONTIER_1080_RECEIPT tick="..game.tick..
      " kind="..kind.." unit="..entity.unit_number..
      " grid="..test.grid..
      " poles="..tostring(frontier.poles_built or 0)..
      " ports="..tostring(frontier.segments or 0))
  end
  if frontier and frontier.status=="complete" then
    local port=frontier.source_port
    local cell=port and port.valid and port.logistic_cell
    local network=cell and cell.logistic_network
    -- Native merges can renumber logistics IDs. Compare the currently
    -- connected source and expanded ports, not the original cached ID.
    local source_read,source_network_id=pcall(function()
      local origin=s2.port
      local source_cell=origin and origin.valid and origin.logistic_cell
      local source_net=source_cell and source_cell.logistic_network
      if not(source_net and source_net.valid) then return nil end
      return source_net.network_id
    end)
    local poles=frontier.poles_built or 0
    local ports=frontier.segments or 0
    local pole_receipts,port_receipts=0,0
    for _ in pairs(test.pole_units) do pole_receipts=pole_receipts+1 end
    for _ in pairs(test.port_units) do port_receipts=port_receipts+1 end
    if not(port and port.valid and port.unit_number~=test.source_port
      and port.electric_network_id==test.grid
      and port.is_connected_to_electric_network()
      and port.energy>0 and network and network.valid~=false
      and source_read and type(source_network_id)=="number"
      and source_network_id>0
      and network.network_id==source_network_id
      and frontier.logistic_network_id==source_network_id
      and cell.is_in_logistic_range(root.roboport_expansion_goal_1076.target)
      and cell.is_in_construction_range(root.roboport_expansion_goal_1076.target)
      and poles>=1 and ports>=2
      and test.forward_port_receipts_1080==ports
      and pole_receipts==poles and port_receipts==ports
      and stock.get_item_count("medium-electric-pole")==
        test.initial_poles-(test.poles_by_builder[test.magos]or 0)
      and stock.get_item_count("roboport")==
        test.initial_ports-(test.ports_by_builder[test.magos]or 0)
      and senior_stock.get_item_count("medium-electric-pole")==
        test.initial_senior_poles-
          (test.poles_by_builder[test.senior_station]or 0)
      and senior_stock.get_item_count("roboport")==
        test.initial_senior_ports-
          (test.ports_by_builder[test.senior_station]or 0)
      and not frontier.pending and not root.construction_custody_0338
      and not root.construction_task_0338
      and not senior.construction_custody_0338
      and not senior.construction_task_0338
      and senior.priest.unit_number==test.senior_priest) then
      error("ROBOT_FRONTIER_1080_POWER_OR_PHYSICAL_CUSTODY_MISMATCH")
    end
    test.complete=true
    test.complete_tick_1080=game.tick
    emit("PASS ROBOT_FRONTIER_1080_POWERED_COVERAGE tick="..game.tick..
      " magos="..test.magos.." priest="..test.priest..
      " source_port="..test.source_port..
      " final_port="..port.unit_number..
      " electric="..test.grid.." logistic="..source_network_id..
      " poles="..poles.." ports="..ports..
      " successive_port_progress=true"..
      " pole_delta="..poles.." port_delta="..ports..
      " magos_poles="..(test.poles_by_builder[test.magos]or 0)..
      " magos_ports="..(test.ports_by_builder[test.magos]or 0)..
      " senior_poles="..(test.poles_by_builder[test.senior_station]or 0)..
      " senior_ports="..(test.ports_by_builder[test.senior_station]or 0)..
      " target_covered=true custody=physical-0338")
    return
  end
  if game.tick-test.started_tick>48000 then
    -- Two or more physical segments require separate legitimate 0338 trips.
    -- Preserve a finite timeout and all late-combat observations.
    -- Native failure evidence: a 1076 submission is not proof that the
    -- canonical 0338 builder was dispatched. Keep the exact current order,
    -- material stock, candidate identity and movement authority in the
    -- failure itself, even when the full engine artifact is unavailable.
    -- Read-only: never mutate custody, scheduling, or construction here.
    local candidate=root.construction_candidate_0338
    local task=root.construction_task_0338
    local receipt=root.construction_last_task_0338
    local queued=root.construction_request
    local attempt=tp.roboport_expansion_broker_1076
      and tp.roboport_expansion_broker_1076.last_attempt
    local order=root.order_queue_0469 and root.order_queue_0469.current
    local movement=root.movement_request_0418
    local diag=" stock_poles="..tostring(stock.get_item_count("medium-electric-pole"))..
      " stock_ports="..tostring(stock.get_item_count("roboport"))..
      " request="..tostring(queued and queued.entity_name)..
      " request_matches="..tostring(frontier and frontier.pending
        and queued==frontier.pending.request)..
      " candidate="..tostring(candidate and candidate.item_name)..
      " candidate_matches="..tostring(candidate and candidate.request_value==queued)..
      " task_phase="..tostring(task and task.phase)..
      " task_carried="..tostring(task and task.carried
        and task.carried.count)..
      " custody="..tostring(root.construction_custody_0338
        and root.construction_custody_0338.count)..
      " last_0338_phase="..tostring(receipt and receipt.phase)..
      " last_0338_result="..tostring(receipt and receipt.result)..
      " order_kind="..tostring(order and order.kind)..
      " action_family="..tostring(root.canonical_action_0744
        and root.canonical_action_0744.family)..
      " dispatch_family="..tostring(root.dispatcher_0510
        and root.dispatcher_0510.family)..
      " movement_owner="..tostring(movement and movement.owner)..
      " movement_reason="..tostring(movement and movement.reason)..
      " broker_tick="..tostring(attempt and attempt.tick)..
      " broker_detail="..tostring(attempt and attempt.detail)..
      " port_receipts="..tostring(test.forward_port_receipts_1080 or 0)..
      " remaining_to_goal="..tostring(test.last_port_distance_1080)
    -- CI mixed-world defense endurance must not silently skip the biter
    -- phase because one independent infrastructure gate failed earlier.
    -- Preserve the exact failure for the final native exit, but continue
    -- observing real industrial and combat functionality until the 123k
    -- checkpoint. No production feature or success assertion is weakened.
    if LATE_COMBAT_SMOKE then
      test.deferred_timeout_1094=true
      test.deferred_timeout_tick_1094=game.tick
      test.deferred_status_1094=tostring(frontier and frontier.status)
      test.deferred_reason_1094=tostring(frontier and frontier.blocked_reason)
      emit("ROBOT_FRONTIER_1080_TIMEOUT_DEFERRED_1094 tick="..game.tick..
        " status="..test.deferred_status_1094..
        " reason="..test.deferred_reason_1094..
        " native_acceptance_passed=false"..
        " late_biter_combat_continues=true"..diag)
      return
    end
    error("ROBOT_FRONTIER_1080_TIMEOUT status="..
      tostring(frontier and frontier.status)..
      " blocked="..tostring(frontier and frontier.blocked_reason)..
      " pending="..tostring(frontier and frontier.pending
        and frontier.pending.kind)..
      " poles="..tostring(frontier and frontier.poles_built)..
      " ports="..tostring(frontier and frontier.segments)..
      " broker="..tostring(tp.roboport_expansion_broker_1076
        and tp.roboport_expansion_broker_1076.last_attempt
        and tp.roboport_expansion_broker_1076.last_attempt.detail)..
      " construction="..tostring(root.construction_task_0338
        and root.construction_task_0338.phase)..diag)
  end
end

-- 1134: Native science factory throughput observer. Production and
-- consumption are read-only Force+Surface statistics from Factorio itself,
-- NOT the planner's forecasts or counts of unconfigured assembling machines.
-- No SPM gate is claimed until exact recipe, material/utility/throughput
-- construction acceptance is implemented; zero production must stay visible.
local SCIENCE_PACKS_1134={
  "automation-science-pack","logistic-science-pack",
  "military-science-pack","chemical-science-pack",
  "production-science-pack","utility-science-pack"
}
local function science_spm_native_observe_1134(state,elapsed)
  if not state.started_tick then return end
  local marks={3600,9000,18000,36000,72000,108000}
  state.science_spm_marks_1134=state.science_spm_marks_1134 or {}
  for _,mark in ipairs(marks)do
    if elapsed>=mark and not state.science_spm_marks_1134[mark] then
      local force=game.forces.player
      local surface=game.surfaces[1]
      local precision=defines.flow_precision_index
        and defines.flow_precision_index.one_minute
      local ok,stats=false,nil
      if force and surface and precision
          and type(force.get_item_production_statistics)=="function" then
        ok,stats=pcall(force.get_item_production_statistics,surface)
      end
      if not(ok and stats and stats.valid~=false
          and type(stats.get_flow_count)=="function")then
        emit("SCIENCE_SPM_1134 tick="..game.tick..
          " elapsed="..elapsed..
          " measurement=unavailable target_spm=5"..
          " native_acceptance_passed=false")
      else
        local measures={}
        local failed=false
        for _,item in ipairs(SCIENCE_PACKS_1134)do
          local a,produced=pcall(stats.get_flow_count,{
            name=item,category="input",precision_index=precision})
          local b,consumed=pcall(stats.get_flow_count,{
            name=item,category="output",precision_index=precision})
          if not(a and b and type(produced)=="number"
              and type(consumed)=="number" and produced>=0
              and consumed>=0)then
            failed=true
            measures[#measures+1]=item..":unavailable"
          else
            measures[#measures+1]=item..":"..
              string.format("%.3f",produced).."/"..
              string.format("%.3f",consumed)
          end
        end
        emit("SCIENCE_SPM_1134 tick="..game.tick..
          " elapsed="..elapsed..
          " target_spm=5 measurement="..
            (failed and "partial" or "factorio-native")..
          " scope=player-force-nauvis-surface"..
          " each_science_pack=produced_per_minute/consumed_per_minute"..
          " values="..table.concat(measures,",")..
          " native_acceptance_passed=false")
      end
      state.science_spm_marks_1134[mark]=true
    end
  end
end

-- 1187: dedicated native Conclave witness in the *existing* 123k
-- late-combat Factorio run. A physically placed CI Conclave Center is
-- test infrastructure, NOT a player-crafted center or a claim that the
-- factory has met 5 SPM. Production and research are untouched.
local function conclave_native_center_1187(state)
  if state.conclave_native_1187 then return end
  local surface=game.surfaces[1]
  local force=game.forces.player
  if not (prototypes.entity["tech-priests-conclave-center"]
      and CONCLAVE_NATIVE_OWNER_1192
      and type(CONCLAVE_NATIVE_OWNER_1192
        .register_native_fixture_center_1192)=="function") then
    error("CONCLAVE_NATIVE_1187_NO_PHYSICAL_CENTER_OR_CANONICAL_REGISTRAR")
  end
  local center=nil
  local sites={
    {x=205,y=25},{x=190,y=25},{x=215,y=-25},
    {x=180,y=-25},{x=160,y=24},{x=150,y=-24}
  }
  for _,position in ipairs(sites) do
    if not center and surface.can_place_entity{
        name="tech-priests-conclave-center",
        position=position,force=force} then
      center=surface.create_entity{
        name="tech-priests-conclave-center",
        position=position,force=force}
    end
  end
  if not (center and center.valid and center.unit_number) then
    error("CONCLAVE_NATIVE_1187_PHYSICAL_CENTER_PLACEMENT_REFUSED")
  end
  local registered,registration_reason=
    CONCLAVE_NATIVE_OWNER_1192.register_native_fixture_center_1192(
      center)
  if not registered then
    error("CONCLAVE_NATIVE_1187_CANONICAL_REGISTRATION_REFUSED:"..
      tostring(registration_reason))
  end
  local root=storage.tech_priests
    and storage.tech_priests.conclave_center_0558
  local listed=root and root.centers_by_force
    and root.centers_by_force[force.name]
  if not (listed and listed[center.unit_number]==center) then
    error("CONCLAVE_NATIVE_1187_CENTER_EVENT_NOT_REGISTERED")
  end
  -- 1212: a registered callback is NOT necessarily an active engine
  -- listener. Native Factorio 2.0.77 observed three Conclave research
  -- routes while the real on_research_finished handler was overwritten.
  -- Refuse at tick 1800 rather than waste a 123k engine run that can
  -- never receive the research event. Do not manufacture an event.
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local delivery=registry and registry.event_delivery_status
    and registry.event_delivery_status(defines.events.on_research_finished)
  if not(delivery and delivery.installed and delivery.verified
      and not delivery.filter_present and delivery.routes>=1) then
    error("CONCLAVE_NATIVE_1187_ENGINE_RESEARCH_DISPATCH_UNVERIFIED"..
      " installed="..tostring(delivery and delivery.installed)..
      " verified="..tostring(delivery and delivery.verified)..
      " routes="..tostring(delivery and delivery.routes)..
      " filter_present="..tostring(delivery and delivery.filter_present))
  end
  state.conclave_native_1187={
    center=center,placed_tick=game.tick,completed=false,
  }
  emit("CONCLAVE_NATIVE_1187_CENTER_REGISTERED tick="..game.tick..
    " original_force="..force.name..
    " physical_center="..center.unit_number..
    " canonical_ci_registration=true"..
    " research_dispatch_verified=true event_proof=false")
end

-- This arms a test-specific near-zero political starting condition only
-- AFTER all normal factory/defense acceptance checkpoints. It proves
-- engine-native faction transfer, not natural erosion from 100 loyalty.
-- The research precondition, however, is a real on_research_finished event
-- earned by the factory's normal science production and lab consumption.
local function conclave_native_schism_prepare_1187(state)
  local rec=state.conclave_native_1187
  if not (rec and rec.center and rec.center.valid) then
    error("CONCLAVE_NATIVE_1187_CENTER_LOST_BEFORE_RESEARCH")
  end
  if rec.armed_tick then return end
  local root=storage.tech_priests
    and storage.tech_priests.conclave_center_0558
  local government=root and root.force_state
    and root.force_state.player
  local force=game.forces.player
  if not (government and government.last_research_tick
      and government.last_research_tick>rec.placed_tick
      and government.last_research_family
      and force.technologies["automation"]
      and force.technologies["automation"].researched) then
    -- 1198: distinguish genuine incomplete/reassigned research from a
    -- lost registry callback. This is read-only failure evidence and MUST
    -- never weaken the completed-technology/event acceptance gate.
    local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
    local status=nil
    if registry and type(registry.event_delivery_status)=="function" then
      local ok,observed=pcall(registry.event_delivery_status,
        defines.events.on_research_finished)
      if ok then status=observed end
    end
    local center_list=root and root.centers_by_force
      and root.centers_by_force[force.name]
    local current=force.current_research
    error("CONCLAVE_NATIVE_1187_NO_REAL_POST_CENTER_RESEARCH"..
      " placed_tick="..tostring(rec.placed_tick)..
      " last_event_tick="..tostring(government and government.last_research_tick)..
      " last_family="..tostring(government and government.last_research_family)..
      " current_research="..tostring(current and current.name)..
      " automation_researched="..tostring(
        force.technologies["automation"] and
        force.technologies["automation"].researched)..
      " center_registered="..tostring(
        center_list and center_list[rec.center.unit_number]==rec.center)..
      " event_dispatch_verified="..tostring(status and status.verified)..
      " event_routes="..tostring(status and status.routes)..
      " event_filter_present="..tostring(status and status.filter_present))
  end
  -- Select the original real senior pair, never create a phantom pair.
  local station=game.surfaces[1].find_entities_filtered{
    name="senior-cogitator-station",force=force,
    position={x=128,y=0},radius=3,limit=1}[1]
  local pair=station and station.valid and storage.tech_priests
    and storage.tech_priests.pairs_by_station
    and storage.tech_priests.pairs_by_station[station.unit_number]
  if not (pair and pair.priest and pair.priest.valid
      and pair.priest.force==force
      and pair.station==station) then
    error("CONCLAVE_NATIVE_1187_ORIGINAL_SENIOR_PAIR_NOT_LIVE")
  end
  -- An explicit Conclave family on this one test pair makes its
  -- intended industry defection deterministic; no research is granted.
  pair.doctrine_family="industry"
  government.loyalty.industry=0
  rec.station=station
  rec.priest=pair.priest
  rec.station_unit=station.unit_number
  rec.priest_unit=pair.priest.unit_number
  rec.pair=pair
  rec.research_tick=government.last_research_tick
  rec.research_family=government.last_research_family
  rec.armed_tick=game.tick
  rec.verify_after=(math.floor(game.tick/607)+1)*607+60
  emit("CONCLAVE_NATIVE_1187_REAL_RESEARCH tick="..game.tick..
    " research=automation earned=true"..
    " event_tick="..rec.research_tick..
    " family="..tostring(rec.research_family)..
    " finished_prototype=true science_grants=0")
  emit("CONCLAVE_NATIVE_1187_TEST_UNREST_ARMED tick="..game.tick..
    " artificially_zero_loyalty=true original_station="..
    tostring(rec.station_unit).." original_priest="..
    tostring(rec.priest_unit)..
    " original_force="..force.name..
    " wait_until="..rec.verify_after)
end

local function conclave_native_schism_verify_1187(state)
  local rec=state.conclave_native_1187
  if not(rec and rec.armed_tick) then
    error("CONCLAVE_NATIVE_1187_NOT_ARMED")
  end
  if game.tick<rec.verify_after then return false end
  local root=storage.tech_priests.conclave_center_0558
  local gov=root and root.force_state and root.force_state.player
  local web=gov and gov.doctrine_web_0588
  local rogue=game.forces["tech-priests-rogue-industry"]
  if not(rogue and rogue.valid
      and rec.station.valid and rec.priest.valid
      and rec.station.unit_number==rec.station_unit
      and rec.priest.unit_number==rec.priest_unit
      and rec.station.force==rogue
      and rec.priest.force==rogue
      and rec.pair.rogue_doctrine_0588==true
      and rec.pair.rogue_original_force_0588=="player"
      and rec.pair.rogue_force_0589==rogue.name
      and gov and gov.loyalty.industry==100) then
    error("CONCLAVE_NATIVE_1187_PHYSICAL_DEFECTION_REFUSED"..
      " station_force="..tostring(rec.station.force.name)..
      " priest_force="..tostring(rec.priest.force.name)..
      " rogue="..tostring(rogue and rogue.name)..
      " blocker="..tostring(rec.pair.last_blocker_0590))
  end
  if not (game.forces.player.get_cease_fire(rogue)==false
      and rogue.get_cease_fire(game.forces.player)==false
      and game.forces.player.get_friend(rogue)==false
      and rogue.get_friend(game.forces.player)==false) then
    error("CONCLAVE_NATIVE_1187_ROGUE_NOT_HOSTILE")
  end
  local witness=nil
  for _,wave in ipairs(web and web.schism_waves or {}) do
    if wave.family=="industry" and wave.force==rogue.name
        and wave.tick>=rec.armed_tick and (wave.converted or 0)>=1 then
      witness=wave
      break
    end
  end
  if not witness then
    error("CONCLAVE_NATIVE_1187_MISSING_VERIFIED_CONVERSION_WAVE")
  end
  rec.completed=true
  emit("PASS CONCLAVE_NATIVE_1187_GENUINE_RESEARCH_AND_FORCE_SCHISM"..
    " tick="..game.tick..
    " original_research_tick="..rec.research_tick..
    " test_zero_loyalty=true"..
    " station_unit="..rec.station_unit..
    " priest_unit="..rec.priest_unit..
    " original_force=player rogue_force="..rogue.name..
    " converted="..tostring(witness.converted)..
    " hostility_verified=true counted_items_created=0")
  return true
end


-- 1291: These CI-initialized, real engine stations are not materials earned,
-- a remote acquisition gate, or a construction receipt. Use only the
-- canonical 0600 broker; normal gameplay and physical ledgers are unchanged.
local function ci_five_setup_1291(state)
  local surface,force=game.surfaces[1],game.forces.player
  local specs={
    {"junior-cogitator-station",0},
    {"intermediate-cogitator-station",64},
    {"senior-cogitator-station",128},
    {"planetary-magos-cogitator-station",192},
    {"junior-cogitator-station",256}}
  if CI_PROFILE_POPULATION_1291==25 or CI_PROFILE_POPULATION_1291==100 then
    -- CI-only real stations, not earned construction or resource credit.
    local names={
      "junior-cogitator-station","intermediate-cogitator-station",
      "senior-cogitator-station","planetary-magos-cogitator-station",
      "junior-cogitator-station"}
    specs={}
    local cols=CI_PROFILE_POPULATION_1291==100 and 10 or 5
    for i=0,CI_PROFILE_POPULATION_1291-1 do
      specs[#specs+1]={names[(i%5)+1],(i%cols)*64,math.floor(i/cols)*64}
    end
  end
  for _,s in ipairs(specs) do
    surface.request_to_generate_chunks({x=s[2],y=s[3] or 0},2)
  end
  surface.force_generate_chunk_requests()
  local units={}
  for index,s in ipairs(specs) do
    local origin={x=s[2],y=s[3] or 0}
    local pos=surface.find_non_colliding_position(s[1],origin,32,2)
    if CI_PROFILE_POPULATION_1291==100 then
      -- The real 100-site native create refused a station after a collision
      -- search returned a candidate. Verify the actual engine placement
      -- predicate, then try a small, deterministic and bounded set of nearby
      -- sites. Never count an unbuilt station or bypass the built event.
      local offsets={
        {0,0},{16,0},{-16,0},{0,16},{0,-16},
        {16,16},{-16,16},{16,-16},{-16,-16},
        {32,0},{-32,0},{0,32},{0,-32}}
      local checked={}
      pos=nil
      for _,delta in ipairs(offsets) do
        local center={x=origin.x+delta[1],y=origin.y+delta[2]}
        local candidate=surface.find_non_colliding_position(s[1],center,32,2)
        if candidate then
          local key=tostring(candidate.x)..":"..tostring(candidate.y)
          if not checked[key] then
            checked[key]=true
            if surface.can_place_entity{
                name=s[1],position=candidate,force=force} then
              pos=candidate
              break
            end
          end
        end
      end
    end
    if not pos then
      error("CI_FIVE_PROFILE_1291_NO_PLACEABLE_SITE index="..index..
        " name="..s[1].." origin="..origin.x..","..origin.y)
    end
    local entity=surface.create_entity{
      name=s[1],position=pos,force=force,raise_built=true}
    if not(entity and entity.valid and entity.unit_number) then
      error("CI_FIVE_PROFILE_1291_STATION_REFUSED index="..index..
        " name="..s[1].." pos="..pos.x..","..pos.y..
        " can_place_prechecked="..tostring(CI_PROFILE_POPULATION_1291==100))
    end
    units[#units+1]=entity.unit_number
  end
  state.started_tick=game.tick
  state.ci_five_1291={units=units,started=game.tick,
    requested=CI_PROFILE_POPULATION_1291,
    samples=0,bad=0,priest_ids={}}
  emit("CI_FIVE_PROFILE_1291_CREATED tick="..game.tick..
    " stations="..#units.." requested="..CI_PROFILE_POPULATION_1291..
    " setup=ci-only-real-entities")
end


-- Sample counters from authoritative broker/movement readback at the five-pair
-- native boundaries; absent counters are unmeasured, not inferred zero.
local function ci_five_activity_snapshot_1291()
  local tp=storage and storage.tech_priests or {}
  local broker=tp.runtime_tick_broker_0600 or {}
  local ext=broker.external_stats or {}
  local movement=tp.movement_controller_0419 or {}
  local ms=movement.stats or {}
  local function observed(obj,key)
    local value=obj[key]
    if type(value)=="number" and value>=0 then return value end
    return false
  end
  local processed,blocked,service_seen=0,0,false
  for _,service in pairs(broker.service_stats or {}) do
    if type(service.processed)~="number"
        or type(service.blocked)~="number" then
      processed=false
      blocked=false
      break
    end
    service_seen=true
    processed=processed+service.processed
    blocked=blocked+service.blocked
  end
  return {
    routed_scans=observed(ext,"scans_attempted"),
    direct_scans=observed(ext,"direct_surface_scans"),
    movement_requests=observed(ext,"path_requests"),
    movement_collapses=observed(ext,"path_requests_collapsed"),
    movement_priority_denials=observed(ms,"lower_priority_retargets_denied"),
    movement_stalled_repaths=observed(ms,"stalled_repaths"),
    broker_processed=service_seen and processed or false,
    broker_blocked=service_seen and blocked or false,
  }
end

local function ci_five_sample_1291(state)
  local rec=state.ci_five_1291
  local requested=rec and rec.requested or 5
  if not rec or state.finished or game.tick-rec.started<600 then return end
  local total=ci_live_paired_priest_population_1071()
  local pairs=storage.tech_priests.pairs_by_station or {}
  local seen,original,identities,current_ids={},0,true,{}
  for _,unit in ipairs(rec.units) do
    local pair=pairs[unit]
    local station=pair and pair.station
    local priest=pair and pair.priest
    if not(station and station.valid and station.unit_number==unit
        and priest and priest.valid and priest.unit_number
        and priest.force==station.force and not seen[priest.unit_number]) then
      identities=false
    else
      seen[priest.unit_number]=true
      original=original+1
      current_ids[unit]=priest.unit_number
    end
  end

  -- The native baseline starts when *all five* actual station/priest pairs
  -- exist, not a fixed 600 ticks after placing the CI-only stations. The
  -- preceding engine run observed ZERO live pairs at tick 600 and five at
  -- tick 11880; crediting that startup interval as a five-pair baseline
  -- would invalidate the population provenance. Never manufacture a pair
  -- or replace a lost identity to satisfy the profiler.
  if not rec.window_start_tick then
    if total~=requested or original~=requested or not identities then
      if (game.tick-rec.started)%3000==0 then
        emit("CI_FIVE_PROFILE_1291_WAITING tick="..game.tick..
          " all="..total.." original="..original.." requested="..requested)
      end
      if game.tick-rec.started>=29880 then
        emit("CI_FIVE_PROFILE_1291_UNAVAILABLE reason=no_complete_requested_pair_window"..
          " tick="..game.tick.." all="..total.." original="..original)
        state.finished=true
      end
      return
    end
    rec.window_start_tick=game.tick
    -- CI-only native broker sampling, never station/item acceptance.
    _G.TP_CI_RUNTIME_PROFILE_1064=true
    rec.priest_ids=current_ids
    rec.activity_start=ci_five_activity_snapshot_1291()
    rec.activity_start_tick=game.tick
    emit("CI_FIVE_PROFILE_1291_START tick="..game.tick..
      " all="..total.." original="..original.." requested="..requested)
  end

  -- From the first real five-pair observation onward, reject every lost
  -- original, any unexpected additional pair and every identity replacement.
  for _,unit in ipairs(rec.units) do
    if rec.priest_ids[unit]~=current_ids[unit] then identities=false end
  end
  rec.samples=rec.samples+1
  if total~=requested or original~=requested or not identities then rec.bad=rec.bad+1 end
  if game.tick-rec.window_start_tick>=11280 then
    _G.TP_CI_RUNTIME_PROFILE_1064=false
    emit("CI_FIVE_PROFILE_1291_END tick="..game.tick..
      " all="..total.." original="..original.." requested="..requested..
      " samples="..rec.samples.." bad="..rec.bad..
      " identity_stable="..tostring(rec.bad==0).." interval=60")
    local after=ci_five_activity_snapshot_1291()
    local function delta(key)
      local before=rec.activity_start and rec.activity_start[key]
      local now=after[key]
      if type(before)=="number" and type(now)=="number" and now>=before then
        return tostring(now-before)
      end
      return "unmeasured"
    end
    emit("CI_FIVE_PROFILE_1291_ACTIVITY start_tick="..
      tostring(rec.activity_start_tick or -1)..
      " end_tick="..game.tick..
      " routed_scans="..delta("routed_scans")..
      " direct_scans="..delta("direct_scans")..
      " movement_requests="..delta("movement_requests")..
      " movement_collapses="..delta("movement_collapses")..
      " movement_priority_denials="..delta("movement_priority_denials")..
      " movement_stalled_repaths="..delta("movement_stalled_repaths")..
      " broker_processed="..delta("broker_processed")..
      " broker_blocked="..delta("broker_blocked"))
    state.finished=true
  elseif game.tick-rec.started>=29880 then
    emit("CI_FIVE_PROFILE_1291_UNAVAILABLE reason=insufficient_stable_window"..
      " tick="..game.tick.." samples="..rec.samples)
    state.finished=true
  end
end

local function initialize_fixture()
  storage.tech_priests=storage.tech_priests or {}
  local state=storage.tech_priests.ci_ground_rank_test or {}
  storage.tech_priests.ci_ground_rank_test=state
  if state.started_tick or state.failed then return end
  if CI_FIVE_PROFILE_1291 then
    local ok,err=pcall(ci_five_setup_1291,state)
    if not ok then
      state.failed=tostring(err)
      emit("CI_FIVE_PROFILE_1291_UNAVAILABLE reason="..state.failed)
    end
    return
  end
  local ok,err=pcall(function()
    setup_fixture()
    prestock_fixture(state)
    verify_laser_mining_rate()
    drill_engine_prepare_0985(state)
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
  if CI_FIVE_PROFILE_1291 then
    if state.started_tick and not state.finished and not state.failed then
      local ok,err=pcall(ci_five_sample_1291,state)
      if not ok then
        state.failed=tostring(err)
        emit("CI_FIVE_PROFILE_1291_UNAVAILABLE reason="..state.failed)
      end
    end
    return {processed=1,acted=0,detail="optional-ci-five-pair-profile"}
  end
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
      if rawget(_G,"TP_CI_STOCK_RELOAD_PROBE")==true then
        robot_engine_s2_service_1071(state)
        robot_frontier_native_1080(state)
      end
      if drill_engine_first_process_attach_0986(state) then
        drill_engine_prepare_0985(state)
        emit("DRILL_ENGINE_0986_LATE_ATTACH tick="..game.tick..
          " initial_save_requested=false")
      end
      drill_engine_observe_target_0989(state)
      if rawget(_G,"TP_CI_COURIER_RELOAD_PROBE")==true
          and not state.drill_engine_reload_verified_0985 then
        drill_engine_reload_0985(state)
      end
      if elapsed>=3000 and state.save_reload_verified
          and not state.drill_engine_verified_0985 then
        drill_engine_verify_0985(state)
      end
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
        ore_engine_native_service_1014(state)
      end
      if state.ore_engine and state.ore_engine.natural_return_verified
          and state.relocation_engine
          and state.relocation_engine.phase=="complete"
          and not state.reversal_engine then
        reversal_engine_place(state)
      end
      if state.reversal_engine then
        -- The five-station reversal shares a live mixed-population map.
        -- The nonserializable profiler is created/stopped in each broker pulse.
        local active=state.reversal_engine.phase~="reversal-natural-ore-return-complete"
        if active and not state.profile_window_started_1064 then
          state.profile_window_started_1064=game.tick
          state.profile_window_counters_1067=ci_activity_counters_1067()
          emit("RUNTIME_PROFILE_WINDOW_1064_START tick="..game.tick..
            " scope=broker-pulse population=mixed reversal_priests=5")
          emit("RUNTIME_PAIRED_POPULATION_1071 boundary=start tick="..game.tick..
            " pairs="..ci_live_paired_priest_population_1071()..
            " scope=live-paired-all-forces")
        end
        _G.TP_CI_RUNTIME_PROFILE_1064=active
        reversal_engine_verify(state)
        reversal_engine_first_depot(state)
        reversal_engine_second_depot(state)
        reversal_engine_later_depots(state)
        reversal_engine_outbound_senior(state)
        reversal_engine_outbound_transit(state)
        reversal_engine_outbound_senior_build(state)
        reversal_engine_intermediate_ghost(state)
        reversal_engine_intermediate_pickup(state)
        reversal_engine_intermediate_transit(state)
        reversal_engine_intermediate_build(state)
        reversal_engine_first_junior_ghost(state)
        reversal_engine_first_junior_pickup(state)
        reversal_engine_first_junior_transit(state)
        reversal_engine_first_junior_build(state)
        reversal_engine_second_junior_ghost(state)
        reversal_engine_second_junior_pickup(state)
        reversal_engine_second_junior_transit(state)
        reversal_engine_second_junior_build(state)
        reversal_engine_natural_ore_return(state)
        if state.reversal_engine.phase=="reversal-natural-ore-return-complete"
            and not state.profile_window_finished_1064 then
          state.profile_window_finished_1064=game.tick
          _G.TP_CI_RUNTIME_PROFILE_1064=false
          emit("RUNTIME_PROFILE_WINDOW_1064_END tick="..game.tick..
            " scope=broker-pulse population=mixed reversal_priests=5")
          emit("RUNTIME_PAIRED_POPULATION_1071 boundary=end tick="..game.tick..
            " pairs="..ci_live_paired_priest_population_1071()..
            " scope=live-paired-all-forces")
          local before=state.profile_window_counters_1067
          if before then
            local after=ci_activity_counters_1067()
            local function delta(key) return after[key]-before[key] end
            emit("RUNTIME_ACTIVITY_WINDOW_1067 tick="..game.tick..
              " start_tick="..state.profile_window_started_1064..
              " population=mixed"..
              " routed_scans="..delta("routed_scans")..
              " direct_scans="..delta("direct_scans")..
              " movement_requests="..delta("movement_requests")..
              " movement_collapses="..delta("movement_collapses")..
              " movement_priority_denials="..delta("movement_priority_denials")..
              " movement_stalled_repaths="..delta("movement_stalled_repaths")..
              " broker_processed="..delta("broker_processed")..
              " broker_blocked="..delta("broker_blocked"))
          end
        end
      end
      if elapsed>=39000 and not (state.ore_engine
          and state.ore_engine.phase=="complete") then
        error("ORE_ENGINE_COUNTED_RETURN_TIMEOUT")
      end
      if elapsed>=60000 and not (state.ore_engine
          and state.ore_engine.native_1014
          and state.ore_engine.native_1014.phase=="complete") then
        error("ORE_ENGINE_NATIVE_CONSTRUCTION_FUEL_AND_ORE_RETURN_TIMEOUT")
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
    science_spm_native_observe_1134(state,elapsed)
    -- 1210: The real automation research can finish BEFORE tick 108000.
    -- A Conclave Center constructed only then sees no completion event in
    -- the remaining late-combat window, even when laboratory research
    -- actually occurred. Register the physical center while the early
    -- factory is still pre-lab (observed native tick 1800: labs=0,
    -- research=none), then keep the dangerous unrest/schism challenge
    -- gated until AFTER tick 122400 combat and factory acceptance below.
    -- No technology is unlocked, completed or granted by this fixture.
    if LATE_COMBAT_SMOKE and not SAVE_RELOAD_SMOKE
        and elapsed>=1800 and not state.conclave_native_1187 then
      conclave_native_center_1187(state)
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
    -- 1280: sample actual 2.1 furnace feed authority early, not just
    -- at 108k. Engine inventory and storage custody are read-only here.
    if LATE_COMBAT_SMOKE and elapsed>=9000 and not state.feed_probe_1280 then
      for _,spec in ipairs(stations) do
        local found=game.surfaces[1].find_entities_filtered({
          name=spec.name,position={spec.x,spec.y},radius=2,
          force=game.forces.player})
        local station=found and found[1]
        if station and station.valid then
          local pair=storage.tech_priests.pairs_by_station
            and storage.tech_priests.pairs_by_station[station.unit_number]
          local diag=pair and pair.emergency_facility_input_diagnostic_0357
          local chest=station.get_inventory(defines.inventory.chest)
          local furnaces=game.surfaces[1].find_entities_filtered({
            name="tech-priests-emergency-smelter",
            position=station.position,radius=36,force=station.force})
          local found_input=0
          local found_iron,found_copper=0,0
          for _,furnace in ipairs(furnaces or {}) do
            local inv_id=crafter_index_1277("input","furnace")
            local inv=nil
            if inv_id then
              local ok,actual=pcall(function()return furnace.get_inventory(inv_id)end)
              if ok and actual and actual.valid then inv=actual end
            end
            if inv then
              found_input=found_input+1
              found_iron=found_iron+inv.get_item_count("iron-ore")
              found_copper=found_copper+inv.get_item_count("copper-ore")
            end
          end
          emit("FEED_PROBE_1280 rank="..spec.name..
            " tick="..game.tick..
            " station_iron="..tostring(chest and chest.valid
              and chest.get_item_count("iron-ore") or 0)..
            " station_copper="..tostring(chest and chest.valid
              and chest.get_item_count("copper-ore") or 0)..
            " furnaces="..tostring(#(furnaces or {}))..
            " valid_furnace_inputs="..tostring(found_input)..
            " input_iron="..tostring(found_iron)..
            " input_copper="..tostring(found_copper)..
            " feed_phase="..tostring(diag and diag.phase)..
            " feed_recipe="..tostring(diag and diag.recipe)..
            " feed_item="..tostring(diag and diag.source_item)..
            " feed_source_stock="..tostring(diag and diag.source_stock)..
            " feed_source_slots="..tostring(diag and diag.source_slots)..
            " engine_input_valid="..tostring(diag and diag.engine_input_available)..
            " accepts_one="..tostring(diag and diag.engine_accepts_one)..
            " feed_request="..tostring(diag and diag.requested)..
            " feed_moved="..tostring(diag and diag.moved)..
            " custody_blocked="..tostring(diag and diag.pending_feed_custody))
        end
      end
      state.feed_probe_1280=true
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
      if elapsed>=116400 and state.reassault_started_tick
          and not state.escalation_started_tick_1092 then
        combat_escalation_wave_1092(state)
      end
      for _,mark in ipairs({110400,114000,118800}) do
        if elapsed>=mark and not (state.combat_marks and state.combat_marks[mark]) then
          combat_checkpoint(state,false)
          state.combat_marks=state.combat_marks or {}
          state.combat_marks[mark]=true
        end
      end
      if elapsed>=122400 and not state.combat_final_checked_1187 then
        -- Finish all genuine combat/ore/factory checks BEFORE the CI
        -- political unrest challenge may change the original senior force.
        combat_checkpoint(state,true)
        local native_frontier=state.robot_frontier_native_1080
        if native_frontier and native_frontier.deferred_timeout_1094
            and not native_frontier.complete then
          error("ROBOT_FRONTIER_1080_TIMEOUT_AFTER_REAL_COMBAT tick="..
            game.tick.." original_tick="..
            tostring(native_frontier.deferred_timeout_tick_1094)..
            " reason="..tostring(native_frontier.deferred_reason_1094))
        end
        state.combat_final_checked_1187=true
      end
      if state.combat_final_checked_1187 and not state.finished
          and not SAVE_RELOAD_SMOKE then
        conclave_native_schism_prepare_1187(state)
        if conclave_native_schism_verify_1187(state) then
          state.finished=true
        end
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
  if SAVE_RELOAD_SMOKE then
    local robot_observer=registry.on_event(
      defines.events.on_robot_built_entity,
      robot_engine_s2_built_observe_1071,nil,{
        owner="ci_ground_rank_harness",
        route="S2-read-only-native-robot-built-observer",
        category="diagnostics",priority=1100})
    if not robot_observer then
      error("ROBOT_ENGINE_S2_NATIVE_EVENT_OBSERVER_UNAVAILABLE")
    end
  end
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
