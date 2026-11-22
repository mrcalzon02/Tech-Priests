-- Native automatic artillery quality acceptance in disposable Factorio 2.1
-- game. Physical artillery shells, two native turrets and genuine spawners.
-- No scripted artillery attacks, entity damage, target kill credits or ammo.
local M={}
local KEY="ci_quality_artillery_range"
local PREFIX="[TP-QUALITY-ARTILLERY] "
local DISTANCE=280  -- Normal automatic 224; Legendary 336, at zero research.
local function emit(s) log(PREFIX..s) end
local function fail(s) error(PREFIX.."FAIL "..s,0) end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  storage.tech_priests[KEY]=storage.tech_priests[KEY] or {}
  return storage.tech_priests[KEY]
end
local function place(surface,params)
  local e=surface.create_entity(params)
  if not(e and e.valid) then fail("NATIVE_PLACE_FAILED "..tostring(params.name)) end
  return e
end
local function clear_site(surface,x,y)
  local tiles={}
  for i=x-12,x+12 do for j=y-12,y+12 do
    tiles[#tiles+1]={name="grass-1",position={x=i,y=j}}
  end end
  surface.set_tiles(tiles,true)
  for _,e in pairs(surface.find_entities_filtered{
    area={{x-13,y-13},{x+13,y+13}}}) do
    if e.valid and (e.type=="tree" or e.type=="cliff"
      or e.type=="resource" or e.type=="simple-entity"
      or e.force==game.forces.enemy) then e.destroy() end
  end
end
local function setup()
  local state=root()
  if state.started then fail("DUPLICATE_SETUP") end
  if not(script.feature_flags and script.feature_flags.quality
    and prototypes.quality and prototypes.quality.legendary) then
    fail("QUALITY_FEATURE_REQUIRED")
  end
  local name="tech-priests-bunker-artillery"
  local proto=prototypes.entity[name]
  if not(proto and proto.type=="artillery-turret"
    and proto.disable_automatic_firing~=true
    and prototypes.item["artillery-shell"]) then
    fail("NATIVE_AUTOMATIC_ARTILLERY_OR_SHELL_MISSING")
  end
  local force,surface=game.forces.player,game.surfaces[1]
  if math.abs(tonumber(force.artillery_range_modifier) or 0)>0.001 then
    fail("UNEXPECTED_ARTILLERY_RESEARCH_RANGE_BONUS")
  end
  -- Generate and chart only the necessary artillery corridors.
  for _,x in ipairs({0,500}) do
    surface.request_to_generate_chunks({x=x,y=140},5)
  end
  surface.force_generate_chunk_requests()
  local targets={}
  for _,spec in ipairs({
    {grade="normal",x=0},{grade="legendary",x=500}}) do
    clear_site(surface,spec.x,0)
    clear_site(surface,spec.x,DISTANCE)
    force.chart(surface,{{spec.x-15,-15},{spec.x+15,DISTANCE+15}})
    local turret=place(surface,{name=name,quality=spec.grade,
      position={x=spec.x,y=0},force=force,raise_built=false})
    turret.destructible=false
    local inventory=turret.get_inventory(defines.inventory.artillery_turret_ammo)
    if not inventory then fail("NATIVE_ARTILLERY_AMMO_INVENTORY_MISSING") end
    local inserted=inventory.insert{name="artillery-shell",count=8}
    if inserted<1 then fail("NATIVE_ARTILLERY_AMMO_INSERT_REFUSED") end
    local spawner=place(surface,{name="biter-spawner",
      position={x=spec.x,y=DISTANCE},force=game.forces.enemy})
    pcall(function() spawner.active=false end)
    if not(turret.quality and turret.quality.name==spec.grade) then
      fail("NATIVE_ARTILLERY_QUALITY_MISSING "..spec.grade)
    end
    targets[spec.grade]={turret=turret,spawner=spawner,
      initial_health=spawner.health,minimum_health=spawner.health,
      inventory=inventory,original_ammo=inventory.get_item_count("artillery-shell")}
    emit("NATIVE_READY grade="..spec.grade.." target_distance="..DISTANCE
      .." shell_count="..inserted.." native_range_multiplier="
      ..tostring(turret.quality.range_multiplier))
  end
  state.started=game.tick
  state.targets=targets
  emit("NATIVE_SETUP_COMPLETE structures=2 turrets=2 original_shells=true")
end
local function sample()
  local state=root()
  if state.passed or state.failed then return {processed=0} end
  local ok,err=pcall(function()
    if not state.started then fail("NO_NATIVE_SETUP") end
    for _,grade in ipairs({"normal","legendary"}) do
      local e=state.targets and state.targets[grade]
      if not(e and e.turret and e.turret.valid) then
        fail("LOST_NATIVE_ARTILLERY "..grade)
      end
      if e.spawner.valid and e.spawner.health then
        e.minimum_health=math.min(e.minimum_health,e.spawner.health)
      else
        e.minimum_health=0
      end
    end
    if game.tick-state.started<1800 then return end
    local normal=state.targets.normal
    local legendary=state.targets.legendary
    local normal_damage=normal.initial_health-normal.minimum_health
    local legend_damage=legendary.initial_health-legendary.minimum_health
    local normal_spent=normal.original_ammo-
      normal.inventory.get_item_count("artillery-shell")
    local legend_spent=legendary.original_ammo-
      legendary.inventory.get_item_count("artillery-shell")
    emit(string.format(
      "NATIVE_RESULT target_distance=%d normal_damage=%.2f legendary_damage=%.2f normal_shells_spent=%d legendary_shells_spent=%d",
      DISTANCE,normal_damage,legend_damage,normal_spent,legend_spent))
    if normal_damage>0.01 or normal_spent>0 then
      fail("NORMAL_ARTILLERY_ATTACKED_OUTSIDE_NATIVE_AUTOMATIC_RANGE")
    end
    if legend_damage<=0.01 or legend_spent<1 then
      fail("LEGENDARY_ARTILLERY_MISSED_NATIVE_AUTOMATIC_RANGE")
    end
    state.passed=true
    emit("PASS real Legendary artillery automatic hit beyond Normal range")
  end)
  if not ok then state.failed=tostring(err);emit("FAIL "..state.failed) end
  return {processed=1,failed=state.failed and 1 or 0}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(registry and registry.on_init and broker and broker.register_service) then
    fail("CANONICAL_REGISTRY_OR_BROKER_MISSING")
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
    note="isolated real automatic artillery quality range witness"})
  emit("INSTALLED native automatic artillery quality range acceptance")
  return true
end
return M
