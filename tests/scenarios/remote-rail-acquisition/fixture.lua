-- Factorio-native test-only distant-resource TRAIN acceptance, independent
-- of ranked Cogitator relays. Test fixture seeds supply and technology only.
-- It NEVER creates rails, locomotives, wagons, miners or mined cargo.
local M={}
local Frontier=require("scripts.core.rail_track_frontier_0836")
local PREFIX="[TP-REMOTE-RAIL-TEST] "
-- Keep the native target inside the production builder's counted segment
-- budget, using the last REAL item-debited rail, not an unbuilt next step.
local MAX_NATIVE_TARGET_X=math.min(960,
  Frontier.start_offset+Frontier.segment_step*(Frontier.max_segments-1)
  +Frontier.destination_clearance)
local STATION={x=0,y=0}
local ORE -- Selected from pre-existing native world-generated iron ore.
local KEY="ci_remote_rail_acquisition"
local function emit(msg)log(PREFIX..msg)end
local function fail(msg)error(PREFIX.."FAIL "..msg)end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  local s=storage.tech_priests[KEY] or {}
  storage.tech_priests[KEY]=s
  return s
end
local function count(surface,opts)
  return #surface.find_entities_filtered(opts)
end
local function setup()
  local s=root()
  if s.started then return end
  local surface,force=game.surfaces[1],game.forces.player
  local necessary={"planetary-magos-cogitator-station","straight-rail",
    "locomotive","cargo-wagon","burner-mining-drill","iron-ore"}
  for _,n in ipairs(necessary) do
    if not prototypes.entity[n] then fail("MISSING_PROTOTYPE "..n) end
  end
  -- A random map seed need not put natural iron on the arbitrary y=0
  -- latitude. Locate a real generated patch FIRST; center the empty test
  -- station on its railway-compatible latitude, without changing the ore.
  -- The 0835/0836 physical item, chart and rail-graph gates remain intact.
  local function find_natural_patch(min_y,max_y)
    local candidates=surface.find_entities_filtered{
      type="resource",name="iron-ore",
      area={{192,min_y},{MAX_NATIVE_TARGET_X,max_y}}}
    table.sort(candidates,function(a,b)
      return a.position.x<b.position.x or
        (a.position.x==b.position.x
          and math.abs(a.position.y)<math.abs(b.position.y))
    end)
    for _,e in ipairs(candidates) do
      if e.valid and (tonumber(e.amount)or 0)>0 then
        -- The original builder uses an even-tile eastbound rail axis.
        local origin={x=0,y=math.floor(e.position.y/2)*2}
        local needed=Frontier.required_segments_for_target(origin,e.position)
        if needed and needed<=Frontier.max_segments then
          return e,origin
        end
      end
    end
  end
  -- Prefer the original generated band; expand only when it lacks a
  -- reachable natural patch. Chunk requests never manufacture ore entities.
  for x=0,960,64 do surface.request_to_generate_chunks({x=x,y=0},3) end
  surface.force_generate_chunk_requests()
  local natural,origin=find_natural_patch(-96,96)
  if not natural then
    for _,latitude in ipairs({192,-192,384,-384,576,-576}) do
      for x=0,576,192 do
        surface.request_to_generate_chunks({x=x,y=latitude},3)
      end
      surface.force_generate_chunk_requests()
      natural,origin=find_natural_patch(latitude-96,latitude+96)
      if natural then break end
    end
  end
  if not natural then
    fail("NO_NATURALLY_GENERATED_EASTBOUND_IRON_PATCH seed_requires_reselection"..
      " max_reachable_x="..MAX_NATIVE_TARGET_X..
      " searched_generated_latitudes=0,+/-192,+/-384,+/-576")
  end
  STATION.y=origin.y
  ORE={x=natural.position.x,y=natural.position.y}
  local original_amount=natural.amount
  local tiles={}
  for x=-25,ORE.x+28 do for y=STATION.y-16,STATION.y+16 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  -- The Magos and build corridor are cleared of unrelated obstacles,
  -- but the real native target iron patch must remain untouched.
  -- This is a controlled isolated test world, not a gameplay cleanup.
  -- Exclude the ENTIRE Magos short-range acquisition footprint; clearing
  -- only the rail corridor left naturally generated ore 20 tiles north
  -- of the station and incorrectly defeated genuine starvation detection.
  local exclusion={{-96,STATION.y-80},{math.max(576,ORE.x+64),STATION.y+80}}
  local area={{-25,STATION.y-16},{ORE.x+28,STATION.y+17}}
  for _,e in ipairs(surface.find_entities_filtered{area=exclusion}) do
    -- Preserve naturally generated target ore, including its surrounding
    -- patch. Other resources here are fixture obstacles, never delivery.
    local target_patch=e.type=="resource" and e.name=="iron-ore"
      and math.abs(e.position.x-ORE.x)<=16
      and math.abs(e.position.y-ORE.y)<=16
    if e.valid and not target_patch
        and (e.type=="resource" or e.type=="tree"
        or e.type=="simple-entity" or e.type=="cliff"
        or e.force==game.forces.enemy) then e.destroy() end
  end
  if not(natural.valid and natural.amount==original_amount) then
    fail("NATURAL_ORE_SOURCE_DAMAGED_DURING_FIXTURE_ISOLATION")
  end
  local station=surface.create_entity{
    name="planetary-magos-cogitator-station",
    position=STATION,force=force,raise_built=true}
  if not(station and station.valid)then fail("PLANETARY_STATION_PLACEMENT")end
  local inventory=station.get_inventory(defines.inventory.chest)
  if not(inventory and inventory.valid)then fail("STATION_INVENTORY_MISSING")end
  -- Technology is unlocked BY THE FIXTURE, not counted as autonomous science.
  -- This exercise starts after the train research phase.
  for _,name in ipairs({"railway","automated-rail-transportation",
      "engine","electric-energy-distribution-1",
      "automobilism","logistics-2","automation-2"}) do
    local tech=force.technologies[name]
    if tech and tech.enabled~=false then tech.researched=true end
  end
  -- Planetary Magos has seven actual chest slots. Keep 600 rails in
  -- six native stacks plus one free slot. Other physical supplies live in
  -- a nearby steel chest, reachable by the canonical 0686/0338 builder.
  -- The fixture supplies this chest, NEVER rails or rolling stock as entities.
  -- It consumes one of the original 20 steel-chest items in the manifest.
  local depot=surface.create_entity{
    name="steel-chest",position={x=-8,y=STATION.y+8},
    force=force,raise_built=true}
  if not(depot and depot.valid)then fail("SUPPLY_DEPOT_PLACEMENT")end
  local depot_inventory=depot.get_inventory(defines.inventory.chest)
  if not(depot_inventory and depot_inventory.valid)then
    fail("SUPPLY_DEPOT_INVENTORY_MISSING")
  end
  -- Preserve all original rail, fuel, train, drill and auxiliary supply
  -- quantities; every item must fit a REAL engine-managed inventory.
  local stock={{"rail",700},{"locomotive",2},{"cargo-wagon",3},
    {"train-stop",4},{"rail-signal",50},{"rail-chain-signal",30},
    {"burner-mining-drill",12},{"electric-mining-drill",12},
    {"transport-belt",300},{"inserter",40},{"iron-chest",30},
    {"steel-chest",19},{"coal",300},{"solid-fuel",100},
    {"stone-furnace",8},{"iron-plate",400},{"copper-plate",200},
    {"repair-pack",30},{"firearm-magazine",30}}
  for _,item in ipairs(stock) do
    if not prototypes.item[item[1]] then
      fail("REQUIRED_RAIL_SUPPLY_MISSING "..item[1])
    end
    local station_quantity=item[1]=="rail" and 600 or 0
    local depot_quantity=item[2]-station_quantity
    if station_quantity>0 then
      local accepted=inventory.insert{name=item[1],count=station_quantity}
      if accepted~=station_quantity then
        fail("STATION_PRESTOCK_CAPACITY "..item[1].." inserted="..accepted)
      end
    end
    if depot_quantity>0 then
      local accepted=depot_inventory.insert{name=item[1],count=depot_quantity}
      if accepted~=depot_quantity then
        fail("DEPOT_PRESTOCK_CAPACITY "..item[1].." inserted="..accepted)
      end
    end
  end
  if inventory.get_item_count("rail")~=600
      or depot_inventory.get_item_count("rail")~=100
      or depot_inventory.get_item_count("steel-chest")~=19 then
    fail("PHYSICAL_PRESTOCK_RECONCILIATION")
  end
  -- Do not credit test-script materialization of ore as native mining.
  local ore_tiles=count(surface,{type="resource",name="iron-ore",
    position=ORE,radius=16})
  if ore_tiles<1 then fail("NATURAL_REMOTE_ORE_PATCH_MISSING")end
  -- The destination has been charted by prior remote reconnaissance. The
  -- Magos may use only charted map intelligence, not omniscient surface scans.
  -- The targeted chart request stayed pending through 1,800 real
  -- headless benchmark ticks in Factorio 2.1.24. During this isolated
  -- pre-mission reconnaissance, chart all ALREADY GENERATED chunks using
  -- Factorio's native force chart API, not fabricated ore/intelligence.
  -- This never credits track, resources, cargo, or a completed objective.
  -- The strict delayed is_chunk_charted readback remains mandatory.
  local target_chunk={x=math.floor(ORE.x/32),y=math.floor(ORE.y/32)}
  force.chart(surface,{{ORE.x-20,ORE.y-20},{ORE.x+20,ORE.y+20}})
  force.chart_all(surface)
  emit("CHART_SETUP target_chunk="..target_chunk.x..","..target_chunk.y..
    " charted="..tostring(force.is_chunk_charted(surface,target_chunk))..
    " requested="..tostring(force.is_chunk_requested_for_charting(surface,target_chunk)))
  s.chart_target_chunk=target_chunk
  if count(surface,{type="resource",
      area={{-64,STATION.y-64},{64,STATION.y+64}}})~=0 then
    fail("UNEXPECTED_NEARBY_ORE")
  end
  local rails=count(surface,{type={"straight-rail","half-diagonal-rail",
    "curved-rail-a","curved-rail-b"},area=area})
  if rails~=0 or count(surface,{name={"locomotive","cargo-wagon"},
        area=area})~=0 then
    fail("FIXTURE_PREBUILT_TRAIN_OR_RAIL")
  end
  s.depot_unit=depot.unit_number
  s.station_unit=station.unit_number
  s.station_y=STATION.y
  s.started=game.tick
  s.start_ore=inventory.get_item_count("iron-ore")
  s.start_rail=inventory.get_item_count("rail")
  s.natural_ore_x=ORE.x
  s.natural_ore_y=ORE.y
  s.natural_ore_amount=original_amount
  s.outbound=false;s.returned=false;s.ride_proof=false
  emit("SETUP no_biters=true local_resources=0 natural_iron=true"..
    " station_y="..STATION.y..
    " native_ore_amount="..original_amount..
    " target_x="..ORE.x.." target_y="..ORE.y..
    " rails=700 rails_station=600 rails_depot=100"..
    " locomotives=2 wagons=3"..
    " tech_preset=true track_prebuilt=0 initial_iron="..s.start_ore)
end
local function inspect(s,elapsed)
  local surface=game.surfaces[1]
  local station=surface.find_entities_filtered{
    name="planetary-magos-cogitator-station",
    position={x=0,y=s.station_y or 0},radius=2,
    force=game.forces.player}[1]
  local p=storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[s.station_unit]
  if not(station and station.valid and p and p.priest
      and p.priest.valid) then fail("PLANETARY_MAGOS_PAIR_LOST") end
  local objective=p.remote_rail_outpost_0835
  if elapsed>=1800 and not s.chart_verified then
    local target_chunk=s.chart_target_chunk
    if not (target_chunk and station.force.is_chunk_charted(
        surface,target_chunk)) then
      local pending=target_chunk and
        station.force.is_chunk_requested_for_charting(surface,target_chunk)
      fail("REMOTE_ORE_NOT_CHARTED_AFTER_TICKS="..elapsed..
        " requested="..tostring(pending))
    end
    s.chart_verified=true
    emit("PASS naturally generated ore chunk charted before rail objective")
  end
  if elapsed>=1800 and not (objective
      and (objective.status=="starvation-confirmed"
        or objective.status=="building-physical-rail"
        or objective.status=="rail-track-established"
        or objective.status=="rail-track-blocked")
      and objective.item=="iron-ore" and objective.target
      and objective.target.x>=192
      and math.abs(objective.target.x-s.natural_ore_x)<=16
      and math.abs(objective.target.y-s.natural_ore_y)<=16
      and objective.root_station_unit==s.station_unit
      and objective.created_tick and objective.next_step) then
    fail("STARVATION_DETECTION_DID_NOT_CREATE_PERSISTENT_RAIL_OBJECTIVE")
  end
  if elapsed>=1800 and not s.starvation_verified then
    s.starvation_verified=true
    emit("PASS starvation detected with real supplies, charted target and durable Magos objective")
  end
  local rails=surface.find_entities_filtered{
    type={"straight-rail","half-diagonal-rail",
      "curved-rail-a","curved-rail-b"},
    area={{-25,(s.station_y or 0)-16},
          {s.natural_ore_x+28,(s.station_y or 0)+17}},
    force=station.force}
  local near,far=0,0
  for _,e in ipairs(rails) do
    if e.position.x<=24 then near=near+1 end
    if e.position.x>=s.natural_ore_x-32 then far=far+1 end
  end
  -- A route objective and even a ghost are not physically placed rail.
  -- The first acceptance requires a real segment with the exact unit
  -- recorded by the 0836 frontier AFTER canonical 0338 construction.
  if elapsed>=18000 and not s.first_physical_rail_verified then
    local frontier=objective and objective.rail_frontier_0836
    local first_unit=frontier and frontier.built_units
      and frontier.built_units[1]
    local first_found=false
    for _,track in ipairs(rails)do
      if track.valid and first_unit and track.unit_number==first_unit
          and track.name=="straight-rail"
          and track.force==station.force then
        first_found=true
        break
      end
    end
    local current_rail=station.get_inventory(defines.inventory.chest)
      .get_item_count("rail")
    if not(frontier and (frontier.segment or 0)>0
        and first_found and current_rail<s.start_rail) then
      fail("RAIL_FIRST_ENGINE_CONSTRUCTION_NOT_PROVEN"..
        " segment="..tostring(frontier and frontier.segment)..
        " physical="..tostring(first_found)..
        " source_rail="..tostring(current_rail))
    end
    s.first_physical_rail_verified=true
    emit("PASS first physical rail built and exact stock debited"..
      " unit="..tostring(first_unit)..
      " station_rail_delta="..tostring(s.start_rail-current_rail))
  end
  -- Distinct native intermediate gate: two original 0338-built rails,
  -- separate real item debits and Factorio's actual graph connectivity.
  if elapsed>=36000 and not s.connected_track_verified then
    local frontier=objective and objective.rail_frontier_0836
    local ids=frontier and frontier.built_units
    local first,second
    for _,track in ipairs(rails) do
      if track.valid and track.name=="straight-rail"
          and track.force==station.force then
        if ids and track.unit_number==ids[1] then first=track end
        if ids and track.unit_number==ids[2] then second=track end
      end
    end
    local connected=false
    if first and second and first~=second
        and type(first.get_connected_rail)=="function" then
      for _,rail_direction in ipairs({
        defines.rail_direction.front,defines.rail_direction.back}) do
        local ok,neighbor=pcall(first.get_connected_rail,{
          rail_direction=rail_direction,
          rail_connection_direction=defines.rail_connection_direction.straight})
        if ok and neighbor==second then connected=true;break end
      end
    end
    local current_rail=station.get_inventory(defines.inventory.chest)
      .get_item_count("rail")
    if not(frontier and frontier.segment>=2 and first and second
        and connected and s.start_rail-current_rail>=2) then
      fail("TWO_NATIVE_CONNECTED_COUNTED_RAILS_NOT_PROVEN"..
        " segment="..tostring(frontier and frontier.segment)..
        " first="..tostring(first and first.unit_number)..
        " second="..tostring(second and second.unit_number)..
        " native_connected="..tostring(connected)..
        " stock_delta="..tostring(s.start_rail-current_rail))
    end
    s.connected_track_verified=true
    emit("PASS two distinct 0338-debited native-connected rails"..
      " first_unit="..first.unit_number..
      " second_unit="..second.unit_number..
      " station_rail_delta="..(s.start_rail-current_rail))
  end
  local locomotives=surface.find_entities_filtered{
    name="locomotive",area={{-25,(s.station_y or 0)-16},
          {s.natural_ore_x+28,(s.station_y or 0)+17}},
    force=station.force}
  local wagons=count(surface,{name="cargo-wagon",
    area={{-25,(s.station_y or 0)-16},
          {s.natural_ore_x+28,(s.station_y or 0)+17}},force=station.force})
  local drills=surface.find_entities_filtered{
    type="mining-drill",
    area={{s.natural_ore_x-32,s.natural_ore_y-24},
          {s.natural_ore_x+32,s.natural_ore_y+24}},
    force=station.force}
  local resource_drills=0
  for _,e in ipairs(drills)do
    if e.valid then resource_drills=resource_drills+1 end
  end
  -- Train position must actually advance to the destination and back.
  -- A train merely spawned next to the station is not remote acquisition.
  for _,loco in ipairs(locomotives) do
    if loco.valid and loco.train and loco.train.valid then
      local train=loco.train
      if loco.position.x>=s.natural_ore_x-37 then s.outbound=true end
      if s.outbound and loco.position.x<=28 then s.returned=true end
      local ride=p.train_transport_rail_0835
      if ride and ride.train_id==train.id
          and ride.boarded_priest_unit==p.priest.unit_number
          and ride.physical_boarding_confirmed==true
          and ride.disembark_confirmed~=true then
        -- A valid, matching train lease is recorded, but actual onboard
        -- capability remains an independent requirement of the executor.
        s.ride_proof=true
      end
    end
  end
  local delivered=station.get_inventory(defines.inventory.chest)
      .get_item_count("iron-ore")-s.start_ore
  emit("CHECKPOINT elapsed="..elapsed..
    " starvation="..tostring(objective and objective.status)..
    " natural_target="..tostring(s.natural_ore_x)..
    " target="..tostring(objective and objective.target and objective.target.x)..
    " rail="..#rails..
    " near_rail="..near.." far_rail="..far..
    " locomotives="..#locomotives.." wagons="..wagons..
    " remote_drills="..resource_drills.." outbound="..tostring(s.outbound)..
    " returned="..tostring(s.returned)..
    " board_proof="..tostring(s.ride_proof)..
    " delivered_ore="..delivered)
  if elapsed>=90000 then
    if near<1 or far<1 then fail("RAIL_LINE_NEVER_REACHED_REMOTE_PATCH")end
    if #locomotives<1 or wagons<1 then fail("TRAIN_NEVER_ASSEMBLED")end
    if not s.ride_proof then fail("MAGOS_PHYSICAL_TRAIN_RIDE_NOT_PROVEN")end
    if not(s.outbound and s.returned)then fail("TRAIN_ROUND_TRIP_NOT_PROVEN")end
    if resource_drills<1 then fail("REMOTE_MINE_NOT_ESTABLISHED")end
    if delivered<=0 then fail("NO_GENUINE_ORE_DELIVERED_BY_RAIL")end
    emit("PASS planetary Magos built rail, rode train, mined and returned real ore")
    s.finished=true
  end
end
local function pulse()
  local s=root()
  if s.finished or s.failed then return {processed=0} end
  local ok,why=pcall(function()
    if not s.started then fail("fixture did not initialize") end
    local elapsed=game.tick-s.started
    for _,mark in ipairs({1800,9000,18000,36000,60000,90000}) do
      if elapsed>=mark and not s["checked_"..mark] then
        inspect(s,mark);s["checked_"..mark]=true
      end
    end
  end)
  if not ok then s.failed=tostring(why);emit("FAIL "..s.failed) end
  return {processed=1,failed=s.failed and 1 or 0}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(registry and registry.on_init and broker
      and broker.register_service)then
    error(PREFIX.."FAIL canonical test-only lifecycle unavailable")
  end
  assert(registry.on_init(setup,{owner="ci_remote_rail_acquisition",
    route="initialize",category="diagnostics",priority="last"}))
  assert(broker.register_service{name="ci_remote_rail_acquisition",
    category="diagnostics",interval=60,priority=1100,budget=1,fn=pulse,
    note="isolated 512-tile train and distant ore acceptance"})
  emit("INSTALLED test-only service")
  return true
end
return M
