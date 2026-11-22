-- Factorio 2.1 isolated native quality acceptance for Tech-Priests.
-- Not packaged. Real placed entities, native health/prototype/quality queries.
-- Native gunfire and power-throughput tests are separate acceptance gates.
local M={}
local Martian=require("scripts.martian_infrastructure")
local CombatRoster=require("shared.combat_roster_catalog")
local PREFIX="[TP-QUALITY-ENTITY-MATRIX] "
local KEY="ci_quality_entity_matrix"
local GRADES={"normal","uncommon","rare","epic","legendary"}
local TURRETS={
  "tech-priests-bunker-autocannon","tech-priests-bunker-lobber",
  "tech-priests-bunker-energy-dish","tech-priests-bunker-chicago-piano",
  "tech-priests-bunker-twin-minigun","tech-priests-bunker-twin-cannon",
  "tech-priests-bunker-rocket-salvo","tech-priests-bunker-artillery"
}
local CUSTOM={
  "junior-cogitator-station","intermediate-cogitator-station",
  "senior-cogitator-station","planetary-magos-cogitator-station",
  "void-cogitator-station",
  "tech-priests-martian-power-1","tech-priests-martian-power-2",
  "tech-priests-martian-power-3",
  "tech-priests-martian-comms-1","tech-priests-martian-comms-2",
  "tech-priests-martian-comms-3",
  "tech-priests-martian-manufactorum","tech-priests-guard-muster-hall",
  "tech-priests-sororitas-convent",
  "tp-mh7-review-purifier","tp-mh7-review-electrolyzer",
  "tp-mh7-review-compressor","tp-mh7-review-crucible",
  "tp-mh7-review-forge","tp-mh7-review-fabricator",
  "tp-mh7-canister-assembler",
  "mars-plasma-reactor-minoris","mars-plasma-reactor-majoris",
  "mars-plasma-reactor-maximus",
  "tech-priests-emergency-assembler","tech-priests-emergency-smelter",
  "tech-priests-emergency-boiler"
}
local function emit(x) log(PREFIX..x) end
local function fail(x) error(PREFIX.."FAIL "..x,0) end
local function near(a,b) return type(a)=="number" and type(b)=="number"
  and math.abs(a-b)<=math.max(0.001,math.abs(b)*0.00001) end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  storage.tech_priests[KEY]=storage.tech_priests[KEY] or {}
  return storage.tech_priests[KEY]
end
local function prep(surface)
  surface.request_to_generate_chunks({x=50,y=72},6)
  surface.force_generate_chunk_requests()
  local tiles={}
  for x=-16,111 do for y=-16,222 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  for _,e in pairs(surface.find_entities_filtered{area={{-16,-16},{112,223}}}) do
    if e.valid and (e.type=="tree" or e.type=="cliff"
      or e.type=="simple-entity" or e.type=="resource"
      or e.force==game.forces.enemy) then e.destroy() end
  end
end
local function setup()
  if not(script.feature_flags and script.feature_flags.quality
    and prototypes.quality and prototypes.quality.legendary) then
    fail("QUALITY_MOD_REQUIRED_ALL_FIVE_TIERS")
  end
  for _,grade in ipairs(GRADES) do
    if not prototypes.quality[grade] then fail("QUALITY_GRADE_MISSING "..grade) end
  end
  local state=root()
  if state.initialized then fail("DUPLICATE_SETUP") end
  local surface,force=game.surfaces[1],game.forces.player
  prep(surface)
  local placed,quality_checks,turret_checks,utility_checks,actor_checks=0,0,0,0,0
  local function place(name,grade,x,y)
    local proto=prototypes.entity[name]
    if not proto then fail("MISSING_CUSTOM_ENTITY "..name) end
    local entity=surface.create_entity{name=name,quality=grade,
      position={x=x,y=y},force=force,raise_built=false}
    if not(entity and entity.valid) then
      fail("NATIVE_PLACEMENT_REFUSED "..name.." grade="..grade)
    end
    if not(entity.quality and entity.quality.name==grade) then
      fail("NATIVE_QUALITY_LOST "..name.." grade="..grade)
    end
    local base=proto.get_max_health("normal")
    local expected=proto.get_max_health(grade)
    if not(near(entity.max_health,expected)
      and (grade=="normal" or expected>base)) then
      fail("NATIVE_HEALTH_QUALITY_BAD "..name.." grade="..grade
        .." actual="..tostring(entity.max_health)
        .." expected="..tostring(expected))
    end
    placed=placed+1;quality_checks=quality_checks+1
    return entity,proto
  end
  -- Every original bunker weapon: full 0/1/2/3/5 Quality grade matrix.
  for i,name in ipairs(TURRETS) do
    for g,grade in ipairs(GRADES) do
      local entity,proto=place(name,grade,(i-1)*12,(g-1)*12)
      if not(entity.type=="ammo-turret" or entity.type=="electric-turret"
        or entity.type=="artillery-turret") then
        fail("TURRET_TYPE_CHANGED "..name)
      end
      local range=entity.quality.range_multiplier
      if not near(range,prototypes.quality[grade].range_multiplier) then
        fail("QUALITY_RANGE_MULTIPLIER_BAD "..name.." grade="..grade)
      end
      -- Actor controls and ammunition are not fabricated by the fixture:
      -- this is entity quality/prototype evidence, not gunfire acceptance.
      turret_checks=turret_checks+1
      emit(string.format("NATIVE_TURRET name=%s grade=%s hp=%.2f range_multiplier=%.3f",
        name,grade,entity.max_health,range))
    end
  end
  -- Two grades for every other audited custom entity family.
  for i,name in ipairs(CUSTOM) do
    local x=((i-1)%8)*12
    local row=math.floor((i-1)/8)
    for _,index in ipairs({1,5}) do
      local grade=GRADES[index]
      local y=70+row*24+(index==1 and 0 or 12)
      local e,proto=place(name,grade,x,y)
      if e.type=="assembling-machine" or e.type=="furnace" then
        local native_speed=proto.get_crafting_speed(grade)
        if not near(e.crafting_speed,native_speed) then
          fail("NATIVE_CRAFT_SPEED_BAD "..name.." grade="..grade)
        end
      elseif e.type=="electric-pole" then
        local reach=proto.get_supply_area_distance(grade)
        local wire=proto.get_max_wire_distance(grade)
        if not(reach>0 and wire>0) then
          fail("NATIVE_POWER_GEOMETRY_BAD "..name.." grade="..grade)
        end
        if name:find("^tech%-priests%-martian%-comms%-") then
          local radar=Martian.ensure(e)
          if not(radar and radar.valid and radar.quality
            and radar.quality.name==grade) then
            fail("MARTIAN_HELPER_LOST_QUALITY "..name.." grade="..grade)
          end
        end
      elseif e.type=="burner-generator" then
        local power=proto.get_max_power_output(grade)
        emit("NATIVE_REACTOR name="..name.." grade="..grade
          .." prototype_power="..tostring(power))
      end
      utility_checks=utility_checks+1
    end
  end
  -- Combat roster uses AAI car-based actors. Check the real entity health
  -- and Quality identity for every canonical named unit without granting
  -- inventory items or using the still-gated automated muster quality path.
  local roster=CombatRoster.units or {}
  if #roster<1 then fail("COMBAT_ROSTER_MISSING") end
  for i,unit in ipairs(roster) do
    local x=((i-1)%8)*12
    local row=math.floor((i-1)/8)
    for _,index in ipairs({1,5}) do
      local grade=GRADES[index]
      local y=174+row*24+(index==1 and 0 or 12)
      local actor=place(unit.name,grade,x,y)
      if actor.type~="car" then fail("COMBAT_UNIT_TYPE_CHANGED "..unit.name) end
      actor_checks=actor_checks+1
      emit(string.format("NATIVE_ACTOR name=%s grade=%s hp=%.2f",
        unit.name,grade,actor.max_health))
    end
  end
  state.initialized=true
  state.passed=true
  state.placed=placed
  state.quality_checks=quality_checks
  state.turret_checks=turret_checks
  state.utility_checks=utility_checks
  state.actor_checks=actor_checks
  emit("NATIVE_CREATE_VERIFIED turrets="..turret_checks
    .." custom_entities="..utility_checks
    .." combat_actors="..actor_checks.." placements="..placed)
end
local function report()
  local state=root()
  if state.passed and not state.reported then
    state.reported=true
    emit("PASS native five-tier bunker turrets and normal-legendary custom entities"
      .." turrets="..state.turret_checks.." others="..state.utility_checks
      .." actors="..state.actor_checks)
  end
  return {processed=1}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(registry and registry.on_init and broker and broker.register_service) then
    fail("CANONICAL_RUNTIME_REGISTRY_OR_BROKER_UNAVAILABLE")
  end
  assert(registry.on_init(setup,{owner=KEY,route="initialize",
    category="diagnostics",priority="last"}))
  assert(broker.register_service{name=KEY,category="diagnostics",
    interval=30,priority=1100,budget=1,fn=report,
    note="isolate native custom entity quality stats without fabricated engine output"})
  emit("INSTALLED isolated quality matrix, no new scheduling authority")
  return true
end
return M
