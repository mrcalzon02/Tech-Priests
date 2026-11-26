-- The actual 0645 ghost must pass a second shared live authorization when
-- 0338 admits physical construction. A ghost is not material custody.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Q,Site,Ghost,Builder,pair,stock,world,checks,claims,terrain
local function load_modules()
  for _,name in ipairs({"force_planning_queue","planning_metadata_1507",
      "construction_site_planner","construction_bootstrap_ghost_planner_0645","construction_planner"})do
    package.loaded["scripts.core."..name]=nil
  end
  _G.TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359=nil
  Q=require("scripts.core.force_planning_queue")
  Site=require("scripts.core.construction_site_planner")
  Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
  Builder=require("scripts.core.construction_planner")
end
local function reset()
  game={tick=1000};storage={tech_priests={pairs_by_station={}}}
  defines={direction={north=0,east=4},distraction={none=0},
    build_check_type={manual=1,ghost_revive=2}}
  prototypes={item={["iron-chest"]={place_result={name="iron-chest"}}},
    entity={["iron-chest"]={type="container",collision_box={{-.35,-.35},{.35,.35}}}}}
  stock,world,checks,claims,terrain=1,{},0,0,false
  local force={object_name="LuaForce",valid=true,index=1,name="player",recipes={},technologies={}}
  local surface={object_name="LuaSurface",valid=true,index=1}
  local station={object_name="LuaEntity",valid=true,unit_number=1,name="junior-cogitator-station",
    type="container",position={x=100,y=0},force=force,surface=surface}
  local priest={object_name="LuaEntity",valid=true,unit_number=2,name="tech-priest",
    type="car",position={x=100,y=1},force=force,surface=surface}
  pair={station=station,priest=priest,station_unit=1,radius=8,
    self_construction_frustration_unlocked_1504=true}
  storage.tech_priests.pairs_by_station[1]=pair
  local function in_area(e,f)
    if f.type and e.type~=f.type then return false end
    if f.name and e.name~=f.name then return false end
    if f.force and e.force~=f.force then return false end
    if f.area then
      local a,b=f.area[1],f.area[2]
      if e.position.x<a[1] or e.position.x>b[1] or e.position.y<a[2] or e.position.y>b[2] then return false end
    end
    if f.position then
      local x,y=e.position.x-f.position.x,e.position.y-f.position.y
      if x*x+y*y>(f.radius or 0)^2 then return false end
    end
    return true
  end
  surface.find_entities_filtered=function(f)
    local out={}
    for _,e in ipairs(world)do
      if e.valid and in_area(e,f) then
        out[#out+1]=e;if #out>=(f.limit or math.huge)then break end
      end
    end
    return out
  end
  surface.find_entity=function(name,position)
    assert(type(name)=="string" and type(position)=="table","native bound method got an extra self argument")
    return surface.find_entities_filtered{name=name,position=position,limit=1}[1]
  end
  surface.can_place_entity=function(f)
    checks=checks+1
    if terrain then return false end
    for _,e in ipairs(world)do
      if e.valid and e.type~="entity-ghost"
        and e.position.x==f.position.x and e.position.y==f.position.y then return false end
    end
    return true
  end
  surface.create_entity=function(f)
    local e={object_name="LuaEntity",valid=true,name=f.name,type=f.name,
      ghost_name=f.inner_name,unit_number=100+#world,position={x=f.position.x,y=f.position.y},
      direction=f.direction or 0,force=f.force,surface=surface}
    e.destroy=function()e.valid=false;return true end
    world[#world+1]=e;return e
  end
  local inv={object_name="LuaInventory",valid=true,
    get_item_count=function(item)return item=="iron-chest" and stock or 0 end,
    remove=function(stack)local amount=math.min(stock,stack.count);stock=stock-amount;return amount end,
    insert=function(stack)stock=stock+stack.count;return stack.count end}
  _G.TechPriestsPlanningConstraints0646={entity_unlocked=function()return true end,
    interior_position_allowed=function()return true end}
  _G.TechPriestsScanRouting0610={find_entities=function(_,filters)return surface.find_entities_filtered(filters)end}
  _G.TechPriestsWorkReservations0601={categories={},root=function()return {reservations={}}end,
    claim=function()claims=claims+1;return true end,release=function()return true end}
  _G.TechPriestsStorageRoleAuthority0686={generic_station_inventories=function()
      return {{inv=inv,entity=station,source="station-container"}}end,
    generic_storage_sources=function()return {{inv=inv,entity=station,source="station-container"}}end}
  _G.tech_priests_request_movement_0418=function()return true end
  load_modules()
end
local function pulse(n)
  game.tick=game.tick+1
  local out=Q.pulse({tick=game.tick},n or 16)
  assert(out.processed<=(n or 16),"planner exceeded offered work")
end
local function no_custody(message)
  assert(not pair.construction_task_0338 and not pair.construction_custody_0338
    and not pair.construction_cooldown_0338 and not pair.construction_site_refusal_0338
    and claims==0 and stock==1,message)
end
local function create_ghost()
  local acted,why=Ghost.service_pair(pair,"admit-ghost","iron-chest")
  assert(not acted and why=="placement-pending")
  pulse(1)
  acted,why=Ghost.service_pair(pair,"complete-ghost","iron-chest")
  assert(acted and why=="ghost-created","actual 0645 caller did not create its queued ghost")
  local rec=pair.construction_bootstrap_ghost_0645
  assert(rec and rec.ghost and rec.ghost.valid)
  return rec
end
local function ready()
  for _=1,100 do
    local c=Builder.discover_pair(pair,true)
    if c then assert(c.placement_ticket_0359,"fixed request bypassed its admission ticket");return c end
    assert(pair.construction_pending_0359 and pair.construction_pending_0359:find("^placement%-pending"))
    pulse(1)
  end
  error("fixed admission failed to resume")
end
local function copy_saved(value,seen)
  local kind=type(value)
  assert(kind~="function" and kind~="thread","function/coroutine escaped into saved continuation")
  if kind~="table" or value.object_name then return value end
  seen=seen or{};if seen[value]then return seen[value]end
  local out={};seen[value]=out
  for k,v in pairs(value)do out[copy_saved(k,seen)]=copy_saved(v,seen)end
  return out
end

reset()
local rec=create_ghost()
local before=checks
for _=1,20 do assert(not Builder.discover_pair(pair,true))end
assert(checks==before,"physical caller advanced fixed admission without the broker")
no_custody("owned ghost was treated as material custody while its admission was pending")
pulse(0)
assert(not Builder.discover_pair(pair,true) and checks==before,"stalled broker ran fixed work through its caller")
storage=copy_saved(storage);pair=storage.tech_priests.pairs_by_station[1];rec=pair.construction_bootstrap_ghost_0645
load_modules()
local candidate=ready()
assert(Q.claim_tick("placement-live",1))
local out=Builder.service_pair(pair,"shared-live-cap")
assert(out.detail=="placement-pending-live-budget" and checks==before)
no_custody("fixed caller ignored the shared final-check cap")
game.tick=game.tick+1
local obstacle={object_name="LuaEntity",valid=true,name="stone-wall",type="wall",
  position={x=candidate.position.x,y=candidate.position.y},force=pair.station.force,surface=pair.station.surface}
world[#world+1]=obstacle
out=Builder.service_pair(pair,"obstruction-before-owned-ghost-custody")
assert(out.waiting==1 and out.detail=="placement-pending-live-obstruction")
no_custody("new obstruction at the owned ghost took materials before physical admission")
assert(rec.ghost.valid and Q.root().tokens["placement-live"]==1,"failed final check destroyed its ghost or was uncharged")
obstacle.valid=false;terrain=true;ready()
out=Builder.service_pair(pair,"terrain-changed-while-pending")
assert(out.detail=="placement-pending-live-obstruction")
no_custody("changed terrain bypassed native final admission")
terrain=false;ready()
local other=pair.station.surface.create_entity{name="entity-ghost",inner_name="iron-chest",
  position=rec.position,force=pair.station.force}
out=Builder.service_pair(pair,"another-ghost-owns-site")
assert(out.detail=="placement-pending-live-obstruction")
no_custody("owned-ghost exemption ignored another ghost")
other.valid=false;ready()
stock=0
out=Builder.service_pair(pair,"stock-drained-while-pending")
assert(out.detail=="waiting-source" and claims==1 and stock==0
  and not pair.construction_custody_0338,"fixed admission fabricated stale material")
local live_checks=checks
stock=1;game.tick=game.tick+1;assert(Q.claim_tick("placement-live",1))
out=Builder.service_pair(pair,"preserve-already-admitted-work")
assert(stock==0 and pair.construction_custody_0338 and checks==live_checks,
  "an already admitted task was replanned or prevented from taking real material")

reset();rec=create_ghost();Q.max_per_force=2
Q.register("blocked-admission-fixture",function()return{processed=1,waiting=true}end)
for i=1,2 do Q.submit(1,"blocked-admission-fixture",i,{})end
before=checks
for _=1,20 do
  assert(not Builder.discover_pair(pair,true))
  assert(pair.construction_pending_0359=="placement-pending-queue-full")
end
assert(checks==before,"full queue ran fixed work outside the broker")
no_custody("full fixed-admission queue claimed material or recorded a failure cooldown")
Q.max_per_force=64;ready()
out=Builder.service_pair(pair,"fairness-after-blocked-job")
assert(stock==0 and claims==1 and pair.construction_custody_0338,
  "unproductive earlier jobs starved the physical owned-ghost admission")

reset()
pair.construction_request={item_name="iron-chest",entity_name="iron-chest",category="storage",
  position={x=150,y=7},direction=4}
assert(not Builder.discover_pair(pair,true));candidate=ready()
assert(candidate.position.x==150 and candidate.position.y==7 and candidate.direction==4)
out=Builder.service_pair(pair,"fixed-authority-preserved")
assert(claims==1 and stock==0 and pair.construction_custody_0338,
  "fixed authority was moved, denied a live token, or failed to admit real construction")

-- An unstarted candidate persisted by the pre-ticket version is still only
-- a proposal. Migration must not grant it physical admission for free.
reset();rec=create_ghost()
pair.construction_candidate_0338={item_name="iron-chest",entity_name="iron-chest",category="storage",
  position=rec.position,ghost=rec.ghost,request_field="construction_bootstrap_ghost_0645",request_value=rec}
out=Builder.service_pair(pair,"legacy-ticketless-candidate")
assert(out.waiting==1 and out.detail=="placement-pending")
no_custody("a saved ticketless candidate bypassed new physical admission")
pulse()
obstacle={object_name="LuaEntity",valid=true,name="stone-wall",type="wall",
  position=rec.position,force=pair.station.force,surface=pair.station.surface}
world[#world+1]=obstacle
out=Builder.service_pair(pair,"legacy-candidate-now-obstructed")
assert(out.detail=="placement-pending-live-obstruction")
no_custody("a saved candidate took material through a new obstruction")
print("[owned-ghost-admission-1507] PASS actual 0645→0338, save/reload, shared live cap, full/stalled queues, obstruction/terrain/stock changes, exact ghost exemption and active custody")
