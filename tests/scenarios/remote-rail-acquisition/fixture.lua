-- Factorio 2.0 test-only distant-resource TRAIN acceptance, independent
-- of ranked Cogitator relays. Test fixture seeds supply and technology only.
-- It NEVER creates rails, locomotives, wagons, miners or mined cargo.
local M={}
local PREFIX="[TP-REMOTE-RAIL-TEST] "
local STATION={x=0,y=0}
local ORE={x=512,y=0}
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
  for x=0,512,64 do surface.request_to_generate_chunks({x=x,y=0},3) end
  surface.force_generate_chunk_requests()
  local tiles={}
  for x=-25,539 do for y=-16,16 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  -- The central factory and entire 512-tile railway corridor have no
  -- naturally occurring ore, trees, cliffs, enemy buildings or biters.
  -- This is a controlled isolated test world, not a gameplay cleanup.
  -- Exclude the ENTIRE Magos short-range acquisition footprint; clearing
  -- only the rail corridor left naturally generated ore 20 tiles north
  -- of the station and incorrectly defeated genuine starvation detection.
  local exclusion={{-96,-80},{576,80}}
  local area={{-25,-16},{540,17}}
  for _,e in ipairs(surface.find_entities_filtered{area=exclusion}) do
    if e.valid and (e.type=="resource" or e.type=="tree"
        or e.type=="simple-entity" or e.type=="cliff"
        or e.force==game.forces.enemy) then e.destroy() end
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
  -- Supplies are items in actual station storage: no railway is prebuilt.
  local stock={{"rail",700},{"locomotive",2},{"cargo-wagon",3},
    {"train-stop",4},{"rail-signal",50},{"rail-chain-signal",30},
    {"burner-mining-drill",12},{"electric-mining-drill",12},
    {"transport-belt",300},{"inserter",40},{"iron-chest",30},
    {"steel-chest",20},{"coal",300},{"solid-fuel",100},
    {"stone-furnace",8},{"iron-plate",400},{"copper-plate",200},
    {"repair-pack",30},{"firearm-magazine",30}}
  for _,item in ipairs(stock) do
    if not prototypes.item[item[1]] then
      fail("REQUIRED_RAIL_SUPPLY_MISSING "..item[1])
    end
    local accepted=inventory.insert{name=item[1],count=item[2]}
    if accepted~=item[2] then
      fail("STATION_PRESTOCK_CAPACITY "..item[1].." inserted="..accepted)
    end
  end
  -- Only a real 9x9 ore patch is provisioned at the distant destination.
  local ore_tiles=0
  for dx=-4,4 do for dy=-4,4 do
    local pos={x=ORE.x+dx,y=ORE.y+dy}
    if surface.can_place_entity{name="iron-ore",position=pos} then
      local e=surface.create_entity{name="iron-ore",
        position=pos,amount=10000}
      if e and e.valid then ore_tiles=ore_tiles+1 end
    end
  end end
  if ore_tiles~=81 then fail("REMOTE_ORE_PATCH_INCOMPLETE "..ore_tiles.."/81")end
  -- The destination has been charted by prior remote reconnaissance. The
  -- Magos may use only charted map intelligence, not omniscient surface scans.
  force.chart(surface,{{ORE.x-20,ORE.y-20},{ORE.x+20,ORE.y+20}})
  if not force.is_chunk_charted(surface,{
      x=math.floor(ORE.x/32),y=math.floor(ORE.y/32)}) then
    fail("REMOTE_ORE_NOT_CHARTED")
  end
  if count(surface,{type="resource",
      area={{-64,-64},{64,64}})~=0 then
    fail("UNEXPECTED_NEARBY_ORE")
  end
  local rails=count(surface,{type={"straight-rail","half-diagonal-rail",
    "curved-rail-a","curved-rail-b"},area=area})
  if rails~=0 or count(surface,{name={"locomotive","cargo-wagon"},
        area=area})~=0 then
    fail("FIXTURE_PREBUILT_TRAIN_OR_RAIL")
  end
  s.station_unit=station.unit_number
  s.started=game.tick
  s.start_ore=inventory.get_item_count("iron-ore")
  s.outbound=false;s.returned=false;s.ride_proof=false
  emit("SETUP no_biters=true local_resources=0 distant_iron_tiles=81"..
    " target_x=512 rails=700 locomotives=2 wagons=3"..
    " tech_preset=true track_prebuilt=0 initial_iron="..s.start_ore)
end
local function inspect(s,elapsed)
  local surface=game.surfaces[1]
  local station=surface.find_entities_filtered{
    name="planetary-magos-cogitator-station",
    position=STATION,radius=2,force=game.forces.player}[1]
  local p=storage.tech_priests.pairs_by_station
      and storage.tech_priests.pairs_by_station[s.station_unit]
  if not(station and station.valid and p and p.priest
      and p.priest.valid) then fail("PLANETARY_MAGOS_PAIR_LOST") end
  local objective=p.remote_rail_outpost_0835
  if elapsed>=1800 and not (objective
      and (objective.status=="starvation-confirmed"
        or objective.status=="building-physical-rail"
        or objective.status=="rail-track-established"
        or objective.status=="rail-track-blocked")
      and objective.item=="iron-ore" and objective.target
      and objective.target.x>=480
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
      "curved-rail-a","curved-rail-b"},area={{-25,-16},{540,17}},
    force=station.force}
  local near,far=0,0
  for _,e in ipairs(rails) do
    if e.position.x<=24 then near=near+1 end
    if e.position.x>=480 then far=far+1 end
  end
  local locomotives=surface.find_entities_filtered{
    name="locomotive",area={{-25,-16},{540,17}},force=station.force}
  local wagons=count(surface,{name="cargo-wagon",
    area={{-25,-16},{540,17}},force=station.force})
  local drills=surface.find_entities_filtered{
    type="mining-drill",area={{480,-16},{540,17}},force=station.force}
  local resource_drills=0
  for _,e in ipairs(drills)do
    if e.valid then resource_drills=resource_drills+1 end
  end
  -- Train position must actually advance to the destination and back.
  -- A train merely spawned next to the station is not remote acquisition.
  for _,loco in ipairs(locomotives) do
    if loco.valid and loco.train and loco.train.valid then
      local train=loco.train
      if loco.position.x>=475 then s.outbound=true end
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
