-- 1200: genuine midgame 1197 saw three *stocked* stone-furnace
-- bootstrap ghosts but zero 0338 tasks through tick 216000. Distinct
-- Factorio LuaInventory objects may stringify identically; presentation
-- text is not a physical inventory identity.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=9000}
storage={tech_priests={pairs_by_station={}}}
defines={distraction={none=0}}
local Builder=require("scripts.core.construction_planner")
local surface={index=1}
local force={index=1,name="player"}
local station={valid=true,unit_number=31,name="junior-cogitator-station",
 position={x=0,y=0},surface=surface,force=force}
local priest={valid=true,unit_number=32,position={x=0,y=1},
 surface=surface,force=force}
local c1={valid=true,unit_number=41,name="steel-chest",
 type="container",position={x=4,y=0},surface=surface,force=force}
local c2={valid=true,unit_number=42,name="steel-chest",
 type="container",position={x=8,y=0},surface=surface,force=force}
local contents=1
local inventory_mt={__tostring=function() return "LuaInventory" end}
local function mock_inventory(read)
 return setmetatable({valid=true,
  get_item_count=function(item) return item=="stone-furnace" and read() or 0 end,
  remove=function(stack)
   if stack.name~="stone-furnace" then return 0 end
   local n=math.min(contents,stack.count);contents=contents-n
   return n
  end,
  insert=function(stack)
   if stack.name~="stone-furnace" then return 0 end
   contents=contents+stack.count;return stack.count
  end,
 },inventory_mt)
end
local station_inv=mock_inventory(function()return 0 end)
local empty_inv=mock_inventory(function()return 0 end)
local stocked_inv=mock_inventory(function()return contents end)
assert(tostring(station_inv)==tostring(empty_inv)
 and tostring(empty_inv)==tostring(stocked_inv),
 "regression requires identical diagnostic inventory strings")
local station_source={entity=station,inv=station_inv,source="station-container"}
local empty_source={entity=c1,inv=empty_inv,source="nearby"}
local stocked_source={entity=c2,inv=stocked_inv,source="nearby"}
_G.TechPriestsStorageRoleAuthority0686={
 generic_station_inventories=function(pair)
  return {station_source}
 end,
 generic_storage_sources=function(pair)
  return {station_source,empty_source,stocked_source,stocked_source}
 end,
}
local steward_calls=0
_G.tech_priests_inventory_steward_sources_for_pair=function(pair)
 steward_calls=steward_calls+1
 error("read-only 0338 discovery must use the canonical 0686 source survey")
end
local pair={station=station,priest=priest,station_unit=31,mode="idle"}
storage.tech_priests.pairs_by_station[31]=pair
local candidate={item_name="stone-furnace",entity_name="stone-furnace",
 position={x=18,y=0},site_reason="bootstrap-ghost",
 request_field="construction_bootstrap_ghost_0645"}
pair.construction_candidate_0338=candidate
local action=Builder.recommend_action(pair)
assert(action and action.kind=="construction"
 and action.item=="stone-furnace" and action.position==candidate.position,
 "physically stocked chest vanished because inventories stringify identically")
assert(contents==1 and pair.construction_task_0338==nil
 and pair.construction_custody_0338==nil and steward_calls==0,
 "read-only construction recommendation fabricated stock or called the steward")
contents=0
assert(Builder.recommend_action(pair)==nil,
 "empty candidate acquired construction priority without physical material")
contents=1
-- The executor must also discover the *real* stocked chest for its
-- waiting-source task: recommendation alone is not inventory custody.
local task={phase="waiting-source",started_tick=game.tick,
 item_name="stone-furnace",entity_name="stone-furnace",
 position=candidate.position,request_field=candidate.request_field}
pair.construction_task_0338=task
local routes={}
_G.tech_priests_request_movement_0418=function(_,position,reason,options)
 routes[#routes+1]={position=position,reason=reason,owner=options.owner}
 return true
end
local result=Builder.service_pair(pair,"inventory-identity-regression")
assert(result and result.detail=="moving-source"
 and task.source_entity==c2 and task.source_inv==stocked_inv
 and contents==1 and #routes==1,
 "0338 failed to select a genuine physical stocked source before movement")
priest.position={x=8,y=0}
game.tick=9001
Builder.service_pair(pair,"inventory-identity-real-pickup")
assert(contents==0
 and pair.construction_custody_0338
 and pair.construction_custody_0338.item_name=="stone-furnace"
 and pair.construction_custody_0338.count==1,
 "0338 failed to debit exactly one real furnace from the identified chest")
assert(steward_calls==0,"physical pickup invoked unrelated legacy steward")
print("[construction-distinct-inventory-sources-1200] PASS canonical 0686 crates, read-only survey, distinct physical chests, real pickup and zero fabrication")
