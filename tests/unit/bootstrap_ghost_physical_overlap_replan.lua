-- Lua 5.2: a real emergency miner can occupy a previously valid
-- assembler ghost. Retire that stale site only after construction returns
-- its physically carried item, then select a new legal site.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=5000}
storage={tech_priests={pairs_by_station={}}}
defines={distraction={none=0},direction={north=0}}
prototypes={entity={
  ["tech-priests-emergency-assembler"]={type="assembling-machine"}
},item={
  ["tech-priests-emergency-assembler"]={place_result={name="tech-priests-emergency-assembler"}}
}}
local force={valid=true,index=1,name="player",technologies={}}
local station={valid=true,unit_number=11,name="junior-cogitator-station",
  position={x=0,y=0},force=force}
local priest={valid=true,unit_number=12,position={x=0,y=0}}
local pair={station=station,priest=priest,station_unit=11}
storage.tech_priests.pairs_by_station[11]=pair
local area={left_top={x=0.5,y=-3.5},right_bottom={x=1.5,y=-2.5}}
local ghost={valid=true,name="entity-ghost",
  ghost_name="tech-priests-emergency-assembler",
  position={x=1,y=-3},selection_box=area,force=force,unit_number=33}
local miner={valid=true,name="tech-priests-emergency-miner",
  type="assembling-machine",position={x=1.5,y=-2.5},
  bounding_box={left_top={x=1.15,y=-2.85},
    right_bottom={x=1.85,y=-2.15}},force=force}
local passerby={valid=true,name="character",type="character",
  position={x=1,y=-3},force=force}
local surface={index=1}
station.surface=surface
ghost.surface=surface
miner.surface=surface
local newghost
surface.find_entities_filtered=function(opts)
  if opts.position then return {ghost,miner,passerby} end
  return {ghost,miner,passerby}
end
surface.create_entity=function(args)
  newghost={valid=true,name="entity-ghost",ghost_name=args.inner_name,
    position={x=args.position.x,y=args.position.y},
    force=force,surface=surface,unit_number=88}
  return newghost
end
ghost.destroy=function()
  ghost.valid=false
  return true
end
local inventory={valid=true,count=0}
inventory.insert=function(stack)
  inventory.count=inventory.count+stack.count
  return stack.count
end
local plan={stage="basic-crafting",target={
  preferred_item="tech-priests-emergency-assembler",
  fallback_item="assembling-machine-1",class="crafting",
  reason="workshop-required"}}
_G.TechPriestsMasterInfrastructurePlan0644={build_plan=function()return plan end}
_G.TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359={
  plan_site=function()return {x=8,y=0},"physically-unoccupied-workshop-site" end
}
_G.TechPriestsPlanningConstraints0646={
  entity_unlocked=function()return true end
}
local Ghosts=require("scripts.core.construction_bootstrap_ghost_planner_0645")
_G.TechPriestsConstructionBootstrapGhostPlanner0645=Ghosts
local Construction=require("scripts.core.construction_planner")
local function check(ok,reason)
  if not ok then error("bootstrap-ghost-overlap: "..reason,2) end
end
local occupied,other=Ghosts.physical_site_obstruction(pair,ghost)
check(occupied and other==miner,
  "overlapping real micro-miner not distinguished from ghosts/characters")
pair.construction_bootstrap_ghost_0645={
  ghost=ghost,entity_name="tech-priests-emergency-assembler",
  item="tech-priests-emergency-assembler",position={x=1,y=-3},
  status="ghosted",tick=4900
}
local task={phase="build",started_tick=4900,
  active_started_tick_0338=4900,
  ghost=ghost,item_name="tech-priests-emergency-assembler",
  entity_name="tech-priests-emergency-assembler",
  position={x=1,y=-3},source_entity=station,
  source_inv=inventory,carried={
    item_name="tech-priests-emergency-assembler",count=1}}
pair.construction_task_0338=task
pair.construction_custody_0338={item_name=task.item_name,count=1}
local deferred,reason=Ghosts.service_pair(pair,"while-construction-carries-device")
check(deferred==false and reason=="physical-site-overlap-awaiting-construction-custody"
    and ghost.valid,
  "planner erased a ghost while construction still held real machinery")
local construction=Construction.service_pair(pair,"blocked-at-revival")
check(construction and construction.blocked==1
    and inventory.count==1 and task.carried.count==0
    and pair.construction_task_0338==nil,
  "physically blocked revival failed to refund the exact machine item")
check(ghost.valid,"construction destroyed the ghost before safe site replan")
local replanned,detail=Ghosts.service_pair(pair,"site-no-longer-physically-legal")
check(replanned==true and newghost and newghost.valid and not ghost.valid
    and pair.construction_bootstrap_ghost_0645.position.x==8,
  "physical-overlap ghost did not replan to a different permitted site")
check(miner.valid and inventory.count==1,
  "replanning removed the working emergency miner or fabricated an assembler")

-- A task holding the obsolete ghost reference must never continue at its
-- original position after the planner has moved the site. Its removed item
-- is explicitly refunded before any later construction claim.
inventory.count=0
local old_task={phase="build",started_tick=game.tick,
  active_started_tick_0338=game.tick,
  ghost=ghost,request_field="construction_bootstrap_ghost_0645",
  item_name="tech-priests-emergency-assembler",
  entity_name="tech-priests-emergency-assembler",
  position={x=1,y=-3},source_entity=station,
  source_inv=inventory,carried={
    item_name="tech-priests-emergency-assembler",count=1}}
pair.construction_task_0338=old_task
pair.construction_custody_0338={item_name=old_task.item_name,count=1}
local obsolete=Construction.service_pair(pair,"obsolete-ghost-reference")
check(obsolete and obsolete.blocked==1 and inventory.count==1
    and pair.construction_task_0338==nil and newghost.valid,
  "superseded ghost was constructed anyway or physical item was not refunded")
check(old_task.result:find("obsolete-or-missing-bootstrap-ghost",1,true),
  "replaced ghost was not rejected by the canonical site validator")
print("[bootstrap-ghost-overlap-regression] PASS scenarios=5")
