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
