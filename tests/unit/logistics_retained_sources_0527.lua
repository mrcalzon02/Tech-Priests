-- Exercise the real fetch executor and its shared 0587 membership authority.
-- Missing stock, different requests and elapsed time must not rediscover the
-- station surroundings; inventory quantities and access policy remain live.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=100}
defines={inventory={chest=1,car_trunk=2,spider_trunk=3,cargo_wagon=4,
  character_corpse=5},distraction={none=0},events={}}
local events={"on_built_entity","on_robot_built_entity","script_raised_built",
  "script_raised_revive","on_player_mined_entity","on_robot_mined_entity",
  "on_entity_died","script_raised_destroy","on_entity_cloned",
  "script_raised_teleported","on_surface_cleared","on_surface_deleted",
  "on_player_driving_changed_state","on_player_changed_position",
  "on_spider_command_completed","on_train_changed_state","on_train_created",
  "on_post_entity_died","on_character_corpse_expired"}
for id,name in ipairs(events) do defines.events[name]=id end
local handlers={}
TechPriestsRuntimeEventRegistry={on_event=function(id,handler)
  handlers[id]=handler;return {id=id}
end}
package.loaded["scripts.core.runtime_event_registry"]=TechPriestsRuntimeEventRegistry
local function event(name,entity)
  assert(handlers[defines.events[name]],"missing real membership event")({entity=entity,destination=entity})
end
local function inventory(items)
  local inv={valid=true,items=items or {}}
  inv.get_item_count=function(item)return inv.items[item] or 0 end
  inv.remove=function(stack)
    local n=math.min(stack.count,inv.get_item_count(stack.name))
    inv.items[stack.name]=inv.get_item_count(stack.name)-n;return n
  end
  inv.insert=function(stack)
    inv.items[stack.name]=inv.get_item_count(stack.name)+stack.count;return stack.count
  end
  return inv
end
local force,neutral,enemy={name="player",index=1},{name="neutral",index=2},{name="enemy",index=3}
local surface={index=1,valid=true}
local entities,spatial_queries,loose_queries,truncated_queries={},0,0,0
local next_unit=10
local function source(kind,x,items,source_force)
  next_unit=next_unit+1
  local inv=inventory(items)
  local id=kind=="car" and defines.inventory.car_trunk
    or kind=="spider-vehicle" and defines.inventory.spider_trunk
    or kind=="cargo-wagon" and defines.inventory.cargo_wagon
    or kind=="character-corpse" and defines.inventory.character_corpse
    or defines.inventory.chest
  local e={valid=true,name=kind,type=kind,unit_number=next_unit,
    position={x=x,y=0},surface=surface,force=source_force or force}
  e.get_inventory=function(requested)return requested==id and inv or nil end
  entities[#entities+1]=e
  return e,inv
end
surface.find_entities_filtered=function(filters)
  if filters.type=="item-entity" then loose_queries=loose_queries+1
  else
    spatial_queries=spatial_queries+1
    if filters.limit~=nil then truncated_queries=truncated_queries+1 end
  end
  local allowed={}
  if type(filters.type)=="string" then allowed[filters.type]=true
  else for _,kind in ipairs(filters.type) do allowed[kind]=true end end
  local found={}
  for _,e in ipairs(entities) do
    if e.valid and allowed[e.type] and e.surface==surface
        and e.position.x>=filters.area[1][1] and e.position.x<=filters.area[2][1]
        and e.position.y>=filters.area[1][2] and e.position.y<=filters.area[2][2]
    then found[#found+1]=e end
  end
  return found
end
TechPriestsScanRouting0610={find_entities=function(world,filters)
  return world.find_entities_filtered(filters)
end}
local station,station_inv=source("container",0,{})
local pair={station=station,station_unit=station.unit_number,
  priest={valid=true,unit_number=9,position={x=2,y=0}},radius=12}
storage.tech_priests.pairs_by_station[station.unit_number]=pair
local warehouse,stock=source("container",2,{})
local hostile,hostile_stock=source("container",2,{coal=20},enemy)
local car,car_stock=source("car",2,{})
local corpse,corpse_stock=source("character-corpse",2,{},neutral)
local catalog_calls=0
tech_priests_0327_scan_station_catalog=function()catalog_calls=catalog_calls+1;return {} end
tech_priests_0327_get_station_catalog=function()catalog_calls=catalog_calls+1;return {} end
package.loaded["scripts.core.station_catalog"]={
  find_known_source=function()catalog_calls=catalog_calls+1;return nil end}
local Economy=require("scripts.core.efficiency_economy_0587")
assert(Economy.install())
local fetch_file=os.getenv("TP_FETCH_EXECUTOR_FILE")
local Fetch=fetch_file and assert(loadfile(fetch_file))()
  or require("scripts.core.logistics_fetch_executor_0527")
local function request(item)
  pair.requested_item=item
  return Fetch.service_pair(pair,"retained-source-regression")
end
for n=1,60 do
  game.tick=game.tick+5
  local acted,reason=request("missing-"..n)
  assert(not acted and reason=="no-known-fetch-source")
end
assert(spatial_queries==1 and catalog_calls==0,
  "different missing items rebuilt a catalog or rediscovered storage")
assert(truncated_queries==0,"retained membership seed was truncated")
game.tick=120000
Economy.cleanup()
assert(not request("later-missing") and spatial_queries==1,
  "elapsed time expired retained surroundings")
stock.items.coal=4
local acted,why=request("coal")
assert(acted and why=="fetched-known-source" and stock.items.coal==3
  and station_inv.items.coal==1 and hostile_stock.items.coal==20 and spatial_queries==1,
  "live stock refill was missed or crossed ownership without a scan")
car_stock.items["iron-plate"]=2
assert(request("iron-plate") and car_stock.items["iron-plate"]==1
  and spatial_queries==1,"retained vehicle trunk stock became inaccessible")
corpse_stock.items["copper-plate"]=2
assert(request("copper-plate") and corpse_stock.items["copper-plate"]==1
  and spatial_queries==1,"neutral corpse source policy changed")
warehouse.circuit_connected_entities={red={car}}
stock.items["repair-pack"]=2
assert(not request("repair-pack") and stock.items["repair-pack"]==2,
  "a newly wired source was fetched from retained membership")
warehouse.circuit_connected_entities={}
assert(request("repair-pack") and stock.items["repair-pack"]==1
  and spatial_queries==1,"unwiring required world rediscovery")
local new_source,new_stock=source("logistic-container",2,{steel=2})
event("on_built_entity",new_source)
assert(request("steel") and new_stock.items.steel==1 and spatial_queries==1,
  "newly built source was not admitted by the existing event owner")
local removed,removed_stock=source("container",2,{uranium=3})
event("on_built_entity",removed)
event("on_player_mined_entity",removed) -- Entity is still valid at this event.
assert(not request("uranium") and removed_stock.items.uranium==3
  and spatial_queries==1,"pre-removal event left a usable stale source")
local converted,converted_stock=source("container",2,{stone=3},enemy)
event("on_built_entity",converted)
assert(not request("stone"))
converted.force=force
assert(request("stone") and converted_stock.items.stone==2 and spatial_queries==1,
  "live force change did not admit the already-known eligible source")
local moved,moved_stock=source("container",100,{wood=2})
event("on_built_entity",moved)
moved.position.x=2;event("script_raised_teleported",moved)
assert(request("wood") and moved_stock.items.wood==1 and spatial_queries==1,
  "teleport event did not admit an arriving source")
local arriving_car,arriving_car_stock=source("car",100,{engine=2})
arriving_car.position.x=2
game.get_player=function()return {valid=true,vehicle=arriving_car} end
handlers[defines.events.on_player_changed_position]({player_index=1})
assert(request("engine") and arriving_car_stock.items.engine==1 and spatial_queries==1,
  "natural vehicle arrival was lost by retaining stationary surroundings")
local spider,spider_stock=source("spider-vehicle",2,{rocket=2})
handlers[defines.events.on_spider_command_completed]({vehicle=spider})
assert(request("rocket") and spider_stock.items.rocket==1 and spatial_queries==1,
  "completed spider route did not expose its physical trunk")
local wagon,wagon_stock=source("cargo-wagon",2,{uranium=2})
handlers[defines.events.on_train_changed_state]({train={valid=true,carriages={wagon}}})
assert(request("uranium") and wagon_stock.items.uranium==1 and spatial_queries==1,
  "arriving train did not expose its cargo without rediscovery")
local new_corpse,new_corpse_stock=source("character-corpse",2,{cable=2},neutral)
handlers[defines.events.on_post_entity_died]({corpses={new_corpse}})
assert(request("cable") and new_corpse_stock.items.cable==1 and spatial_queries==1,
  "new character corpse did not enter retained inventory membership")
local catalog_source,catalog_stock=source("container",2,{battery=3})
storage.tech_priests.station_catalog_0327={stations={[station.unit_number]={
  storage_items={battery={entity=catalog_source,inventory_id=defines.inventory.chest,
    distance_sq=4,instances={{entity=catalog_source,
      inventory_id=defines.inventory.chest,distance_sq=4}}}}}}}
catalog_source.position.x=100
pair.priest.position.x=100
assert(not request("battery") and catalog_stock.items.battery==3
  and spatial_queries==1,"retained catalog fetched a source outside the live station radius")
pair.priest.position.x=2
local nearer,near_stock=source("container",2,{plastic=2})
local farther,far_stock=source("container",4,{plastic=2})
storage.tech_priests.station_catalog_0327.stations[station.unit_number].storage_items.plastic={
  entity=farther,inventory_id=defines.inventory.chest,distance_sq=0,
  instances={{entity=farther,inventory_id=defines.inventory.chest,distance_sq=0},
    {entity=nearer,inventory_id=defines.inventory.chest,distance_sq=999}}}
assert(request("plastic") and near_stock.items.plastic==1 and far_stock.items.plastic==2
  and spatial_queries==1,"catalog source selection used obsolete saved distances")
local ground={valid=true,type="item-entity",name="item-on-ground",
  position={x=2,y=0},surface=surface,force=neutral,
  stack={valid_for_read=true,name="sulfur",count=2}}
ground.destroy=function()ground.valid=false end
entities[#entities+1]=ground
assert(request("sulfur") and ground.stack.count==1 and station_inv.items.sulfur==1
  and spatial_queries==1 and loose_queries>0,
  "independent loose-stack discovery/pickup was lost")
assert(catalog_calls==0,"known-source miss invoked a full catalog reader/scanner")
print("[logistics-retained-sources-0527] PASS storage_queries="..spatial_queries
  .." catalog_calls="..catalog_calls.." live_counts wires forces vehicle corpse events loose_pickup")
