-- Behavioral regression: reach large storage physically and fetch the whole
-- outstanding recipe dependency, without touching another force or cargo owner.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Fetch=require("scripts.core.logistics_fetch_executor_0527")
defines={inventory={chest=1},distraction={none=0}}
game={tick=1000}
storage={tech_priests={}}
local force={name="tp-arena-2",index=2}
local surface={index=1}
TechPriestsScanRouting0610={find_entities=function(sf,filters)
  return sf.find_entities_filtered(filters)
end}
local source_count,station_count=20,0
local source_inv={valid=true,get_item_count=function()return source_count end,
  remove=function(stack) local n=math.min(source_count,stack.count)
    source_count=source_count-n;return n end}
local station_inv={valid=true,get_item_count=function()return station_count end,
  insert=function(stack)station_count=station_count+stack.count;return stack.count end}
local source={valid=true,name="large-storage",type="container",unit_number=3,
  position={x=10,y=0},surface=surface,force=force,
  bounding_box={left_top={x=7.8,y=-1.9},right_bottom={x=12.2,y=1.9}},
  get_inventory=function()return source_inv end}
surface.find_entities_filtered=function()return {source}end
local pair={station={valid=true,unit_number=1,position={x=0,y=0},
  force=force,surface=surface,get_inventory=function()return station_inv end},
  priest={valid=true,unit_number=2,position={x=0,y=0},force=force},
  requested_item="stone",logistic_requested_item="stone",logistic_requested_count=5,
  infrastructure_recipe_request_0647={item="stone-furnace",missing="stone",
    ingredients={{name="stone",count=5}}}}
local moves=0
tech_priests_request_movement_0418=function(p,pos,reason,opts)
  moves=moves+1
  assert(pos.x==7.8 and pos.y==0,"fetch still targets solid storage center")
  p.movement_request_0418={owner=opts.owner,reason=reason,x=pos.x,y=pos.y}
  return true
end
local acted,why=Fetch.service_pair(pair)
assert(acted and why=="moving-to-known-source" and moves==1,tostring(why))
assert(source_count==20 and station_count==0,"removed cargo before arrival")
-- The center is 3.5 tiles away, but the actual inventory edge is reachable.
pair.priest.position={x=6.5,y=0};game.tick=1005
acted,why=Fetch.service_pair(pair)
assert(acted and why=="fetched-known-source")
assert(source_count==15 and station_count==5,"recipe quantity was reduced to one")
assert(pair.logistics_fetch_0527.requested==5)
acted,why=Fetch.service_pair(pair)
assert(not acted and why=="already-in-station")
assert(source_count+station_count==20,"inventory conservation failed")
-- Partial prior stock must reduce the debit, and the recipe remains the
-- quantity authority when the compatibility count field is absent.
station_count=2;source_count=18;pair.logistic_requested_count=nil
game.tick=1010
acted,why=Fetch.service_pair(pair)
assert(acted and station_count==5 and source_count==15)
source.force={name="foreign",index=4};station_count=0;game.tick=1020
acted,why=Fetch.service_pair(pair)
assert(not acted and why=="no-known-fetch-source" and source_count==15)
source.force=force;pair.combat_target={valid=true};game.tick=1030
acted,why=Fetch.service_pair(pair)
assert(not acted and why=="combat-has-priority" and source_count==15)
-- Point-like sources preserve the ordinary center-based approach.
source.bounding_box=nil
local point=Fetch.pickup_position(pair,source)
assert(point==source.position)
print("PASS large storage reach, recipe count, partial stock, foreign force and combat priority")
pair.combat_target=nil;source_count=2;station_count=0
pair.logistic_requested_count=3
pair.infrastructure_recipe_request_0647.ingredients={{name="stone",count=3}}
TechPriestsStorageRoleAuthority0686={generic_item_count=function()return source_count+station_count end,
 generic_storage_sources=function()return{{entity=source,inv=source_inv},{entity=pair.station,inv=station_inv}}end}
pair.priest.position={x=10,y=0};game.tick=2000
acted,why=Fetch.service_pair(pair)
assert(not acted and why=="no-known-fetch-source"and source_count==2 and station_count==0,
 "counted partial stock was repeatedly rearranged to fill an impossible total-stock deficit")
local extra=1
local outside={valid=true,name="outside-storage",type="container",unit_number=4,
 position={x=10,y=0},surface=surface,force=force,
 get_inventory=function()return{valid=true,get_item_count=function()return extra end,
 remove=function(stack)local n=math.min(extra,stack.count);extra=extra-n;return n end}end}
surface.find_entities_filtered=function()return{source,outside}end
game.tick=2010;acted,why=Fetch.service_pair(pair)
assert(acted and why=="fetched-known-source"and extra==0 and source_count==2 and station_count==1,
 "excluding counted stock concealed a genuine uncounted source or changed its paid quantity")
print("PASS counted partial sources yield to production; genuinely new stock still fills the exact deficit")
station_count=0;source_count=2;extra=0
local wrapper={__eq=function(a,b)return a.native_id==b.native_id end}
source.get_inventory=function()return setmetatable({valid=true,native_id=7,
 get_item_count=function()return source_count end,
 remove=function(stack)source_count=source_count-stack.count;return stack.count end},wrapper)end
local stored,current=source.get_inventory(),source.get_inventory()
assert(stored==current and ({[stored]=true})[current]==nil,
 "fixture must reproduce native equality without raw table-key identity")
TechPriestsStorageRoleAuthority0686.generic_storage_sources=function()return{{inv=stored}}end
game.tick=2020;acted,why=Fetch.service_pair(pair)
assert(not acted and why=="no-known-fetch-source"and source_count==2,
 "equal native inventory wrappers were mistaken for uncounted physical stock")
print("PASS native inventory equality is distinct from raw Lua table-key identity")
