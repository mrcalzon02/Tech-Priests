-- Exercise the real generated fallback, its 0214/0325 wrappers and the existing
-- catalog/0587 owner. Only Factorio objects and script callbacks are fixtures.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=1,forces={}}
settings={global={}}
defines={inventory={chest=1,car_trunk=2,spider_trunk=3,cargo_wagon=4,
  assembling_machine_input=5,assembling_machine_output=6,furnace_source=5,
  furnace_result=6,lab_input=7},events={},direction={north=0,northeast=2,east=4,
    southeast=6,south=8,southwest=10,west=12,northwest=14}}
local event_names={"on_built_entity","on_robot_built_entity","script_raised_built",
  "script_raised_revive","on_player_mined_entity","on_robot_mined_entity",
  "on_pre_player_mined_item","on_robot_pre_mined","on_entity_died",
  "script_raised_destroy","on_entity_cloned","script_raised_teleported",
  "on_surface_cleared","on_surface_deleted","on_chunk_generated"}
for id,name in ipairs(event_names)do defines.events[name]=id end
local handlers,ticks={},{}
script={on_event=function(id,handler)handlers[id]=handler end,
  get_event_handler=function(id)return handlers[id]end,
  on_nth_tick=function(id,handler)ticks[id]=handler end}
function log()end
prototypes={entity={},item={},recipe={
  ["iron-gear-wheel"]={name="iron-gear-wheel",
    ingredients={{name="iron-plate",amount=2,type="item"}}}}}
local surface={valid=true,index=1,name="nauvis"}
local force={valid=true,index=1,name="player",technologies={},logistic_networks={}}
local enemy={valid=true,index=2,name="enemy",technologies={},logistic_networks={}}
game.forces={player=force,enemy=enemy}
local entities,vehicles={},{}
game.get_vehicles=function(options)assert(options.surface==surface);return vehicles end
local inventory_queries,ground_queries,resource_queries=0,0,0
local function inventory(stacks)
  local inv={valid=true}
  inv.set=function(values)
    for i=#inv,1,-1 do inv[i]=nil end
    for i,stack in ipairs(values or {})do
      inv[i]={valid_for_read=true,name=stack.name,count=stack.count,
        quality=stack.quality or "normal"}
    end
  end
  inv.get_item_count=function(name)
    local count=0
    for _,stack in ipairs(inv)do
      if stack.valid_for_read and stack.name==name then count=count+stack.count end
    end
    return count
  end
  inv.remove=function(request)
    local left=request.count
    for _,stack in ipairs(inv)do
      if stack.valid_for_read and stack.name==request.name
          and (not request.quality or request.quality==stack.quality) then
        local n=math.min(left,stack.count);left=left-n;stack.count=stack.count-n
        if stack.count==0 then stack.valid_for_read=false end
      end
    end
    return request.count-left
  end
  inv.set(stacks)
  return inv
end
local prototype_by_type={}
for kind,ids in pairs({container={[1]=true},["logistic-container"]={[1]=true},
  ["assembling-machine"]={[5]=true,[6]=true},car={[2]=true},character={[1]=true},
  ["item-entity"]={},["asteroid-chunk"]={},resource={},tree={},
  ["simple-entity"]={},["simple-entity-with-owner"]={}})do
  local proto={name=kind,type=kind,mineable_properties={products={}}}
  proto.get_inventory_size=function(id)if ids[id]then return 0 end end
  prototype_by_type[kind]=proto;prototypes.entity[kind]=proto
end
local serial=0
local function entity(kind,x,y,slots,owner,name)
  serial=serial+1
  local e={valid=true,type=kind,name=name or kind,unit_number=serial,
    position={x=x,y=y or 0},surface=surface,force=owner or force,
    prototype=prototype_by_type[kind],slots=slots or {}}
  e.get_inventory=function(id)return e.slots[id]end
  entities[#entities+1]=e
  return e
end
surface.find_entities_filtered=function(query)
  local types={}
  if type(query.type)=="string"then types[query.type]=true
  else for _,kind in ipairs(query.type or {})do types[kind]=true end end
  if not query.type or types.container then inventory_queries=inventory_queries+1
  elseif types["item-entity"]then ground_queries=ground_queries+1
  else resource_queries=resource_queries+1 end
  local left,right=query.area[1],query.area[2]
  local out={}
  for _,e in ipairs(entities)do
    if e.valid and e.surface==surface and (not query.force or e.force==query.force)
        and (not query.type or types[e.type])
        and e.position.x>=left[1] and e.position.x<=right[1]
        and e.position.y>=left[2] and e.position.y<=right[2] then
      out[#out+1]=e
      if query.limit and #out>=query.limit then break end
    end
  end
  return out
end
local fragments=(arg and arg[1]) or "tech-priests_src/scripts/generated"
for _,part in ipairs({"001","002","005","009","012"})do
  assert(loadfile(fragments.."/control_legacy_part_"..part..".lua"))()
end
local Economy=require("scripts.core.efficiency_economy_0587")
local Catalog=require("scripts.core.station_catalog")
assert(Economy.install())
assert(Catalog.install())
assert(require("scripts.core.resource_doctrine").install())
require("scripts.core.inventory_target_safety").install()
local function emit(name,e)
  local id=defines.events[name]
  assert(handlers[id],"missing actual membership route")({name=id,tick=game.tick,entity=e})
end
local station=entity("container",0,0,{[1]=inventory({{name="iron-plate",count=90}})})
local pair={station=station,station_unit=station.unit_number,
  priest={valid=true,name="senior-tech-priest",unit_number=9999,
    position={x=0,y=1},surface=surface,force=force}}
storage.tech_priests.pairs_by_station[station.unit_number]=pair
local chest_stock=inventory()
local chest=entity("container",4,0,{[1]=chest_stock})
local machine_stock=inventory({{name="iron-plate",count=7}})
local machine=entity("assembling-machine",8,0,{[5]=inventory(),[6]=machine_stock})
local hostile=entity("container",2,0,{[1]=inventory({{name="iron-plate",count=11}})},enemy)
local corner=entity("container",19,19,{[1]=inventory({{name="iron-plate",count=13}})})
local helper=entity("logistic-container",2,0,{[1]=inventory({{name="iron-plate",count=17}})},
  force,LOGISTIC_REQUESTER_CACHE_NAME)
local player=entity("character",2,0,{[1]=inventory({{name="iron-plate",count=19}})})
local ground=entity("item-entity",3,0)
ground.stack={valid_for_read=true,name="iron-plate",count=3}
local ore=entity("resource",9,0);ore.name="iron-ore"
local rock=entity("simple-entity",10,0);rock.name="big-rock"
rock.prototype={name="big-rock",type="simple-entity",
  mineable_properties={minable=true,products={{name="stone",type="item",amount=20}}}}
local custody={item="copper-plate",count=3}
pair.emergency_production_custody_0514=custody
local function rebuild()
  assert(tech_priests_start_emergency_operation_craft_item_0184(pair,"iron-gear-wheel"))
  assert(pair.emergency_production_custody_0514==custody,"discovery replaced held custody")
  return pair.emergency_craft.candidates
end
local function candidate(list,e,kind,item,id)
  for _,c in ipairs(list)do
    if c.entity==e and (not kind or c.kind==kind) and (not item or c.item_name==item)
        and (not id or c.inventory_id==id)then return c end
  end
end
local first=rebuild()
assert(inventory_queries==1,"fallback did not use one complete inventory seed")
assert(candidate(first,machine,"inventory","iron-plate",6),"machine output source was narrowed")
assert(candidate(first,ground,"ground") and candidate(first,ore,"resource")
  and candidate(first,rock,"mineable-entity"),"separate ground/resource/0214 paths changed")
for _,blocked in ipairs({station,hostile,corner,helper,player})do
  assert(not candidate(first,blocked,"inventory"),"live inventory eligibility widened")
end
local initial_ground,initial_resources=ground_queries,resource_queries
for i=1,60 do game.tick=i*1800;rebuild()end
assert(inventory_queries==1,"repeated emergency fallback rediscovered surrounding inventories")
assert(ground_queries>initial_ground and resource_queries>initial_resources,
  "inventory reuse suppressed independent loose/resource discovery")
chest_stock.set({{name="copper-plate",count=4,quality="rare"}})
machine_stock.set({})
local changed=rebuild()
local found=candidate(changed,chest,"inventory","copper-plate",1)
assert(found and not candidate(changed,machine,"inventory"),"same-tick stock changes stayed cached")
assert(chest_stock[1].quality=="rare" and chest_stock[1].count==4,
  "candidate discovery mutated quality or physically consumed stock")
chest.force=enemy
assert(not candidate(rebuild(),chest,"inventory"),"live force change retained source permission")
chest.force=force;chest.position={x=19,y=19}
assert(not candidate(rebuild(),chest,"inventory"),"square retained view replaced circular eligibility")
chest.position={x=4,y=0}
local added_stock=inventory({{name="iron-plate",count=5}})
local added=entity("container",5,0,{[1]=added_stock})
emit("script_raised_built",added)
assert(candidate(rebuild(),added,"inventory"),"build event did not update the existing identity owner")
emit("on_pre_player_mined_item",added)
assert(not candidate(rebuild(),added,"inventory"),"pre-removal event left a usable retained source")
added.valid=false
local car=entity("car",100,0,{[2]=inventory({{name="iron-plate",count=6}})})
vehicles={car};car.position={x=6,y=0}
assert(candidate(rebuild(),car,"inventory","iron-plate",2),"autonomous vehicle arrival was missed")
assert(inventory_queries==1,"events or vehicle arrival rediscovered inventory membership")
-- Candidate selection still calls the installed eligibility hook live. No
-- catalog quantity/role/wire policy replaces this legacy consumer's policy.
local previous_filter=is_logistic_scan_candidate_entity
is_logistic_scan_candidate_entity=function(p,e)
  return not e.fixture_blocked and previous_filter(p,e)
end
chest.fixture_blocked=true
assert(not candidate(rebuild(),chest,"inventory"),"live candidate policy was cached")
chest.fixture_blocked=false
assert(candidate(rebuild(),chest,"inventory"),"restored policy required a scan")
-- Existing physical acquisition still removes exactly one counted real item.
local physical=candidate(rebuild(),car,"inventory","iron-plate",2)
local task=pair.emergency_craft
assert(acquire_emergency_material(pair,task,physical))
assert(car.slots[2].get_item_count("iron-plate")==5 and task.gathered_units==physical.value,
  "retained membership changed the physical withdrawal contract")
assert(inventory_queries==1 and pair.emergency_production_custody_0514==custody)
print("[emergency-craft-retained-inventory] PASS full-generated-fallback 0214-0325-wrappers one-seed live-stock-force-range-policy events vehicle-arrival real-withdrawal")
