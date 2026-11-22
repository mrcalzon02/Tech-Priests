-- Isolated native Factorio 2.1 doctrine acceptance. Never packaged.
-- Checks research unlocks, real module insertion and physical crafting/detritus.
local M={}
-- Parse-time import; never dynamically require from a runtime event.
local Doctrine=require("scripts.core.consecration.doctrine_effects")
local PREFIX="[TP-MACHINE-SPIRIT-DOCTRINE] "
local KEY="ci_machine_spirit_doctrine"
-- Factorio Quality is optional; exercise native legendary module quality
-- when enabled without making non-Quality installs fail their baseline gate.
local HAS_QUALITY = script and script.feature_flags and script.feature_flags.quality
local CASES={
  {kind="baseline",x=-12,modules={}},
  {kind="order",x=0,modules={{name="tech-priests-order-module-2",count=1}}},
  {kind="chaos",x=12,modules={{name="tech-priests-chaos-module-2",count=1}}},
  {kind="mixed",x=24,modules={{name="tech-priests-order-module-1",count=1},
                                {name="tech-priests-chaos-module-1",count=1}}}
}
local function emit(message) log(PREFIX..message) end
local function fail(message) error(PREFIX.."FAIL "..message,0) end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  local state=storage.tech_priests[KEY] or {}
  storage.tech_priests[KEY]=state
  return state
end
local function place(surface,opts)
  if not (prototypes.entity[opts.name]
    and surface.can_place_entity{name=opts.name,position=opts.position,force=opts.force}) then
    fail("CANNOT_PLACE "..opts.name)
  end
  local entity=surface.create_entity(opts)
  if not(entity and entity.valid) then fail("ENGINE_CREATE_FAILED "..opts.name) end
  return entity
end
local function prepare(surface)
  surface.request_to_generate_chunks({x=6,y=3},4)
  surface.force_generate_chunk_requests()
  local tiles={}
  for x=-26,42 do for y=-8,24 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  for _,e in pairs(surface.find_entities_filtered{area={{-26,-8},{43,25}}}) do
    if e.valid and (e.type=="tree" or e.type=="cliff" or
      e.type=="simple-entity" or e.type=="resource" or
      e.force==game.forces.enemy) then e.destroy() end
  end
end
local function setup()
  local state=root()
  if state.started then fail("DUPLICATE_SETUP") end
  local force,surface=game.forces.player,game.surfaces[1]
  for _,kind in ipairs({"order","chaos"}) do
    for tier=1,2 do
      local name="tech-priests-"..kind.."-module-"..tier
      local tech="machine-spirit-"..(kind=="order" and "law-order" or "chaos-anarchy").."-"..tier
      if not(prototypes.item[name] and prototypes.recipe[name] and force.recipes[name]
        and force.technologies[tech]) then fail("MISSING_MODULE_OR_TECH "..name) end
      force.technologies[tech].researched=true
      if not force.recipes[name].enabled then fail("RECIPE_NOT_UNLOCKED "..name) end
    end
  end
  prepare(surface)
  local generator=place(surface,{name="electric-energy-interface",position={12,16},force=force})
  generator.power_production=10000000
  generator.energy=10000000
  generator.power_usage=0
  for _,x in ipairs({-12,0,12,24}) do
    place(surface,{name="substation",position={x,6},force=force})
  end
  state.cases={}
  for _,spec in ipairs(CASES) do
    local machine=place(surface,{name="assembling-machine-3",position={spec.x,0},
      force=force,raise_built=true})
    -- Production-only acceptance: avoid nondeterministic destruction at 5/100.
    -- The released mod's damage mechanics remain unchanged; destructive
    -- survival endurance is a separate acceptance case.
    machine.destructible=false
    if machine.destructible~=false then fail("FIXTURE_DAMAGE_ISOLATION_FAILED "..spec.kind) end
    machine.set_recipe("iron-gear-wheel")
    local recipe=machine.get_recipe()
    if not(recipe and recipe.name=="iron-gear-wheel") then
      fail("RECIPE_SELECTION "..spec.kind)
    end
    local input=machine.get_inventory(defines.inventory.assembling_machine_input)
    if not(input and input.insert{name="iron-plate",count=30}==30) then
      fail("ENGINE_INPUT_INSERT "..spec.kind)
    end
    local inventory=machine.get_module_inventory()
    if not inventory then fail("MODULE_SLOTS_ABSENT "..spec.kind) end
    for _,module in ipairs(spec.modules) do
      local stack={name=module.name,count=module.count}
      if HAS_QUALITY and spec.kind=="mixed"
        and module.name=="tech-priests-order-module-1" then
        stack.quality="legendary"
      end
      if inventory.insert(stack)~=module.count then
        fail("NATIVE_MODULE_INSERT_REFUSED "..spec.kind.." "..module.name)
      end
    end
    local inserted=0
    for _,stack in ipairs(inventory.get_contents()) do
      if stack.name:find("^tech%-priests%-") then inserted=inserted+stack.count end
      if HAS_QUALITY and spec.kind=="mixed"
        and stack.name=="tech-priests-order-module-1"
        and stack.quality~="legendary" then
        fail("NATIVE_MODULE_QUALITY_READBACK")
      end
    end
    if inserted~=#spec.modules then fail("MODULE_READBACK "..spec.kind) end
    if not(get_consecration_record and is_consecration_target
      and is_consecration_target(machine)) then
      fail("NOT_SANCTIFICATION_TARGET "..spec.kind)
    end
    local record=get_consecration_record(machine)
    -- Explicit pre-aging is the only injected state: never synthesize crafting
    -- operations, machine outputs, or detritus, which must come from the engine.
    record.sanctification=5
    record.max_sanctification=100
    clamp_machine_sanctification(record)
    state.cases[#state.cases+1]={kind=spec.kind,entity=machine,gears=0,detritus=0}
    emit("NATIVE_READY case="..spec.kind.." unit="..machine.unit_number
      .." modules="..inserted.." seeded_sanctity="..record.sanctification)
  end
  state.started=game.tick
  emit("NATIVE_SETUP_COMPLETE research=true module_inventory=true real_input=true"
    .." legendary_module="..tostring(HAS_QUALITY==true))
end
local function sample()
  local state=root()
  if state.passed or state.failed then return {processed=0} end
  local ok,err=pcall(function()
    if not state.started then fail("MISSING_INIT") end
    for _,entry in ipairs(state.cases) do
      local e=entry.entity
      if not(e and e.valid) then fail("LOST_ENTITY "..entry.kind) end
      local output=e.get_output_inventory()
      if not output then fail("NO_ENGINE_OUTPUT "..entry.kind) end
      for _,item in ipairs({{"iron-gear-wheel","gears"},{"mechanical-detritus","detritus"}}) do
        local n=output.get_item_count(item[1])
        if n>0 then
          local removed=output.remove{name=item[1],count=n}
          if removed~=n then fail("OUTPUT_ACCOUNTING "..entry.kind.." "..item[1]) end
          entry[item[2]]=entry[item[2]]+removed
        end
      end
    end
    if game.tick-state.started<3600 then return end
    for _,entry in ipairs(state.cases) do
      local record=get_consecration_record(entry.entity)
      if not record then fail("MISSING_SANCTITY_RECORD "..entry.kind) end
      local ops=record.completed_operations_seen_0417 or 0
      local multiplier=record.last_detritus_quantity_multiplier or 1
      local modules=Doctrine.snapshot(record)
      local expected={
        baseline={order=0,chaos=0},
        order={order=20,chaos=0},
        chaos={order=0,chaos=22},
        mixed={order=HAS_QUALITY and 15 or 10,chaos=12}
      }
      local want=expected[entry.kind]
      if not(want and modules.order==want.order and modules.chaos==want.chaos) then
        fail("DOCTRINE_MODULE_STATE_MISMATCH "..entry.kind)
      end
      emit(string.format("NATIVE_RESULT case=%s gears=%d detritus=%d operations=%d multiplier=%.3f",
        entry.kind,entry.gears,entry.detritus,ops,multiplier))
      if ops<1 or entry.gears<1 then fail("NO_REAL_CRAFT "..entry.kind) end
      -- A clean Order machine may correctly generate zero detritus.
      if (entry.kind=="baseline" or entry.kind=="chaos") and entry.detritus<1 then
        fail("NO_PHYSICAL_DETRITUS "..entry.kind)
      end
      if entry.kind=="chaos" and multiplier<1.30 then fail("CHAOS_NO_YIELD_BOOST") end
      if entry.kind=="mixed" and multiplier<1.15 then fail("MIXED_EXTRACTION_MISSING") end
      if entry.kind=="order" and math.abs(multiplier-1)>0.001 then
        fail("ORDER_MUST_NOT_BONUS_DETRITUS")
      end
      if entry.kind=="baseline" and math.abs(multiplier-1)>0.001 then
        fail("BASELINE_YIELD_MUTATED")
      end
    end
    emit("PASS native doctrine modules and detritus production cases=4")
    state.passed=true
  end)
  if not ok then state.failed=tostring(err);emit("FAIL "..state.failed) end
  return {processed=1,failed=state.failed and 1 or 0}
end
function M.install()
  local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(registry and registry.on_init and broker and broker.register_service) then
    fail("MISSING_CANONICAL_REGISTRY_OR_BROKER")
  end
  assert(registry.on_init(setup,{owner=KEY,route="initialize",
    category="diagnostics",priority="last"}))
  assert(broker.register_service{name=KEY,category="diagnostics",interval=30,
    priority=1100,budget=1,fn=sample,
    note="isolated native doctrine module/real detritus acceptance"})
  emit("INSTALLED isolated acceptance; no extra scheduler")
  return true
end
return M
