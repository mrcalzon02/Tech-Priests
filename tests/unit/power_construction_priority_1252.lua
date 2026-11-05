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
print("[power-construction-priority-1252] PASS funded ghost retained, power priority unstarted, real task not preempted, source stock unchanged")
