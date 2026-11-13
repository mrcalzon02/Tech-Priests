-- Isolated native Method II checkpoint: autonomous 0259 discovery ONLY.
-- This fixture provides real powered infrastructure/robots and a physically
-- mined Intermediate station item; it never injects a 1076 objective, creates
-- ore, impersonates an on_robot_built_entity event or constructs the target.
-- It is not packaged with the production mod or a substitute for ore return.
local M={}
local KEY="ci_autonomous_robot_1380"
local PREFIX="[TP-AUTONOMOUS-ROBOT-1380] "
local CARGO_RELOAD=rawget(_G,"TP_CI_1380_CARGO_RELOAD")==true
local RELOAD_PROCESS=rawget(_G,"TP_CI_1380_CARGO_RELOAD_PROBE")==true
local FULL_STORAGE=rawget(_G,"TP_CI_1380_FULL_STORAGE")==true
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
    name="iron-ore",type="resource",area={{85,12},{110,43}}}
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
  local area={{-12,-12},{90,58}}
  for _,entity in pairs(surface.find_entities_filtered{area=area}) do
    if entity.valid and (entity.position.x<70 or entity.position.y<12) then
      if entity.type=="resource" or entity.type=="tree"
        -- The 2.1 native map may populate the newly extended solar staging
        -- strip with ordinary fish. Remove only such native obstructors from
        -- the corridor that is being tiled; never touch the natural ore patch.
        or entity.type=="cliff" or entity.type=="simple-entity"
        or entity.type=="fish" then
        entity.destroy()
      else fail("UNEXPECTED_OCCUPIED_SITE "..entity.name) end
    end
  end
  local tiles={}
  for x=-12,90 do for y=-12,58 do
    if x<70 or y<12 then
      tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
    end
  end end
  surface.set_tiles(tiles,true)
  local force=game.forces.player
  -- Native, physically powered pre-existing infrastructure for the first
  -- already-covered stage. No electric-energy-interface or ghost credit.
  -- Only the ORIGINAL island is powered; expansion must build the rest.
  place(surface,force,"substation",18,8)
  place(surface,force,"substation",18,24)
  place(surface,force,"substation",18,40)
  place(surface,force,"substation",18,56)
  -- The isolated native surface starts with EMPTY accumulator charge.
  -- The previous 16-panel/4-accumulator island showed radar_energy=334 J,
  -- electrically connected but unable to chart even its own chunk.
  -- Supply the 300 kW native radar AND roboports through an ordinary,
  -- day/night-cycled physical solar grid: 32 x 60 kW panels (1.344 MW
  -- average on Nauvis) and 16 x 5 MJ accumulators (80 MJ capacity).
  -- No energy injection, forced daylight, forced chart or scripted scan.
  for _,x in ipairs({10,14,22,26}) do
    for _,y in ipairs({18,22,26,30,34,38,42,46}) do
      place(surface,force,"solar-panel",x,y)
    end
  end
  for _,x in ipairs({10,14,22,26}) do
    for _,y in ipairs({10,14,50,54}) do
      place(surface,force,"accumulator",x,y)
    end
  end
  -- One original native port. Natural ore at x>85 is beyond original green.
  local port=place(surface,force,"roboport",12,0)
  local provider=place(surface,force,"passive-provider-chest",18,6)
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
  local radar=place(surface,force,"radar",18,20)
  local magos=place(surface,force,
    "planetary-magos-cogitator-station",0,0,true)
  local senior=place(surface,force,"senior-cogitator-station",55,12,true)
  -- Supply both ORIGINAL station chests by physically mining actual poles
  -- and roboports. This is only scenario bootstrap, not synthetic 1076
  -- construction, fabricated ore or permission to teleport later goods.
  local magos_inv=magos.get_inventory(defines.inventory.chest)
  local senior_inv=senior.get_inventory(defines.inventory.chest)
  if not(magos_inv and magos_inv.valid and senior_inv and senior_inv.valid)then
    fail("ORIGINAL_PHYSICAL_SUPPLY_INVENTORY_MISSING")
  end
  local function mine_existing_supply(name,count,inventory)
    for _=1,count do
      local source_entity=place(surface,force,name,40,50)
      local before=inventory.get_item_count(name)
      if not(source_entity.mine{inventory=inventory}==true
        and not source_entity.valid
        and inventory.get_item_count(name)==before+1)then
        fail("NATIVE_CONSTRUCTION_SUPPLY_MINE_REFUSED "..name)
      end
    end
  end
  mine_existing_supply("medium-electric-pole",6,magos_inv)
  mine_existing_supply("roboport",3,magos_inv)
  mine_existing_supply("medium-electric-pole",6,senior_inv)
  mine_existing_supply("roboport",3,senior_inv)
  s.initial_pole_stock=magos_inv.get_item_count("medium-electric-pole")
    +senior_inv.get_item_count("medium-electric-pole")
  s.initial_port_stock=magos_inv.get_item_count("roboport")
    +senior_inv.get_item_count("roboport")
  if s.initial_pole_stock~=12 or s.initial_port_stock~=6 then
    fail("PHYSICAL_START_SUPPLY_COUNT_MISMATCH")
  end
  emit("NATIVE_INITIAL_CONSTRUCTION_SUPPLY tick="..game.tick..
    " original_magos="..magos.unit_number..
    " original_senior="..senior.unit_number..
    " poles=12 ports=6 native_mined=true")
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
    " natural_ore_unit="..tostring(ore.unit_number)..
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
    -- Require the original physical port to exclude the untouched patch.
    if not s.original_coverage_read then
      if cell.is_in_construction_range(s.ore.position)~=false then
        fail("ORIGINAL_ORE_ALREADY_GREEN_COVERED")
      end
      s.original_electric_grid=s.port.electric_network_id
      if not(type(s.original_electric_grid)=="number"
        and s.original_electric_grid>0)then
        fail("ORIGINAL_ELECTRIC_NETWORK_ID_MISSING")
      end
      s.original_coverage_read=true
      emit("NATIVE_ORIGINAL_GREEN_BOUNDARY tick="..game.tick..
        " ore_initial_green=false original_port="..s.port.unit_number)
    end
    local chunk={x=math.floor(s.ore.position.x/32),
      y=math.floor(s.ore.position.y/32)}
    local charted=root.station.force.is_chunk_charted(s.surface,chunk)
    -- Factorio's real player/radar chart job can become visible after the
    -- previous 18,000-tick fixture deadline. Start a bounded, genuine
    -- 0259 discovery window from the FIRST observed force-charted ore, not
    -- from on_init. This only observes native discovery; it cannot chart
    -- a chunk, supply stock, select the strategy or start construction.
    if charted and not s.first_chart_tick then
      s.first_chart_tick=game.tick
      emit("NATIVE_ORE_CHARTED tick="..game.tick..
        " resource_unit="..tostring(s.ore.unit_number)..
        " last_0259_reason="..tostring(root.resource_expansion_0259
          and root.resource_expansion_0259.last_reason)..
        " next_0259_tick="..tostring(root.resource_expansion_0259
          and root.resource_expansion_0259.next_tick))
    end
    -- One bounded native readback to distinguish a genuinely unpowered radar
    -- or uncharted ore from a persistent original 0820 relay monopoly.
    -- Diagnostic ONLY: never chart a chunk, reassign a strategy or create ore.
    if (s.discovery_readback_stage or 0)<2
      and game.tick-s.started_tick>=
        ((s.discovery_readback_stage or 0)==0 and 1800 or 12000) then
      s.discovery_readback_stage=(s.discovery_readback_stage or 0)+1
      local radar_power_ok,radar_connected=pcall(function()
        return s.radar.is_connected_to_electric_network()
      end)
      local radar_chunk={x=math.floor(s.radar.position.x/32),
        y=math.floor(s.radar.position.y/32)}
      local radar_chart_ok,radar_charted=pcall(function()
        return root.station.force.is_chunk_charted(s.surface,radar_chunk)
      end)
      local chain=root.resource_expansion_0259
        and root.resource_expansion_0259.chain_0820
      local stored_j=0
      for _,battery in pairs(s.surface.find_entities_filtered{
        name="accumulator",area={{9,8},{28,58}}}) do
        if battery.valid then stored_j=stored_j+battery.energy end
      end
      emit("NATIVE_RADAR_AND_STRATEGY_READBACK tick="..game.tick..
        " stage="..s.discovery_readback_stage..
        " daytime="..tostring(s.surface.daytime)..
        " solar_multiplier="..tostring(s.surface.solar_power_multiplier)..
        " physical_accumulator_j="..tostring(stored_j)..
        " radar_energy="..tostring(s.radar.energy)..
        " radar_connected="..tostring(radar_power_ok and radar_connected)..
        " radar_chunk_charted="..tostring(radar_chart_ok and radar_charted)..
        " ore_chunk_charted="..tostring(charted)..
        " chain_status="..tostring(chain and chain.status)..
        " chain_need="..tostring(chain and chain.need))
    end
    if s.phase=="awaiting-native-strategy"
      and s.first_chart_tick and not s.uncovered_admission_probe
      and game.tick>=s.first_chart_tick+60 then
      -- DIAGNOSTIC ONLY, once per genuine chart. Inspect the same original
      -- Senior station-radius candidate geometry as production 0259 and
      -- 1076's read-only physical admission; never call a plan executor,
      -- assign a goal, chart a chunk or change a physical item.
      s.uncovered_admission_probe=true
      local sr=tonumber(senior.radius or senior.scan_radius
        or senior.station_radius)
      local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
      local cap=h and h.direct_capacity_remaining(senior)
      local frontier=rawget(_G,"TechPriestsRoboportExpansionFrontier1076")
      local candidates=0
      local last_reason="no-senior-radius-site"
      local first_site
      for _,delta in ipairs({
        {-6,0},{6,0},{0,-6},{0,6},
        {-9,0},{9,0},{0,-9},{0,9}})do
        local site={x=math.floor(s.ore.position.x+delta[1]+0.5),
          y=math.floor(s.ore.position.y+delta[2]+0.5)}
        local dx=senior.station.position.x-site.x
        local dy=senior.station.position.y-site.y
        if sr and dx*dx+dy*dy<=sr*sr
          and s.surface.can_place_entity{
            name="intermediate-cogitator-station",position=site,
            force=root.station.force}==true then
          candidates=candidates+1
          first_site=first_site or site
          if frontier and type(
              frontier.native_uncovered_ore_admission_1076)=="function"then
            local ok,approved,why=pcall(
              frontier.native_uncovered_ore_admission_1076,
              root,s.ore.position,site)
            if ok and approved==true then
              last_reason="original-grid-stocked-admitted"
              break
            end
            last_reason=ok and tostring(why)
              or "uncovered-admission-error:"..tostring(approved)
          else
            last_reason="1076-admission-unavailable"
          end
        end
      end
      emit("NATIVE_UNCOVERED_ADMISSION_READBACK tick="..game.tick..
        " ore_x="..tostring(s.ore.position.x)..
        " ore_y="..tostring(s.ore.position.y)..
        " senior_x="..tostring(senior.station.position.x)..
        " senior_y="..tostring(senior.station.position.y)..
        " senior_radius="..tostring(sr)..
        " direct_capacity="..tostring(cap)..
        " candidate_sites="..candidates..
        " first_site_x="..tostring(first_site and first_site.x)..
        " first_site_y="..tostring(first_site and first_site.y)..
        " admission="..last_reason..
        " pole_stock_magos="..tostring(item_count(root.station,
          "medium-electric-pole"))..
        " port_stock_magos="..tostring(item_count(root.station,
          "roboport"))..
        " pole_stock_senior="..tostring(item_count(senior.station,
          "medium-electric-pole"))..
        " port_stock_senior="..tostring(item_count(senior.station,
          "roboport")))
    end
    if s.phase=="awaiting-native-strategy" then
      local goal=root.roboport_expansion_goal_1076
      if goal then
        -- 0259 owns the natural-ore choice. It may select a different
        -- naturally generated tile on the same charted patch than the
        -- bootstrap witness, which is NOT an authorization to reject
        -- genuine uncovered network expansion. Bind only to the actual
        -- selected, observed, mineable natural resource.
        local p=goal.remote_resource_position_1076
        local selected_candidates=p and s.surface.find_entities_filtered{
          name="iron-ore",type="resource",position=p,radius=0.1,limit=2} or {}
        local selected_ore=#selected_candidates==1 and selected_candidates[1]
        local selected_products=selected_ore and selected_ore.valid
          and selected_ore.prototype
          and selected_ore.prototype.mineable_properties
          and selected_ore.prototype.mineable_properties.products or {}
        local selected_mineable=false
        for _,product in pairs(selected_products)do
          if product.type=="item" and product.name=="iron-ore"then
            selected_mineable=true
            break
          end
        end
        local selected_charted=false
        if selected_ore and selected_ore.valid then
          local known,yes=pcall(function()
            return root.station.force.is_chunk_charted(s.surface,{
              x=math.floor(selected_ore.position.x/32),
              y=math.floor(selected_ore.position.y/32)})
          end)
          selected_charted=known and yes==true
        end
        local original_green=selected_ore and selected_ore.valid
          and cell.is_in_construction_range(selected_ore.position)
        if not(goal.remote_resource_item_1076=="iron-ore"
          and goal.root_station_unit==s.magos
          and goal.remote_station_item_1076=="intermediate-cogitator-station"
          and goal.autonomous_coverage_extension_0259==true
          and selected_ore and selected_ore.valid
          and selected_ore.name=="iron-ore"
          and selected_ore.type=="resource"
          and selected_ore.surface==s.surface
          and selected_ore.position.x==p.x
          and selected_ore.position.y==p.y
          and selected_ore.amount>=2
          and selected_mineable
          and selected_charted
          and original_green==false
          and item_count(s.provider,"intermediate-cogitator-station")==1
          and charted and network.available_construction_robots>0) then
          -- Observe original live selection and physical custody before
          -- diagnosing an actual 0259/1076 refusal. No acceptance relaxation.
          local p=goal.remote_resource_position_1076
          local frontier=root.roboport_frontier_1076
          emit("NATIVE_AUTONOMOUS_GOAL_READBACK tick="..game.tick..
            " item="..tostring(goal.remote_resource_item_1076).. 
            " extension="..tostring(goal.autonomous_coverage_extension_0259)..
            " actual_natural="..tostring(selected_ore and selected_ore.valid)..
            " selected_charted="..tostring(selected_charted)..
            " selected_mineable="..tostring(selected_mineable)..
            " original_green="..tostring(original_green)..
            " root="..tostring(goal.root_station_unit)..
            " expected_root="..tostring(s.magos)..
            " station_item="..tostring(goal.remote_station_item_1076)..
            " target_x="..tostring(p and p.x)..
            " target_y="..tostring(p and p.y)..
            " selected_ore_x="..tostring(s.ore.position.x)..
            " selected_ore_y="..tostring(s.ore.position.y)..
            " charted="..tostring(charted)..
            " provider_stock="..tostring(item_count(s.provider,
              "intermediate-cogitator-station"))..
            " network_stock="..tostring(network.get_item_count(
              "intermediate-cogitator-station"))..
            " robots_available="..tostring(
              network.available_construction_robots)..
            " robots_total="..tostring(network.all_construction_robots)..
            " frontier_status="..tostring(frontier and frontier.status)..
            " 0259_reason="..tostring(root.resource_expansion_0259
              and root.resource_expansion_0259.last_reason))
          fail("UNVERIFIED_AUTONOMOUS_GOAL_OR_MATERIAL")
        end
        s.ore=selected_ore
        s.ore_initial=selected_ore.amount
        emit("NATIVE_SELECTED_NATURAL_ORE tick="..game.tick..
          " x="..s.ore.position.x.." y="..s.ore.position.y..
          " amount="..s.ore_initial..
          " original_green=false naturally_generated=true")
        s.goal=goal
        s.phase="awaiting-native-robot-build"
        -- Targeted actual-engine diagnostic: 43388837914 proved a bot
        -- departs its original port BEFORE the late 0338 extension receipt.
        -- 0259 has now already chosen a naturally mined target with THREE
        -- live robots and one real station item. Temporarily retain those
        -- SAME three still-docked robot ITEMS in a serialized engine-owned
        -- inventory while the genuine priest-built pole/port frontier
        -- continues. Do not remove flying bots, fabricate replacement bots
        -- or change the strategy/ghost/production controller.
        local dock=s.port.get_inventory(defines.inventory.roboport_robot)
        local docked=dock and dock.valid
          and dock.get_item_count("construction-robot") or nil
        if docked~=3 then
          fail("NATIVE_PRESTAGE_ROBOTS_NOT_DOCKED tick="..game.tick..
            " docked="..tostring(docked)..
            " available="..tostring(network.available_construction_robots)..
            " all="..tostring(network.all_construction_robots))
        end
        local hold=game.create_inventory(1)
        if not(hold and hold.valid)then fail("ROBOTLESS_CUSTODY_HOLD_MISSING")end
        s.robotless_hold=hold
        local removed=dock.remove{name="construction-robot",count=3}
        local stored=hold.insert{name="construction-robot",count=removed}
        if not(removed==3 and stored==3
          and dock.get_item_count("construction-robot")==0
          and hold.get_item_count("construction-robot")==3
          and item_count(s.provider,"intermediate-cogitator-station")==1)then
          fail("NATIVE_ROBOTLESS_PHYSICAL_CUSTODY_INVALID")
        end
        emit("NATIVE_ROBOTLESS_PRESTAGE tick="..game.tick..
          " original_port="..s.port.unit_number..
          " robots_held=3 station_stock=1 extension_not_yet_credited=true")
        emit("PASS AUTONOMOUS_0259_SELECTED tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " ore="..tostring(s.ore.unit_number).." original_station_stock=1"..
          " real_power=true charted=true real_robots=true")
        -- The previous native coverage-refusal attempt physically mined the
        -- extended roboport, but another real port appeared at its site
        -- during the 1,500-tick outage. Five ORIGINAL mined spare roboport
        -- items were still available to the canonical 0338 builder. Escrow
        -- those exact spare items now, BEFORE physical frontier dispatch,
        -- leaving one original Senior-owned item for the genuine first
        -- 1076/0338 extension. This isolates loss of COVERAGE from immediate
        -- fully funded autonomous repair without altering production logic.
        local magos_stock=root.station.get_inventory(defines.inventory.chest)
        local senior_stock=senior.station.get_inventory(defines.inventory.chest)
        if not(magos_stock and magos_stock.valid
          and senior_stock and senior_stock.valid
          and magos_stock.get_item_count("roboport")==3
          and senior_stock.get_item_count("roboport")==3)then
          fail("NATIVE_SPARE_ROBOPORT_ORIGINAL_STOCK_CHANGED")
        end
        local magos_spare=game.create_inventory(1)
        local senior_spare=game.create_inventory(1)
        if not(magos_spare and magos_spare.valid
          and senior_spare and senior_spare.valid)then
          fail("NATIVE_SPARE_ROBOPORT_HOLDS_UNAVAILABLE")
        end
        s.spare_port_magos=magos_spare
        s.spare_port_senior=senior_spare
        local mm=magos_stock.remove{name="roboport",count=3}
        local sm=senior_stock.remove{name="roboport",count=2}
        local mc=magos_spare.insert{name="roboport",count=mm}
        local sc=senior_spare.insert{name="roboport",count=sm}
        if not(mm==3 and sm==2 and mc==3 and sc==2
          and magos_stock.get_item_count("roboport")==0
          and senior_stock.get_item_count("roboport")==1
          and magos_spare.get_item_count("roboport")==3
          and senior_spare.get_item_count("roboport")==2)then
          fail("NATIVE_SPARE_ROBOPORT_CUSTODY_INVALID")
        end
        emit("NATIVE_SPARE_ROBOPORT_PRESTAGE tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " magos_held=3 senior_held=2 senior_available=1 source_total=6")
        return
      end
      -- Do not report a 0259 failure in the same tick that the genuine
      -- resource first became charted. Require three complete existing
      -- 0259 discovery intervals before refusal, with a separate hard
      -- 30k-tick bound on a radar that never charts its real natural ore.
      -- An unselected/failed build still FAILS; this changes no runtime gate.
      local interval=tonumber(TECH_PRIESTS_RESOURCE_EXPANSION_INTERVAL_0259)
        or 1200
      if not charted and game.tick-s.started_tick>=30000 then
        fail("NATIVE_ORE_NOT_CHARTED_BY_BOUND tick="..game.tick..
          " radar_energy="..tostring(s.radar.energy))
      end
      if s.first_chart_tick
        and game.tick-s.first_chart_tick>=3*interval then
        fail("AUTONOMOUS_0259_NOT_SELECTED first_chart_tick="..
          tostring(s.first_chart_tick)..
          " last_next_tick="..tostring(root.resource_expansion_0259
            and root.resource_expansion_0259.next_tick)..
          " reason="..
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
      -- Bounded READ-ONLY native 1076/0338/0488 admission diagnostics.
      -- These cannot grant movement, build, cargo, construction or acceptance.
      if game.tick>=12000 and game.tick%6000==0 then
        local frontier=root.roboport_frontier_1076
        local pending=frontier and frontier.pending
        local worker_id=pending and pending.builder_station_unit
        local worker=worker_id and pairs_by_station[worker_id]
        local task=worker and worker.construction_task_0338
        local candidate=worker and worker.construction_candidate_0338
        local queue=worker and worker.order_queue_0469
        local order=worker and ((queue and queue.current)
          or worker.active_order_0469)
        local last=worker and worker.construction_last_task_0338
        local broker=storage.tech_priests.roboport_expansion_broker_1076
        local attempt=broker and broker.last_attempt
        emit("NATIVE_FRONTIER_BUILDER_READBACK tick="..game.tick..
          " frontier="..tostring(frontier and frontier.status)..
          " pending="..tostring(pending and pending.kind)..
          " pending_builder="..tostring(worker_id)..
          " worker_live="..tostring(worker and worker.priest and worker.priest.valid)..
          " request_same="..tostring(worker and pending
            and worker.construction_request==pending.request)..
          " candidate_field="..tostring(candidate and candidate.request_field)..
          " candidate_same="..tostring(candidate and pending
            and candidate.request_value==pending.request)..
          " candidate_item="..tostring(candidate and candidate.item_name)..
          " task_phase="..tostring(task and task.phase)..
          " task_field="..tostring(task and task.request_field)..
          " task_same="..tostring(task and pending
            and task.request_value==pending.request)..
          " task_cargo="..tostring(task and task.carried and task.carried.count)..
          " custody="..tostring(worker and worker.construction_custody_0338~=nil)..
          " blocked="..tostring(worker and worker.construction_blocked_reason_0338)..
          " discovery="..tostring(frontier and frontier.last_candidate_discovery_1076)..
          " site_refusal="..tostring(worker and worker.construction_site_refusal_0338
            and worker.construction_site_refusal_0338.reason)..
          " earlier_structure="..tostring(worker and worker.structure_construction_requested_item
            and worker.structure_construction_requested_item.item_name)..
          " earlier_item="..tostring(worker and worker.construction_requested_item
            and (type(worker.construction_requested_item)=="table"
              and worker.construction_requested_item.item_name
              or worker.construction_requested_item))..
          " bootstrap="..tostring(worker and worker.construction_bootstrap_ghost_0645
            and worker.construction_bootstrap_ghost_0645.item)..
          " pole_station_stock="..tostring(worker and worker.station
            and item_count(worker.station,"medium-electric-pole"))..
          " order_kind="..tostring(order and order.kind)..
          " order_source="..tostring(order and order.source)..
          " order_status="..tostring(order and order.status)..
          " direct_custody="..tostring(worker and worker.direct_acquisition_custody_0513~=nil)..
          " automatic_assignment="..tostring(worker and worker.active_task_0285~=nil)..
          " strict_craft="..tostring(worker and worker.emergency_craft
            and worker.emergency_craft.strict_recipe_0647)..
          " last_phase="..tostring(last and last.phase)..
          " last_failure="..tostring(last and last.failure_reason_0338)..
          " broker_detail="..tostring(attempt and attempt.detail))
      end
      -- Only a completed original 0338 build receipt, live electric/logistic
      -- merge, and actual exact pole/port stock withdrawals prove extension.
      local f=root.roboport_frontier_1076
      if not s.extension_accepted and f and f.status=="complete"
        and (f.segments or 0)>=1 and (f.poles_built or 0)>=1 then
        local built_port=f.source_port
        local original=s.port
        local fresh=built_port and built_port.valid and built_port.logistic_cell
        local old=original.logistic_cell
        local new_network=fresh and fresh.logistic_network
        local old_network=old and old.logistic_network
        local last=f.last_receipt
        local builder_unit=last and last.request_value
          and last.request_value.frontier_builder_unit_1076
        local builder=builder_unit and pairs_by_station[builder_unit]
        -- Distinguish actual CONSUMPTION by canonical 0338 from these
        -- five originally mined items physically held in engine-owned
        -- inventories during the coverage-loss negative. An escrowed
        -- roboport is NOT a constructed port or an item debit.
        local spare_m=s.spare_port_magos
        local spare_s=s.spare_port_senior
        local spare_m_qty=spare_m and spare_m.valid
          and spare_m.get_item_count("roboport") or nil
        local spare_s_qty=spare_s and spare_s.valid
          and spare_s.get_item_count("roboport") or nil
        local port_debit=s.initial_port_stock
          -((item_count(root.station,"roboport") or 0)
            +(item_count(senior.station,"roboport") or 0)
            +(spare_m_qty or 0)+(spare_s_qty or 0))
        local pole_debit=s.initial_pole_stock
          -((item_count(root.station,"medium-electric-pole") or 0)
            +(item_count(senior.station,"medium-electric-pole") or 0))
        if not(built_port and built_port.valid and built_port~=original
          and built_port.type=="roboport"
          and built_port.force==root.station.force
          and built_port.surface==s.surface
          and built_port.is_connected_to_electric_network()
          and built_port.energy>0
          and built_port.electric_network_id==s.original_electric_grid
          and original.electric_network_id==s.original_electric_grid
          and new_network and new_network.valid
          and old_network and old_network.valid
          and new_network.network_id==old_network.network_id
          and old.is_in_construction_range(s.ore.position)==false
          and fresh.is_in_construction_range(s.ore.position)==true
          and last and last.phase=="complete"
          and last.built_entity==built_port
          and last.item_name=="roboport"
          and spare_m_qty==3 and spare_s_qty==2
          and builder and builder.station.valid
          and builder.station.force==root.station.force
          and port_debit==f.segments and pole_debit==f.poles_built)then
          fail("NATIVE_FRONTIER_EXTENSION_RECEIPT_OR_STOCK_INVALID"..
            " status="..tostring(f.status)..
            " segments="..tostring(f.segments)..
            " poles="..tostring(f.poles_built)..
            " port_debit="..tostring(port_debit)..
            " magos_spare_held="..tostring(spare_m_qty)..
            " senior_spare_held="..tostring(spare_s_qty)..
            " pole_debit="..tostring(pole_debit)..
            " last_item="..tostring(last and last.item_name)..
            " original_grid="..tostring(s.original_electric_grid))
        end
        s.extension_accepted=true
        -- Native run 43388837914 showed that 0338 finished the counted
        -- frontier AFTER a bot had already left its original dock. Never
        -- seize an in-flight robot or destroy its cargo. Stage the exact
        -- three docked physical robot items only AFTER autonomous 0259
        -- genuinely selected its goal, BEFORE the network extension; the
        -- original priest still constructs poles and ports through 0338.
        -- The refusal interval itself begins only after physical extension
        -- is verified here; the green site can never be credited early.
        local held=s.robotless_hold
        local dock=s.port.get_inventory(defines.inventory.roboport_robot)
        if not(held and held.valid
          and held.get_item_count("construction-robot")==3
          and dock and dock.valid
          and dock.get_item_count("construction-robot")==0)then
          fail("NATIVE_PRESTAGED_ROBOT_CUSTODY_ORIGINAL_GRID_LOST")
        end
        s.robotless_cut_tick=game.tick
        emit("NATIVE_ROBOTLESS_CUT tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " original_port="..s.port.unit_number..
          " robots_held=3 station_stock=1 extension=verified")
        emit("PASS NATIVE_PHYSICAL_FRONTIER_EXTENSION tick="..game.tick..
          " original_magos="..s.magos..
          " original_senior="..s.senior..
          " original_port="..original.unit_number..
          " built_port="..built_port.unit_number..
          " poles_built="..f.poles_built..
          " ports_built="..f.segments..
          " pole_debit="..pole_debit..
          " port_debit="..port_debit..
          " original_green=false actual_green=true"..
          " electric_grid=original logistic_network=merged builder_receipt=0338")
      end
      -- Observe 1,500 native ticks with zero original construction robots,
      -- beyond the formerly successful ~957-tick robot dispatch/build.
      -- No station may be credited, no resource mined, no item consumed,
      -- and neither original priest identity may change. Restore the
      -- EXACT same three robot items, then complete ordinary production.
      if s.robotless_hold then
        -- A pre-staged item hold is not a refusal proof until the genuine
        -- 0338 counted frontier actually reaches the remote green site.
        if not s.extension_accepted then return end
        if game.tick-s.robotless_cut_tick<1500 then return end
        local held=s.robotless_hold
        local dock=s.port.get_inventory(defines.inventory.roboport_robot)
        local live_cell=s.port.logistic_cell
        local live_net=live_cell and live_cell.logistic_network
        local site=s.goal and s.goal.remote_station_position_1076
        local built=site and s.surface.find_entities_filtered{
          name="intermediate-cogitator-station",position=site,
          radius=1.5,force=root.station.force,limit=2} or {}
        if not(held.valid and held.get_item_count("construction-robot")==3
          and dock and dock.valid
          and dock.get_item_count("construction-robot")==0
          and live_net and live_net.valid
          and live_net.available_construction_robots==0
          and live_net.all_construction_robots==0
          and #built==0 and not s.event_station
          and item_count(s.provider,"intermediate-cogitator-station")==1
          and s.ore.amount==s.ore_initial
          and root.priest.unit_number==s.magos_priest
          and senior.priest.unit_number==s.senior_priest)then
          fail("NATIVE_ROBOTLESS_REFUSAL_OR_CUSTODY_INVALID tick="..
            game.tick.." held="..tostring(held.valid and
              held.get_item_count("construction-robot"))..
            " network_robots="..tostring(live_net and
              live_net.all_construction_robots)..
            " provider_item="..tostring(item_count(s.provider,
              "intermediate-cogitator-station"))..
            " built="..tostring(#built))
        end
        emit("PASS NATIVE_ROBOTLESS_REFUSAL tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " robots_held=3 network_robots=0 station_stock=1"..
          " native_event=none ore_unchanged=true")
        -- Third independent physical negative: AFTER the original 0338
        -- finished the counted grid and the zero-robot refusal was observed,
        -- mine only its newly built roboport into an ENGINE-OWNED item hold.
        -- Keep the original network, real station item and original identities.
        -- Restoring the SAME mined item below is a test disturbance repair,
        -- never credit for autonomous 0338 construction.
        local port_to_cut=f and f.source_port
        local port_pos=port_to_cut and port_to_cut.valid
          and {x=port_to_cut.position.x,y=port_to_cut.position.y}
        if not(port_pos and port_to_cut~=s.port
          and port_to_cut.name=="roboport"
          and port_to_cut.unit_number~=s.port.unit_number)then
          fail("NATIVE_COVERAGELESS_ORIGINAL_FRONTIER_MISSING")
        end
        local port_hold=game.create_inventory(1)
        if not(port_hold and port_hold.valid)then
          fail("NATIVE_COVERAGELESS_HOLD_MISSING")
        end
        s.coverageless_hold=port_hold
        s.coverageless_position=port_pos
        s.coverageless_cut_tick=game.tick
        local retired_port=port_to_cut.unit_number
        local mined=port_to_cut.mine{inventory=port_hold}
        if not(mined==true and not port_to_cut.valid
          and port_hold.get_item_count("roboport")==1
          and s.port.valid and s.port.logistic_cell
          and s.port.logistic_cell.is_in_construction_range(
            s.ore.position)==false)then
          fail("NATIVE_COVERAGELESS_CUSTODY_OR_GREEN_INVALID")
        end
        emit("NATIVE_COVERAGELESS_CUT tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " original_port="..s.port.unit_number..
          " retired_port="..retired_port..
          " roboport_held=1 station_stock=1 robots_restored=3")
        local released=held.remove{name="construction-robot",count=3}
        local restored=dock.insert{name="construction-robot",count=released}
        if not(released==3 and restored==3
          and dock.get_item_count("construction-robot")==3
          and held.get_item_count("construction-robot")==0)then
          fail("NATIVE_ROBOTLESS_RESTORATION_NOT_COUNTED")
        end
        held.destroy() -- only after empty native item custody is verified
        s.robotless_hold=nil
        s.robotless_restored=true
        emit("PASS NATIVE_ROBOTLESS_RECOVERY tick="..game.tick..
          " original_port="..s.port.unit_number..
          " robots_restored=3 held=0 original_mission=retained")
      end
      if s.coverageless_hold then
        -- 1,500 real powered ticks with THREE original physical robots
        -- and a genuine station item, but without the only remote green
        -- coverage. A ghost or dead mission is NOT a successful station.
        if game.tick-s.coverageless_cut_tick<1500 then return end
        local hold=s.coverageless_hold
        local old=s.port.logistic_cell
        local net=old and old.logistic_network
        local p=s.coverageless_position
        local remaining=s.surface.find_entities_filtered{
          name="roboport",position=p,radius=1.5,
          force=root.station.force,limit=2}
        local site=s.goal and s.goal.remote_station_position_1076
        local built=site and s.surface.find_entities_filtered{
          name="intermediate-cogitator-station",position=site,
          radius=1.5,force=root.station.force,limit=2} or {}
        local spare_m=s.spare_port_magos
        local spare_s=s.spare_port_senior
        if not(hold.valid and hold.get_item_count("roboport")==1
          and spare_m and spare_m.valid
          and spare_s and spare_s.valid
          and spare_m.get_item_count("roboport")==3
          and spare_s.get_item_count("roboport")==2
          and item_count(root.station,"roboport")==0
          and item_count(senior.station,"roboport")==0
          and #remaining==0 and old and net and net.valid
          and old.is_in_construction_range(s.ore.position)==false
          and net.all_construction_robots==3
          and item_count(s.provider,"intermediate-cogitator-station")==1
          and #built==0 and not s.event_station
          and s.ore.amount==s.ore_initial
          and root.priest.unit_number==s.magos_priest
          and senior.priest.unit_number==s.senior_priest)then
          fail("NATIVE_COVERAGELESS_REFUSAL_OR_CUSTODY_INVALID tick="..
            game.tick.." held="..tostring(hold.valid and
              hold.get_item_count("roboport"))..
            " ports="..tostring(#remaining)..
            " robots="..tostring(net and net.all_construction_robots)..
            " built="..tostring(#built)..
            " magos_stock="..tostring(item_count(root.station,"roboport"))..
            " senior_stock="..tostring(item_count(senior.station,"roboport"))..
            " magos_escrow="..tostring(spare_m and spare_m.valid
              and spare_m.get_item_count("roboport"))..
            " senior_escrow="..tostring(spare_s and spare_s.valid
              and spare_s.get_item_count("roboport")))
        end
        emit("PASS NATIVE_COVERAGELESS_REFUSAL tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " retained_port=1 original_green=false remote_port=absent"..
          " robots=3 native_event=none ore_unchanged=true")
        -- Restore the exact previously mined item as the negative fixture's
        -- physical repair. No credited construction, free roboport, ghost
        -- revival or alteration to original mission/custody authorities.
        local spec={name="roboport",position=p,force=root.station.force}
        if not s.surface.can_place_entity(spec)then
          fail("NATIVE_COVERAGELESS_RESTORATION_SITE_BLOCKED")
        end
        local debit=hold.remove{name="roboport",count=1}
        if debit~=1 or hold.get_item_count("roboport")~=0 then
          fail("NATIVE_COVERAGELESS_RESTORATION_NOT_COUNTED")
        end
        local restored=s.surface.create_entity(spec)
        local cell=restored and restored.valid and restored.logistic_cell
        local new_net=cell and cell.logistic_network
        -- Removing the frontier roboport invalidates its old network
        -- handle. Factorio may also replace that network on restoration.
        -- Compare only two CURRENT native network handles after repair.
        local original_cell=s.port.valid and s.port.logistic_cell
        local original_net=original_cell and original_cell.logistic_network
        if not(restored and restored.valid and restored.name=="roboport"
          and restored.unit_number~=s.port.unit_number
          and restored.is_connected_to_electric_network()
          and restored.electric_network_id==s.original_electric_grid
          and cell and cell.is_in_construction_range(s.ore.position)
          and new_net and new_net.valid
          and original_net and original_net.valid
          and new_net.network_id==original_net.network_id)then
          fail("NATIVE_COVERAGELESS_RESTORED_GRID_NOT_MERGED")
        end
        hold.destroy() -- only after the single engine-owned item was used
        s.coverageless_hold=nil
        s.coverageless_restored=true
        emit("PASS NATIVE_COVERAGELESS_RECOVERY tick="..game.tick..
          " original_port="..s.port.unit_number..
          " restored_port="..restored.unit_number..
          " port_debit=1 held=0 electric_grid=original"..
          " logistic_network=merged original_mission=retained")
        -- Return the exact five earlier physically mined spare port items
        -- to their ORIGINAL station chests, not as a fresh credit. Both
        -- persistent escrow inventories must be emptied before destruction.
        local magos_inv=root.station.get_inventory(defines.inventory.chest)
        local senior_inv=senior.station.get_inventory(defines.inventory.chest)
        local magos_return=spare_m.remove{name="roboport",count=3}
        local senior_return=spare_s.remove{name="roboport",count=2}
        local magos_received=magos_inv and magos_inv.valid
          and magos_inv.insert{name="roboport",count=magos_return} or 0
        local senior_received=senior_inv and senior_inv.valid
          and senior_inv.insert{name="roboport",count=senior_return} or 0
        if not(magos_return==3 and senior_return==2
          and magos_received==3 and senior_received==2
          and spare_m.get_item_count("roboport")==0
          and spare_s.get_item_count("roboport")==0
          and magos_inv.get_item_count("roboport")==3
          and senior_inv.get_item_count("roboport")==2)then
          fail("NATIVE_SPARE_ROBOPORT_RESTITUTION_OR_CONSERVATION_INVALID")
        end
        spare_m.destroy()
        spare_s.destroy()
        s.spare_port_magos=nil
        s.spare_port_senior=nil
        emit("PASS NATIVE_SPARE_ROBOPORT_RECOVERY tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " magos_returned=3 senior_returned=2 empty_holds=true"..
          " total_restituted=5")
        -- Next independent negative starts with three real network robots
        -- but zero original station items. Withhold the one existing mined
        -- station item before the next native robot dispatch.
        local provider=s.provider.get_inventory(defines.inventory.chest)
        if not(provider and provider.valid
          and provider.get_item_count("intermediate-cogitator-station")==1)then
          fail("NATIVE_MATERIALLESS_ORIGINAL_STOCK_MISSING")
        end
        local station_hold=game.create_inventory(1)
        if not(station_hold and station_hold.valid)then
          fail("NATIVE_MATERIALLESS_HOLD_MISSING")
        end
        s.materialless_hold=station_hold
        local withdrawn=provider.remove{
          name="intermediate-cogitator-station",count=1}
        local retained=station_hold.insert{
          name="intermediate-cogitator-station",count=withdrawn}
        if not(withdrawn==1 and retained==1
          and provider.get_item_count("intermediate-cogitator-station")==0
          and station_hold.get_item_count("intermediate-cogitator-station")==1)then
          fail("NATIVE_MATERIALLESS_CUSTODY_INVALID")
        end
        s.materialless_cut_tick=game.tick
        emit("NATIVE_MATERIALLESS_CUT tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " provider="..s.provider.unit_number..
          " station_held=1 station_stock=0 robots_still_held=3")
      end
      if s.materialless_hold then
        -- After restoring those EXACT 3 robots, let 1,500 genuine ticks
        -- elapse with ZERO station items. Reject a ghost or stray native
        -- event as a false physical build; preserve ore, rank and stock.
        if s.robotless_hold then
          fail("NATIVE_MATERIALLESS_OVERLAPPING_ROBOT_CUSTODY")
        end
        if game.tick-s.materialless_cut_tick<1500 then return end
        local hold=s.materialless_hold
        local provider=s.provider.get_inventory(defines.inventory.chest)
        local cell=s.port.logistic_cell
        local net=cell and cell.logistic_network
        local site=s.goal and s.goal.remote_station_position_1076
        local built=site and s.surface.find_entities_filtered{
          name="intermediate-cogitator-station",position=site,
          radius=1.5,force=root.station.force,limit=2} or {}
        if not(hold.valid
          and hold.get_item_count("intermediate-cogitator-station")==1
          and provider and provider.valid
          and provider.get_item_count("intermediate-cogitator-station")==0
          and net and net.valid
          and net.all_construction_robots==3
          and net.get_item_count("intermediate-cogitator-station")==0
          and #built==0 and not s.event_station
          and s.ore.amount==s.ore_initial
          and root.priest.unit_number==s.magos_priest
          and senior.priest.unit_number==s.senior_priest)then
          fail("NATIVE_MATERIALLESS_REFUSAL_OR_CUSTODY_INVALID tick="..
            game.tick.." hold="..tostring(hold.valid and
              hold.get_item_count("intermediate-cogitator-station"))..
            " provider="..tostring(provider and provider.valid and
              provider.get_item_count("intermediate-cogitator-station"))..
            " robots="..tostring(net and net.all_construction_robots)..
            " built="..tostring(#built))
        end
        emit("PASS NATIVE_MATERIALLESS_REFUSAL tick="..game.tick..
          " original_magos="..s.magos.." original_senior="..s.senior..
          " station_held=1 network_station_stock=0 robots=3"..
          " native_event=none ore_unchanged=true")
        local removed=hold.remove{name="intermediate-cogitator-station",count=1}
        local inserted=provider.insert{
          name="intermediate-cogitator-station",count=removed}
        if not(removed==1 and inserted==1
          and hold.get_item_count("intermediate-cogitator-station")==0
          and provider.get_item_count("intermediate-cogitator-station")==1)then
          fail("NATIVE_MATERIALLESS_RESTORATION_NOT_COUNTED")
        end
        hold.destroy() -- only once the exact item is in original provider
        s.materialless_hold=nil
        s.materialless_restored=true
        emit("PASS NATIVE_MATERIALLESS_RECOVERY tick="..game.tick..
          " provider="..s.provider.unit_number..
          " station_restored=1 held=0 original_mission=retained")
        -- Genuine negative: remove a PHYSICALLY BUILT feeder pole while the
        -- exact station item and all original robots remain available.
        -- Candidate poles are mined into engine-owned holds. Ineffective
        -- cuts are restored from the SAME mined item, never spawned stock.
        local frontier=root.roboport_frontier_1076
        local remote=frontier and frontier.source_port
        if not(remote and remote.valid and remote~=s.port
          and remote.is_connected_to_electric_network()
          and s.port.valid and s.port.is_connected_to_electric_network()
          and item_count(s.provider,"intermediate-cogitator-station")==1)then
          fail("NATIVE_POWERLESS_PRECONDITION_INVALID")
        end
        local candidates=s.surface.find_entities_filtered{
          name="medium-electric-pole",force=root.station.force}
        table.sort(candidates,function(a,b)
          local da=(a.position.x-remote.position.x)^2
            +(a.position.y-remote.position.y)^2
          local db=(b.position.x-remote.position.x)^2
            +(b.position.y-remote.position.y)^2
          return da==db and a.unit_number<b.unit_number or da<db
        end)
        local separated=false
        for _,pole in ipairs(candidates)do
          if pole.valid then
            local pos={x=pole.position.x,y=pole.position.y}
            local cargo_hold=game.create_inventory(1)
            if not(cargo_hold and cargo_hold.valid)then
              fail("NATIVE_POWERLESS_POLE_HOLD_MISSING")
            end
            local mined=pole.mine{inventory=cargo_hold}
            if not(mined==true and not pole.valid
              and cargo_hold.get_item_count("medium-electric-pole")==1)then
              fail("NATIVE_POWERLESS_POLE_MINE_NONCONSERVING")
            end
            if not remote.is_connected_to_electric_network()
              and s.port.is_connected_to_electric_network()then
              separated=true
              s.powerless_hold=cargo_hold
              s.powerless_position=pos
              s.powerless_cut_tick=game.tick
              s.powerless_remote_port=remote.unit_number
              break
            end
            if not s.surface.can_place_entity{
              name="medium-electric-pole",position=pos,
              force=root.station.force}then
              fail("NATIVE_POWERLESS_CANDIDATE_RESTITUTION_BLOCKED")
            end
            local debit=cargo_hold.remove{
              name="medium-electric-pole",count=1}
            if debit~=1 or cargo_hold.get_item_count("medium-electric-pole")~=0 then
              fail("NATIVE_POWERLESS_CANDIDATE_ITEM_LOST")
            end
            local restored=s.surface.create_entity{
              name="medium-electric-pole",position=pos,
              force=root.station.force}
            if not(restored and restored.valid
              and restored.is_connected_to_electric_network())then
              fail("NATIVE_POWERLESS_CANDIDATE_GRID_RESTORE_FAILED")
            end
            cargo_hold.destroy()
          end
        end
        if not separated then
          fail("NATIVE_POWERLESS_NO_REAL_SEPARATING_POLE")
        end
        emit("NATIVE_POWERLESS_CUT tick="..game.tick..
          " original_magos="..s.magos..
          " original_senior="..s.senior..
          " original_port="..s.port.unit_number..
          " remote_port="..s.powerless_remote_port..
          " pole_held=1 robots=3 station_stock=1")
        return
      end
      if s.powerless_hold then
        if game.tick-s.powerless_cut_tick<1500 then return end
        local remote=root.roboport_frontier_1076
          and root.roboport_frontier_1076.source_port
        local hold=s.powerless_hold
        -- Verify the outage and custody only before the ONE real item
        -- is spent. Later ticks verify restoration, not a still-cut grid.
        if not s.powerless_restoration_pole then
          local site=s.goal and s.goal.remote_station_position_1076
          local built=site and s.surface.find_entities_filtered{
            name="intermediate-cogitator-station",position=site,
            radius=1.5,force=root.station.force,limit=2} or {}
          local original_cell=s.port.valid and s.port.logistic_cell
          local network=original_cell and original_cell.logistic_network
          if not(hold.valid
            and hold.get_item_count("medium-electric-pole")==1
            and remote and remote.valid
            and remote.unit_number==s.powerless_remote_port
            and not remote.is_connected_to_electric_network()
            and s.port.valid and s.port.is_connected_to_electric_network()
            and network and network.valid and network.all_construction_robots==3
            and item_count(s.provider,"intermediate-cogitator-station")==1
            and not s.event_station and #built==0
            and s.ore.amount==s.ore_initial
            and root.priest.unit_number==s.magos_priest
            and senior.priest.unit_number==s.senior_priest)then
            fail("NATIVE_POWERLESS_REFUSAL_OR_CUSTODY_INVALID tick="..
              game.tick.." held="..tostring(hold.valid
                and hold.get_item_count("medium-electric-pole"))..
              " remote_powered="..tostring(remote and remote.valid
                and remote.is_connected_to_electric_network())..
              " robots="..tostring(network and network.valid
                and network.all_construction_robots)..
              " built="..tostring(#built))
          end
          emit("PASS NATIVE_POWERLESS_REFUSAL tick="..game.tick..
            " original_magos="..s.magos..
            " original_senior="..s.senior..
            " remote_port="..s.powerless_remote_port..
            " pole_held=1 station_stock=1 robots=3"..
            " native_event=none ore_unchanged=true")
        end
        -- A physically replaced pole has paid its exact item cost. Factorio
        -- may publish its merged electric/logistic graph on a later native
        -- update, so do not confuse one same-tick graph snapshot with failure.
        -- Retain the empty engine-owned hold until a real graph readback passes.
        if not s.powerless_restoration_pole then
          local pos=s.powerless_position
          if not s.surface.can_place_entity{
            name="medium-electric-pole",position=pos,
            force=root.station.force}then
            fail("NATIVE_POWERLESS_RESTORATION_SITE_BLOCKED")
          end
          local debit=hold.remove{name="medium-electric-pole",count=1}
          if debit~=1 or hold.get_item_count("medium-electric-pole")~=0 then
            fail("NATIVE_POWERLESS_RESTORATION_ITEM_NONCONSERVING")
          end
          local restored=s.surface.create_entity{
            name="medium-electric-pole",position=pos,
            force=root.station.force}
          if not(restored and restored.valid
            and restored.name=="medium-electric-pole"
            and restored.force==root.station.force
            and restored.position.x==pos.x
            and restored.position.y==pos.y)then
            fail("NATIVE_POWERLESS_RESTORATION_ENTITY_INVALID")
          end
          s.powerless_restoration_pole=restored
          s.powerless_restoration_tick=game.tick
          return
        end
        local restored=s.powerless_restoration_pole
        if not(hold.valid
          and hold.get_item_count("medium-electric-pole")==0
          and restored.valid and restored.name=="medium-electric-pole"
          and restored.force==root.station.force
          and restored.position.x==s.powerless_position.x
          and restored.position.y==s.powerless_position.y
          and remote and remote.valid
          and remote.unit_number==s.powerless_remote_port
          and s.port.valid and s.port.is_connected_to_electric_network()
          and root.priest.unit_number==s.magos_priest
          and senior.priest.unit_number==s.senior_priest)then
          fail("NATIVE_POWERLESS_RESTORATION_CUSTODY_INVALID")
        end
        local current_root=s.port.logistic_cell
        local current_remote=remote.logistic_cell
        local original_network=current_root and current_root.logistic_network
        local returned_network=current_remote and current_remote.logistic_network
        -- Electric poles do not consume or produce electric power; the
        -- Factorio API's is_connected_to_electric_network() is false for
        -- them even when they join an ordinary live copper-wire grid.
        -- Require the actual pole's native electric_network_id instead.
        local joined=(restored.electric_network_id~=nil
          and restored.electric_network_id==s.original_electric_grid
          and remote.is_connected_to_electric_network()
          and remote.electric_network_id==s.port.electric_network_id
          and s.port.electric_network_id==s.original_electric_grid
          and original_network and original_network.valid
          and returned_network and returned_network.valid
          and original_network.network_id==returned_network.network_id)
        if not joined then
          if game.tick-s.powerless_restoration_tick<180 then return end
          fail("NATIVE_POWERLESS_RESTORED_GRID_NOT_JOINED tick="..game.tick..
            " pole_grid="..tostring(restored.electric_network_id)..
            " remote_power="..tostring(remote.is_connected_to_electric_network())..
            " root_grid="..tostring(s.port.electric_network_id)..
            " remote_grid="..tostring(remote.electric_network_id)..
            " original_grid="..tostring(s.original_electric_grid)..
            " root_network="..tostring(original_network and original_network.valid
              and original_network.network_id)..
            " remote_network="..tostring(returned_network and returned_network.valid
              and returned_network.network_id))
        end
        hold.destroy() -- only after exact mined pole item was consumed
        s.powerless_hold=nil
        s.powerless_restoration_pole=nil
        s.powerless_restored=true
        emit("PASS NATIVE_POWERLESS_RECOVERY tick="..game.tick..
          " original_port="..s.port.unit_number..
          " remote_port="..remote.unit_number..
          " pole_debit=1 held=0 electric_grid=original"..
          " logistic_network=merged original_mission=retained")
      end
      local goal=s.goal
      local site=goal and goal.remote_station_position_1076
      if not(site and s.event_station and s.event_robot) then
        if game.tick-s.started_tick>42000 then
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
      if not s.extension_accepted then
        fail("ROBOT_STATION_WITHOUT_COUNTED_POWERED_FRONTIER_EXTENSION")
      end
      local built=pairs_by_station[s.event_station]
      local receipt=senior.robot_network_last_task_0338
      local last=receipt and receipt.built_entity
      local ghosts=s.surface.find_entities_filtered{
        name="entity-ghost",position=site,radius=1.5,
        force=root.station.force,limit=5}
      -- A native robot event precedes the 0338 receipt service and can
      -- precede the next 0480 hierarchy rebuild. Never accept the event
      -- alone: observe the ORIGINAL full item/rank/identity contract after
      -- three bounded canonical rebuilds, and fail closed if it never settles.
      local provider_stock=item_count(s.provider,"intermediate-cogitator-station")
      local network_stock=network.get_item_count("intermediate-cogitator-station")
      local built_rank=built and hierarchy.rank(built) or nil
      local direct=built and hierarchy.is_direct_subordinate(senior,built) or false
      if not(built and built.station and built.station.valid
        and built.station.unit_number==s.event_station
        and built.priest and built.priest.valid
        and built.station==last and receipt.phase=="complete"
        and receipt.child_station_unit==s.event_station
        and receipt.child_priest_unit==built.priest.unit_number
        and receipt.network_stock_before==1
        and receipt.stock_delta_verified==true
        and provider_stock==0 and network_stock==0
        and #ghosts==0 and built_rank==2 and direct==true
        and root.priest.unit_number==s.magos_priest
        and senior.priest.unit_number==s.senior_priest
        and type(receipt.started_tick)=="number"
        and s.event_tick>=receipt.started_tick) then
        local active=senior.robot_network_task_0338
        local detail=" tick="..game.tick..
          " event_tick="..tostring(s.event_tick)..
          " built_pair="..tostring(built~=nil)..
          " built_priest="..tostring(built and built.priest and built.priest.unit_number)..
          " built_rank="..tostring(built_rank)..
          " direct="..tostring(direct)..
          " receipt_phase="..tostring(receipt and receipt.phase)..
          " active_phase="..tostring(active and active.phase)..
          " receipt_station="..tostring(receipt and receipt.child_station_unit)..
          " debit="..tostring(receipt and receipt.stock_delta_verified)..
          " provider_stock="..tostring(provider_stock)..
          " network_stock="..tostring(network_stock)..
          " ghosts="..tostring(#ghosts)
        if not s.receipt_wait_logged then
          s.receipt_wait_logged=true
          emit("WAIT NATIVE_ROBOT_RECEIPT_SETTLING"..detail)
        end
        local interval=tonumber(hierarchy.rebuild_interval) or 300
        if game.tick-s.event_tick<3*interval then return end
        fail("NATIVE_ROBOT_RECEIPT_RANK_OR_ITEM_MISMATCH"..detail)
      end
      -- The first paid station is already an independently accepted gate.
      -- Continue observing PRODUCTION 1076 -> 0820 -> 0837, without
      -- inserting ore, forcing a task or granting coverage. A complete
      -- Method II ore milestone needs real upstream chest receipts too.
      s.phase="awaiting-native-ore-return"
      s.ore_return_wait_started=game.tick
      s.intermediate_priest=built.priest.unit_number
      emit("PASS autonomous original 0259 selected and physical native robot-built Intermediate paired"..
        " tick="..game.tick.." magos="..s.magos..
        " magos_priest="..s.magos_priest..
        " senior="..s.senior.." senior_priest="..s.senior_priest..
        " intermediate="..s.event_station..
        " intermediate_priest="..built.priest.unit_number..
        " native_robot="..s.event_robot.." material_delta=1"..
        " source_stock=0 ghost=0 ore_return_not_credited=true")
      return
    end
    if s.phase=="awaiting-native-ore-return" then
      local chain=rawget(_G,"TechPriestsResourceStationChain0820")
      local courier=rawget(_G,"TechPriestsResourceReturnCourier0837")
      local mission=root.resource_expansion_0259
        and root.resource_expansion_0259.chain_0820
      local cargo=mission and mission.return_courier_0837
      local route,why=chain and chain.return_route(root)

      -- 1382: occupy the ORIGINAL Magos with fully counted, physically mined
      -- native tank items while an independently mined natural ore is en route.
      -- Congestion is not emulated by filters, inventory bars or free item grants.
      if FULL_STORAGE and not s.storage_cut_tick
        and cargo and cargo.phase=="carrying"
        and (cargo.hops_completed or 0)<1
        and cargo.source_kind_0991=="natural-ore"
        and cargo.quantity==1 and cargo.inventory and cargo.inventory.valid
        and cargo.inventory.get_item_count("iron-ore")==1 then
        local chest=root.station.get_inventory(defines.inventory.chest)
        if not(chest and chest.valid
          and chest.get_item_count("iron-ore")==0)then
          fail("NATIVE_PARENT_STORAGE_PRECONDITION_INVALID")
        end
        local tanks=0
        local slots=#chest
        while chest.get_insertable_count("iron-ore")>0
          and tanks<=slots+1 do
          local before=chest.get_item_count("tank")
          local entity=place(s.surface,root.station.force,"tank",40,50)
          if not(entity.mine{inventory=chest}==true and not entity.valid
            and chest.get_item_count("tank")==before+1)then
            fail("NATIVE_PARENT_STORAGE_TANK_MINE_FAILED")
          end
          tanks=tanks+1
        end
        if not(tanks>0 and tanks<=slots+1
          and chest.get_insertable_count("iron-ore")==0)then
          fail("NATIVE_PARENT_STORAGE_NOT_GENUINELY_FULL")
        end
        s.storage_cut_tick=game.tick
        s.storage_filler_count=tanks
        emit("NATIVE_MAGOS_FULL_STORAGE_CUT tick="..game.tick..
          " magos="..s.magos.." tanks_physically_mined="..tanks..
          " insertable_ore=0 original_courier_held=1")
      end
      if FULL_STORAGE and s.storage_cut_tick and not s.storage_restored then
        local chest=root.station.get_inventory(defines.inventory.chest)
        if cargo and cargo.phase=="carrying"
          and cargo.hops_completed==1
          and cargo.last_reason=="upstream-inventory-full"
          and cargo.last_refused_destination_unit==s.magos
          and type(cargo.last_refused_tick)=="number"
          and cargo.last_refused_tick>=s.storage_cut_tick then
          s.storage_refusal_tick=s.storage_refusal_tick or game.tick
        end
        if s.storage_refusal_tick
          and game.tick-s.storage_refusal_tick>=1500 then
          local entries=cargo and cargo.receipts_0982
          local first=entries and entries[1]
          if not(chest and chest.valid
            and chest.get_insertable_count("iron-ore")==0
            and chest.get_item_count("iron-ore")==0
            and chest.get_item_count("tank")==s.storage_filler_count
            and cargo and cargo.phase=="carrying"
            and cargo.hops_completed==1
            and cargo.quantity==1
            and cargo.inventory and cargo.inventory.valid
            and cargo.inventory.get_item_count("iron-ore")==1
            and type(entries)=="table" and #entries==1
            and first and first.hop==1
            and first.destination_station_unit==s.senior
            and s.ore.amount==cargo.ore_amount_before-1
            and root.priest.unit_number==s.magos_priest
            and senior.priest.unit_number==s.senior_priest)then
            fail("NATIVE_PARENT_FULL_REFUSAL_OR_CUSTODY_MISMATCH")
          end
          emit("PASS NATIVE_MAGOS_FULL_STORAGE_REFUSAL tick="..game.tick..
            " magos="..s.magos.." held=1 hops=1 magos_ore=0"..
            " elapsed="..(game.tick-s.storage_refusal_tick)..
            " no_ore_created=true")
          local hold=game.create_inventory(math.max(1,s.storage_filler_count))
          if not(hold and hold.valid) then
            fail("NATIVE_PARENT_STORAGE_ESCROW_UNAVAILABLE")
          end
          local moved=chest.remove{name="tank",count=s.storage_filler_count}
          local inserted=hold.insert{name="tank",count=moved}
          if not(moved==s.storage_filler_count
            and inserted==moved
            and chest.get_item_count("tank")==0
            and hold.get_item_count("tank")==s.storage_filler_count
            and chest.get_insertable_count("iron-ore")>0)then
            fail("NATIVE_PARENT_STORAGE_RECOVERY_NONCONSERVING")
          end
          s.storage_hold=hold
          s.storage_restored=true
          emit("PASS NATIVE_MAGOS_STORAGE_RECOVERY tick="..game.tick..
            " magos="..s.magos.." tanks_escrowed="..moved..
            " insertable_ore_positive=true original_courier_retained=true")
        elseif game.tick-s.storage_cut_tick>18000 then
          fail("NATIVE_PARENT_STORAGE_REFUSAL_TIMEOUT tick="..game.tick..
            " phase="..tostring(cargo and cargo.phase)..
            " reason="..tostring(cargo and cargo.last_reason)..
            " hops="..tostring(cargo and cargo.hops_completed))
        end
      end
      -- Save only an actually mined, engine-owned first-hop ore item after
      -- the restored original-powered roboport network and ranked robot
      -- station are complete. No source inventory or entity is manufactured.
      if CARGO_RELOAD and not s.cargo_reload_requested
        and cargo and cargo.phase=="carrying" and (cargo.hops_completed or 0)==0
        and type(cargo.receipts_0982)=="table" and #cargo.receipts_0982==0
        and cargo.source_kind_0991=="natural-ore" and cargo.quantity==1
        and cargo.inventory and cargo.inventory.valid
        and cargo.inventory.get_item_count("iron-ore")==1 then
        local frontier=root.roboport_frontier_1076
        local remote=frontier and frontier.source_port
        local a=s.port.valid and s.port.logistic_cell
        local b=remote and remote.valid and remote.logistic_cell
        local an=a and a.logistic_network
        local bn=b and b.logistic_network
        if not(s.coverageless_restored and s.materialless_restored
          and s.extension_accepted and remote and remote.valid
          and remote~=s.port and an and an.valid and bn and bn.valid
          and an.network_id==bn.network_id
          and s.port.electric_network_id==s.original_electric_grid
          and remote.electric_network_id==s.original_electric_grid
          and s.ore.amount==cargo.ore_amount_before-1
          and root.priest.unit_number==s.magos_priest
          and senior.priest.unit_number==s.senior_priest
          and not(cargo.receipts_0982 and cargo.receipts_0982[1])) then
          fail("NATIVE_CARGO_RELOAD_UNSAFE_SAVE_PRECONDITION")
        end
        s.cargo_reload_snapshot={
          magos=s.magos,senior=s.senior,intermediate=s.event_station,
          magos_priest=s.magos_priest,senior_priest=s.senior_priest,
          intermediate_priest=s.intermediate_priest,
          root_port=s.port.unit_number,remote_port=remote.unit_number,
          grid=s.original_electric_grid,ore_before=cargo.ore_amount_before,
          ore_after=s.ore.amount}
        s.cargo_reload_requested=true
        local ok,why=pcall(function()
          game.auto_save("tech-priests-ci-1380-cargo", true)
        end)
        if not ok then fail("NATIVE_CARGO_AUTOSAVE_FAILED "..tostring(why)) end
        emit("NATIVE_CARGO_SAVE_REQUESTED tick="..game.tick..
          " magos="..s.magos.." senior="..s.senior..
          " intermediate="..s.event_station..
          " magos_priest="..s.magos_priest..
          " senior_priest="..s.senior_priest..
          " intermediate_priest="..s.intermediate_priest..
          " root_port="..s.port.unit_number.." remote_port="..remote.unit_number..
          " ore_before="..cargo.ore_amount_before..
          " ore_after="..s.ore.amount.." held=1 hops=0")
      end
      if CARGO_RELOAD and RELOAD_PROCESS and not s.cargo_reload_verified then
        local snap=s.cargo_reload_snapshot
        local frontier=root.roboport_frontier_1076
        local remote=frontier and frontier.source_port
        local a=s.port.valid and s.port.logistic_cell
        local b=remote and remote.valid and remote.logistic_cell
        local an=a and a.logistic_network
        local bn=b and b.logistic_network
        if not(s.cargo_reload_requested and snap
          and root.station.unit_number==snap.magos
          and senior.station.unit_number==snap.senior
          and s.event_station==snap.intermediate
          and root.priest.unit_number==snap.magos_priest
          and senior.priest.unit_number==snap.senior_priest
          and s.intermediate_priest==snap.intermediate_priest
          and s.port.valid and s.port.unit_number==snap.root_port
          and remote and remote.valid and remote.unit_number==snap.remote_port
          and an and an.valid and bn and bn.valid
          and an.network_id==bn.network_id
          and s.port.electric_network_id==snap.grid
          and remote.electric_network_id==snap.grid
          and s.ore.amount==snap.ore_after
          and snap.ore_before==snap.ore_after+1
          and cargo and cargo.phase=="carrying"
          and (cargo.hops_completed or 0)==0 and cargo.quantity==1
          and type(cargo.receipts_0982)=="table" and #cargo.receipts_0982==0
          and cargo.source_kind_0991=="natural-ore"
          and cargo.inventory and cargo.inventory.valid
          and cargo.inventory.get_item_count("iron-ore")==1
          and not(cargo.receipts_0982 and cargo.receipts_0982[1])) then
          fail("NATIVE_CARGO_INDEPENDENT_RELOAD_CUSTODY_INVALID")
        end
        s.cargo_reload_verified=true
        emit("PASS NATIVE_CARGO_INDEPENDENT_RELOAD tick="..game.tick..
          " magos="..snap.magos.." senior="..snap.senior..
          " intermediate="..snap.intermediate..
          " magos_priest="..snap.magos_priest..
          " senior_priest="..snap.senior_priest..
          " intermediate_priest="..snap.intermediate_priest..
          " root_port="..snap.root_port.." remote_port="..snap.remote_port..
          " ore_before="..snap.ore_before.." ore_after="..snap.ore_after..
          " held=1 hops=0 original_grid=joined")
      end
      if not s.ore_wait_readback and
          game.tick-s.ore_return_wait_started>=3600 then
        s.ore_wait_readback=true
        emit("NATIVE_ORE_RETURN_WAIT tick="..game.tick..
          " frontier="..tostring(root.roboport_frontier_1076
            and root.roboport_frontier_1076.status)..
          " station="..tostring(root.roboport_frontier_1076
            and root.roboport_frontier_1076.remote_station_unit_1076)..
          " mission="..tostring(mission and mission.status)..
          " robot_route="..tostring(mission and mission.robot_frontier_route_0820)..
          " route="..tostring(route and #route)..
          " route_reason="..tostring(why)..
          " cargo_phase="..tostring(cargo and cargo.phase)..
          " cargo_reason="..tostring(cargo and cargo.last_reason)..
          " courier_block="..tostring(cargo and cargo.last_terminal_handoff_reason_1126)..
          " magos_ore="..tostring(item_count(root.station,"iron-ore")))
      end
      local entries=cargo and cargo.receipts_0982
      local hop1=entries and entries[1]
      local hop2=entries and entries[2]
      local ledger_ok=route and courier and courier.validate_receipts_0982
        and courier.validate_receipts_0982(cargo,route)==true
      if mission and mission.status=="reached-resource"
        and mission.robot_frontier_route_0820==true
        and mission.current_station_unit==s.event_station
        and route and #route==3 and route[1]==s.event_station
        and route[2]==s.senior and route[3]==s.magos
        and cargo and cargo.phase=="magos-delivered"
        and cargo.source_kind_0991=="natural-ore"
        and cargo.item=="iron-ore" and cargo.quantity==1
        and cargo.inventory==nil and cargo.hops_completed==2
        and cargo.delivered_count==1
        and cargo.delivered_station_unit==s.magos
        and (mission.delivered_to_magos_count or 0)>=1
        and ledger_ok
        and hop1 and hop1.hop==1
        and hop1.source_station_unit==s.event_station
        and hop1.destination_station_unit==s.senior
        and hop1.carrier_priest_unit==s.intermediate_priest
        and hop1.item=="iron-ore" and hop1.quantity==1
        and hop1.destination_after==hop1.destination_before+1
        and hop2 and hop2.hop==2
        and hop2.source_station_unit==s.senior
        and hop2.destination_station_unit==s.magos
        and hop2.carrier_priest_unit==s.senior_priest
        and hop2.item=="iron-ore" and hop2.quantity==1
        and hop2.destination_after==hop2.destination_before+1
        and s.ore.valid and cargo.ore_amount_before
        and cargo.ore_source_name_1171=="iron-ore"
        and cargo.ore_source_surface_index_1171==s.surface.index
        and cargo.ore_source_position_1171
        and cargo.ore_source_position_1171.x==s.ore.position.x
        and cargo.ore_source_position_1171.y==s.ore.position.y
        and s.ore.amount==cargo.ore_amount_before-1
        and (item_count(root.station,"iron-ore") or 0)>=hop2.destination_after
        and root.priest.unit_number==s.magos_priest
        and senior.priest.unit_number==s.senior_priest then
        if FULL_STORAGE then
          if not(s.storage_restored and s.storage_hold and s.storage_hold.valid
            and s.storage_hold.get_item_count("tank")==s.storage_filler_count)then
            fail("NATIVE_PARENT_STORAGE_DELIVERY_WITHOUT_REFUSAL_RECOVERY")
          end
          emit("PASS NATIVE_MAGOS_STORAGE_RECOVERED_DELIVERY tick="..game.tick..
            " magos="..s.magos.." delivered=1 held=0 hops=2"..
            " filler_preserved="..s.storage_filler_count)
        end
        if CARGO_RELOAD then
          if not(RELOAD_PROCESS and s.cargo_reload_verified) then
            fail("NATIVE_CARGO_RELOAD_DELIVERY_NOT_VERIFIED")
          end
          emit("PASS NATIVE_CARGO_RELOADED_DELIVERY tick="..game.tick..
            " magos="..s.magos.." senior="..s.senior..
            " intermediate="..s.event_station..
            " ore_after="..s.ore.amount.." delivered=1 held=0 hops=2")
        end
        s.finished=true
        emit("PASS NATIVE_PHYSICAL_ORE_RETURN tick="..game.tick..
          " original_magos="..s.magos..
          " magos_priest="..s.magos_priest..
          " senior="..s.senior..
          " senior_priest="..s.senior_priest..
          " intermediate="..s.event_station..
          " intermediate_priest="..s.intermediate_priest..
          " source_amount_before="..cargo.ore_amount_before..
          " source_amount_after="..s.ore.amount..
          " hop1_delta=1 hop2_delta=1 magos_deposit=1"..
          " delivered_tick="..tostring(cargo.completed_tick)..
          " source_kind=natural-ore inventory_hold=empty")
        return
      end
      if game.tick-s.ore_return_wait_started>=48000 then
        fail("NATIVE_ORE_RETURN_TIMEOUT tick="..game.tick..
          " mission="..tostring(mission and mission.status)..
          " frontier="..tostring(root.roboport_frontier_1076
            and root.roboport_frontier_1076.status)..
          " route_reason="..tostring(why)..
          " cargo_phase="..tostring(cargo and cargo.phase)..
          " cargo_reason="..tostring(cargo and cargo.last_reason)..
          " delivered="..tostring(mission and mission.delivered_to_magos_count)..
          " current_source="..tostring(s.ore.valid and s.ore.amount)..
          " magos_ore="..tostring(item_count(root.station,"iron-ore")))
      end
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
