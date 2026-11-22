-- Native Factorio 2.1 quality-range firing, six real ammunition families.
-- Tests physically loaded Native ammo, real stationary enemy health and native
-- projectile delivery. No LuaEntity.damage, script-minted hits or ammo bypass.
local M={}
local KEY="ci_quality_bunker_ammo_range"
local PREFIX="[TP-QUALITY-BUNKER-AMMO] "
local SPECS={
  {name="tech-priests-bunker-autocannon",ammo="tech-priests-autocannon-magazine"},
  {name="tech-priests-bunker-chicago-piano",ammo="firearm-magazine"},
  {name="tech-priests-bunker-twin-minigun",ammo="firearm-magazine"},
  {name="tech-priests-bunker-twin-cannon",ammo="cannon-shell"},
  {name="tech-priests-bunker-rocket-salvo",ammo="rocket"},
  {name="tech-priests-bunker-lobber",ammo="tech-priests-lobber-grenade-magazine"}
}
local function emit(x) log(PREFIX..x) end
local function fail(x) error(PREFIX.."FAIL "..x,0) end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  storage.tech_priests[KEY]=storage.tech_priests[KEY] or {}
  return storage.tech_priests[KEY]
end
local function place(surface,opts)
  local e=surface.create_entity(opts)
  if not(e and e.valid) then
    fail("NATIVE_PLACEMENT_REFUSED "..tostring(opts.name))
  end
  return e
end
local function prepare(surface)
  surface.request_to_generate_chunks({x=170,y=90},7)
  surface.force_generate_chunk_requests()
  local tiles={}
  for x=-20,365 do for y=-12,194 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  for _,e in pairs(surface.find_entities_filtered{area={{-21,-13},{366,195}}}) do
    if e.valid and (e.type=="tree" or e.type=="cliff"
      or e.type=="resource" or e.type=="simple-entity"
      or e.force==game.forces.enemy) then e.destroy() end
  end
end
local function setup()
  if not(script.feature_flags and script.feature_flags.quality
    and prototypes.quality and prototypes.quality.legendary) then
    fail("QUALITY_FEATURE_REQUIRED")
  end
  local state=root()
  if state.started then fail("DUPLICATE_SETUP") end
  local surface,force=game.surfaces[1],game.forces.player
  prepare(surface)
  local rows={}
  for i,spec in ipairs(SPECS) do
    local proto=prototypes.entity[spec.name]
    local ammo_proto=prototypes.item[spec.ammo]
    if not(proto and proto.type=="ammo-turret" and ammo_proto) then
      fail("MISSING_NATIVE_TURRET_OR_AMMO "..spec.name.." ammo="..spec.ammo)
    end
    local base=proto.attack_parameters and proto.attack_parameters.range
    if not(base and base>0) then fail("TURRET_ATTACK_RANGE_UNREADABLE "..spec.name) end
    local legend=base*prototypes.quality.legendary.range_multiplier
    local distance=math.floor(base*1.38+0.5)
    if not(distance>base+1 and distance<legend-0.5) then
      fail("INVALID_QUALITY_DISTANCE_BRACKET "..spec.name
        .." base="..tostring(base).." legendary="..tostring(legend))
    end
    local case={name=spec.name,ammo=spec.ammo,normal=nil,legendary=nil,distance=distance}
    for _,grade in ipairs({"normal","legendary"}) do
      local x=(i-1)*65+5
      local y=grade=="normal" and 0 or 105
      local turret=place(surface,{name=spec.name,force=force,
        quality=grade,position={x=x,y=y},raise_built=false})
      turret.destructible=false
      local inventory=turret.get_inventory(defines.inventory.turret_ammo)
      if not inventory then fail("NATIVE_AMMO_INVENTORY_MISSING "..spec.name) end
      local inserted=inventory.insert{name=spec.ammo,count=24}
      if inserted<1 then fail("NATIVE_AMMO_REJECTED "..spec.name.." "..grade) end
      local worm=place(surface,{name="behemoth-worm-turret",
        force=game.forces.enemy,position={x=x,y=y+distance}})
      pcall(function() worm.active=false end)
      if not(turret.quality and turret.quality.name==grade) then
        fail("NATIVE_QUALITY_MISMATCH "..spec.name.." "..grade)
      end
      local entry={turret=turret,target=worm,
        original_hp=worm.health,minimum_hp=worm.health,
        initial_ammo=inventory.get_item_count(spec.ammo),inventory=inventory}
      case[grade]=entry
      emit(string.format("NATIVE_READY turret=%s grade=%s base_range=%.1f target_distance=%d ammo=%s count=%d",
        spec.name,grade,base,distance,spec.ammo,inserted))
    end
    rows[#rows+1]=case
  end
  state.cases=rows
  state.started=game.tick
  emit("NATIVE_SETUP_COMPLETE turrets=12 targets=12 real_ammo=true")
end
local function sample()
  local state=root()
  if state.passed or state.failed then return {processed=0} end
  local ok,err=pcall(function()
    if not state.started then fail("NO_NATIVE_SETUP") end
    for _,spec in ipairs(state.cases or {}) do
      for _,grade in ipairs({"normal","legendary"}) do
        local e=spec[grade]
        if not(e and e.turret and e.turret.valid) then
          fail("LOST_NATIVE_TURRET "..spec.name.." "..grade)
        end
        if e.target.valid and e.target.health then
          e.minimum_hp=math.min(e.minimum_hp,e.target.health)
        else
          e.minimum_hp=0
        end
      end
    end
    if game.tick-state.started<1800 then return end
    for _,spec in ipairs(state.cases) do
      local normal=spec.normal.original_hp-spec.normal.minimum_hp
      local legendary=spec.legendary.original_hp-spec.legendary.minimum_hp
      local spent=spec.legendary.initial_ammo-
        spec.legendary.inventory.get_item_count(spec.ammo)
      emit(string.format(
        "NATIVE_RESULT turret=%s target_distance=%d normal_damage=%.2f legendary_damage=%.2f legendary_ammo_spent=%d",
        spec.name,spec.distance,normal,legendary,spent))
      if normal>0.01 then fail("NORMAL_FIRED_OUTSIDE_RANGE "..spec.name) end
      if legendary<=0.01 then fail("LEGENDARY_FAILED_EXTENDED_RANGE "..spec.name) end
      if spent<1 then fail("NO_PHYSICAL_LEGENDARY_AMMO_SPENT "..spec.name) end
    end
    state.passed=true
    emit("PASS native extended-range ammunition hits for all six bunker families")
  end)
  if not ok then
    state.failed=tostring(err)
    emit("FAIL "..state.failed)
  end
  return {processed=1,failed=state.failed and 1 or 0}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(registry and registry.on_init and broker and broker.register_service) then
    fail("CANONICAL_EVENT_REGISTRY_OR_BROKER_MISSING")
  end
  assert(registry.on_init(setup,{owner=KEY,route="initialize",
    category="diagnostics",priority="last"}))
  assert(broker.register_service{name=KEY,category="diagnostics",
    interval=30,priority=1100,budget=1,fn=sample,
    run_while_dormant=true,
    dormant_active=function()
      local tp=storage and storage.tech_priests
      local state=tp and tp[KEY]
      return state~=nil and state.started~=nil
        and not state.passed and not state.failed
    end,
    note="native six ammunition turret families quality-range firing acceptance"})
  emit("INSTALLED isolated real-ammo quality range fixture")
  return true
end
return M
