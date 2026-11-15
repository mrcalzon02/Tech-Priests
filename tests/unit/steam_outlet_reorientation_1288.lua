package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
defines={build_check_type={manual=1},distraction={none=0}}
local force={index=1};local surface={index=1}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,name="test-priest",unit_number=2,position={x=0,y=0},force=force,surface=surface},
 radius=20,independent_emergency_operation_0184={enabled=true},
 emergency_craft={output_item="lab",strict_recipe_0647=true,facility_only_0647=true}}
storage.tech_priests.pairs_by_station[1]=pair
local target_segment,source_segment=1,2
local function box(fluid,ports,segment)
 return{valid=true,true,get_filter=function()return fluid end,
 get_fluid_segment_contents=function()return{}end,get_fluid_segment_id=function()return segment()end,
 get_pipe_connections=function()return ports end}
end
local engine={valid=true,name="steam-engine",type="generator",unit_number=3,position={x=4.5,y=-8.5},force=force,surface=surface,
 fluidbox=box("steam",{{target_position={x=4.5,y=-5.5}}},function()return target_segment end)}
local steam={target_position={x=4.5,y=4.5}}
local water={{target_position={x=2.5,y=2.5}},{target_position={x=6.5,y=2.5}}}
local boiler={valid=true,name="boiler",type="boiler",unit_number=4,position={x=4.5,y=3},force=force,surface=surface,
 direction=8,rotatable=true,burner={remaining_burning_fuel=0},
 bounding_box={left_top={x=3,y=2},right_bottom={x=6,y=4}},selection_box={left_top={x=3,y=2},right_bottom={x=6,y=4}},
 get_fuel_inventory=function()return{valid=true,is_empty=function()return true end}end,
 get_fluid_contents=function()return{water=200}end}
boiler.fluidbox={valid=true,true,true,get_filter=function(i)return i==1 and"water"or"steam"end,
 get_fluid_segment_contents=function(i)return i==1 and{water=200}or{}end,
 get_fluid_segment_id=function()return source_segment end,
 get_pipe_connections=function(i)return i==1 and water or{steam}end}
local rotations=0
boiler.rotate=function(options)
 rotations=rotations+1;boiler.direction=(boiler.direction+(options and options.reverse and-4 or 4))%16
 return true
end
surface.can_place_entity=function(spec)
 if spec.name=="test-priest"then return true end
 local p=spec.position
 return(p.x==4.5 and p.y<=1.5)or(p.x==6.5 and p.y==3.5)
end
surface.create_entity=function()error("rotation minted a free entity")end
surface.find_entities_filtered=function(spec)
 for _,kind in ipairs(type(spec.type)=="table"and spec.type or{spec.type})do
  if kind=="boiler"then return{boiler}end
 end
 return{}
end
local Power=require("scripts.core.power_setup_1252")
Power.native_port_geometry_1288=function(_,position,direction)
 assert(direction==0)
 return position,{{x=position.x-2,y=3.5},{x=position.x+2,y=3.5}},{{x=position.x,y=1.5,dx=0,dy=-1}}
end
local proposal={tick=1000,expires_tick=2200,direction="input",fluid="steam",machine=engine,
 machine_unit=3,machine_name=engine.name,fluidbox_index=1,connection_targets={{x=4.5,y=-5.5}},
 source={entity=boiler,fluidbox_index=2,segment_id=2,interfaces={{x=4.5,y=4.5}}}}
pair.fluid_connection_proposals_0689={proposal}
TechPriestsFluidNetworkDoctrine0689={scan_pair=function()end,validate_proposal=function()return true,"valid",{tick=1000}end}
TechPriestsPlanningConstraints0646={interior_position_allowed=function()return true end}
local Planner=require("scripts.core.fluid_connection_planner_0691");TechPriestsFluidConnectionPlanner0691=Planner
Planner.refresh_pair(pair)
assert(not pair.standard_fluid_route_plan_0691 and pair.standard_fluid_route_refusal_0691.reason=="no-route",
 tostring(pair.standard_fluid_route_refusal_0691 and pair.standard_fluid_route_refusal_0691.reason))
local request=assert(pair.steam_outlet_reorientation_1288,"a proven alternate steam route was not proposed")
assert(rotations==0 and boiler.direction==8,"planning remotely rotated the machine")
local Builder=require("scripts.core.construction_planner");TechPriestsConstructionPlanner0338=Builder
local Arbiter=require("scripts.core.action_state_arbiter_0488")
assert(Arbiter.action(pair).kind=="construction","strict lab task hid its own reorientation dependency")
local move
tech_priests_request_movement_0418=function(_,position,_,options)
 assert(options.owner=="construction-planner-0338");move=position;return true end
local waiting=Builder.service_pair(pair,"native-rotation-test")
assert(waiting.detail=="approaching-native-boiler-rotation"and rotations==0 and move)
pair.priest.position=move
local completed=Builder.service_pair(pair,"native-rotation-arrival")
assert(completed.detail=="native-boiler-reoriented"and rotations==2 and boiler.direction==0
 and boiler.unit_number==4 and boiler.get_fluid_contents().water==200
 and not pair.construction_custody_0338 and not pair.construction_task_0338
 and pair.emergency_craft.output_item=="lab"and request.success)
-- A foreign active order and counted cargo must prevent new orientation work.
boiler.direction=8;pair.active_order_0469={status="active",kind="movement",source="player"}
pair.steam_outlet_reorientation_last_1288=nil;Planner.refresh_pair(pair)
assert(not pair.steam_outlet_reorientation_1288 and rotations==2)
pair.active_order_0469=nil;pair.item_family_custody_0702={count=1};Planner.refresh_pair(pair)
assert(not pair.steam_outlet_reorientation_1288 and rotations==2)
pair.item_family_custody_0702=nil;pair.independent_emergency_operation_0184.enabled=false
Planner.refresh_pair(pair)
assert(not pair.steam_outlet_reorientation_1288 and rotations==2,"maintenance mode reoriented a native machine")
pair.independent_emergency_operation_0184.enabled=true;boiler.burner.remaining_burning_fuel=100
Planner.refresh_pair(pair)
assert(not pair.steam_outlet_reorientation_1288 and rotations==2,"burning boiler was reoriented")
boiler.burner.remaining_burning_fuel=0
-- A single neutral tree at the alternative outlet is a conditional dependency,
-- never an excuse to rotate early or mine unrelated resources beyond the cap.
pair.item_family_custody_0702=nil;pair.tier="planetary-magos";pair.radius=40
boiler.position.x=30.5;boiler.bounding_box.left_top.x=29;boiler.bounding_box.right_bottom.x=32
engine.position.x=30.5;proposal.connection_targets[1].x=30.5;proposal.source.interfaces[1].x=30.5
steam.target_position.x=30.5;water[1].target_position.x=28.5;water[2].target_position.x=32.5
game.tick=2000;proposal.expires_tick=3200
local tree={valid=true,name="tree-07",type="tree",position={x=30.5,y=.3},force={name="neutral"},surface=surface,
 prototype={mineable_properties={products={{name="wood",type="item",amount=4}}}}}
local old_find=surface.find_entities_filtered
surface.find_entities_filtered=function(spec)
 if spec.type=="tree"then return tree.valid and{tree}or{}end
 if not spec.type and spec.area and tree.valid and spec.area[1][2]<=.3 and spec.area[2][2]>=.3 then return{tree}end
 return old_find(spec)
end
surface.can_place_entity=function(spec)
 if spec.name=="test-priest"then return true end
 local p=spec.position
 return(p.x==30.5 and p.y<=1.5 and not(tree.valid and p.y==.5))or(p.x==32.5 and p.y==3.5)
end
surface.get_tile=function()return{prototype={collision_mask={layers={ground_tile=true}}}}end
prototypes={entity={pipe={collision_mask={layers={water_tile=true,object=true}}}},item={wood={}}}
Planner.refresh_pair(pair)
local wooded=assert(pair.steam_outlet_reorientation_1288)
assert(wooded.clear_tree==tree and rotations==2 and not Planner.reorientation_request_valid(pair,wooded,true))
local Queue=require("scripts.core.order_queue_0469");TECH_PRIESTS_ORDER_QUEUE_0469=Queue
local Direct=require("scripts.core.direct_acquisition_executor_0513");TechPriestsDirectAcquisitionExecutor0513=Direct
local clearance=Builder.service_pair(pair,"choose-own-steam-clearance")
assert(clearance.detail=="native-steam-outlet-tree-clearance-requested"and rotations==2)
assert(Direct.target_within_bounds(pair,tree.position),"owned construction tree was stranded beyond generic hand-mining cap")
assert(not Direct.target_within_bounds(pair,{x=30.5,y=8}),"specific clearance widened unrelated ore acquisition")
local bag;local wood=0
game.create_inventory=function()
 local qty=0;bag={valid=true,get_item_count=function()return qty end,
 get_contents=function()return{{name="wood",count=qty}}end,is_empty=function()return qty==0 end}
 bag.insert=function(s)qty=qty+s.count;return s.count end
 bag.remove=function(s)local n=math.min(qty,s.count);qty=qty-n;return n end
 bag.destroy=function()assert(qty==0);bag.valid=false end;return bag
end
tree.mine=function(spec)assert(spec.inventory==bag);bag.insert{name="wood",count=4};tree.valid=false;return true end
tech_priests_stop_movement_0418=function()return true end
tech_priests_safe_deposit_item=function(_,item,n)assert(item=="wood");wood=wood+n;return true,"deposited",n end
pair.priest.position=tree.position;Direct.service_pair(pair);game.tick=2100;Direct.service_pair(pair)
assert(not tree.valid and bag.valid and pair.direct_acquisition_custody_0513.count==4 and wood==0 and rotations==2)
pair.priest.position=pair.station.position;Direct.service_pair(pair)
assert(wood==4 and not bag.valid and not pair.direct_acquisition_custody_0513 and not pair.direct_acquisition_task_0336)
Builder.service_pair(pair);pair.priest.position=move
assert(Builder.service_pair(pair).detail=="native-boiler-reoriented"and rotations==4 and boiler.direction==0)
assert(pair.emergency_craft.output_item=="lab"and boiler.unit_number==4)
print("PASS autonomous alternate-route proof, physical native boiler rotation and custody/order preservation")
