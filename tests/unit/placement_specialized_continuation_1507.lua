-- Real 0359/0338/0645 integration for resource and defense continuations.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100};storage={tech_priests={pairs_by_station={}}}
defines={direction={north=0},distraction={none=0}}
local Queue=require("scripts.core.force_planning_queue")
local Site=require("scripts.core.construction_site_planner")
local Builder=require("scripts.core.construction_planner")
local Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
local calls,stock,claims,created=0,1,0,0
local types={['gun-turret']='ammo-turret',['burner-mining-drill']='mining-drill'}
prototypes={entity={},item={}}
for name,kind in pairs(types)do
 prototypes.entity[name]={type=kind,collision_box={{-.9,-.9},{.9,.9}}}
 prototypes.item[name]={place_result={name=name}}
end
_G.TechPriestsPlanningConstraints0646={entity_unlocked=function()return true end,
 interior_position_allowed=function()return true end}
_G.TechPriestsScanRouting0610={find_entities=function()error("specialized planning used broad routed query")end}
_G.TechPriestsWorkReservations0601={categories={},root=function()return {reservations={}}end,
 claim=function()claims=claims+1;return true end,release=function()return true end}
local force={valid=true,index=1,name="player",technologies={},recipes={}}
local enemy={valid=true,index=2,name="enemy"}
force.is_enemy=function(other)return other==enemy end
local surface={index=1,valid=true}
local entities={}
local function matches(value,wanted)
 if wanted==nil then return true end
 if type(wanted)~="table"then return value==wanted end
 for _,v in ipairs(wanted)do if v==value then return true end end
 return false
end
surface.find_entities_filtered=function(filter)
 calls=calls+1
 if filter.area then
  local a,b=filter.area[1],filter.area[2]
  assert(b[1]-a[1]<=8 and b[2]-a[2]<=8,
    "specialized worker issued a broad native area query")
 end
 local out={}
 for _,entity in ipairs(entities)do
  local pos=entity.position
  local okay=entity.valid and matches(entity.type,filter.type)
    and matches(entity.name,filter.name) and (not filter.force or entity.force==filter.force)
  if okay and filter.area then
   local a,b=filter.area[1],filter.area[2]
   okay=pos.x>=a[1] and pos.x<=b[1] and pos.y>=a[2] and pos.y<=b[2]
  end
  if okay and filter.position then
   local dx,dy=pos.x-filter.position.x,pos.y-filter.position.y
   okay=dx*dx+dy*dy<=(filter.radius or .01)^2
  end
  if okay then out[#out+1]=entity end
  if filter.limit and #out>=filter.limit then break end
 end
 return out
end
surface.can_place_entity=function(args)
 calls=calls+1
 for _,entity in ipairs(entities)do
  if entity.valid and entity.type~="resource"
   and math.abs(entity.position.x-args.position.x)<1
   and math.abs(entity.position.y-args.position.y)<1 then return false end
 end
 return true
end
surface.create_entity=function(args)
 created=created+1
 return {valid=true,unit_number=20000+created,name=args.name,
   ghost_name=args.inner_name,position=args.position,surface=surface,force=force}
end
local station={valid=true,unit_number=1,name="junior-cogitator-station",
 position={x=0,y=0},surface=surface,force=force}
local priest={valid=true,unit_number=2,position={x=0,y=0},surface=surface,force=force}
local pair={station=station,priest=priest,radius=8,self_construction_frustration_unlocked_1504=true,
 combat_target={valid=true,force=enemy,position={x=50,y=0}}}
storage.tech_priests.pairs_by_station[1]=pair
-- 120 unrelated stations test that one eligibility visit is one step.
for id=2,121 do
 storage.tech_priests.pairs_by_station[id]={station={valid=true,unit_number=id,
  name="junior-cogitator-station",force=force,surface=surface,position={x=id*100,y=100}},radius=8}
end
local radius_reads=0
_G.refresh_pair_radius=function(p)radius_reads=radius_reads+1;return p.radius end
local inv={valid=true,get_item_count=function()return stock end,
 remove=function(stack)local n=math.min(stock,stack.count);stock=stock-n;return n end,
 insert=function(stack)stock=stock+stack.count;return stack.count end}
_G.TechPriestsStorageRoleAuthority0686={generic_station_inventories=function()
 return {{inv=inv,entity=station,source="station-container"}}end,
 generic_storage_sources=function()return {{inv=inv,entity=station,source="station-container"}}end}
_G.tech_priests_request_movement_0418=function()return true end
pair.construction_requested_item={item_name="gun-turret",entity_name="gun-turret",
 category="defense-turret",position={x=8,y=0}}
assert(not Builder.discover_pair(pair,true) and calls==0,
 "fixed defense caller performed synchronous perimeter work")
local function advance()
 game.tick=game.tick+1
 local before,before_radius=calls,radius_reads
 Queue.pulse({tick=game.tick},16)
 assert(calls-before<=16,"native queries escaped charged specialized steps")
 assert(radius_reads-before_radius<=32,"whole station group was charged as one operation")
end
local function candidate()
 for step=1,5000 do
  advance()
  local value=Builder.discover_pair(pair,true)
  assert(not pair.construction_site_refusal_0338 and not pair.construction_cooldown_0338,
    "pending defense triggered construction failure cooldown")
  if value then return value end
 end
 error("fixed defense did not finish")
end
local found=candidate()
assert(found.effectiveness and found.effectiveness.territory_epoch and claims==0,
 "defense published partial ownership or took a physical reservation")
local job_count=Queue.root().total
-- Unrelated machine edits do not invalidate station ownership proof.
Site.on_station_changed({entity={valid=true,name="assembling-machine-1",force=force,surface=surface}})
assert(Queue.root().total==job_count,"unrelated machine edit discarded planning")
local overlap={station={valid=true,unit_number=500,name="junior-cogitator-station",
 position={x=10,y=0},surface=surface,force=force},radius=8}
storage.tech_priests.pairs_by_station[500]=overlap
Site.on_station_changed({entity=overlap.station})
-- Combat target is solely a scoring witness; don't let 0338 combat priority
-- replace the construction admission being tested here.
pair.combat_target=nil
local denied=Builder.service_pair(pair,"new-station-overlap")
assert(denied.detail=="placement-pending-live-obstruction" and claims==0 and stock==1
 and not pair.construction_task_0338 and not pair.construction_custody_0338,
 "stale defense ownership admitted a build or material custody")
Site.on_station_changed({entity=overlap.station});overlap.station.valid=false
pair.combat_target={valid=true,force=enemy,position={x=50,y=0}}
found=candidate();pair.combat_target=nil
local admitted=Builder.service_pair(pair,"current-defense-admission")
assert(claims==1 and stock==0 and pair.construction_custody_0338,
 "queued defense admission never reached real physical custody")
local before=calls
assert(Site.live_admitted_defense_site(pair,"gun-turret",{x=8,y=0},"defense-turret",found.effectiveness),
 "active approved defense was stalled behind another complete planner")
assert(calls-before<=2,"active defense reran whole scoring/support scan")

-- A mining ghost uses the same broker, and loss of its live ore witness
-- before final admission cannot create a phantom working drill.
storage={tech_priests={pairs_by_station={[1]=pair}}}
pair.construction_task_0338=nil;pair.construction_custody_0338=nil
pair.construction_candidate_0338=nil;pair.construction_requested_item=nil
pair.construction_bootstrap_ghost_0645=nil;pair.radius=8;stock=1
entities={{valid=true,type="resource",name="iron-ore",amount=100,
 position={x=4.5,y=.5},force=force}}
local began,begun_reason=Ghost.service_pair(pair,"mining-enqueue","burner-mining-drill")
assert(not began and Site.is_pending(begun_reason),"mining caller did not queue")
local mined
for step=1,2000 do
 advance()
 local pos,why,report,ticket=Site.plan_site(pair,{entity_name="burner-mining-drill",category="miner"})
 if pos then mined={position=pos,ticket=ticket};break end
 assert(Site.is_pending(why),why)
end
assert(mined and mined.position.x%1==0,"queued mining did not retain legal alignment")
entities[1].amount=0
local ghosted,reason=Ghost.service_pair(pair,"ore-depleted-before-ghost","burner-mining-drill")
assert(not ghosted and Site.is_pending(reason) and created==0
 and not pair.construction_bootstrap_ghost_0645,"depleted ore authorized a stale mining ghost")
entities[1].amount=100
for step=1,2000 do
 advance()
 local worked=Ghost.service_pair(pair,"ore-restored","burner-mining-drill")
 if worked then break end
end
assert(created==1 and pair.construction_bootstrap_ghost_0645
 and pair.construction_bootstrap_ghost_0645.entity_name=="burner-mining-drill"
 and stock==1,"pending mining failed to produce a legitimate ghost or spent material")
print("[placement-specialized-continuation-1507] PASS actual fixed-defense/mining callers, per-station and per-entity work, bounded native cells, changed territory/ore, active construction, no premature custody")
