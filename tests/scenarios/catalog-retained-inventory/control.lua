-- Standalone native fixture: stage this control.lua with the actual catalog,
-- 0587, registry and catalog helper modules under scripts/core. Enable base
-- and space-age, create a save, then benchmark that save for at least10ticks.
-- It creates real entities, inventories, wires and engine events; no owner
-- or native inventory API is replaced by a fixture implementation.
local Registry=require("scripts.core.runtime_event_registry")
local Economy=require("scripts.core.efficiency_economy_0587")
local Catalog=require("scripts.core.station_catalog")
local StorageAuthority=require("scripts.core.storage_role_authority_0686")
TechPriestsRuntimeEventRegistry=Registry
local installed=false
local function install()
  assert(Economy.install())
  assert(Catalog.install())
  installed=true
end
local function check(value,message)assert(value,"[CATALOG NATIVE] "..message)end
local function candidates_contain(pair,entity)
  for _,candidate in ipairs(Catalog.inventory_candidates(pair))do
    if candidate==entity then return true end
  end
  return false
end
local function inventory_queries()
  return storage.tech_priests.station_catalog_0327.stats.inventory_initial_queries_1497 or 0
end
script.on_init(function()
  storage.tech_priests={pairs_by_station={}}
  local surface=game.create_surface("catalog-native",{water=0,
    default_enable_all_autoplace_controls=false,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},
      decorative={treat_missing_as_default=false,settings={}}}})
  surface.request_to_generate_chunks({0,0},3)
  surface.force_generate_chunk_requests()
  local force=game.forces.player
  local function place(name,x,y,raised)
    return assert(surface.create_entity{name=name,position={x,y},force=force,
      raise_built=raised==true})
  end
  local station=place("steel-chest",0,0)
  local priest=place("character",0,2)
  local pair={station=station,station_unit=station.unit_number,priest=priest,radius=64}
  storage.tech_priests.pairs_by_station[station.unit_number]=pair
  local chest=place("steel-chest",6,0)
  local machine=place("assembling-machine-1",12,0)
  machine.set_recipe("iron-gear-wheel")
  local output=assert(machine.get_inventory(defines.inventory.crafter_output))
  check(output.insert{name="iron-gear-wheel",count=7}==7,"native machine output fixture")
  local proxy=place("proxy-container",16,0)
  local corpse=place("character-corpse",20,0)
  local pod=place("cargo-pod",24,0)
  local pod_inventory=assert(pod.get_inventory(defines.inventory.cargo_unit))
  check(pod_inventory.insert{name="copper-plate",count=11}==11,"native pod inventory fixture")
  local port=place("roboport",32,0)
  port.energy=1000000000
  local fixture={pair=pair,chest=chest,machine=machine,proxy=proxy,
    corpse=corpse,pod=pod,port=port,surface=surface,phase=0}
  storage.catalog_native=fixture
  install()
  local names,types=Catalog.inventory_types()
  check(types["character-corpse"]and types["cargo-pod"]and types["proxy-container"],
    "runtime-dependent inventory families missing")
  local initial=Catalog.scan_pair(pair)
  check(next(initial.storage_items)==nil,"scheduled scan materialized inventory contents")
  check(candidates_contain(pair,corpse)and candidates_contain(pair,pod)
    and candidates_contain(pair,proxy),"native dynamic identity missing")
  local source=Catalog.find_inventory_source(pair,"iron-gear-wheel")
  check(source and source.source==machine and source.inventory_id==defines.inventory.crafter_output,
    "native machine output not available")
  output.clear()
  check(not Catalog.find_inventory_source(pair,"iron-gear-wheel"),"same-tick output removal stale")
  local chest_inventory=chest.get_inventory(defines.inventory.chest)
  chest_inventory.insert{name="iron-plate",count=9}
  check(Catalog.find_inventory_source(pair,"iron-plate").source==chest,
    "initially empty native source stayed empty")
  local red=chest.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  local other=station.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  check(red.connect_to(other),"native wire fixture connection")
  check(not Catalog.find_inventory_source(pair,"iron-plate"),"native live wire exclusion ignored")
  red.disconnect_from(other)
  check(Catalog.find_inventory_source(pair,"iron-plate").source==chest,
    "native wire disconnection stayed stale")
  proxy.proxy_target_entity=chest
  proxy.proxy_target_inventory=defines.inventory.chest
  check(proxy.get_inventory(defines.inventory.proxy_main).get_item_count("iron-plate")==9,
    "native proxy inventory fixture")
  local first_queries=inventory_queries()
  for i=1,100 do
    Catalog.find_inventory_source(pair,"uranium-235")
    Catalog.inventory_candidates(pair,i%2==0 and 64 or 32)
  end
  check(inventory_queries()==first_queries,"native misses/alternating radius reseeded identities")
  local vehicle=place("car",100,12,false)
  local fuel=vehicle.get_inventory(defines.inventory.fuel)
  local trunk=vehicle.get_inventory(defines.inventory.car_trunk)
  check(vehicle.get_inventory(defines.inventory.chest)==fuel,
    "native car chest/fuel alias fixture")
  check(fuel.insert{name="coal",count=7}==7,"native car fuel fixture")
  check(vehicle.teleport({8,12}),"native autonomous vehicle arrival fixture")
  check(StorageAuthority.generic_item_count(pair,"coal")==0
    and StorageAuthority.remove_generic_item(pair,"coal",2)==0
    and fuel.get_item_count("coal")==7,
    "generic storage exposed a real car's fuel while its trunk was empty")
  check(trunk.insert{name="coal",count=5}==5,"native car trunk fixture")
  check(StorageAuthority.generic_item_count(pair,"coal")==5
    and StorageAuthority.remove_generic_item(pair,"coal",2)==2
    and trunk.get_item_count("coal")==3 and fuel.get_item_count("coal")==7,
    "generic vehicle storage did not use only the live physical trunk")
  fuel.clear();trunk.clear()
  trunk.insert{name="stone",count=3}
  check(Catalog.find_inventory_source(pair,"stone").source==vehicle,
    "engine vehicle-list arrival missing")
  check(StorageAuthority.generic_item_count(pair,"stone")==3,
    "generic storage missed the shared engine vehicle arrival")
  check(inventory_queries()==first_queries,
    "generic vehicle storage created a second inventory discovery domain")
  local pod_is_vehicle=false
  for _,entity in ipairs(game.get_vehicles{surface=surface})do if entity==pod then pod_is_vehicle=true end end
  local corpse_inventory=corpse.get_inventory(defines.inventory.character_corpse)
  fixture.initial_queries=inventory_queries()
  fixture.robot=place("logistic-robot",32,10,false)
  fixture.robot.get_inventory(defines.inventory.robot_cargo).insert{name="wood",count=2}
  fixture.outside_robot=place("logistic-robot",32,14,false)
  fixture.outside_robot.get_inventory(defines.inventory.robot_cargo).insert{name="copper-cable",count=3}
  log("[TP-CATALOG-NATIVE-CREATE] "..helpers.table_to_json{
    passed=true,inventory_types=#names,initial_queries=fixture.initial_queries,
    warm_item_questions=100,corpse_inventory_valid=corpse_inventory and corpse_inventory.valid or false,
    pod_in_vehicle_list=pod_is_vehicle,proxy_runtime_inventory=true,
    native_wires=true,native_vehicle_arrival=true,native_generic_trunk_only=true,
    native_fuel_only_source_rejected=true})
end)
script.on_event(defines.events.on_tick,function(event)
  local fixture=storage.catalog_native
  if not fixture or fixture.phase==1 then return end
  if not installed then install()end
  if event.tick==2 then fixture.outside_robot.teleport({250,14})end
  if event.tick<5 then return end
  local pair,robot=fixture.pair,fixture.robot
  -- Native lifecycle events are not delivered during on_init. Exercise the
  -- real raised build/destruction routes on an engine tick after loading.
  local added=assert(fixture.surface.create_entity{name="steel-chest",
    position={10,7},force=pair.station.force,raise_built=true})
  check(added.insert{name="coal",count=4}==4,"native built chest fixture")
  local built_source=Catalog.find_inventory_source(pair,"coal")
  check(built_source and built_source.source==added,"native raised build not observed")
  added.destroy{raise_destroy=true}
  check(not Catalog.find_inventory_source(pair,"coal"),"native raised removal not observed")
  local source=Catalog.find_inventory_source(pair,"wood")
  check(source and source.source==robot,"automatically deployed native robot not observed")
  robot.teleport({250,10})
  check(not Catalog.find_inventory_source(pair,"wood"),"native robot outside square remained eligible")
  fixture.port.die()
  check(robot.valid,"last port removal destroyed native robot fixture")
  robot.teleport({10,10})
  source=Catalog.find_inventory_source(pair,"wood")
  check(source and source.source==robot,"native last-port death lost retained orphan robot")
  fixture.outside_robot.teleport({10,12})
  source=Catalog.find_inventory_source(pair,"copper-cable")
  check(source and source.source==fixture.outside_robot,
    "native last-cell event failed to retain a previously unobserved outside robot")
  check(inventory_queries()==fixture.initial_queries,
    "reload, robot deployment or port death rediscovered inventory area")
  local snapshot=Catalog.snapshot_inventory(pair,Catalog.get_for_pair(pair))
  check(snapshot.storage_items["wood"].count==2,"native explicit inventory snapshot stale")
  fixture.phase=1
  log("[TP-CATALOG-NATIVE-PASS] "..helpers.table_to_json{passed=true,tick=event.tick,
    initial_queries=inventory_queries(),native_orphan_retained=true,
    cold_and_reloaded_membership=true,live_quantities=true,native_build_remove=true,
    pre_removal_outside_robot_retained=true})
end)
