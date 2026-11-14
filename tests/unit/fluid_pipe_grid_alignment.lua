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
