-- Real Factorio 2.1 quality power acceptance. Disposable isolated scenario.
-- Six native plasma reactors, six isolated networks, actual contained-pellet
-- burner fuel and consuming electric interfaces. No synthesized power credits.
local M={}
local KEY="ci_quality_plasma_load"
local PREFIX="[TP-QUALITY-PLASMA-LOAD] "
local REACTORS={
  {name="mars-plasma-reactor-minoris",base_mw=1},
  {name="mars-plasma-reactor-majoris",base_mw=2},
  {name="mars-plasma-reactor-maximus",base_mw=4}
}
local FUEL="tp-mh7-contained-metallicized-pellet"
-- get_max_power_output returns Joules/tick in Factorio. Convert to MW.
local function output_megawatts(joules_per_tick)
  return joules_per_tick*60/1000000
end
local function emit(message) log(PREFIX..message) end
local function fail(message) error(PREFIX.."FAIL "..message,0) end
local function root()
  storage.tech_priests=storage.tech_priests or {}
  storage.tech_priests[KEY]=storage.tech_priests[KEY] or {}
  return storage.tech_priests[KEY]
end
local function create(surface,spec)
  local e=surface.create_entity(spec)
  if not(e and e.valid) then
    fail("NATIVE_PLACE_REJECTED "..tostring(spec.name))
  end
  return e
end
local function prepare(surface)
  surface.request_to_generate_chunks({x=110,y=0},5)
  surface.force_generate_chunk_requests()
  local tiles={}
  for x=-20,240 do for y=-20,20 do
    tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
  end end
  surface.set_tiles(tiles,true)
  for _,e in pairs(surface.find_entities_filtered{area={{-21,-21},{241,21}}}) do
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
  if state.started then fail("DUPLICATE_NATIVE_SETUP") end
  if not prototypes.item[FUEL] then fail("PHYSICAL_PLASMA_FUEL_MISSING") end
  local surface,force=game.surfaces[1],game.forces.player
  prepare(surface)
  local cases={}
  for index,spec in ipairs(REACTORS) do
    local proto=prototypes.entity[spec.name]
    if not proto or proto.type~="burner-generator" then
      fail("REACTOR_PROTOTYPE_MISSING "..spec.name)
    end
    for j,quality in ipairs({"normal","legendary"}) do
      local base=proto.get_max_power_output("normal")
      local scaled=proto.get_max_power_output(quality)
      if not(type(base)=="number" and base>0
        and type(scaled)=="number" and scaled>0) then
        fail("REACTOR_PROTO_OUTPUT_UNREADABLE "..spec.name)
      end
      if quality=="legendary" and scaled<=base then
        fail("REACTOR_QUALITY_PROTO_NOT_SCALED "..spec.name)
      end
      if math.abs(output_megawatts(base)-spec.base_mw)>0.01 then
        fail("REACTOR_BASE_WATTS_MISMATCH "..spec.name
          .." got_MW="..tostring(output_megawatts(base)))
      end
      local lane=(index-1)*2+j
      local x=8+(lane-1)*38
      local reactor=create(surface,{name=spec.name,force=force,
        quality=quality,position={x=x,y=0},raise_built=false})
      local pole=create(surface,{name="substation",force=force,
        position={x=x+7,y=0}})
      local sink=create(surface,{name="electric-energy-interface",
        force=force,position={x=x+13,y=0}})
      -- Consumer-only load: a full battery would otherwise give the
      -- reactor nothing to generate. No script power injected.
      sink.power_production=0
      sink.power_usage=50*1000000
      sink.energy=0
      sink.input_flow_limit=50*1000000
      local burner=reactor.burner
      if not(burner and burner.valid and burner.fuel_categories
        and burner.fuel_categories["tp-metallicized-hydrogen"]) then
        fail("WRONG_PLASMA_FUEL_CATEGORY "..spec.name.." "..quality)
      end
      local inserted=burner.inventory.insert{name=FUEL,count=1}
      if inserted~=1 then fail("PHYSICAL_FUEL_INSERT_REFUSED "..spec.name.." "..quality) end
      if not(reactor.quality and reactor.quality.name==quality) then
        fail("PLACED_REACTOR_QUALITY_LOST "..spec.name)
      end
      cases[#cases+1]={
        name=spec.name,quality=quality,reactor=reactor,pole=pole,
        sink=sink,max_power=scaled,base_power=base,
        fuel_name=FUEL,starting_tick=game.tick
      }
      emit(string.format("NATIVE_READY reactor=%s quality=%s nominal_MW=%.3f",
        spec.name,quality,output_megawatts(scaled)))
    end
  end
  state.cases=cases
  state.started=game.tick
  emit("NATIVE_SETUP_COMPLETE cases=6 physical_fuel=6 independent_networks=true")
end
local function sample()
  local state=root()
  if state.passed or state.failed then return {processed=0} end
  local ok,err=pcall(function()
    if not state.started then fail("MISSING_NATIVE_SETUP") end
    if game.tick-state.started<600 then return end
    local produced={}
    for _,entry in ipairs(state.cases) do
      if not(entry.reactor and entry.reactor.valid and entry.pole.valid
        and entry.sink.valid) then fail("LOST_NATIVE_REACTOR_OR_GRID "..entry.name) end
      local stats=entry.pole.electric_network_statistics
      if not stats then fail("NATIVE_ELECTRIC_STATISTICS_MISSING "..entry.name) end
      -- Energy comes from the engine-maintained grid statistics, not a
      -- computed ratio or a direct LuaEntity.damage/energy mutation.
      local joules=stats.get_output_count(entry.reactor)
      if not(type(joules)=="number" and joules>0) then
        fail("NO_MEASURED_PLASMA_ELECTRIC_OUTPUT "..entry.name
          .." quality="..entry.quality.." generated="..tostring(joules))
      end
      local current=entry.reactor.burner.currently_burning
      if not(current or entry.reactor.burner.inventory.get_item_count(FUEL)>0) then
        fail("PLASMA_FUEL_CUSTODY_MISSING "..entry.name)
      end
      local key=entry.name
      produced[key]=produced[key] or {}
      produced[key][entry.quality]=joules
      emit(string.format("NATIVE_POWER reactor=%s quality=%s generated_J=%.0f native_max_MW=%.3f sink_energy=%.0f",
        key,entry.quality,joules,output_megawatts(entry.max_power),entry.sink.energy))
    end
    for _,spec in ipairs(REACTORS) do
      local values=produced[spec.name]
      local normal=values and values.normal or 0
      local legendary=values and values.legendary or 0
      if legendary<=normal*1.2 then
        fail(string.format("LEGENDARY_POWER_NOT_GREATER reactor=%s normal_J=%.0f legendary_J=%.0f",
          spec.name,normal,legendary))
      end
      emit(string.format("NATIVE_RATIO reactor=%s legendary_over_normal=%.3f",
        spec.name,legendary/normal))
    end
    state.passed=true
    emit("PASS physical plasma fuel and loaded Normal/Legendary output for all three reactor sizes")
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
    note="isolated burner-generator native electricity output acceptance"})
  emit("INSTALLED native reactor quality load fixture")
  return true
end
return M
