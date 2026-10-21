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
  ghost=ghost,request_field="construction_bootstrap_ghost_0645",
  item_name="tech-priests-emergency-assembler",
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
pair.construction_candidate_0338={
  request_field="construction_bootstrap_ghost_0645",
  entity_name="tech-priests-emergency-assembler",
  position={x=1,y=-3},ghost=ghost,item_name="tech-priests-emergency-assembler"}
local construction=Construction.service_pair(pair,"blocked-at-revival")
check(construction and construction.blocked==1
    and inventory.count==1 and task.carried.count==0
    and pair.construction_task_0338==nil,
  "physically blocked revival failed to refund the exact machine item")
check(newghost and newghost.valid and not ghost.valid
    and pair.construction_bootstrap_ghost_0645.position.x==8,
  "physical-overlap ghost did not replan to a different permitted site")
check(miner.valid and inventory.count==1,
  "replanning removed the working emergency miner or fabricated an assembler")
check(pair.construction_candidate_0338==nil,
  "old construction discovery candidate kept targeting the obstructed ghost")

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
-- An obsolete mining/workshop ghost must not keep an already crafted
-- real laboratory from reaching the construction planner. Supersede only
-- when the replacement is physically present in general storage, and no
-- construction task owns the previous ghost or any carried material.
do
  local lab="tech-priests-emergency-laboratorium"
  prototypes.entity[lab]={type="lab"}
  prototypes.item[lab]={place_result={name=lab}}
  local current=newghost
  current.destroy=function()
    current.valid=false
    return true
  end
  local previous_item="tech-priests-emergency-assembler"
  plan={stage="research-readiness",target={
    preferred_item=lab,class="research",reason="laboratory-ready"}}
  local remaining={[lab]=1}
  _G.TechPriestsStorageRoleAuthority0686={
    generic_item_count=function(_,item)return remaining[item] or 0 end}
  pair.construction_candidate_0338={
    request_field="construction_bootstrap_ghost_0645",
    entity_name=previous_item,position={x=8,y=0},
    item_name=previous_item}
  game.tick=game.tick+150
  local changed,why=Ghosts.service_pair(pair,"genuine-laboratory-ready")
  local new_record=pair.construction_bootstrap_ghost_0645
  check(changed and why and current.valid==false and new_record
      and new_record.entity_name==lab and new_record.ghost.valid
      and new_record.ghost.ghost_name==lab
      and pair.construction_candidate_0338==nil
      and remaining[lab]==1,
    "stocked real laboratory did not supersede stale unclaimed workshop ghost"..
      " accepted="..tostring(changed).." reason="..tostring(why)..
      " current_valid="..tostring(current.valid)..
      " new_record="..tostring(new_record and new_record.entity_name)..
      " new_ghost="..tostring(new_record and new_record.ghost and new_record.ghost.ghost_name)..
      " candidate="..tostring(pair.construction_candidate_0338 and pair.construction_candidate_0338.entity_name)..
      " laboratory_stock="..tostring(remaining[lab]))
  -- A held construction item keeps its original reservation. No live ghost
  -- can be retired or replaced merely because the master plan changes.
  local lab_ghost=new_record.ghost
  local ref=new_record
  plan={stage="basic-crafting",target={
    preferred_item=previous_item,class="crafting",reason="workshop-required"}}
  remaining[previous_item]=1
  pair.construction_task_0338={phase="build"}
  pair.construction_custody_0338={item_name=lab,count=1}
  local accepted,blocked=Ghosts.service_pair(pair,"held-laboratory-custody")
  check(not accepted and blocked=="active-ghost-present"
      and pair.construction_bootstrap_ghost_0645==ref
      and lab_ghost.valid and remaining[lab]==1,
    "construction custody was discarded to supersede a live laboratory ghost")
  pair.construction_task_0338=nil
  pair.construction_custody_0338=nil
  _G.TechPriestsStorageRoleAuthority0686=nil
end

print("[bootstrap-ghost-overlap-regression] PASS scenarios=9")
