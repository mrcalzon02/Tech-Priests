-- Lua 5.2 regression: inventory custody reach is measured to a physical
-- entity footprint, not to the unreachable center of a large Cogitator.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
storage={tech_priests={pairs_by_station={}}}
defines={distraction={none=0}}
local Construction=require("scripts.core.construction_planner")
local stock=1
local inv={valid=true}
inv.get_item_count=function(name)
  return name=="tech-priests-emergency-miner" and stock or 0
end
inv.remove=function(stack)
  if stack.name~="tech-priests-emergency-miner" then return 0 end
  local n=math.min(stock,stack.count);stock=stock-n;return n
end
inv.insert=function(stack)
  if stack.name~="tech-priests-emergency-miner" then return 0 end
  stock=stock+stack.count;return stack.count
end
local surface={index=1}
surface.can_place_entity=function() return true end
local force={index=1,name="player"}
local station={valid=true,unit_number=1,position={x=0,y=0},
  selection_box={left_top={x=-1.25,y=-1.25},
    right_bottom={x=1.25,y=1.25}},
  surface=surface,force=force}
local priest={valid=true,position={x=1.8,y=0}}
local pair={station=station,priest=priest,station_unit=1}
storage.tech_priests.pairs_by_station[1]=pair
local moves={}
_G.tech_priests_request_movement_0418=function(_,pos,reason,opts)
  moves[#moves+1]={pos=pos,reason=reason,owner=opts.owner}
  return true
end
local function check(cond,msg)
  if not cond then error("construction-footprint regression: "..msg,2) end
end
local function task(phase)
  return {phase=phase,started_tick=game.tick,
    source_entity=station,source_inv=inv,item_name="tech-priests-emergency-miner",
    entity_name="tech-priests-emergency-miner",position={x=6,y=0}}
end

pair.construction_task_0338=task("move-source")
local pickup=Construction.service_pair(pair,"station-footprint-pickup")
check(pickup.waiting==1 and pickup.detail=="moving-site",
  "standing beside the station box did not advance to construction site")
check(stock==0,"physical device was not removed from its original inventory")
check(pair.construction_custody_0338 and pair.construction_custody_0338.count==1,
  "picked-up machine lacks persistent physical custody")
check(#moves==1 and moves[1].reason=="construction-site-standoff-0338",
  "unreachable station-center movement was requested rather than a site route")

-- The same proximity correction must apply when interrupted construction
-- returns an item to its original machine inventory.
pair.construction_task_0338=task("return-custody")
pair.construction_task_0338.carried={item_name="tech-priests-emergency-miner",count=1}
moves={}
local returned=Construction.service_pair(pair,"station-footprint-return")
check(returned and returned.detail=="custody-returned-source",
  "interrupted build failed to return custody beside the station footprint")
check(stock==1 and not pair.construction_custody_0338,
  "returned item was not physically restored or custody was not cleared")
check(#moves==0,"station-center route blocked physically reachable item return")

-- A remote priest must still travel to the station; using the footprint
-- cannot make machine inventories accessible from arbitrary distances.
priest.position={x=10,y=0}
pair.construction_task_0338=task("move-source")
moves={}
local remote=Construction.service_pair(pair,"remote-pickup-needs-movement")
check(remote and remote.detail=="moving-source",
  "out-of-range construction pickup was incorrectly accepted")
check(stock==1 and #moves==1
  and moves[1].reason=="construction-source-0338",
  "remote pickup removed an item or skipped physical movement")
check(moves[1].pos.x>station.selection_box.right_bottom.x
    and moves[1].pos.x<priest.position.x
    and moves[1].pos.y==0,
  "construction requested movement into an impassable station center")
-- A returning priest can be hundreds of real tiles away after gathering
-- material beyond its assigned radius. A fixed 1,200-tick timeout is shorter
-- than legitimate travel; scale that deadline once a source exists.
priest.position={x=300,y=0}
game.tick=5000
pair.construction_task_0338=task("move-source")
pair.construction_task_0338.started_tick=1000
moves={}
local far=Construction.service_pair(pair,"long-physical-return")
check(far and far.detail=="moving-source" and stock==1,
  "legitimate far-away source route aborted without moving")
check(pair.construction_task_0338.travel_allowance_ticks_0338>Construction.request_timeout,
  "construction route failed to account for 300 real tiles of travel")
game.tick=6300
local enroute=Construction.service_pair(pair,"long-physical-return-continuing")
check(enroute and enroute.detail=="moving-source",
  "far-away priest was timed out after only the old fixed deadline")
game.tick=15000
local timed=Construction.service_pair(pair,"unreachable-route-is-finite")
check(timed and tostring(timed.detail):find("construction%-timeout:move%-source"),
  "unreachable construction was allowed to monopolize its source indefinitely")
check(stock==1 and pair.construction_task_0338==nil,
  "construction timeout incorrectly consumed uncollected materials")

-- Manufacturing time is not construction travel. An item produced after
-- the former timeout still permits actual source pickup and site travel.
game.tick=20000
stock=0
_G.tech_priests_inventory_steward_sources_for_pair=function()
  return {{inv=inv,entity=station,source="station-container"}}
end
priest.position={x=1.8,y=0}
pair.construction_task_0338=task("waiting-source")
pair.construction_task_0338.started_tick=1
local awaiting=Construction.service_pair(pair,"ingredient-manufacture-pending")
check(awaiting and awaiting.detail=="waiting-source"
  and not pair.construction_task_0338.active_started_tick_0338,
  "unmanufactured placeable consumed its physical travel budget")
stock=1
local acquired=Construction.service_pair(pair,"material-now-available")
check(acquired and acquired.detail=="moving-site" and stock==0
  and pair.construction_custody_0338 and pair.construction_custody_0338.count==1,
  "manufactured item was not physically acquired after a long recipe wait")
-- Remote priority can defer UNFUNDED untouched work, but not custody.
local routine={item_name="stone-furnace"}
local priority={item_name="burner-mining-drill",
 entity_name="burner-mining-drill",remote_drill_terminal_1011=1,
 position={x=8,y=0}}
pair.construction_request=routine
pair.remote_drill_request_1011=priority
pair.construction_task_0338={phase="waiting-source",
 item_name="stone-furnace",entity_name="stone-furnace",
 request_field="construction_request",request_value=routine,
 position={x=6,y=0}}
pair.construction_custody_0338=nil
local discover=Construction.discover_pair
Construction.discover_pair=function()return nil end
local yielded=Construction.service_pair(pair,"unfunded-routine-yields")
check(yielded and yielded.detail=="no-candidate"
 and not pair.construction_task_0338
 and pair.construction_request==routine
 and pair.remote_drill_request_1011==priority
 and not pair.construction_custody_0338,
 "unfunded routine task was not safely deferred")
local carried={item_name="stone-furnace",count=1}
local active={phase="waiting-source",item_name="stone-furnace",
 entity_name="stone-furnace",carried=carried,
 request_field="construction_request",request_value=routine}
pair.construction_task_0338=active
pair.construction_custody_0338=carried
Construction.service_pair(pair,"custody-cannot-yield")
check(pair.construction_task_0338==active
 and pair.construction_custody_0338==carried
 and carried.count==1 and pair.construction_request==routine,
 "remote priority stole active construction custody")
Construction.discover_pair=discover
pair.construction_task_0338=nil
pair.construction_custody_0338=nil
prototypes={item={["burner-mining-drill"]={},["stone-furnace"]={}},
 entity={["burner-mining-drill"]={},["stone-furnace"]={}}}
pair.construction_candidate_0338={request_field="construction_request",
 request_value=routine,item_name="stone-furnace",position={x=4,y=0}}
local chosen=Construction.discover_pair(pair,false)
check(chosen and chosen.request_field=="remote_drill_request_1011"
 and chosen.request_value==priority and chosen.item_name=="burner-mining-drill"
 and pair.construction_request==routine,
 "cached routine candidate defeated dedicated remote priority")
-- A temporarily refused site movement MUST NOT refund the real item
-- while 0338 still has a bounded opportunity to deliver it. This was the
-- native receiver failure in Factorio 2.0.77 run 41126009999.
pair.remote_drill_request_1011=nil
pair.construction_request=nil
pair.construction_candidate_0338=nil
priest.position={x=1.8,y=0}
game.tick=25000
stock=0 -- The physical item was already removed into carried custody.
local site_task=task("move-site")
site_task.carried={item_name="tech-priests-emergency-miner",count=1}
pair.construction_task_0338=site_task
pair.construction_custody_0338=nil
local allow_route=false
_G.tech_priests_request_movement_0418=function(_,pos,reason)
  moves[#moves+1]={pos=pos,reason=reason}
  return allow_route
end
moves={}
local denied=Construction.service_pair(pair,"receiver-route-temporarily-denied")
check(denied and denied.detail=="construction-site-route-denied"
  and site_task.phase=="move-site" and site_task.movement_denials_0338==1
  and pair.construction_task_0338==site_task
  and pair.construction_custody_0338
  and pair.construction_custody_0338.count==1
  and site_task.carried.count==1 and stock==0,
  "a temporary movement denial abandoned/refunded counted receiver custody")
allow_route=true
local retried=Construction.service_pair(pair,"receiver-route-now-available")
check(retried and retried.detail=="moving-site"
  and pair.construction_task_0338==site_task
  and site_task.movement_denials_0338==nil
  and site_task.carried.count==1 and stock==0
  and #moves==2 and moves[2].reason=="construction-site-standoff-0338",
  "physical receiver route was not retried with intact item custody")
-- A permanently denied route still has the original finite deadline and
-- returns the same carried item to the original physical source.
allow_route=false
game.tick=25000+Construction.request_timeout
  +(site_task.travel_allowance_ticks_0338 or 0)+1
local expired=Construction.service_pair(pair,"receiver-route-deadline")
check(expired and tostring(expired.detail):find("construction%-timeout:move%-site")
  and stock==1 and not pair.construction_task_0338
  and not pair.construction_custody_0338
  and site_task.carried.count==0,
  "timed-out receiver movement failed exact source inventory restitution")
-- A real 1x1 receiver site can be blocked by the builder itself after
-- the physical chest has already been removed from canonical storage.
-- 0338 must move that same priest aside and retry engine validation, not
-- refund the chest or place it through an occupied tile.
game.tick=30000
stock=0
priest.name="tech-priests-test-unit"
priest.position={x=6,y=0}
local static_obstruction=false
surface.can_place_entity=function(opts)
 if opts.name==priest.name then return true end
 return not static_obstruction
   and ((priest.position.x-opts.position.x)^2
       +(priest.position.y-opts.position.y)^2)>=1.21
end
local constructed=0
surface.create_entity=function(opts)
 constructed=constructed+1
 return {valid=true,name=opts.name,force=opts.force,
   surface=surface,position=opts.position,unit_number=900+constructed}
end
local occupied=task("build")
occupied.carried={item_name="tech-priests-emergency-miner",count=1}
pair.construction_task_0338=occupied
pair.construction_custody_0338=nil
allow_route=true
local wait_clear=Construction.service_pair(pair,"engine-occupied-receiver")
check(wait_clear and wait_clear.detail=="engine-site-obstructed-retry"
 and occupied.phase=="move-clear-site" and occupied.build_standoff_0338
 and occupied.carried.count==1 and stock==0 and constructed==0
 and pair.construction_custody_0338.count==1,
 "engine site obstruction discarded custody or built through the priest")
local route_clear=Construction.service_pair(pair,"move-receiver-builder-aside")
check(route_clear and route_clear.detail=="clearing-occupied-site"
 and occupied.phase=="move-clear-site" and occupied.carried.count==1,
 "receiver builder failed to request physical standoff")
priest.position=occupied.build_standoff_0338
local placed=Construction.service_pair(pair,"receiver-site-now-physically-clear")
check(placed and placed.acted==1 and constructed==1
 and not pair.construction_task_0338 and not pair.construction_custody_0338
 and occupied.carried.count==0 and stock==0,
 "receiver did not consume the original carried item after actual clearance")
-- An immovable *static* obstruction must never be built through or
-- indefinitely retain the item. The existing real source gets it back.
game.tick=31000
priest.position={x=1.8,y=0}
static_obstruction=true
stock=0
local blocked=task("build")
blocked.carried={item_name="tech-priests-emergency-miner",count=1}
pair.construction_task_0338=blocked
local first=Construction.service_pair(pair,"static-site-obstruction")
check(first and first.detail=="engine-site-obstructed-retry"
 and blocked.phase=="move-clear-site" and blocked.carried.count==1
 and stock==0 and constructed==1,
 "static site blocker bypassed the engine or refunded too early")
-- Even a blocked fixture must model actual walking to the proposed
-- standoff before 0338 can revalidate. A refund likewise requires the
-- priest to walk back to the real source inventory.
priest.position=blocked.build_standoff_0338
game.tick=31601
local terminal=Construction.service_pair(pair,"static-site-obstruction-deadline")
check(terminal and terminal.detail=="returning-source-custody"
 and blocked.phase=="return-custody" and stock==0
 and blocked.carried.count==1 and constructed==1,
 "static blocker spent cargo or refunded remotely without walking")
priest.position={x=1.8,y=0}
local refunded=Construction.service_pair(pair,"static-obstruction-physical-refund")
check(refunded and tostring(refunded.detail):find("site%-invalid:engine%-revalidated")
 and stock==1 and not pair.construction_task_0338
 and not pair.construction_custody_0338 and constructed==1,
 "static blocked receiver did not fail closed with exact item restitution")
-- Native run 41161056070: direct routes toward a solid receiver
-- reintroduced site collision. A non-ghost builder must instead request a
-- real, collision-clear position close enough to build without entering it.
game.tick=33000
static_obstruction=false
priest.position={x=0,y=0}
stock=0
local standoff_task=task("move-site")
standoff_task.carried={item_name="tech-priests-emergency-miner",count=1}
pair.construction_task_0338=standoff_task
-- The real executor already synced this record at physical source pickup.
pair.construction_custody_0338={item_name=standoff_task.item_name,count=1}
moves={}
allow_route=true
local route=Construction.service_pair(pair,"non-ghost-receiver-standoff")
local stand=moves[1] and moves[1].pos
check(route and route.detail=="moving-site" and stand
 and moves[1].reason=="construction-site-standoff-0338"
 and (stand.x-6)^2+stand.y^2>1.21
 and (stand.x-6)^2+stand.y^2<=Construction.build_reach_sq
 and standoff_task.carried.count==1 and stock==0
 and pair.construction_custody_0338.count==1,
 "builder routed into solid receiver tile or lost physical item custody")
priest.position=stand
local built_at_standoff=Construction.service_pair(pair,"physically-arrived-at-standoff")
check(built_at_standoff and built_at_standoff.acted==1
 and constructed==2 and stock==0
 and standoff_task.carried.count==0
 and not pair.construction_custody_0338,
 "standoff arrival did not produce one engine-approved counted build")
-- A site with no collision-clear approach cannot consume or discard the
-- carried item, and the existing finite timeout must refund it.
game.tick=34000
priest.position={x=1.8,y=0}
surface.can_place_entity=function() return false end
local no_stand=task("move-site")
no_stand.carried={item_name="tech-priests-emergency-miner",count=1}
pair.construction_task_0338=no_stand
pair.construction_custody_0338=nil
local denied_stand=Construction.service_pair(pair,"no-legal-standoff")
check(denied_stand and denied_stand.detail=="construction-site-no-safe-standoff"
 and stock==0 and no_stand.carried.count==1
 and pair.construction_custody_0338.count==1,
 "blocked standoff silently spent or abandoned carried item")
game.tick=34000+Construction.request_timeout
 +(no_stand.travel_allowance_ticks_0338 or 0)+1
local standoff_expired=Construction.service_pair(pair,"standoff-timeout")
check(standoff_expired and tostring(standoff_expired.detail):find("construction%-timeout")
 and stock==1 and no_stand.carried.count==0
 and not pair.construction_task_0338 and not pair.construction_custody_0338,
 "unreachable standoff did not return exact physical item")
print("[construction-footprint-regression] PASS scenarios=17")
