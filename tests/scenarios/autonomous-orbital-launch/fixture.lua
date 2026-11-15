-- Isolated late-stage diagnostic. Declared machines/stock/power only at setup;
-- no actor tasks, executor calls, movement commands or runtime refills.
-- This validates native launch and paid starter delivery; not campaign research/build or science.
local M={};local PREFIX="[TP-ORBITAL-LAUNCH] "
local Campaign=require("scripts.core.orbital_campaign_1287")
local function emit(s)log(PREFIX..s)end
local function fail(s)error(PREFIX.."FAIL "..s)end
local function root()
 storage.tech_priests=storage.tech_priests or{}
 local s=storage.tech_priests.ci_orbital_launch_1287 or{}
 storage.tech_priests.ci_orbital_launch_1287=s;return s
end
local function create(surface,name,position,force)
 if not surface.can_place_entity{name=name,position=position,force=force}then fail("illegal setup "..name)end
 local e=surface.create_entity{name=name,position=position,force=force,raise_built=true}
 if not(e and e.valid)then fail("creation refused "..name)end;return e
end
local function setup()
 local s=root();local surface,force=game.surfaces[1],game.forces.player
 surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
 local tiles={};for x=-24,42 do for y=-20,24 do tiles[#tiles+1]={name="grass-1",position={x=x,y=y}}end end
 surface.set_tiles(tiles,true)
 for _,e in pairs(surface.find_entities_filtered{area={{-24,-20},{43,25}}})do
  if e.valid and(e.type=="tree"or e.type=="resource"or e.type=="simple-entity"or e.type=="cliff"or e.force==game.forces.enemy)then e.destroy()end
 end
 local station=create(surface,"senior-cogitator-station",{0,0},force)
 local silo=create(surface,"rocket-silo",{20,0},force)
 local power=create(surface,"electric-energy-interface",{12,12},force)
 power.power_production=10000000;power.energy=10000000
 create(surface,"substation",{20,10},force)
 local recipe=silo.get_recipe();if not recipe then fail("native fixed rocket-part recipe absent")end
 local supply=create(surface,"steel-chest",{-6,4},force)
 local stock=supply.get_inventory(defines.inventory.chest)
 if not(stock and stock.valid)then fail("station storage absent")end
 s.supplies={};s.required_deliveries=1 -- the real starter pack
 for _,ingredient in pairs(recipe.ingredients)do
  if ingredient.type=="item"then
   local count=math.ceil(ingredient.amount*(silo.prototype.rocket_parts_required+2))
   if stock.insert{name=ingredient.name,count=count}~=count then fail("declared ingredient stock refused")end
   s.supplies[ingredient.name]=count
   s.required_deliveries=s.required_deliveries+ingredient.amount*silo.prototype.rocket_parts_required
  end
 end
 for _,name in ipairs{"repair-pack","sacred-machine-oil","machine-maintenance-litany","firearm-magazine"}do
  if prototypes.item[name]then stock.insert{name=name,count=8}end
 end
 assert(stock.insert{name="space-platform-starter-pack",count=1}==1)
 s.station=station;s.supply=supply;s.silo=silo;s.started=game.tick;s.initial_parts=silo.rocket_parts
 emit("SETUP late-stage diagnostic silo="..silo.unit_number.." parts="..s.initial_parts..
  " planet="..tostring(surface.planet and surface.planet.name).." stock="..helpers.table_to_json(s.supplies))
end
local function pulse()
 local s=root();if s.finished or s.failed then return{processed=0}end
 local ok,err=pcall(function()
  local p=storage.tech_priests.pairs_by_station[s.station.unit_number]
  if not(p and p.priest and p.priest.valid)then
   if game.tick-s.started>3600 then fail("pair initialization")end;return
  end
  if not s.preset_applied then
   p.emergency_operation_auto_allowed_0190=true
   p.logistic_frustration_due_tick=game.tick
   assert(tech_priests_set_emergency_operation_0184(p,true,"isolated-orbital-launch-preset"))
   s.preset_applied=true
  end
  local parts=s.silo.rocket_parts
  if s.silo.rocket_silo_status==defines.rocket_silo_status.rocket_ready and not s.ready_checkpoint_requested then
   s.ready_checkpoint_requested=true
   local saved,reason=pcall(game.auto_save,"tp-orbital-native-ready-1287")
   emit("CHECKPOINT_REQUEST ready saved="..tostring(saved).." detail="..tostring(reason))
  end
  s.max_parts=math.max(s.max_parts or 0,parts)
  local campaign=storage.tech_priests.orbital_campaign_1287
  local r=campaign and campaign.by_force[s.station.force.index]
  if r and r.delivered_tick and r.platform.valid and r.platform.hub and r.platform.hub.valid then
   local doctrine=TechPriestsRocketSiloLogistics0710.root()
   local stock=s.supply.get_inventory(defines.inventory.chest)
   assert(stock.get_item_count("space-platform-starter-pack")==0,"starter pack never charged")
   assert(r.launch_requested_tick and s.ready_checkpoint_requested,"native ready-to-flight cycle not observed")
   assert((doctrine.stats["input-items-delivered"]or 0)>=s.required_deliveries,
    "full native rocket recipe and starter pack were not supplied by the actor")
   assert(r.platform.hub.force==s.station.force and r.platform.space_location.name==s.station.surface.planet.name)
   emit("PASS autonomous native rocket launch and paid platform starter delivery parts_peak="..s.max_parts..
     " delivered_items="..tostring(doctrine.stats["input-items-delivered"]).." hub="..r.platform.hub.unit_number)
   s.finished=true;return
  end
  if game.tick>=(s.next_log or 0)then
   local report=p.rocket_silo_reports_0709 and p.rocket_silo_reports_0709[1]
   local need,why=Campaign.requirement(p,report)
   emit("INTENT why="..tostring(why).." loaded="..tostring(need and need.loaded)..
    " independent="..tostring(p.independent_emergency_operation_0184 and p.independent_emergency_operation_0184.enabled)..
    " native_status="..tostring(report and report.rocket_silo_status_name)..
    " rocket_inv="..tostring(report and report.rocket_inventory and report.rocket_inventory.valid)..
    " attached_inv="..tostring(report and report.attached_cargo_inventory and report.attached_cargo_inventory.valid))
   s.next_log=game.tick+1800
   emit("OBSERVE elapsed="..(game.tick-s.started).." parts="..parts.." priest="..helpers.table_to_json(p.priest.position)..
    " dispatcher="..helpers.table_to_json(p.dispatcher_0510 or{})..
    " campaign="..tostring(r and r.phase).." readiness="..tostring(p.rocket_silo_reports_0709 and p.rocket_silo_reports_0709[1]and p.rocket_silo_reports_0709[1].state))
  end
  if game.tick-s.started>=59400 then fail("no completed native platform starter delivery")end
 end)
 if not ok then s.failed=tostring(err);emit("FAIL "..s.failed)end
 return{processed=1,failed=s.failed and 1 or 0}
end
function M.install()
 local registry=TechPriestsRuntimeEventRegistry;local broker=TechPriestsRuntimeTickBroker0600
 assert(registry.on_init(setup,{owner="ci_orbital_launch_1287",route="initialize",category="diagnostics",priority="last"}))
 assert(broker.register_service{name="ci_orbital_launch_1287",category="diagnostics",interval=60,
  priority=1100,budget=1,fn=pulse,note="passive native silo access and production diagnostic"})
 return true
end
return M
