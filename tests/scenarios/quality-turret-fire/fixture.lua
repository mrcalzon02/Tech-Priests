-- Test-only native Factorio 2.1 acceptance: Legendary Energy Dish must
-- damage an enemy beyond Normal-quality range; no simulated combat outcomes.
local M={}
local KEY="ci_quality_turret_firing"
local PREFIX="[TP-QUALITY-TURRET-FIRE] "
local DISTANCE=35
local function emit(msg) log(PREFIX..msg) end
local function fail(msg) error(PREFIX.."FAIL "..msg,0) end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  storage.tech_priests[KEY]=storage.tech_priests[KEY] or {}
  return storage.tech_priests[KEY]
end
local function create(surface,opts)
  local e=surface.create_entity(opts)
  if not(e and e.valid) then fail("NATIVE_ENTITY_CREATION "..tostring(opts.name)) end
  return e
end
local function prepare(surface)
  surface.request_to_generate_chunks({x=45,y=18},4)
  surface.force_generate_chunk_requests()
  local tiles={}
  for x=-14,111 do for y=-14,53 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  for _,e in pairs(surface.find_entities_filtered{area={{-14,-14},{112,54}}}) do
    if e.valid and (e.type=="tree" or e.type=="cliff"
      or e.type=="simple-entity" or e.type=="resource"
      or e.force==game.forces.enemy) then e.destroy() end
  end
end
local function setup()
  local s=root()
  if s.started then fail("DUPLICATE_SETUP") end
  if not(script.feature_flags and script.feature_flags.quality
    and prototypes.quality and prototypes.quality.legendary) then
    fail("QUALITY_FEATURE_REQUIRED")
  end
  local name="tech-priests-bunker-energy-dish"
  local proto=prototypes.entity[name]
  if not(proto and proto.attack_parameters and proto.attack_parameters.range) then
    fail("MISSING_ENERGY_DISH_PROTOTYPE")
  end
  local normal_range=proto.attack_parameters.range
  local legendary_range=normal_range*prototypes.quality.legendary.range_multiplier
  if not(DISTANCE>normal_range and DISTANCE<legendary_range) then
    fail("RANGE_FIXTURE_NOT_BRACKETED normal="..tostring(normal_range)
      .." legendary="..tostring(legendary_range))
  end
  local surface,force=game.surfaces[1],game.forces.player
  prepare(surface)
  local results={}
  for _,spec in ipairs({{grade="normal",x=0},{grade="legendary",x=90}}) do
    local turret=create(surface,{name=name,position={x=spec.x,y=0},force=force,
      quality=spec.grade,raise_built=false})
    local substation=create(surface,{name="substation",position={x=spec.x+4,y=0},force=force})
    local generator=create(surface,{name="electric-energy-interface",
      position={x=spec.x+7,y=0},force=force})
    substation.destructible=false
    generator.destructible=false
    turret.destructible=false
    generator.power_production=50*1000*1000
    generator.energy=50*1000*1000
    generator.power_usage=0
    local target=create(surface,{name="behemoth-worm-turret",
      position={x=spec.x,y=DISTANCE},force=game.forces.enemy})
    -- Disable only the test worm's firing, never its native damage receipt.
    pcall(function() target.active=false end)
    if not(turret.quality and turret.quality.name==spec.grade) then
      fail("PLACED_TURRET_QUALITY_MISMATCH "..spec.grade)
    end
    results[#results+1]={grade=spec.grade,turret=turret,target=target,
      starting_health=target.health,minimum_health=target.health}
    emit("NATIVE_SETUP grade="..spec.grade.." range="..normal_range
      .." multiplier="..turret.quality.range_multiplier
      .." target_distance="..DISTANCE.." target_hp="..target.health)
  end
  s.cases=results
  s.started=game.tick
  emit("NATIVE_SETUP_COMPLETE")
end
local function sample()
  local s=root()
  if s.passed or s.failed then return {processed=0} end
  local ok,err=pcall(function()
    if not s.started then fail("NOT_INITIALIZED") end
    for _,entry in ipairs(s.cases or {}) do
      if not(entry.turret and entry.turret.valid) then
        fail("TURRET_NOT_VALID "..entry.grade)
      end
      if entry.target.valid and entry.target.health then
        entry.minimum_health=math.min(entry.minimum_health,entry.target.health)
      else
        entry.minimum_health=0
      end
    end
    if game.tick-s.started<900 then return end
    local normal,legendary=s.cases[1],s.cases[2]
    emit("NATIVE_RESULT normal_damage="..
      tostring(normal.starting_health-normal.minimum_health)..
      " legendary_damage="..
      tostring(legendary.starting_health-legendary.minimum_health))
    if normal.minimum_health<normal.starting_health-0.01 then
      fail("NORMAL_TURRET_DAMAGED_OUT_OF_RANGE_TARGET")
    end
    if legendary.minimum_health>=legendary.starting_health-0.01 then
      fail("LEGENDARY_TURRET_DID_NOT_HIT_EXTENDED_TARGET")
    end
    s.passed=true
    emit("PASS native Legendary Energy Dish hit outside Normal range")
  end)
  if not ok then s.failed=tostring(err);emit("FAIL "..s.failed) end
  return {processed=1,failed=s.failed and 1 or 0}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(registry and registry.on_init and broker and broker.register_service) then
    fail("MISSING_CANONICAL_REGISTRY_OR_BROKER")
  end
  assert(registry.on_init(setup,{owner=KEY,route="initialize",
    category="diagnostics",priority="last"}))
  -- The real mod's 0595 dormant gate stops ordinary services when no
  -- Cogitator exists. This isolated physics test deliberately contains only
  -- turrets and targets; opt just its bounded observation service into the
  -- existing broker until it records a terminal result. Never wake the
  -- production services or install a second tick dispatcher.
  assert(broker.register_service{name=KEY,category="diagnostics",
    interval=30,priority=1100,budget=1,fn=sample,
    run_while_dormant=true,
    dormant_active=function()
      local tp=storage and storage.tech_priests
      local state=tp and tp[KEY]
      return state~=nil and state.started~=nil
        and not state.passed and not state.failed
    end,
    note="isolated dormant-safe actual quality-range hit acceptance"} )
  emit("INSTALLED isolated real-firing fixture")
  return true
end
return M
