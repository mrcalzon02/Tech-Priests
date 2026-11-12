-- Isolated native Method II checkpoint: autonomous 0259 discovery ONLY.
-- This fixture provides real powered infrastructure/robots and a physically
-- mined Intermediate station item; it never injects a 1076 objective, creates
-- ore, impersonates an on_robot_built_entity event or constructs the target.
-- It is not packaged with the production mod or a substitute for ore return.
local M={}
local KEY="ci_autonomous_robot_1380"
local PREFIX="[TP-AUTONOMOUS-ROBOT-1380] "
local SURFACE="tp-ci-autonomous-robot-1380"
local function emit(s) log(PREFIX..s) end
local function fail(s) error(PREFIX.."FAIL "..s) end
local function state()
  storage.tech_priests=storage.tech_priests or {}
  local tp=storage.tech_priests
  tp[KEY]=tp[KEY] or {phase="search",seed_offset=0}
  return tp[KEY]
end
local function item_count(container,name)
  local inventory=container and container.valid
    and container.get_inventory(defines.inventory.chest)
  return inventory and inventory.valid and inventory.get_item_count(name)
end
local function place(surface,force,name,x,y,raised)
  local spec={name=name,position={x=x,y=y},force=force,
    raise_built=raised==true}
  if not surface.can_place_entity(spec) then
    fail("NATIVE_PLACEMENT_REFUSED item="..name.." x="..x.." y="..y)
  end
  local entity=surface.create_entity(spec)
  if not(entity and entity.valid) then fail("NATIVE_ENTITY_MISSING "..name) end
  return entity
end
local function candidate_ore(surface)
  local orelist=surface.find_entities_filtered{
    name="iron-ore",type="resource",area={{70,12},{110,43}}}
  for _,ore in ipairs(orelist) do
    if ore.valid and ore.amount>=2 and ore.position then
      local products=ore.prototype and ore.prototype.mineable_properties
        and ore.prototype.mineable_properties.products
      for _,product in pairs(products or {}) do
        if product.type=="item" and product.name=="iron-ore" then
          return ore
        end
      end
    end
  end
end
local function create_native_site(s)
  if s.phase~="search" then return end
  -- The production 0595/0596 idle-world gate correctly suspends broker ticks
  -- before the first real Magos pair. A diagnostic broker-only bootstrap
  -- therefore cannot start an empty native save. Select an actual generated
  -- natural patch ON INIT, using unique bounded candidate surfaces so Factorio
  -- can retire rejected surfaces asynchronously without reusing their names.
  -- No resource is created or counted as mined by this search.
  local surface,settings,ore
  while s.seed_offset<64 do
    local name=SURFACE.."-"..tostring(s.seed_offset)
    if game.surfaces[name] then fail("UNOWNED_TEST_SURFACE") end
    settings=game.surfaces[1].map_gen_settings
    settings.seed=1380001+s.seed_offset
    settings.autoplace_controls=settings.autoplace_controls or {}
    settings.autoplace_controls["enemy-base"]={frequency=0,size=0,richness=0}
    surface=game.create_surface(name,settings)
    if not(surface and surface.valid) then fail("NATIVE_SURFACE_MISSING") end
    surface.request_to_generate_chunks({x=64,y=18},4)
    surface.force_generate_chunk_requests()
    ore=candidate_ore(surface)
    if ore then break end
    if not game.delete_surface(surface) then fail("SURFACE_DELETE_REFUSED") end
    s.seed_offset=s.seed_offset+1
  end
  if not ore then fail("NO_NATURAL_IRON_IN_64_GENERATED_SEEDS") end
  -- Keep the selected patch unmodified: only the staging corridor is cleared.
  -- Every actual ore item must later come from a native resource.mine() call.
  local area={{-12,-12},{90,42}}
  for _,entity in pairs(surface.find_entities_filtered{area=area}) do
    if entity.valid and (entity.position.x<70 or entity.position.y<12) then
      if entity.type=="resource" or entity.type=="tree"
        or entity.type=="cliff" or entity.type=="simple-entity" then
        entity.destroy()
      else fail("UNEXPECTED_OCCUPIED_SITE "..entity.name) end
    end
  end
  local tiles={}
  for x=-12,90 do for y=-12,42 do
    if x<70 or y<12 then
      tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
    end
  end end
  surface.set_tiles(tiles,true)
  local force=game.forces.player
  -- Native, physically powered pre-existing infrastructure for the first
  -- already-covered stage. No electric-energy-interface or ghost credit.
  for _,x in ipairs({18,34,50,66,82}) do
    place(surface,force,"substation",x,8)
  end
  place(surface,force,"substation",18,24)
  place(surface,force,"substation",66,24)
  for _,x in ipairs({10,14,22,26}) do
    for _,y in ipairs({18,22,26,30}) do
      place(surface,force,"solar-panel",x,y)
    end
  end
  for _,x in ipairs({10,14,22,26}) do
    place(surface,force,"accumulator",x,14)
  end
  local near_port=place(surface,force,"roboport",18,0)
  place(surface,force,"roboport",46,0)
  local port=place(surface,force,"roboport",80,0)
  local provider=place(surface,force,"passive-provider-chest",80,6)
  local robot_inv=port.get_inventory(defines.inventory.roboport_robot)
  if not(robot_inv and robot_inv.valid
    and robot_inv.insert{name="construction-robot",count=3}==3) then
    fail("REAL_PREEXISTING_CONSTRUCTION_ROBOT_SUPPLY_FAILED")
  end
  local provider_inv=provider.get_inventory(defines.inventory.chest)
  local source=place(surface,force,"intermediate-cogitator-station",55,35)
  local original_source=source.unit_number
  if not(source.mine{inventory=provider_inv}==true and not source.valid
    and provider_inv.get_item_count("intermediate-cogitator-station")==1) then
    fail("INTERMEDIATE_ITEM_NOT_PHYSICALLY_MINED_INTO_PROVIDER")
  end
  -- A real powered radar, not a forced chart or hidden map observation,
  -- must reveal the naturally generated patch to the production 0259 planner.
  local radar=place(surface,force,"radar",66,20)
  local magos=place(surface,force,
    "planetary-magos-cogitator-station",0,0,true)
  local senior=place(surface,force,"senior-cogitator-station",55,12,true)
  s.phase="awaiting-native-strategy"
  s.started_tick=game.tick
  s.surface=surface
  s.ore=ore
  s.ore_initial=ore.amount
  s.magos=magos.unit_number
  s.senior=senior.unit_number
  s.provider=provider
  s.port=port
  s.radar=radar
  s.original_source=original_source
  emit("NATIVE_PHYSICAL_SOURCE tick="..game.tick..
    " seed="..settings.seed.." magos="..s.magos..
    " senior="..s.senior.." provider="..provider.unit_number..
    " original_source="..original_source.." item=1 robots_docked=3"..
    " natural_ore_unit="..ore.unit_number..
    " ore_amount="..s.ore_initial.." generated=true chart_forced=false")
end
local function observed_robot(event)
  local s=state()
  if s.phase~="awaiting-native-robot-build" then return end
  local entity=event.entity or event.created_entity
  local robot=event.robot
  if not(entity and entity.valid and robot and robot.valid
    and entity.name=="intermediate-cogitator-station"
    and entity.surface==s.surface and robot.surface==s.surface
    and robot.force==entity.force and robot.type=="construction-robot") then
    return
  end
  if s.event_station then fail("DUPLICATE_NATIVE_ROBOT_BUILD") end
  s.event_station=entity.unit_number
  s.event_robot=robot.unit_number
  s.event_tick=game.tick
  emit("NATIVE_ROBOT_EVENT tick="..game.tick..
    " station="..s.event_station.." robot="..s.event_robot..
    " event=on_robot_built_entity")
end
local function pulse()
  local s=state()
  if s.finished or s.failed then return {processed=0,detail="finished"} end
  local ok,err=pcall(function()
    if s.phase=="search" then create_native_site(s);return end
    if not(s.surface and s.surface.valid and s.ore and s.ore.valid) then
      fail("NATIVE_SURFACE_OR_NATURAL_ORE_LOST")
    end
    local pairs_by_station=storage.tech_priests.pairs_by_station or {}
    local root=pairs_by_station[s.magos]
    local senior=pairs_by_station[s.senior]
    if not(root and senior and root.priest and root.priest.valid
      and senior.priest and senior.priest.valid) then
      if game.tick-s.started_tick>1800 then
        fail("ORIGINAL_RANKED_PAIRS_MISSING")
      end
      return
    end
    s.magos_priest=s.magos_priest or root.priest.unit_number
    s.senior_priest=s.senior_priest or senior.priest.unit_number
    if root.priest.unit_number~=s.magos_priest
      or senior.priest.unit_number~=s.senior_priest then
      fail("ORIGINAL_PRIEST_IDENTITY_CHANGED")
    end
    local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
    -- 0480 owns ranked links and rebuilds topology on its own 300-tick
    -- cadence. Both original native pairs can exist before the first slate
    -- includes the newly paired Senior. Never force a hierarchy edge or
    -- replace either priest; wait for the original authority to reconcile it.
    local root_rank=hierarchy and hierarchy.rank(root) or 0
    local senior_rank=hierarchy and hierarchy.rank(senior) or 0
    if root_rank~=4 or senior_rank~=3 then
      fail("ORIGINAL_RANKS_INVALID root="..tostring(root_rank)..
        " senior="..tostring(senior_rank))
    end
    if hierarchy.is_direct_subordinate(root,senior)~=true then
      local slate=hierarchy.hierarchy(senior)
      local interval=tonumber(hierarchy.rebuild_interval) or 300
      if game.tick-s.started_tick<3*interval then
        if not s.hierarchy_wait_logged then
          s.hierarchy_wait_logged=true
          emit("WAIT ORIGINAL_0480_SLATE_PENDING tick="..game.tick..
            " magos="..s.magos.." senior="..s.senior..
            " superior="..tostring(slate and slate.superior_unit)..
            " interval="..interval)
        end
        return
      end
      fail("ORIGINAL_HIERARCHY_NOT_DIRECT_RANKED root="..s.magos..
        " senior="..s.senior..
        " superior="..tostring(slate and slate.superior_unit)..
        " elapsed="..tostring(game.tick-s.started_tick))
    end
    local cell=s.port.logistic_cell
    local network=cell and cell.logistic_network
    local powered=s.port.is_connected_to_electric_network()
      and s.port.energy>0 and network and network.valid
    if not powered then
      if game.tick-s.started_tick>1800 then
        fail("NATIVE_ROBOT_NETWORK_NOT_POWERED")
      end
      return
    end
    local chunk={x=math.floor(s.ore.position.x/32),
      y=math.floor(s.ore.position.y/32)}
    local charted=root.station.force.is_chunk_charted(s.surface,chunk)
    if s.phase=="awaiting-native-strategy" then
      local goal=root.roboport_expansion_goal_1076
      if goal then
        if not(goal.remote_resource_item_1076=="iron-ore"
          and goal.root_station_unit==s.magos
          and goal.remote_station_item_1076=="intermediate-cogitator-station"
          and goal.remote_resource_position_1076
          and goal.remote_resource_position_1076.x==s.ore.position.x
          and goal.remote_resource_position_1076.y==s.ore.position.y
          and item_count(s.provider,"intermediate-cogitator-station")==1
          and charted and network.available_construction_robots>0) then
          fail("UNVERIFIED_AUTONOMOUS_GOAL_OR_MATERIAL")
        end
        s.goal=goal
        s.phase="awaiting-native-robot-build"
        emit("PASS AUTONOMOUS_0259_SELECTED tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " ore="..s.ore.unit_number.." original_station_stock=1"..
          " real_power=true charted=true real_robots=true")
        return
      end
      if game.tick-s.started_tick>=18000 then
        fail("AUTONOMOUS_0259_NOT_SELECTED reason="..
          tostring(root.resource_expansion_0259
          and root.resource_expansion_0259.last_reason)..
          " charted="..tostring(charted)..
          " provider_stock="..tostring(item_count(s.provider,
            "intermediate-cogitator-station"))..
          " network_stock="..tostring(network.get_item_count(
            "intermediate-cogitator-station"))..
          " original_chain="..tostring(root.remote_resource_assignment_0820~=nil))
      end
      return
    end
    if s.phase=="awaiting-native-robot-build" then
      local goal=s.goal
      local site=goal and goal.remote_station_position_1076
      if not(site and s.event_station and s.event_robot) then
        if game.tick-s.started_tick>30000 then
          fail("AUTONOMOUS_NATIVE_ROBOT_STATION_TIMEOUT event="..
            tostring(s.event_station).." frontier="..
            tostring(root.roboport_frontier_1076
              and root.roboport_frontier_1076.status)..
            " senior_request="..tostring(senior.robot_network_request_0338
              and senior.robot_network_request_0338.site_reason)..
            " reason="..tostring(root.resource_expansion_0259
              and root.resource_expansion_0259.last_reason))
        end
        return
      end
      local built=pairs_by_station[s.event_station]
      local receipt=senior.robot_network_last_task_0338
      local last=receipt and receipt.built_entity
      local ghosts=s.surface.find_entities_filtered{
        name="entity-ghost",position=site,radius=1.5,
        force=root.station.force,limit=5}
      if not(built and built.station and built.station.valid
        and built.station.unit_number==s.event_station
        and built.priest and built.priest.valid
        and built.station==last and receipt.phase=="complete"
        and receipt.child_station_unit==s.event_station
        and receipt.child_priest_unit==built.priest.unit_number
        and receipt.network_stock_before==1
        and receipt.stock_delta_verified==true
        and item_count(s.provider,"intermediate-cogitator-station")==0
        and network.get_item_count("intermediate-cogitator-station")==0
        and #ghosts==0
        and hierarchy.rank(built)==2
        and hierarchy.is_direct_subordinate(senior,built)==true
        and root.priest.unit_number==s.magos_priest
        and senior.priest.unit_number==s.senior_priest
        and s.event_tick>=receipt.started_tick) then
        fail("NATIVE_ROBOT_RECEIPT_RANK_OR_ITEM_MISMATCH")
      end
      s.finished=true
      emit("PASS autonomous original 0259 selected and physical native robot-built Intermediate paired"..
        " tick="..game.tick.." magos="..s.magos..
        " magos_priest="..s.magos_priest..
        " senior="..s.senior.." senior_priest="..s.senior_priest..
        " intermediate="..s.event_station..
        " intermediate_priest="..built.priest.unit_number..
        " native_robot="..s.event_robot.." material_delta=1"..
        " source_stock=0 ghost=0 ore_return_not_credited=true")
    end
  end)
  if not ok then s.failed=tostring(err);emit("FAIL "..s.failed) end
  return {processed=1,failed=s.failed and 1 or 0,detail=s.phase}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(registry and registry.on_init and registry.on_event
    and broker and broker.register_service) then
    error(PREFIX.."FAIL canonical observer/broker unavailable")
  end
  assert(registry.on_init(function()
    local s=state()
    s.phase="search";s.seed_offset=0;s.started_tick=game.tick
    create_native_site(s)
    emit("NATIVE_ON_INIT_BOOTSTRAP_COMPLETE phase="..tostring(s.phase)..
      " seed="..tostring(1380001+s.seed_offset))
  end,{owner=KEY,route="initialize",category="diagnostics",priority="last"}))
  assert(registry.on_event(defines.events.on_robot_built_entity,
    observed_robot,nil,{owner=KEY,route="native-robot-build-observe",
    category="diagnostics",priority=1100}))
  assert(broker.register_service{name=KEY,category="diagnostics",
    interval=60,priority=1100,budget=1,fn=pulse,
    note="isolated native 0259 autonomous physical robot acquisition"})
  emit("INSTALLED no prewritten objective no synthetic ore")
  return true
end
return M
