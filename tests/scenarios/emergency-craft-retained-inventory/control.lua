-- Stage with the real scripts/shared trees and base + Space Age. Create a save,
-- then benchmark that save for at least six ticks. No inventory API is mocked.
for _,part in ipairs({"001","002","005","009","012"})do
  require("scripts.generated.control_legacy_part_"..part)
end
local Economy=require("scripts.core.efficiency_economy_0587")
local Catalog=require("scripts.core.station_catalog")
local Doctrine=require("scripts.core.resource_doctrine")
local TargetSafety=require("scripts.core.inventory_target_safety")
local installed=false
local function install()
  assert(Economy.install());assert(Catalog.install());assert(Doctrine.install())
  TargetSafety.install();installed=true
end
local function check(value,message)assert(value,"[EMERGENCY RETAINED NATIVE] "..message)end
local function queries()
  return storage.tech_priests.station_catalog_0327.stats.inventory_initial_queries_1497 or 0
end
local function rebuild(pair)
  check(tech_priests_start_emergency_operation_craft_item_0184(pair,"iron-gear-wheel"),
    "actual fallback did not start")
  return pair.emergency_craft.candidates
end
local function found(list,entity,item,id)
  for _,candidate in ipairs(list)do
    if candidate.kind=="inventory" and candidate.entity==entity
        and (not item or candidate.item_name==item)
        and (not id or candidate.inventory_id==id)then return candidate end
  end
end
script.on_init(function()
  storage.tech_priests={pairs_by_station={}}
  local surface=game.create_surface("emergency-retained-native",{water=0,
    default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},
      decorative={treat_missing_as_default=false,settings={}}}})
  surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
  local force=game.forces.player
  local function place(name,x,y,owner)
    return assert(surface.create_entity{name=name,position={x,y},force=owner or force})
  end
  local station=place("steel-chest",0,0)
  local pair={station=station,station_unit=station.unit_number,
    priest=place("character",0,2)}
  storage.tech_priests.pairs_by_station[station.unit_number]=pair
  local chest=place("steel-chest",5,0)
  local hostile=place("steel-chest",8,0,game.forces.enemy)
  check(hostile.insert{name="iron-plate",count=11}==11,"hostile fixture")
  install()
  local first=rebuild(pair)
  check(queries()==1 and not found(first,chest) and not found(first,hostile),
    "initial complete seed or same-force eligibility failed")
  for _=1,100 do rebuild(pair)end
  check(queries()==1,"warm fallback rediscovered inventories")
  local inv=chest.get_inventory(defines.inventory.chest)
  check(inv.insert{name="copper-plate",count=4,quality="rare"}==4,"quality fixture")
  check(found(rebuild(pair),chest,"copper-plate",defines.inventory.chest),
    "initially empty native inventory refill was missed")
  check(inv.get_item_count{name="copper-plate",quality="rare"}==4,
    "discovery changed native quality stock")
  chest.force=game.forces.enemy
  check(not found(rebuild(pair),chest),"live native force change ignored")
  chest.force=force
  check(chest.teleport({19,19}),"corner fixture")
  check(not found(rebuild(pair),chest),"square identities bypassed circular eligibility")
  check(chest.teleport({5,0}),"return fixture")
  local car=place("car",60,0)
  local trunk=car.get_inventory(defines.inventory.car_trunk)
  check(trunk.insert{name="iron-plate",count=6}==6,"native trunk fixture")
  check(car.teleport({10,5}),"autonomous vehicle fixture")
  local physical=found(rebuild(pair),car,"iron-plate",defines.inventory.car_trunk)
  check(physical,"engine-list vehicle arrival missing")
  check(acquire_emergency_material(pair,pair.emergency_craft,physical),"real withdrawal failed")
  check(trunk.get_item_count("iron-plate")==5
      and pair.emergency_craft.gathered_units==physical.value,
    "physical single-item transaction changed")
  check(queries()==1,"native stock/domain-view changes repeated initial discovery")
  storage.emergency_retained_native={pair=pair,surface=surface,chest=chest,done=false}
  log("[TP-EMERGENCY-RETAINED-CREATE] "..helpers.table_to_json{passed=true,
    initial_queries=queries(),warm_rebuilds=100,native_quality_preserved=true,
    native_force_range=true,native_vehicle_arrival=true,native_physical_withdrawal=true})
end)
script.on_event(defines.events.on_tick,function(event)
  local fixture=storage.emergency_retained_native
  if not fixture or fixture.done then return end
  if not installed then install()end
  if event.tick<5 then return end
  local pair=fixture.pair
  check(found(rebuild(pair),fixture.chest,"copper-plate"),"reload lost retained live stock")
  local added=assert(fixture.surface.create_entity{name="steel-chest",position={8,7},
    force=pair.station.force,raise_built=true})
  check(added.insert{name="coal",count=3}==3,"raised build stock fixture")
  check(found(rebuild(pair),added,"coal"),"actual raised build was missed")
  added.destroy{raise_destroy=true}
  for _,candidate in ipairs(rebuild(pair))do
    check(not(candidate.kind=="inventory" and candidate.entity==added),"raised removal stayed usable")
  end
  check(queries()==1,"reload or raised events rediscovered inventories")
  fixture.done=true
  log("[TP-EMERGENCY-RETAINED-PASS] "..helpers.table_to_json{passed=true,
    tick=event.tick,initial_queries=queries(),reloaded_membership=true,native_build_remove=true})
end)
