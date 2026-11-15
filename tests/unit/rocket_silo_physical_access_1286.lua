-- Physical access to a real-sized silo and large storage must never require
-- walking into a solid center or permit remote item mutation.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}};defines={distraction={none=0}}
local force={index=1};local enemy={index=2};local surface={index=1}
local station={valid=true,name="test-station",unit_number=1,position={x=0,y=0},force=force,surface=surface,
 bounding_box={left_top={x=-2,y=-2},right_bottom={x=2,y=2}}}
local priest={valid=true,name="test-priest",unit_number=2,position={x=-10,y=0},force=force,surface=surface}
local source={valid=true,name="steel-chest",unit_number=3,position={x=6,y=0},force=force,surface=surface,
 bounding_box={left_top={x=4,y=-2},right_bottom={x=8,y=2}}}
local silo={valid=true,name="rocket-silo",type="rocket-silo",unit_number=4,position={x=20,y=0},force=force,surface=surface,
 bounding_box={left_top={x=15.5,y=-4.5},right_bottom={x=24.5,y=4.5}}}
local stock,input=10,0
local inv={valid=true,get_item_count=function()return stock end,
 remove=function(s)local n=math.min(stock,s.count);stock=stock-n;return n end,
 insert=function(s)stock=stock+s.count;return s.count end}
local targetinv={valid=true,get_item_count=function()return input end,
 can_insert=function()return true end,insert=function(s)input=input+s.count;return s.count end}
local report={silo=silo,state="manual-input-service-eligible",input_inventory=targetinv,
 item_ingredients_missing={{name="low-density-structure",missing=3}}}
TechPriestsRocketSiloReadiness0709={inspect_silo=function()return report end}
TechPriestsWorkReservations0601={categories={},release=function()return true end}
surface.can_place_entity=function(spec)
 local p=spec.position
 return not(p.x>=15.5 and p.x<=24.5 and p.y>=-4.5 and p.y<=4.5)
end
local moves={}
tech_priests_request_movement_0418=function(_,pos,reason,opts)
 assert(opts.owner=="rocket-silo-logistics-0710");moves[#moves+1]={position=pos,reason=reason};return true end
local pair={station=station,priest=priest,radius=40}
storage.tech_priests.pairs_by_station[1]=pair
local function task()
 return{family="rocket-silo-input",phase="move-to-source",target=silo,target_unit=4,target_name=silo.name,
 source_entity=source,source_inv=inv,item="low-density-structure",count=3,started_tick=game.tick}
end
local Silo=require("scripts.core.rocket_silo_logistics_0710")
pair.rocket_silo_logistics_0710=task()
assert(Silo.service_pair(pair).detail=="moving-to-source"and stock==10 and input==0)
priest.position={x=3.2,y=0}
assert(Silo.service_pair(pair).detail=="delivering-silo-input"and stock==7 and input==0
 and pair.rocket_silo_custody_0710.count==3,"large storage edge failed exact physical pickup")
local first=moves[#moves].position
assert(first.x<15.5 and first.x>=13.9 and first.y==0,"delivery routed into the solid silo center")
-- Real approach progress keeps the same contact; lateral stalls rotate it.
priest.position={x=10,y=.1};game.tick=1010;Silo.service_pair(pair)
assert(moves[#moves].position==first and input==0)
priest.position={x=10,y=-.1};game.tick=1200;Silo.service_pair(pair)
assert(moves[#moves].position~=first and input==0 and pair.rocket_silo_custody_0710.count==3)
priest.position={x=14.5,y=0}
Silo.service_pair(pair)
assert(input==3 and stock==7 and not pair.rocket_silo_custody_0710 and not pair.rocket_silo_logistics_0710,
 "standing at the native silo footprint failed exact input delivery")
-- Reloaded cargo must return to its same original large storage edge if
-- automation takes ownership; it cannot be inserted remotely or deleted.
priest.position={x=3.2,y=0};pair.rocket_silo_logistics_0710=task();Silo.service_pair(pair)
assert(stock==4 and pair.rocket_silo_custody_0710.count==3)
report.automation_owned=true;priest.position={x=12,y=0}
package.loaded["scripts.core.rocket_silo_logistics_0710"]=nil
Silo=require("scripts.core.rocket_silo_logistics_0710")
Silo.service_pair(pair)
assert(stock==4 and input==3 and pair.rocket_silo_custody_0710.count==3)
priest.position={x=3.2,y=0};Silo.service_pair(pair)
assert(stock==7 and input==3 and not pair.rocket_silo_custody_0710)
-- Reassigned targets and sources cannot borrow this force's held items.
report.automation_owned=false;pair.rocket_silo_logistics_0710=task();Silo.service_pair(pair)
silo.force=enemy;priest.position={x=14.5,y=0};Silo.service_pair(pair)
assert(input==3 and stock==4 and pair.rocket_silo_custody_0710.count==3)
priest.position={x=3.2,y=0};Silo.service_pair(pair)
assert(stock==7 and input==3 and not pair.rocket_silo_custody_0710)
silo.force=force;source.force=enemy;pair.rocket_silo_logistics_0710=task()
Silo.service_pair(pair)
assert(stock==7 and input==3 and not pair.rocket_silo_custody_0710,
 "cached foreign source was debited after reassignment")
print("PASS physical silo access, stalled contact retry, reload restitution and ownership guards")
