-- Power infrastructure must win UNSTARTED construction discovery from a
-- ghost, not erase ghost state or interrupt any genuine 0338 cargo.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=15000}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1}}
local force={index=1,name="player"}
local surface={index=1}
local station={valid=true,name="planetary-magos-cogitator-station",
 unit_number=20,position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=21,position={x=1,y=0},
 force=force,surface=surface}
local chest={valid=true,unit_number=24,name="steel-chest",type="container",
 position={x=-20,y=0},force=force,surface=surface}
local stored={["tech-priests-emergency-miner"]=1,boiler=2}
local inventory={valid=true,get_item_count=function(item)
 return stored[item]or 0 end}
local source={inv=inventory,entity=chest,source="nearby"}
_G.TechPriestsStorageRoleAuthority0686={
 generic_storage_sources=function()return{source}end,
 generic_station_inventories=function()return{}end,
}
local ghost={valid=true,name="entity-ghost",
 ghost_name="tech-priests-emergency-miner",
 position={x=11,y=0},force=force,surface=surface}
surface.find_entity=function()return ghost end
surface.can_place_entity=function()return true end
prototypes={item={
 ["tech-priests-emergency-miner"]={
  place_result={name="tech-priests-emergency-miner"}},
 boiler={place_result={name="boiler"}},
},entity={
 ["tech-priests-emergency-miner"]={type="assembling-machine"},
 boiler={type="boiler"},
}}
local pair={station=station,priest=priest,station_unit=20}
storage.tech_priests.pairs_by_station[20]=pair
local bootstrap={item="tech-priests-emergency-miner",
 entity_name="tech-priests-emergency-miner",position={x=11,y=0},
 ghost=ghost,status="ghosted"}
local power={owner="power-setup-1252",item_name="boiler",
 entity_name="boiler",position={x=-12,y=0},
 site_reason="physical-steam-power-1252:heat-water"}
pair.construction_bootstrap_ghost_0645=bootstrap
pair.structure_construction_requested_item=power
_G.TechPriestsWorkReservations0601={
 categories={},
 root=function()return{reservations={}}end,
 claim=function()return true,"owned-construction-position"end,
 release=function()return true end,
}
_G.tech_priests_request_movement_0418=function()return true end
local Builder=require("scripts.core.construction_planner")
local candidate=Builder.discover_pair(pair,true)
assert(candidate and candidate.item_name=="boiler"
 and candidate.request_value==power
 and candidate.request_field=="structure_construction_requested_item"
 and candidate.position.x==-12
 and pair.construction_bootstrap_ghost_0645==bootstrap
 and bootstrap.status=="ghosted"
 and stored.boiler==2
 and stored["tech-priests-emergency-miner"]==1
 and pair.construction_task_0338==nil
 and pair.construction_custody_0338==nil,
 "funded bootstrap ghost monopolized physical power construction request")
local original=candidate
pair.construction_task_0338={item_name="stone-furnace",phase="move-source"}
local untouched=Builder.discover_pair(pair,true)
assert(untouched==original and pair.construction_task_0338.phase=="move-source"
 and pair.construction_bootstrap_ghost_0645==bootstrap
 and stored.boiler==2,
 "power construction preempted an active 0338 physical task")
pair.construction_task_0338=nil
-- The dispatcher may have cached an old funded ghost BEFORE the new
-- electricity requirement was discovered. Only this UNSTARTED candidate
-- may be retired. Its ghost and physical stock remain intact.
pair.construction_candidate_0338={
 item_name="tech-priests-emergency-miner",
 request_value=bootstrap,position=bootstrap.position,
 request_field="construction_bootstrap_ghost_0645",
}
local plan=Builder.service_pair(pair,"power-priority-candidate")
assert(pair.construction_task_0338
 and pair.construction_task_0338.item_name=="boiler"
 and pair.construction_task_0338.request_value==power
 and stored.boiler==2
 and stored["tech-priests-emergency-miner"]==1
 and pair.construction_bootstrap_ghost_0645==bootstrap,
 "cached funded ghost stole the staged real boiler or erased physical stock")
-- 1258: a source-confirmed real pipe route must beat a stocked but UNSTARTED
-- emergency ghost. A mismatched/stale plan may not claim that priority.
pair.construction_task_0338=nil
pair.construction_custody_0338=nil
pair.structure_construction_requested_item=nil
pair.construction_candidate_0338=nil
stored.pipe=5
prototypes.item.pipe={place_result={name="pipe"}}
prototypes.entity.pipe={type="pipe"}
local steam_machine={valid=true,unit_number=50,
 name="boiler",force=force,surface=surface}
local water_source={valid=true,unit_number=51,
 name="offshore-pump",force=force,surface=surface}
local route={id="station20-water-1258",state="construction-requested",
 direction="input",machine=steam_machine,remote={entity=water_source},
 current_index=1,tiles={{x=-8,y=2}}}
pair.standard_fluid_route_plan_0691=route
local pipe={item_name="pipe",entity_name="pipe",
 source="standard-fluid-route-0691",route_plan_id=route.id,
 route_direction="input",route_index=1,
 position={x=-8,y=2}}
pair.construction_request=pipe
local ready=Builder.discover_pair(pair,true)
assert(ready and ready.request_field=="construction_request"
 and ready.request_value==pipe and ready.item_name=="pipe"
 and ready.position.x==-8 and ready.position.y==2
 and stored.pipe==5 and stored["tech-priests-emergency-miner"]==1,
 "genuine funded steam pipe request lost to an unstarted stocked ghost")
-- Invalid route ID is not the owner and must never gain priority.
pair.construction_candidate_0338=nil
pipe.route_plan_id="foreign-mismatched"
local spoof=Builder.discover_pair(pair,true)
assert(spoof and spoof.request_value==bootstrap
 and stored.pipe==5 and not pair.construction_task_0338,
 "foreign pipe route illegally displaced the original funded ghost")
pipe.route_plan_id=route.id
-- Even a cached funded ghost candidate does not own actual material or a
-- physical transaction until original 0338 starts. Rebuild discovery safely.
pair.construction_candidate_0338={item_name=bootstrap.item,
 request_value=bootstrap,request_field="construction_bootstrap_ghost_0645",
 position=bootstrap.position}
local pipe_work=Builder.service_pair(pair,"steam-pipe-priority-1258")
assert(pair.construction_task_0338
 and pair.construction_task_0338.item_name=="pipe"
 and pair.construction_task_0338.request_value==pipe
 and pair.construction_bootstrap_ghost_0645==bootstrap
 and pair.construction_request==pipe
 and stored.pipe==5,
 "cached ghost seized funded fluid-pipe construction or spent uncarried stock")
print("[power-construction-priority-1252] PASS power and native-pipe priority, exact route ID, funded ghost retention, no ownership theft or free stock")
