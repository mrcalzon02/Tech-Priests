-- Lua 5.2 integration regression: a standard furnace must be fueled and
-- supplied from the stone-cache stock that the bootstrap governor counts.
-- The Cogitator machine's recipe, fuel and result inventories are not stock.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1500}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1,character_main=2,assembling_machine_input=3,
  assembling_machine_output=4,furnace_source=5,furnace_result=6,
  fuel=7,burnt_result=8}}
prototypes={item={coal={},["iron-ore"]={},["iron-plate"]={}},
  recipe={}}
local function check(ok,why)
 if not ok then error("stone-cache-bootstrap-feeding: "..why,2)end
end
local function inventory(initial,capacity)
 local items=initial or {}
 local i={valid=true,items=items,capacity=capacity or 100}
 i.get_item_count=function(name)return items[name]or 0 end
 i.can_insert=function(stack)
  local total=0;for _,n in pairs(items)do total=total+n end
  return total+stack.count<=i.capacity
 end
 i.insert=function(stack)
  if i.block_refund then return 0 end
  local total=0;for _,n in pairs(items)do total=total+n end
  local n=math.max(0,math.min(i.capacity-total,stack.count))
  if i.partial then n=math.min(n,i.partial)end
  items[stack.name]=(items[stack.name]or 0)+n;return n
 end
 i.remove=function(stack)
  local n=math.min(items[stack.name]or 0,stack.count)
  items[stack.name]=(items[stack.name]or 0)-n;return n
 end
 return i
end
local surface={index=1}
local force={index=1}
local station_chest=inventory({coal=1})
local station_recipe_input=inventory({coal=25,["iron-ore"]=25})
local station_recipe_output=inventory({["iron-plate"]=25})
local cache_inventory=inventory({coal=4,["iron-ore"]=4})
local fuel=inventory({},8)
local furnace_input=inventory({},8)
local station={valid=true,unit_number=10,name="junior-cogitator-station",
  position={x=0,y=0},surface=surface,force=force}
station.get_inventory=function(id)
 if id==defines.inventory.chest then return station_chest end
 if id==defines.inventory.assembling_machine_input then return station_recipe_input end
 if id==defines.inventory.assembling_machine_output then return station_recipe_output end
end
local cache={valid=true,unit_number=11,name="tech-priests-martian-stone-cache",
 type="container",position={x=2,y=2},surface=surface,force=force}
cache.get_inventory=function(id)
 if id==defines.inventory.chest then return cache_inventory end
end
local furnace={valid=true,unit_number=12,name="stone-furnace",type="furnace",
 position={x=3,y=0},surface=surface,force=force}
furnace.get_inventory=function(id)
 if id==defines.inventory.fuel then return fuel end
 if id==defines.inventory.furnace_source then return furnace_input end
end
local resources={}
for n,name in ipairs({"coal","iron-ore","copper-ore"})do
 resources[name]={valid=true,name=name,type="resource",amount=100,
  surface=surface,force=force,position={x=n*3,y=4}}
end
surface.find_entities_filtered=function(options)
 if options.type=="resource" then return {resources[options.name]} end
 if type(options.type)=="table" then return {furnace} end
 return {furnace}
end
local pair={station=station,station_unit=10,radius=24,
 priest={valid=true,unit_number=20,surface=surface,force=force,
  name="tech-priest",position={x=0,y=0}},
 mode="infrastructure-first-0643",
 emergency_craft={output_item="iron-plate",facility_only_0647=true},
 local_infrastructure_gate_0640={item="iron-plate",state="waiting-recipe-material"}}
storage.tech_priests.pairs_by_station[10]=pair
local calls={counts=0,sources=0}
_G.TechPriestsStorageRoleAuthority0686={
 generic_item_count=function(_,item)
  calls.counts=calls.counts+1
  return cache_inventory.get_item_count(item)+station_chest.get_item_count(item)
 end,
 generic_storage_sources=function()
  calls.sources=calls.sources+1
  -- Station is intentionally first: feeder must prefer actual stone cache.
  return {{entity=station,inv=station_chest},
    {entity=cache,inv=cache_inventory}}
 end,
}
package.loaded["scripts.core.direct_acquisition_executor_0513"]={
 service_pair=function()return true end}
local Governor=require("scripts.core.bootstrap_resource_governor_0637")
local Facility=require("scripts.core.emergency_facility_doctrine")
Governor.root().enabled=true
check(Facility.tag_built_entity(pair,furnace,"regression"),
 "real furnace was not tagged as owned physical production machinery")
local assigned,why=Governor.service_pair(pair,"cache-stock-before-mining")
check(assigned==false and why=="infrastructure-prerequisite-priority"
  and not pair.direct_acquisition_task_0336,
 "governor ignored available stone-cache fuel and ore and mined unnecessarily")
check(calls.counts>0,"authoritative stock count was not consulted")
local serviced,detail=Facility.service_pair(pair,"dispatcher-0514")
check(serviced==true and detail=="used-owned-facilities",
 "real furnace with managed raw stock did not run facility feeder")
check(fuel.get_item_count("coal")==2 and
  furnace_input.get_item_count("iron-ore")==4,
 "cache-backed coal/ore did not enter physical furnace inventory")
check(cache_inventory.get_item_count("coal")==2 and
  cache_inventory.get_item_count("iron-ore")==0,
 "stone-cache withdrawal did not conserve exact material counts")
check(station_chest.get_item_count("coal")==1,
 "feeder consumed Cogitator reserve while a stone cache had stock")
check(station_recipe_input.get_item_count("coal")==25 and
  station_recipe_input.get_item_count("iron-ore")==25 and
  station_recipe_output.get_item_count("iron-plate")==25,
 "Cogitator machine recipe/result inventories were treated as general storage")
check(pair.emergency_facility_feed_custody_0357==nil,
 "successful cache-fed furnace retained spurious material custody")

-- When managed storage is genuinely empty, unrelated Cogitator recipe
-- input is not fuel stock and the governor must request physical coal.
cache_inventory.items.coal=0
station_chest.items.coal=0
fuel.items.coal=0
pair.direct_acquisition_task_0336=nil
pair.mode="infrastructure-first-0643"
local fetching=Governor.service_pair(pair,"cache-fuel-exhausted")
check(fetching==true and pair.direct_acquisition_task_0336 and
  pair.direct_acquisition_task_0336.output_item=="coal",
 "governor falsely considered the station recipe input an available coal reserve")
check(fuel.get_item_count("coal")==0,
 "furnace received nonexistent fuel without a real stock debit")
print("[stone-cache-bootstrap-feeding] PASS scenarios=5")
