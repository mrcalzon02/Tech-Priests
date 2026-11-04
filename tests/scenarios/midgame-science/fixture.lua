-- Tech Priests isolated MID-GAME science factory endurance scenario.
-- CI-only fixture; never packaged. ALL research permissions and supply
-- crates are explicit starting conditions, never credited as production.
-- No laboratory, mining drill, power plant, assembler, belt or pipe is built
-- by this fixture. Original Tech Priest physical builders must do that.
local M={}
local PREFIX="[TP-MIDGAME-SCIENCE] "
local KEY="ci_midgame_science_1194"
local MARKS={0,9000,18000,36000,72000,108000,144000,180000,216000}
local RANKS={
 {name="junior-cogitator-station",x=0,y=0},
 {name="senior-cogitator-station",x=96,y=0},
 {name="planetary-magos-cogitator-station",x=192,y=0},
}
local ORES={"iron-ore","copper-ore","coal","stone","uranium-ore"}
local STOCK={
 {"energy",{{"small-electric-pole",200},{"medium-electric-pole",80},
   {"steam-engine",8},{"boiler",8},{"offshore-pump",4},
   {"pipe",900},{"pipe-to-ground",120},{"coal",1000}}},
 {"mining",{{"burner-mining-drill",24},{"electric-mining-drill",48},
   {"pumpjack",12},{"stone-furnace",40},{"steel-furnace",32},
   {"coal",800}}},
 {"factory",{{"assembling-machine-1",48},{"assembling-machine-2",24},
   {"chemical-plant",24},{"oil-refinery",6},{"lab",12},
   {"storage-tank",16}}},
 {"transport",{{"transport-belt",1800},{"fast-transport-belt",600},
   {"inserter",250},{"fast-inserter",80},{"long-handed-inserter",80},
   {"underground-belt",120},{"splitter",45}}},
 {"construction",{{"iron-chest",60},{"steel-chest",50},
   {"wooden-chest",40},{"repair-pack",120},{"radar",8},
   {"pipe",200},{"small-electric-pole",40}}},
 {"intermediates",{{"iron-plate",900},{"copper-plate",900},
   {"steel-plate",300},{"iron-gear-wheel",400},
   {"electronic-circuit",500},{"copper-cable",600},
   {"engine-unit",100}}},
 {"senior-supply",{{"assembling-machine-1",24},{"electric-mining-drill",18},
   {"stone-furnace",12},{"transport-belt",500},{"inserter",100},
   {"small-electric-pole",60},{"iron-plate",350}}},
 {"junior-supply",{{"assembling-machine-1",12},{"burner-mining-drill",12},
   {"stone-furnace",10},{"transport-belt",350},{"inserter",70},
   {"small-electric-pole",40},{"coal",250}}},
}
local PRESET_ROOTS={
 "automation","automation-2","electronics","logistics","logistics-2",
 "logistic-science-pack","steel-processing","military","military-2",
 "military-science-pack",
 "engine","oil-processing","fluid-handling",
 "electric-energy-distribution-1",
}
local PRODUCTS={
 "automation-science-pack","logistic-science-pack",
 "military-science-pack","chemical-science-pack",
}
local TYPES={
 "assembling-machine","furnace","mining-drill","lab","inserter",
 "transport-belt","underground-belt","splitter","electric-pole",
 "generator","boiler","offshore-pump","pumpjack","pipe",
 "pipe-to-ground","storage-tank","container","logistic-container",
 "roboport","radar",
}
local function emit(msg)log(PREFIX..msg)end
local function fail(msg)error(PREFIX.."FAIL "..msg)end
local function state()
 storage.tech_priests=storage.tech_priests or {}
 local root=storage.tech_priests
 root[KEY]=root[KEY] or {}
 return root[KEY]
end
local function area()
 return {{-50,-53},{243,51}}
end
local function create(surface,name,x,y,force)
 if not prototypes.entity[name] then fail("MISSING_ENTITY "..name)end
 local spec={name=name,position={x=x,y=y},force=force}
 -- Match the verified Factorio scenario setup: a station built with
 -- raise_built=true must enter the canonical station/paired-priest route.
 -- Supplies, ore and water remain fixture-only physical starting stock.
 if name:find("cogitator-station",1,true) then
  spec.raise_built=true
 end
 if not surface.can_place_entity(spec) then
  fail("PLACEMENT_BLOCKED "..name.." x="..x.." y="..y)
 end
 local ent=surface.create_entity(spec)
 if not(ent and ent.valid)then fail("CREATE_ENTITY_FAILED "..name)end
 return ent
end
local function supply_chest(surface,force,kind,x,y,items)
 local chest=create(surface,"steel-chest",x,y,force)
 local inv=chest.get_inventory(defines.inventory.chest)
 if not(inv and inv.valid)then fail("INVALID_CHEST_INVENTORY "..kind)end
 local contents={}
 for _,entry in ipairs(items)do
  local name,count=entry[1],entry[2]
  if not prototypes.item[name] then fail("SUPPLY_ITEM_MISSING "..name)end
  local actual=inv.insert{name=name,count=count}
  if actual~=count then
   fail("SUPPLY_CRATE_CAPACITY "..kind.." "..name..
     " expected="..count.." actual="..tostring(actual))
  end
  contents[name]=actual
 end
 return {unit=chest.unit_number,kind=kind,x=x,y=y,contents=contents}
end
local function patch(surface,name,cx,cy)
 if not prototypes.entity[name] then fail("MISSING_ORE "..name)end
 local n=0
 for dx=-2,2 do for dy=-2,2 do
  local p={x=cx+dx,y=cy+dy}
  if surface.can_place_entity{name=name,position=p} then
   local ent=surface.create_entity{
    name=name,position=p,amount=20000}
   if ent and ent.valid then n=n+1 end
  end
 end end
 if n~=25 then fail("RESOURCE_PATCH_PARTIAL "..name.." tiles="..n)end
 return n
end
local function unlock_midgame(force)
 local observed,visiting,roots={},{},{}
 local function walk(name)
  local tech=force.technologies[name]
  if not tech then fail("PRESET_TECH_MISSING "..name)end
  if observed[name] then return end
  if visiting[name] then fail("TECH_PREREQUISITE_CYCLE "..name)end
  visiting[name]=true
  for _,prerequisite in pairs(tech.prerequisites or {})do
   walk(prerequisite.name)
  end
  tech.researched=true
  if not tech.researched then fail("TECH_PRESET_REFUSED "..name)end
  observed[name]=true
  visiting[name]=nil
 end
 for _,root in ipairs(PRESET_ROOTS)do
  roots[#roots+1]=root
  walk(root)
 end
 local disallowed=force.technologies["chemical-science-pack"]
 if not disallowed then fail("NO_ADVANCED_SCIENCE_TECH")end
 if disallowed.researched then
  fail("PRESET_ALREADY_RESEARCHED_CHEMICAL_SCIENCE")
 end
 local known={}
 for name in pairs(observed)do known[#known+1]=name end
 table.sort(known)
 emit("TECH_PRESET researched="..#known..
  " roots="..table.concat(roots,",")..
  " unlocked="..table.concat(known,",")..
  " chemical_science_tech_unlocked=false"..
  " fixture_science_items=0")
 return known
end
local function setup()
 local s=state()
 if s.started then return end
 local surface=game.surfaces[1]
 local force=game.forces.player
 for _,r in ipairs(RANKS)do
  surface.request_to_generate_chunks({x=r.x,y=r.y},3)
 end
 surface.force_generate_chunk_requests()
 local blank=area()
 local tiles={}
 for x=-50,242 do for y=-52,50 do
  tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}
 end end
 -- Fixture is a disposable world. Reset only the reserved local area.
 for _,ent in ipairs(surface.find_entities_filtered{area=blank})do
  if ent.valid and (ent.type=="resource" or ent.type=="tree"
    or ent.type=="simple-entity" or ent.type=="cliff"
    or ent.force==game.forces.enemy) then ent.destroy() end
 end
 surface.set_tiles(tiles,true)
 local p=0
 for _,r in ipairs(RANKS)do
  local station=create(surface,r.name,r.x,r.y,force)
  r.unit_number=station.unit_number
  s["station_"..r.name]=station.unit_number
  -- Each rank gets local patches. No ore or products enter its crates.
  for index,name in ipairs(ORES)do
   p=p+patch(surface,name,r.x-18+(index-1)*10,23)
  end
  if not surface.can_place_entity{
      name="crude-oil",position={x=r.x+24,y=-27}} then
   fail("OIL_WELL_SITE_BLOCKED "..r.name)
  end
  local well=surface.create_entity{
   name="crude-oil",position={x=r.x+24,y=-27},
   amount=250000}
  if not(well and well.valid and well.amount>=250000)then
   fail("OIL_WELL_CREATION_REFUSED "..r.name)
  end
  -- A pond near every station makes offshore pumping a real design task.
  local water={}
  for dx=-2,2 do for dy=-2,2 do
   water[#water+1]={name="water",
     position={x=r.x-29+dx,y=-30+dy}}
  end end
  surface.set_tiles(water,true)
  emit("STATION_CREATED rank="..r.name.." unit="..station.unit_number..
    " resource_tiles=125 oil_well=true local_water=true")
 end
 if p~=375 then fail("RESOURCE_PRESET_COUNT "..p)end
 s.crates={}
 local crates={
  {STOCK[1],192,-18,-12},{STOCK[2],192,-9,-12},
  {STOCK[3],192,0,-12},{STOCK[4],192,9,-12},
  {STOCK[5],192,-18,-22},{STOCK[6],192,-9,-22},
  {STOCK[7],96,-8,-13},{STOCK[8],0,-8,-13},
 }
 for _,entry in ipairs(crates)do
  local pack=entry[1]
  local box=supply_chest(surface,force,pack[1],
    entry[2]+entry[3],entry[4],pack[2])
  s.crates[#s.crates+1]=box
  emit("SUPPLY_CRATE kind="..box.kind.." unit="..box.unit..
    " position="..box.x..","..box.y..
    " item_types="..#pack[2])
 end
 if #s.crates~=8 then fail("SUPPLY_CRATE_COUNT")end
 -- 1199: prove early Conclave access in the genuine Factorio runtime
 -- BEFORE any military-era technologies are preset by this fixture.
 -- Do not fabricate a free center or enable the recipe via a CI bypass.
 local conclave=force.recipes["tech-priests-conclave-center"]
 if not(conclave and conclave.enabled==true)then
  fail("CONCLAVE_START_RECIPE_LOCKED")
 end
 emit("CONCLAVE_START_RECIPE enabled=true native=true"..
   " tech_granted=false center_granted=false")
 s.unlocked=unlock_midgame(force)
 s.started=game.tick
 s.checkpoints={}
 s.research_finishes={}
 s.initial_product_counts={}
 for _,name in ipairs(PRODUCTS)do
  s.initial_product_counts[name]=0
 end
 -- DO NOT force current_research: research choice is under autonomous AI.
 s.initial_selected_research=
   force.current_research and force.current_research.name or "none"
 emit("MIDGAME_READY tick="..game.tick..
  " stations=3 crates=8 ore_tiles="..p..
  " prefabricated_machines=0 production_science_seeded=0"..
  " selected_research="..s.initial_selected_research)
end
local function observed_spm(force,surface,name)
 -- A resource patch can produce either a physical item or a fluid.
 -- Factorio's production statistics are distinct typed registries:
 -- querying crude-oil through item statistics aborts a live checkpoint.
 local stats
 if prototypes.item[name] then
  stats=force.get_item_production_statistics(surface)
 elseif prototypes.fluid[name] then
  stats=force.get_fluid_production_statistics(surface)
 else
  fail("UNRECOGNIZED_PRODUCTION_PROTOTYPE "..tostring(name))
 end
 if not(stats and stats.valid)then
  fail("PRODUCTION_STATISTICS_UNAVAILABLE "..name)
 end
 local flow=stats.get_flow_count{
  name=name,category="input",
  precision_index=defines.flow_precision_index.one_minute}
 if type(flow)~="number" then
  fail("PRODUCTION_FLOW_UNAVAILABLE "..name)
 end
 return flow
end
-- Compact, read-only evidence for why a physically supplied priest has
-- not built anything. This samples canonical live pair tasks; it never
-- creates requests, clears reservations, or grants inventory.
local function diagnostic_pair(label,unit)
 local root=storage.tech_priests or {}
 local pair=root.pairs_by_station and root.pairs_by_station[unit]
 if not(pair and pair.priest and pair.priest.valid)then
  return {rank=label,paired=false}
 end
 local plan=pair.master_infrastructure_plan_0644 or {}
 local target=plan.target or {}
 local deferred=target.deferred_output or {}
 local ghost=pair.construction_bootstrap_ghost_0645 or {}
 local candidate=pair.construction_candidate_0338 or {}
 local task=pair.construction_task_0338 or {}
 local request=pair.construction_requested_item or {}
 local event=pair.construction_last_event_0338 or {}
 -- 1197: record the actual canonical dispatcher choice, not just the
 -- unexecuted 0338 request. These persisted fields are observation only.
 local assigned=pair.order_queue_0469
   and pair.order_queue_0469.current or pair.active_order_0469
 if type(assigned)~="table" then assigned={} end
 local canonical=pair.canonical_action_0744
 if type(canonical)~="table" then canonical={} end
 local candidate_request=candidate.request_value
 local priest=pair.priest
 return {
  rank=label,paired=true,station_unit=unit,
  priest_unit=priest.unit_number,
  priest_x=priest.position.x,priest_y=priest.position.y,
  infrastructure_stage=tostring(plan.stage or "unobserved"),
  infrastructure_blocker=tostring(plan.blocker or target.blocker or "none"),
  infrastructure_item=tostring(target.preferred_item or "none"),
  deferred_receiver_reason=tostring(deferred.reason or "none"),
  deferred_receiver_x=deferred.position and deferred.position.x or nil,
  deferred_receiver_y=deferred.position and deferred.position.y or nil,
  deferred_drill_unit=deferred.drill_unit,
  research_plan_reason=tostring(plan.science_reason or "none"),
  ghost_entity=tostring(ghost.entity_name or "none"),
  ghost_status=tostring(ghost.status or "none"),
  ghost_blocker=tostring(ghost.blocker or "none"),
  construction_candidate=tostring(candidate.item_name or candidate.item or "none"),
  construction_candidate_field=tostring(candidate.request_field or "none"),
  candidate_matches_bootstrap=candidate_request==ghost
    and candidate.request_field=="construction_bootstrap_ghost_0645",
  construction_blocked_reason=tostring(
    pair.construction_blocked_reason_0338 or "none"),
  active_order_kind=tostring(assigned.kind or "none"),
  active_order_source=tostring(assigned.source or "none"),
  mode=tostring(pair.mode or "none"),
  canonical_family=tostring(canonical.family or "none"),
  canonical_status=tostring(canonical.status or "none"),
  canonical_reason=tostring(canonical.reason or "none"),
  emergency_craft=type(pair.emergency_craft)=="table",
  strict_recipe=type(pair.emergency_craft)=="table"
    and pair.emergency_craft.strict_recipe_0647==true,
  active_direct=type(pair.direct_acquisition_task_0336)=="table",
  direct_custody=pair.direct_acquisition_custody_0513~=nil,
  construction_task_phase=tostring(task.phase or "none"),
  construction_request=tostring(request.item_name or request.item or "none"),
  construction_last_action=tostring(event.action or "none"),
  construction_last_detail=tostring(event.detail or "none"),
  construction_last_tick=event.tick or 0,
 }
end
local function snapshot(elapsed)
 local s=state()
 local surface,force=game.surfaces[1],game.forces.player
 local entities={}
 local counts={}
 local paired=0
 local diagnostics={}
 for _,r in ipairs(RANKS)do
  diagnostics[#diagnostics+1]=diagnostic_pair(r.name,
    s["station_"..r.name])
 end
 local live_ghosts=surface.count_entities_filtered{
   area=area(),force=force,type="entity-ghost"}
 for _,r in ipairs(RANKS)do
  local pair=storage.tech_priests.pairs_by_station
   and storage.tech_priests.pairs_by_station[
     s["station_"..r.name]]
  if pair and pair.priest and pair.priest.valid then paired=paired+1 end
 end
 for _,ent in ipairs(surface.find_entities_filtered{
     area=area(),force=force,type=TYPES})do
  if ent.valid then
   local typ=ent.type
   counts[typ]=(counts[typ] or 0)+1
   local recipe=nil
   if ent.get_recipe then
    local ok,selected=pcall(ent.get_recipe)
    if ok and selected then recipe=selected.name end
   end
   entities[#entities+1]={
    x=ent.position.x,y=ent.position.y,name=ent.name,
    type=typ,recipe=recipe or "none",
    unit=ent.unit_number or 0,
   }
  end
 end
 table.sort(entities,function(a,b)
  if a.y~=b.y then return a.y<b.y end
  if a.x~=b.x then return a.x<b.x end
  return a.name<b.name
 end)
 -- Telemetry exports existing entity positions; it neither positions nor
 -- constructs an entity. Maps rendered from these records ARE NOT screenshots.
 local current=force.current_research
 local packs={}
 for _,name in ipairs(PRODUCTS)do
  packs[name]=observed_spm(force,surface,name)
 end
 local mining={}
 for _,name in ipairs({"iron-ore","copper-ore","coal",
     "stone","uranium-ore","crude-oil"})do
  mining[name]=observed_spm(force,surface,name)
 end
 local frame={
  schema="tech-priests-midgame-engine-checkpoint-v1",
  tick=game.tick,elapsed=elapsed,
  force=force.name,surface=surface.name,
  research=current and current.name or "none",
  research_progress=force.research_progress or 0,
  research_finished=s.research_finishes,
  technology_researched={
   military=force.technologies["military-science-pack"].researched,
   chemical=force.technologies["chemical-science-pack"].researched,
  },
  paired_priests=paired,
  live_planning_ghosts=live_ghosts,
  pair_diagnostics=diagnostics,
  observed_science_spm=packs,
  observed_raw_resource_production=mining,
  entity_counts=counts,
  entities=entities,
  starter_crates=s.crates,
  fixture_supply_is_not_production=true,
  visual_source="factorio-live-engine-entity-telemetry",
 }
 local name="checkpoint-"..string.format("%06d",elapsed)
 local path="tech-priests-midgame/"..name..".json"
 helpers.write_file(path,helpers.table_to_json(frame),false)
 s.checkpoints[elapsed]={tick=game.tick,
  entity_count=#entities,paired=paired,
  red=packs["automation-science-pack"],
  green=packs["logistic-science-pack"],
  military=packs["military-science-pack"],
  chemical=packs["chemical-science-pack"],
  research=frame.research}
 -- The Factorio 2.0 game client can render a true image from these same
 -- positions. Headless benchmarks cannot: this API is a no-op on headless.
 pcall(function()game.take_screenshot{
   surface=surface,position={x=96,y=0},
   resolution={x=1600,y=900},zoom=0.16,
   show_entity_info=true,
   path="tech-priests-midgame/"..name..".png",
   force_render=true}
 end)
 -- Named autosaves are requested, but only an actual ZIP file on disk
 -- counts as a verified recoverable save; the runner checks separately.
 local saved,save_error=pcall(game.auto_save,"tp-midgame-"..name)
 for _,d in ipairs(diagnostics)do
  emit("PAIR_DIAGNOSTIC elapsed="..elapsed..
    " rank="..d.rank..
    " priest="..tostring(d.priest_unit or "none")..
    " infrastructure="..tostring(d.infrastructure_stage or "none")..
    " blocker="..tostring(d.infrastructure_blocker or "none")..
    " target="..tostring(d.infrastructure_item or "none")..
    " deferred_receiver="..tostring(d.deferred_receiver_reason or "none")..
    " deferred_drill="..tostring(d.deferred_drill_unit or "none")..
    " deferred_at="..tostring(d.deferred_receiver_x or "none")..
      ","..tostring(d.deferred_receiver_y or "none")..
    " research_plan="..tostring(d.research_plan_reason or "none")..
    " ghost="..tostring(d.ghost_entity or "none")..
    " ghost_status="..tostring(d.ghost_status or "none")..
    " ghost_blocker="..tostring(d.ghost_blocker or "none")..
    " candidate="..tostring(d.construction_candidate or "none")..
    " candidate_field="..tostring(d.construction_candidate_field or "none")..
    " candidate_matches_bootstrap="..tostring(d.candidate_matches_bootstrap)..
    " construction_blocked="..tostring(d.construction_blocked_reason or "none")..
    " order="..tostring(d.active_order_kind or "none")..
    " order_source="..tostring(d.active_order_source or "none")..
    " mode="..tostring(d.mode or "none")..
    " dispatch="..tostring(d.canonical_family or "none")..
    " dispatch_status="..tostring(d.canonical_status or "none")..
    " dispatch_reason="..tostring(d.canonical_reason or "none")..
    " strict_recipe="..tostring(d.strict_recipe)..
    " emergency_craft="..tostring(d.emergency_craft)..
    " direct_task="..tostring(d.active_direct)..
    " direct_custody="..tostring(d.direct_custody)..
    " task="..tostring(d.construction_task_phase or "none")..
    " request="..tostring(d.construction_request or "none")..
    " last_action="..tostring(d.construction_last_action or "none")..
    " last_detail="..tostring(d.construction_last_detail or "none"))
 end
 emit("CHECKPOINT tick="..game.tick.." elapsed="..elapsed..
    " live_ghosts="..live_ghosts..
  " paired="..paired.." entities="..#entities..
  " research="..frame.research..
  " red_spm="..tostring(packs["automation-science-pack"])..
  " green_spm="..tostring(packs["logistic-science-pack"])..
  " military_spm="..tostring(packs["military-science-pack"])..
  " chemical_spm="..tostring(packs["chemical-science-pack"])..
  " mined_iron_per_min="..tostring(mining["iron-ore"])..
  " mined_copper_per_min="..tostring(mining["copper-ore"])..
  " screenshot_request=headless-noop-or-client-render"..
  " autosave_requested="..tostring(saved)..
  " autosave_error="..tostring(not saved and save_error or "nil")..
  " telemetry="..path)
 if elapsed==216000 then
  local started=paired>=3
  local basic=(packs["automation-science-pack"] or 0)>0
    and (packs["logistic-science-pack"] or 0)>0
    and (packs["military-science-pack"] or 0)>0
  local advanced=(packs["chemical-science-pack"] or 0)>0
  emit("MIDGAME_OBJECTIVE status="..
    (started and "audited" or "pairing-incomplete")..
    " all_three_sciences_produced="..tostring(basic)..
    " chemical_science_produced="..tostring(advanced)..
    " selected_research="..frame.research..
    " real_output_only=true")
  if not started then fail("MIDGAME_PAIRS_INCOMPLETE") end
  emit("PASS fixture, authentic research observations and nine engine checkpoints audited")
 end
end
local function pulse()
 local s=state()
 if not s.started or s.failed then return {processed=1,acted=0}end
 local elapsed=game.tick-s.started
 local ok,err=pcall(function()
  for _,mark in ipairs(MARKS)do
   if elapsed>=mark and not s.checkpoints[mark] then
    snapshot(mark)
   end
  end
 end)
 if not ok then
  s.failed=tostring(err)
  emit("FAIL "..s.failed)
  return {processed=1,acted=0,failed=1,detail=s.failed}
 end
 return {processed=1,acted=0,detail="midgame-science-observation"}
end
local function on_research(event)
 local s=state()
 if not s.started or game.tick<=s.started then return end
 local research=event and event.research
 if not(research and research.valid and research.force==game.forces.player)then
  return
 end
 s.research_finishes[#s.research_finishes+1]={
  name=research.name,tick=game.tick}
 emit("REAL_RESEARCH_COMPLETED tick="..game.tick..
   " research="..research.name.." fixture_grants=0")
end
function M.install()
 local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
 if not(registry and registry.on_init and registry.on_event
     and broker and broker.register_service)then
  error(PREFIX.."FAIL runtime registry/broker unavailable")
 end
 assert(registry.on_init(setup,{
  owner="ci_midgame_science_1194",route="physical-fixture",
  category="diagnostics",priority="last"}))
 assert(registry.on_event(defines.events.on_research_finished,
   on_research,nil,{owner="ci_midgame_science_1194",
   route="real-research-observer",category="diagnostics",
   priority=1100}))
 assert(broker.register_service{
  name="ci_midgame_science_1194",category="diagnostics",
  interval=60,priority=1100,budget=1,fn=pulse,
  note="midgame real science factories, research and map checkpoints"})
 emit("INSTALLED science=red,green,military unlocked_to=military"..
  " advanced=chemical is locked crates=8 output_from_real_engine=true")
 return true
end
return M
