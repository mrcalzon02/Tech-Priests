-- Actual 0359 + 0645 + 0338 callers. Queued discovery must never become
-- material custody or a failure cooldown, including after a save/reload.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Q,Site,Ghost,Builder
local trace,stock,created,claims,blocked
local function reset()
  game={tick=1000};storage={tech_priests={pairs_by_station={}}}
  defines={direction={north=0},distraction={none=0}}
  trace,stock,created,claims,blocked={},1,0,0,{}
  prototypes={item={["iron-chest"]={place_result={name="iron-chest"}}},
    entity={["iron-chest"]={type="container",collision_box={{-.35,-.35},{.35,.35}}}}}
  _G.TechPriestsPlanningConstraints0646={entity_unlocked=function()return true end,
    interior_position_allowed=function()return true end}
  _G.TechPriestsScanRouting0610={find_entities=function()return {} end}
  _G.TechPriestsWorkReservations0601={categories={},root=function()return {reservations={}} end,
    claim=function()claims=claims+1;return true end,release=function()return true end}
  for _,name in ipairs({"force_planning_queue","construction_site_planner",
      "construction_bootstrap_ghost_planner_0645","construction_planner"})do
    package.loaded["scripts.core."..name]=nil
  end
  Q=require("scripts.core.force_planning_queue")
  Site=require("scripts.core.construction_site_planner")
  Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
  Builder=require("scripts.core.construction_planner")
end
local function pair(id,can_place)
  local force={index=1,name="player",valid=true,technologies={},recipes={}}
  local surface={index=1,valid=true}
  local station={valid=true,unit_number=id,name="junior-cogitator-station",
    position={x=id*100,y=0},force=force,surface=surface}
  local priest={valid=true,unit_number=id+10000,position={x=id*100,y=1},
    force=force,surface=surface}
  surface.can_place_entity=function(args)
    trace[#trace+1]={tick=game.tick,id=id,x=args.position.x-station.position.x,y=args.position.y}
    return can_place==nil or can_place(args.position)
  end
  surface.find_entities_filtered=function(filters)
    if not filters.area then return {} end
    local center=(filters.area[1][1]+filters.area[2][1])/2
    if blocked[center] then return {{valid=true,type="assembling-machine"}} end
    return {}
  end
  surface.create_entity=function(args)
    created=created+1
    return {valid=true,name=args.name,ghost_name=args.inner_name,
      unit_number=100000+created,position=args.position,force=force,surface=surface}
  end
  local inv={valid=true,get_item_count=function(item)return item=="iron-chest" and stock or 0 end,
    remove=function(stack)local n=math.min(stock,stack.count);stock=stock-n;return n end,
    insert=function(stack)stock=stock+stack.count;return stack.count end}
  _G.TechPriestsStorageRoleAuthority0686={generic_station_inventories=function()
      return {{inv=inv,entity=station,source="station-container"}} end,
    generic_storage_sources=function()return {{inv=inv,entity=station,source="station-container"}} end}
  _G.tech_priests_request_movement_0418=function()return true end
  local p={station=station,priest=priest,station_unit=id,radius=8,
    self_construction_frustration_unlocked_1504=true}
  p.construction_requested_item={item_name="iron-chest",entity_name="iron-chest",category="storage"}
  storage.tech_priests.pairs_by_station[id]=p
  return p
end
local function no_custody(p,message)
  assert(not p.construction_task_0338 and not p.construction_custody_0338
    and not p.construction_cooldown_0338 and not p.construction_site_refusal_0338
    and not p.construction_bootstrap_ghost_0645 and claims==0 and stock==1,message)
end
local function pulse(n)
  game.tick=game.tick+1
  return Q.pulse({tick=game.tick},n or 16)
end
reset()
local p=pair(1,function()return false end)
for i=1,20 do
  local _,why=Ghost.service_pair(p,"pending-ghost","iron-chest")
  Builder.discover_pair(p,true)
  assert(why=="placement-pending")
end
assert(#trace==0 and Q.root().total==1,"actual callers advanced or duplicated the shared scan")
no_custody(p,"unfinished placement acquired custody or failure cooldown")
pulse();assert(#trace==15,"rejected candidates were not charged against the shared 15-position cap")
Q.pulse({tick=game.tick},16)
assert(#trace==15,"repeat broker invocation exceeded the same-tick hard cap")
for i=1,20 do Ghost.service_pair(p,"poll","iron-chest");Builder.discover_pair(p,true)end
assert(#trace==15,"polling advanced a saved search")
-- A simulated Factorio save round-trip rejects functions in continuation data.
local function serialized(value)
  local kind=type(value)
  assert(kind~="function" and kind~="thread" and kind~="userdata","unsafe saved continuation")
  if kind~="table" then return value end
  local out={};for key,child in pairs(value)do out[serialized(key)]=serialized(child)end
  return out
end
storage.tech_priests[Q.storage_key]=serialized(Q.root())
package.loaded["scripts.core.force_planning_queue"]=nil
package.loaded["scripts.core.construction_site_planner"]=nil
Q=require("scripts.core.force_planning_queue");Site=require("scripts.core.construction_site_planner")
pulse();assert(#trace==30,"saved search failed to resume")
local expected=Site.debug_sequence(p,"iron-chest",30)
for i,actual in ipairs(trace)do
  assert(actual.x==expected[i].x-p.station.position.x and actual.y==expected[i].y,
    "ordinary spiral search order changed at candidate "..i)
end
no_custody(p,"reload/poll created an invalid task")

-- A valid site can become obstructed between discovery and physical admission.
reset();p=pair(1)
assert(Builder.discover_pair(p,true)==nil);pulse(1)
local c=Builder.discover_pair(p,true)
assert(c and c.placement_ticket_0359 and claims==0 and stock==1,"proposal claimed material")
blocked[c.position.x]=true
local refusal=Builder.service_pair(p,"obstruction-before-custody")
assert(refusal.waiting==1 and refusal.detail=="placement-pending-live-obstruction",
  "new obstruction did not resume planning")
no_custody(p,"new obstruction took custody before the live site check")
assert(Q.root().tokens["placement-live"]==1,"rejected live check was not charged")
blocked={};pulse(1);c=Builder.discover_pair(p,true)
assert(c and c.position.x==p.station.position.x-1,"rejected site restarted or skipped spiral order")
stock=0
local waiting=Builder.service_pair(p,"stock-changed-while-pending")
assert(waiting.detail=="waiting-source" and stock==0 and not p.construction_custody_0338,
  "stale stock fabricated physical material")
stock=1;game.tick=game.tick+1
local acquired=Builder.service_pair(p,"stock-now-physical")
assert(stock==0 and p.construction_custody_0338 and p.construction_custody_0338.count==1,
  "ready construction stopped real material pickup")

-- Mutating a request in place cannot reuse a saved proposal's authority.
reset();p=pair(1)
Builder.discover_pair(p,true);pulse(1);assert(Builder.discover_pair(p,true))
p.construction_requested_item.position={x=105,y=2}
local changed=Builder.service_pair(p,"same-table-request-changed")
assert(changed.detail=="placement-pending-request-changed" and claims==0 and stock==1
 and not p.construction_task_0338,"mutated request admitted an obsolete proposal")

-- Both actual callers share the live token, including a failed check.
reset();local a=pair(1);local b=pair(2)
Ghost.service_pair(a,"enqueue","iron-chest");Builder.discover_pair(b,true);pulse(2)
local ok,why=Ghost.service_pair(a,"ghost-ready","iron-chest")
assert(ok and why=="ghost-created" and created==1,"queued ghost never became real")
c=Builder.discover_pair(b,true);assert(c)
local live_wait=Builder.service_pair(b,"shared-live-cap")
assert(live_wait.detail=="placement-pending-live-budget" and claims==0
  and not b.construction_task_0338 and stock==1,"callers exceeded one live authorization/tick")
game.tick=game.tick+1
Builder.service_pair(b,"next-tick-live-check")
assert(claims==1 and stock==0 and b.construction_custody_0338,
  "next-tick continuation starved physical construction")

-- Queue saturation and stalled broker are backpressure, never no-site results.
reset();a=pair(1,function()return false end);b=pair(2)
Q.max_per_force=1
Site.plan_site(a,{entity_name="iron-chest",category="storage"})
for i=1,10 do
  local _,pending=Ghost.service_pair(b,"queue-full","iron-chest")
  Builder.discover_pair(b,true)
  assert(pending=="placement-pending-queue-full")
end
assert(#trace==0 and Q.root().total==1,"full queue ran work outside the broker")
no_custody(b,"full/stalled queue triggered cooldown or material claim")
Q.max_per_force=64
Ghost.service_pair(b,"queue-admitted","iron-chest");pulse(2)
local acted=Ghost.service_pair(b,"fairness-after-unproductive-job","iron-chest")
assert(acted and created==1,"no-action earlier station starved later ready job")
print("[ordinary-placement-continuation-1507] PASS actual ghost/builder, 15+1 cap, order, serialized reload, full/stalled queues, no-action fairness, live obstruction, changing stock and real custody")
