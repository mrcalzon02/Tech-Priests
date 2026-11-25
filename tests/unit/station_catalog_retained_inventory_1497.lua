-- Exercise the actual catalog, source cache, registry, doctrine and fetcher.
-- Only engine objects/events are fixtures; no production owner is replaced.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=1,forces={}}
settings={global={}}
defines={inventory={chest=1,assembling_machine_input=2,assembling_machine_output=3,
  furnace_result=3,lab_modules=4,character_corpse=5,car_trunk=6,
  robot_cargo=7,cargo_unit=8,proxy_main=9,spider_trunk=10,cargo_wagon=11},
  events={},wire_connector_id={circuit_red=1},distraction={none=0}}
local event_names={"on_built_entity","on_robot_built_entity","script_raised_built",
  "script_raised_revive","on_player_mined_entity","on_robot_mined_entity",
  "on_pre_player_mined_item","on_robot_pre_mined","on_entity_died",
  "script_raised_destroy","on_entity_cloned","script_raised_teleported",
  "on_surface_cleared","on_surface_deleted","on_player_driving_changed_state",
  "on_player_changed_position","on_player_changed_surface","on_spider_command_completed",
  "on_train_changed_state","on_train_created","on_post_entity_died",
  "on_character_corpse_expired","on_cargo_pod_started_ascending",
  "on_cargo_pod_finished_ascending","on_cargo_pod_finished_descending",
  "on_cargo_pod_delivered_cargo","on_rocket_launch_ordered","on_chunk_generated"}
for id,name in ipairs(event_names)do defines.events[name]=id end
local handlers,ticks={},{}
script={on_event=function(id,handler)handlers[id]=handler end,
  get_event_handler=function(id)return handlers[id]end,
  on_nth_tick=function(id,handler)ticks[id]=handler end}
local Registry=require("scripts.core.runtime_event_registry")
TechPriestsRuntimeEventRegistry=Registry
local function emit(name,event)
  event=event or {};event.name=defines.events[name];event.tick=game.tick
  assert(handlers[event.name],"missing actual event route: "..name)(event)
end
local surface={valid=true,index=1,name="nauvis"}
local force={valid=true,index=1,name="player",logistic_networks={}}
local enemy={valid=true,index=2,name="enemy",logistic_networks={}}
game.forces={player=force,enemy=enemy}
local entities,vehicles={},{}
game.get_vehicles=function(options)assert(options.surface==surface);return vehicles end
local contents_reads,spatial_queries,inventory_queries,visual_queries,metadata_reads=0,0,0,0,0
local function inventory(items)
  local inv={valid=true,items=items or {}}
  inv.get_contents=function()contents_reads=contents_reads+1;return inv.items end
  inv.get_item_count=function(item)return inv.items[item] or 0 end
  inv.remove=function(stack)local n=math.min(stack.count,inv.get_item_count(stack.name));inv.items[stack.name]=inv.get_item_count(stack.name)-n;return n end
  inv.insert=function(stack)inv.items[stack.name]=inv.get_item_count(stack.name)+stack.count;return stack.count end
  return inv
end
prototypes={entity={},item={}}
local function prototype(name,kind,ids,runtime)
  local proto={name=name,type=kind,mineable_properties={products={}}}
  proto.get_inventory_size=function(id)
    metadata_reads=metadata_reads+1
    if not runtime and ids[id]then return 0 end
  end
  prototypes.entity[name]=proto
  return proto
end
local prototypes_by_type={}
for kind,ids in pairs({container={[1]=true},["assembling-machine"]={[2]=true,[3]=true},
  lab={[4]=true},car={[6]=true},["logistic-robot"]={[7]=true},
  ["character-corpse"]={[5]=true},["cargo-pod"]={[8]=true},
  ["proxy-container"]={[9]=true},["temporary-container"]={[1]=true},
  roboport={},["rocket-silo"]={},resource={},tree={}})do
  prototypes_by_type[kind]=prototype(kind,kind,ids,
    kind=="character-corpse"or kind=="cargo-pod"or kind=="proxy-container")
end
local serial=0
local function entity(kind,x,slots,owner,y)
  serial=serial+1
  local e={valid=true,type=kind,name=kind,unit_number=serial,
    position={x=x,y=y or 0},surface=surface,force=owner or force,
    prototype=assert(prototypes_by_type[kind]),slots=slots or {}}
  e.get_inventory=function(id)return e.slots[id]end
  e.get_wire_connector=function()return e.wired and {connection_count=1}or nil end
  entities[#entities+1]=e
  return e
end
surface.find_entities_filtered=function(query)
  spatial_queries=spatial_queries+1
  if query.invert then visual_queries=visual_queries+1
  elseif query.type~="item-entity"then
    inventory_queries=inventory_queries+1
    assert(query.limit==nil,"permanent source seed was truncated")
  end
  local types={}
  if type(query.type)=="string"then types[query.type]=true
  else for _,kind in ipairs(query.type or {})do types[kind]=true end end
  local left,right=query.area.left_top or query.area[1],query.area.right_bottom or query.area[2]
  local x1,y1,x2,y2=left.x or left[1],left.y or left[2],right.x or right[1],right.y or right[2]
  local out={}
  for _,e in ipairs(entities)do
    local match=not query.type or types[e.type]==true
    if query.invert then match=not match end
    if e.valid and match and e.surface==surface and e.position.x>=x1 and e.position.x<=x2
        and e.position.y>=y1 and e.position.y<=y2 then
      out[#out+1]=e
      if query.limit and #out>=query.limit then break end
    end
  end
  return out
end
local station_stock=inventory()
local station=entity("container",0,{[1]=station_stock})
local pair={station=station,station_unit=station.unit_number,radius=160,
  priest={valid=true,unit_number=9999,position={x=0,y=1}}}
storage.tech_priests.pairs_by_station[station.unit_number]=pair
local empty_stock=inventory()
local chest=entity("container",6,{[1]=empty_stock})
local output=inventory({["iron-plate"]=20})
local machine=entity("assembling-machine",12,{[2]=inventory(),[3]=output})
local hostile_stock=inventory({modules=2})
local hostile=entity("lab",15,{[4]=hostile_stock},enemy)
local corpse=entity("character-corpse",20,{})
local proxy=entity("proxy-container",22,{})
local pod=entity("cargo-pod",24,{})
local resource=entity("resource",25,{});resource.name="iron-ore";resource.amount=50
local Economy=require("scripts.core.efficiency_economy_0587")
assert(Economy.install())
local Catalog=require("scripts.core.station_catalog")
assert(Catalog.install())
local false_certifications=0
tech_priests_efficiency_0579_note_area_scan=function()false_certifications=false_certifications+1 end
local first=Catalog.scan_pair(pair)
assert(inventory_queries==1 and visual_queries==1 and contents_reads==0,
  "scheduled survey read inventory contents or repeated its identity seed")
assert(next(first.storage_items)==nil and first.entities["assembling-machine"],
  "visual entity tallies lost retained machine identities")
local initial_metadata=metadata_reads
for n=1,8 do
  game.tick=n*1200
  Catalog.scan_pair(pair)
  assert(not Catalog.find_inventory_source(pair,"missing-"..n))
  assert(Catalog.inventory_candidates(pair,96))
end
assert(inventory_queries==1 and metadata_reads==initial_metadata and contents_reads==0,
  "periods, item misses or narrower views rediscovered inventory membership")
assert(false_certifications==0,"filtered visual survey certified complete world cells")
local source=Catalog.find_known_source(pair,"iron-plate")
assert(source and source.source==machine and source.inventory_id==3,
  "universal machine output source was lost")
output.items["iron-plate"]=0
assert(not Catalog.find_inventory_source(pair,"iron-plate"),"same-tick removal remained available")
empty_stock.items["iron-plate"]=4
assert(Catalog.find_inventory_source(pair,"iron-plate").source==chest,
  "initially empty inventory refill required rediscovery")
chest.wired=true
assert(not Catalog.find_inventory_source(pair,"iron-plate"),"live wire exclusion ignored")
chest.wired=false
assert(Catalog.find_inventory_source(pair,"modules").source==hostile,"catalog force policy narrowed")
corpse.slots[5]=inventory({salvage=3})
proxy.slots[9]=inventory({proxy_stock=7})
pod.slots[8]=inventory({pod_stock=11})
assert(Catalog.find_inventory_source(pair,"salvage").source==corpse
  and Catalog.find_inventory_source(pair,"proxy_stock").source==proxy
  and Catalog.find_inventory_source(pair,"pod_stock").source==pod,
  "runtime-dependent inventories were excluded or permanently cached empty")
machine.position={x=155,y=155};output.items["iron-plate"]=9
empty_stock.items["iron-plate"]=0
assert(Catalog.find_inventory_source(pair,"iron-plate").source==machine,
  "square catalog corner was incorrectly clipped to a circle")
machine.position.x=200
assert(not Catalog.find_inventory_source(pair,"iron-plate"),"teleported source stayed eligible")
machine.position={x=12,y=0}
local added=entity("container",4,{[1]=inventory({built_stock=6})})
emit("script_raised_built",{entity=added})
assert(Catalog.find_inventory_source(pair,"built_stock").source==added)
emit("on_pre_player_mined_item",{entity=added})
added.valid=false
assert(not Catalog.find_inventory_source(pair,"built_stock"))
assert(inventory_queries==1,"build/remove events rescanned the station")
local vehicle=entity("car",8,{[6]=inventory({vehicle_stock=5})})
vehicles={vehicle} -- An autonomous arrival without a driving event.
assert(Catalog.find_inventory_source(pair,"vehicle_stock").source==vehicle)
vehicles={};vehicle.position.x=200
assert(not Catalog.find_inventory_source(pair,"vehicle_stock"))
vehicle.position.x=8
assert(Catalog.find_inventory_source(pair,"vehicle_stock").source==vehicle,
  "observed vehicle identity was not retained")
local robot=entity("logistic-robot",10,{[7]=inventory({robot_stock=2})})
local network={valid=true,robots={robot},cells={{}}}
force.logistic_networks.nauvis={network}
assert(Catalog.find_inventory_source(pair,"robot_stock").source==robot)
robot.position.x=250
assert(not Catalog.find_inventory_source(pair,"robot_stock"))
local outside=entity("logistic-robot",260,{[7]=inventory({outside_stock=3})})
network.robots={robot,outside}
local port=entity("roboport",270,{})
port.logistic_network=network
port.logistic_cell={valid=true,owner=port,logistic_network=network}
emit("on_pre_player_mined_item",{entity=port})
force.logistic_networks.nauvis={};network.valid=false;port.valid=false
robot.position.x=10;outside.position.x=11
assert(Catalog.find_inventory_source(pair,"robot_stock").source==robot
  and Catalog.find_inventory_source(pair,"outside_stock").source==outside,
  "observed or pre-removal orphan robot identity was lost outside the square")
local delivered=entity("temporary-container",9,{[1]=inventory({delivered_stock=4})})
emit("on_cargo_pod_delivered_cargo",{spawned_container=delivered,cargo_pod=pod})
assert(Catalog.find_inventory_source(pair,"delivered_stock").source==delivered)
local launched=entity("cargo-pod",26,{[8]=inventory({launched_stock=2})})
emit("on_rocket_launch_ordered",{rocket={valid=true,attached_cargo_pod=launched}})
assert(Catalog.find_inventory_source(pair,"launched_stock").source==launched,
  "rocket-attached pod was not observed before ascent")
local spawned=entity("container",30,{[1]=inventory({generated_stock=2})})
emit("on_chunk_generated",{surface=surface,area={{16,-16},{48,16}}})
assert(Catalog.find_inventory_source(pair,"generated_stock").source==spawned)
local after_event_queries=inventory_queries
local Doctrine=require("scripts.core.resource_doctrine")
for n=1,60 do
  Catalog.find_inventory_source(pair,"no-stock-"..n)
  Doctrine.find_inventory_source(pair,"no-stock-"..n)
end
assert(inventory_queries==after_event_queries and contents_reads==0,
  "doctrine misses repeated inventory discovery or read every item")
local snapshot=Catalog.snapshot_inventory(pair,Catalog.get_for_pair(pair))
assert(contents_reads>0 and snapshot.storage_items["iron-plate"].count==9,
  "explicit ledger snapshot did not read current retained inventory stock")
local before_contents=contents_reads
game.tick=100000
Economy.cleanup();Catalog.scan_pair(pair)
assert(contents_reads==before_contents,"scheduled survey refreshed UI inventory contents")
-- A fetch may use a known general container beyond its old96-tile fallback
-- radius, but it must not use a machine input/output, enemy stock or corners.
local far_stock=inventory({fetch_stock=4})
local far=entity("container",120,{[1]=far_stock})
emit("script_raised_built",{entity=far})
pair.priest.position={x=120,y=0};pair.requested_item="fetch_stock"
local Fetch=require("scripts.core.logistics_fetch_executor_0527")
assert(Fetch.service_pair(pair,"retained-catalog-regression"))
assert(far_stock.items.fetch_stock==3 and station_stock.items.fetch_stock==1)
pair.requested_item="iron-plate"
local acted=Fetch.service_pair(pair,"retained-catalog-regression")
assert(not acted and output.items["iron-plate"]==9,"generic fetch consumed machine output")
assert(inventory_queries==after_event_queries,
  "fetch added a second inventory domain after catalog already covered it")
assert(contents_reads==before_contents,"physical fetch read all inventory contents")
-- Generic storage shares this same catalog identity domain and engine vehicle
-- list, but retains its four-type, same-force, circle and trunk-only policy.
local Authority=require("scripts.core.storage_role_authority_0686")
local fuel_stock=inventory({fuel_only=7})
local trunk_stock=inventory()
local autonomous=entity("car",200,{[1]=fuel_stock,[6]=trunk_stock})
vehicles={autonomous};autonomous.position.x=8
assert(Authority.generic_item_count(pair,"fuel_only")==0
  and Authority.remove_generic_item(pair,"fuel_only",1)==0
  and fuel_stock.items.fuel_only==7,"generic storage exposed a car's aliased fuel slot")
trunk_stock.items.fuel_only=3
assert(Authority.generic_item_count(pair,"fuel_only")==3
  and Authority.remove_generic_item(pair,"fuel_only",1)==1
  and trunk_stock.items.fuel_only==2 and fuel_stock.items.fuel_only==7,
  "generic storage did not use the immediately arriving vehicle's physical trunk")
assert(Authority.generic_item_count(pair,"iron-plate")==0,
  "generic storage broadened into universal catalog machine inventories")
assert(inventory_queries==after_event_queries,
  "generic storage created a duplicate retained inventory domain")
-- Filter ineligible force/type entries before the 256-source view limit, and
-- retain the 257th eligible identity for promotion without another query.
local cap_station=entity("container",1000,{[1]=inventory()})
local cap_pair={station=cap_station,station_unit=cap_station.unit_number,radius=32,
  priest={valid=true,unit_number=9998,position={x=1000,y=1}}}
storage.tech_priests.pairs_by_station[cap_station.unit_number]=cap_pair
for n=1,260 do entity("container",1004,{[1]=inventory({cap_stock=1})},enemy)end
local overflow={}
for n=1,257 do overflow[n]=entity("container",1005,{[1]=inventory({cap_stock=1})})end
local before_cap=inventory_queries
assert(Authority.generic_item_count(cap_pair,"cap_stock")==256,
  "generic shared view counted foreign sources or lost its eligible-source cap")
assert(inventory_queries==before_cap+1,"generic shared view did not seed once")
overflow[1].valid=false
assert(Authority.generic_item_count(cap_pair,"cap_stock")==256
  and inventory_queries==before_cap+1,"generic shared view lost retained overflow promotion")
local shared_record=false
for _,record in pairs(Economy.root().source_cache)do
  if record.station==cap_station then
    assert(record.domain=="catalog-inventory-0327","generic storage created a second source owner")
    shared_record=record.complete and #record.list>256
  end
end
assert(shared_record,"shared catalog incorrectly truncated retained membership")
print("[station-catalog-retained-inventory-1497] PASS cold_seeds=1_per_domain scheduled_contents_reads=0 live_stock=true radius_reuse=true dynamic_membership=true generic_trunks=true shared_overflow=true")
