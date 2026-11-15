package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
defines={build_check_type={manual=1}}
prototypes={item={pipe={}},entity={pipe={}}}
local force={index=1};local surface={index=1}
surface.find_entities_filtered=function()return {}end
local checks=0
surface.can_place_entity=function(spec)
 assert(spec.name=="pipe" and spec.force==force,"native method received a spurious self argument")
 assert(spec.position.x%1==.5 and spec.position.y%1==.5,"native half-tile port lattice was rounded away")
 checks=checks+1;return true
end
local machine_segment,source_segment=1,2
local box={valid=true,true,get_fluid_segment_contents=function()return {}end,
 get_fluid_segment_id=function()return machine_segment end,get_filter=function()return "steam"end}
local source_box={valid=true,true,get_fluid_segment_contents=function()return {}end,
 get_fluid_segment_id=function()return source_segment end,get_filter=function()return "steam"end}
source_box[2]=true
source_box.get_fluid_segment_contents=function(index)return index==2 and {water=100}or{}end
source_box.get_filter=function(index)return index==2 and "water"or"steam"end
source_box.get_pipe_connections=function(index)
 return {{target_position={x=2.5,y=index==2 and -2.5 or .5}}}
end
local machine={valid=true,name="steam-engine",type="generator",unit_number=3,
 position={x=8.5,y=.5},force=force,surface=surface,fluidbox=box}
local source={valid=true,name="boiler",type="boiler",unit_number=4,
 position={x=.5,y=.5},force=force,surface=surface,fluidbox=source_box}
surface.find_entities_filtered=function(spec)
 local accepts_boiler=false
 for _,kind in ipairs(spec.type or{})do if kind=="boiler"then accepts_boiler=true end end
 if not accepts_boiler then return {}end
 local area=spec.area
 if area and area[1][1]<=2.5 and area[2][1]>=2.5 then return {source}end
 return {}
end
local proposal={tick=1000,expires_tick=2000,direction="input",fluid="steam",
 machine=machine,machine_unit=3,machine_name=machine.name,fluidbox_index=1,
 connection_targets={{x=6.5,y=.5}},
 source={entity=source,fluidbox_index=1,segment_id=2,interfaces={{x=2.5,y=.5}}}}
TechPriestsFluidNetworkDoctrine0689={scan_pair=function()end,
 validate_proposal=function()return true,"valid",{tick=1000}end,
 inspect_machine=function()return {records={{index=1,requirement={name="steam"},connected=true}}}end}
TechPriestsPlanningConstraints0646={interior_position_allowed=function()return true end}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},surface=surface,force=force},
 priest={valid=true,unit_number=2},radius=30,fluid_connection_proposals_0689={proposal}}
storage.tech_priests.pairs_by_station[1]=pair
local Planner=require("scripts.core.fluid_connection_planner_0691")
Planner.refresh_pair(pair)
local plan=assert(pair.standard_fluid_route_plan_0691,
 pair.standard_fluid_route_refusal_0691 and pair.standard_fluid_route_refusal_0691.reason)
assert(checks>0 and #plan.tiles==5)
for _,tile in ipairs(plan.tiles)do assert(tile.x%1==.5 and tile.y==.5)end
assert(pair.construction_request and pair.construction_request.item_name=="pipe")
Planner.refresh_pair(pair)
assert(pair.standard_fluid_route_plan_0691==plan,"first attached pipe falsely completed disconnected route")
machine_segment=source_segment
Planner.refresh_pair(pair)
assert(not pair.standard_fluid_route_plan_0691 and plan.state=="complete",
 "real endpoint segment connection was not acknowledged")
print("PASS native bound placement call and exact half-tile pipe route")
machine_segment=1;source_segment=2
pair.construction_request=nil
source_box.get_pipe_connections=function(index)
 return{{target_position=index==2 and{x=4.5,y=1.5}or{x=2.5,y=.5}}}
end
Planner.refresh_pair(pair)
local protected=assert(pair.standard_fluid_route_plan_0691)
for _,tile in ipairs(protected.tiles)do
 assert((tile.x-4.5)^2+(tile.y-1.5)^2>1.0225,
  "steam route sealed the boiler's future physical water inlet")
end
Planner.abort_pair(pair,"test-protected-boiler-port")
pair.standard_fluid_route_reject_until_0691=nil
print("PASS steam routing preserves the boiler's distinct unbuilt water connection")
machine_segment=1;source_segment=2
surface.find_entities_filtered=function()return{}end
pair.station.position={x=32,y=-32};pair.radius=40
machine.name="boiler";machine.type="boiler";machine.position={x=18.5,y=-61}
source.name="offshore-pump";source.type="offshore-pump";source.position={x=18.5,y=-67.5}
source_box[2]=nil
source_box.get_filter=function()return"water"end
source_box.get_fluid_segment_contents=function()return{water=100}end
source_box.get_pipe_connections=function()return{{target_position={x=17.5,y=-67.5}}}end
box.get_filter=function()return"water"end
proposal.fluid="water";proposal.connection_targets={{x=20.5,y=-60.5}}
proposal.source.interfaces={{x=17.5,y=-67.5}}
TechPriestsPlanningConstraints0646.interior_position_allowed=function(p,pos,margin)
 return (pos.x-32)^2+(pos.y+32)^2<=(40-margin)^2
end
pair.standard_fluid_route_reject_until_0691=nil;pair.construction_request=nil
Planner.refresh_pair(pair)
local shoreline=assert(pair.standard_fluid_route_plan_0691,
 "real shoreline pump outlet was blocked by the ordinary interior inset")
local found=false
for _,tile in ipairs(shoreline.tiles)do
 if tile.x==17.5 and tile.y==-67.5 then found=true
 else assert((tile.x-32)^2+(tile.y+32)^2<=37.5^2,"route interior escaped its normal inset")end
end
assert(found,"shoreline route omitted the exact physical pump outlet")
Planner.abort_pair(pair,"test-endpoint-domain-refusal")
pair.standard_fluid_route_reject_until_0691=nil;source.force={index=99}
Planner.refresh_pair(pair)
assert(not pair.standard_fluid_route_plan_0691,"foreign pump received shoreline endpoint allowance")
print("PASS exact same-force shoreline outlet fits native territory; route interior and foreign sources stay constrained")
