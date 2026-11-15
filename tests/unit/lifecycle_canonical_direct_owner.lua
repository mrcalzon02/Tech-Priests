package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
defines={command={stop=1,go_to_location=2},distraction={none=0}}
TechPriestsPairBucketRegistry0600={force_bucket=function()end}
local force,surface={index=1},{index=1}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=2,position={x=0,y=0},force=force,surface=surface,commandable={valid=true,set_command=function()end}},radius=40}
local strict={strict_recipe_0647=true,output_item="stone-brick",current={entity={valid=true,position={x=-20,y=0}}}}
local child={current={entity={valid=true,position={x=20,y=0}}},output_item="stone",required_count=6,gathered_units=5}
pair.emergency_craft=strict;pair.direct_acquisition_task_0336=child
local order={status="active",kind="crafting",task=strict};pair.order_queue_0469={current=order}
TechPriestsDirectAcquisitionExecutor0513={current_direct_task=function(p)return p.direct_acquisition_task_0336 end}
local Movement=require("scripts.core.movement_controller");TECH_PRIESTS_MOVEMENT_CONTROLLER_0418=Movement
assert(Movement.request(pair,{x=-20,y=0},"obsolete-alias",{owner="task-lifecycle-0478",priority=660,ttl=480}))
local Lifecycle=require("scripts.core.task_lifecycle_authority_0478")
local _,why=Lifecycle.service_pair(pair)
assert(why=="canonical-direct-owner"and not pair.movement_request_0418,
 "legacy target movement still blocked the canonical raw-material child")
assert(pair.emergency_craft==strict and pair.direct_acquisition_task_0336==child and pair.order_queue_0469.current==order,
 "lifecycle handoff destroyed the parent, child or original order")
game.tick=1005
assert(Movement.request(pair,{x=20,y=0},"real-stone",{owner="direct-acquisition-0513",priority=650,ttl=600}))
local request=pair.movement_request_0418
Lifecycle.service_pair(pair)
assert(pair.movement_request_0418==request and child.gathered_units==5,
 "lifecycle stopped foreign movement or credited unmined stone")
pair.direct_acquisition_task_0336=nil
TechPriestsEmergencyProductionExecutor0514={service_pair=function()end}
Movement.stop(pair,"test-return")
assert(Movement.request(pair,{x=-20,y=0},"obsolete-alias",{owner="task-lifecycle-0478",priority=660,ttl=480}))
local _,production_why=Lifecycle.service_pair(pair)
assert(production_why=="canonical-production-owner"and not pair.movement_request_0418,
 "legacy parent alias resumed after the physical material child completed")
assert(pair.emergency_craft==strict and pair.order_queue_0469.current==order,
 "lifecycle prematurely completed strict production from partial target stock")
print("PASS lifecycle yields stale parent aliases to canonical mining and strict production owners")
local legacy_moves=0
tech_priests_0312_service_direct_current=function()legacy_moves=legacy_moves+1;return true end
strict.current={kind="direct-mine-0273",entity={valid=true,position={x=20,y=0}}}
local Direct=require("scripts.core.direct_acquisition_executor_0513")
assert(Direct.install())
tech_priests_0312_service_direct_current(pair,strict)
assert(legacy_moves==0 and pair.emergency_craft==strict,
 "stale strict-recipe mining child moved the priest away from canonical crafting")
pair.emergency_craft=nil
tech_priests_0312_service_direct_current(pair,{})
assert(legacy_moves==1,"strict recipe protection disabled unrelated legacy work")
pair.emergency_craft=strict;strict.strict_recipe_0647=nil;strict.facility_only_0647=true
assert(Direct.current_direct_task(pair)==nil,
 "a furnace recipe's obsolete legacy child displaced its explicit raw-material task")
tech_priests_0312_service_direct_current(pair,strict)
assert(legacy_moves==1,"legacy mining hijacked an owned furnace recipe")
local _,facility_why=Lifecycle.service_pair(pair)
assert(facility_why=="canonical-production-owner","legacy lifecycle retained furnace recipe ownership")
print("PASS legacy mining cannot hijack an active canonical strict recipe")
