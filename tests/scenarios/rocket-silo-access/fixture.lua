-- Isolated late-stage diagnostic. Declared machines/stock/power only at setup;
-- no actor tasks, executor calls, movement commands or runtime refills.
-- This does not establish autonomous rocket research/build or a launch.
local M={};local PREFIX="[TP-SILO-ACCESS] "
local function emit(s)log(PREFIX..s)end
local function fail(s)error(PREFIX.."FAIL "..s)end
local function root()
 storage.tech_priests=storage.tech_priests or{}
 local s=storage.tech_priests.ci_rocket_silo_access_1286 or{}
 storage.tech_priests.ci_rocket_silo_access_1286=s;return s
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
 local stock=station.get_inventory(defines.inventory.chest)
 if not(stock and stock.valid)then fail("station storage absent")end
 s.supplies={}
 for _,ingredient in pairs(recipe.ingredients)do
  if ingredient.type=="item"then
   local count=math.ceil(ingredient.amount*10)
   if stock.insert{name=ingredient.name,count=count}~=count then fail("declared ingredient stock refused")end
   s.supplies[ingredient.name]=count
  end
 end
 for _,name in ipairs{"repair-pack","sacred-machine-oil","machine-maintenance-litany","firearm-magazine"}do
  if prototypes.item[name]then stock.insert{name=name,count=8}end
 end
 s.station=station;s.silo=silo;s.started=game.tick;s.initial_parts=silo.rocket_parts
 emit("SETUP late-stage diagnostic silo="..silo.unit_number.." parts="..s.initial_parts.." stock="..helpers.table_to_json(s.supplies))
end
local function pulse()
 local s=root();if s.finished or s.failed then return{processed=0}end
 local ok,err=pcall(function()
  local p=storage.tech_priests.pairs_by_station[s.station.unit_number]
  if not(p and p.priest and p.priest.valid)then
   if game.tick-s.started>3600 then fail("pair initialization")end;return
  end
  local parts=s.silo.rocket_parts
  if parts>s.initial_parts then
   local doctrine=TechPriestsRocketSiloLogistics0710.root()
   if(tonumber(doctrine.stats["input-items-delivered"])or 0)<=0 then fail("parts without original delivery evidence")end
   emit("PASS autonomous physical silo delivery and native rocket-part production parts="..parts..
     " delivered="..tostring(doctrine.stats["input-items-delivered"]))
   s.finished=true;return
  end
  if game.tick>=(s.next_log or 0)then
   s.next_log=game.tick+1800
   emit("OBSERVE elapsed="..(game.tick-s.started).." parts="..parts.." priest="..helpers.table_to_json(p.priest.position)..
    " dispatcher="..helpers.table_to_json(p.dispatcher_0510 or{})..
    " readiness="..tostring(p.rocket_silo_reports_0709 and p.rocket_silo_reports_0709[1]and p.rocket_silo_reports_0709[1].state))
  end
  if game.tick-s.started>=17400 then fail("no native rocket part after autonomous supply window")end
 end)
 if not ok then s.failed=tostring(err);emit("FAIL "..s.failed)end
 return{processed=1,failed=s.failed and 1 or 0}
end
function M.install()
 local registry=TechPriestsRuntimeEventRegistry;local broker=TechPriestsRuntimeTickBroker0600
 assert(registry.on_init(setup,{owner="ci_rocket_silo_access_1286",route="initialize",category="diagnostics",priority="last"}))
 assert(broker.register_service{name="ci_rocket_silo_access_1286",category="diagnostics",interval=60,
  priority=1100,budget=1,fn=pulse,note="passive native silo access and production diagnostic"})
 return true
end
return M
