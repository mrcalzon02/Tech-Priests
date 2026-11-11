-- Actual 0835 starvation decision with inventory, map-intelligence and
-- remote-ore mocks. The production planner creates no entities or resources.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Rail=require("scripts.core.remote_rail_outpost_0835")
local Frontier=require("scripts.core.rail_track_frontier_0836")
local max_reachable=math.min(Rail.remote_max,
  Frontier.start_offset+(Frontier.max_segments-1)*Frontier.segment_step
  +Frontier.destination_clearance)
assert(max_reachable==666,"unexpected 0836 physical-rail reach budget")
game={tick=1000}
defines={inventory={chest=1}}
local qty={
  rail=700,locomotive=2,["cargo-wagon"]=3,coal=300,
  ["burner-mining-drill"]=12,["train-stop"]=4,["iron-ore"]=0
}
local inventory={valid=true,get_item_count=function(name)return qty[name] or 0 end}
local surface={valid=true,index=1}
local intel=true
local nearby=false
local remote=true
local force={index=1,technologies={
    railway={researched=true},
    ["automated-rail-transportation"]={researched=true}}}
force.is_chunk_charted=function(_,sector)
  return intel and sector.y==0 and (sector.x==8 or sector.x==16
    or sector.x==20 or sector.x==25)
end
local ore={valid=true,name="iron-ore",unit_number=991,
  type="resource",surface=surface,position={x=512,y=0},amount=10000}
local off_corridor={valid=true,name="iron-ore",unit_number=992,
  type="resource",surface=surface,position={x=256,y=16},amount=10000}
local beyond_segment_budget={valid=true,name="iron-ore",unit_number=993,
  type="resource",surface=surface,position={x=800,y=0},amount=10000}
local terminal_reachable={valid=true,name="iron-ore",unit_number=994,
  type="resource",surface=surface,position={x=666,y=0},amount=10000}
local terminal_unreachable={valid=true,name="iron-ore",unit_number=995,
  type="resource",surface=surface,position={x=668,y=0},amount=10000}
-- At native last paid rail (651,1), (664,6) is within 16 true tiles,
-- while (666,-6) is outside it despite its east coordinate being <= 666.
local lateral_terminal_reachable={valid=true,name="iron-ore",unit_number=996,
  type="resource",surface=surface,position={x=664,y=6},amount=10000}
local lateral_terminal_unreachable={valid=true,name="iron-ore",unit_number=997,
  type="resource",surface=surface,position={x=666,y=-6},amount=10000}
local remote_entities={ore}
surface.find_entities_filtered=function(args)
  assert(args.type=="resource" and args.name=="iron-ore",
    "rail observer searched unrelated entities")
  if args.position then
    return nearby and {{valid=true,amount=10}} or {}
  end
  assert(args.area and args.area[1][1]==192
      and args.area[1][2]==-6
      and args.area[2][1]==max_reachable
      and args.area[2][2]==6,
    "rail observer did not bound its resource scan to the buildable corridor")
  return remote and remote_entities or {}
end
_G.TechPriestsScanRouting0610={
  find_entities=function(scanned_surface,filters,context)
    assert(scanned_surface==surface
        and context and context.category=="resource"
        and filters.limit and filters.limit<=512,
      "rail planner bypassed canonical budgeted world scan")
    return surface.find_entities_filtered(filters)
  end,
}
local station={valid=true,name="planetary-magos-cogitator-station",
  unit_number=104,position={x=0,y=0},surface=surface,force=force,
  get_inventory=function(id)
    assert(id==defines.inventory.chest)
    return inventory
  end}
local pair={station=station,priest={valid=true,unit_number=105}}
local function blocked(want)
  local mission,reason=Rail.assess(pair)
  assert(mission==nil and reason==want,
    "incorrect starvation gate: "..tostring(reason).." expected "..want)
end

intel=false
blocked("no-charted-rail-corridor-ore")
intel=true
nearby=true
blocked("local-patch-available")
nearby=false
qty["iron-ore"]=Rail.stock_floor
blocked("stock-available")
qty["iron-ore"]=0
qty.locomotive=0
blocked("missing-physical-rail-supplies:locomotive")
qty.locomotive=2
force.technologies.railway.researched=false
blocked("railway-technology-locked")
force.technologies.railway.researched=true
remote=false
blocked("no-charted-rail-corridor-ore")
remote=true
-- A perfectly charted, aligned patch beyond the 320-segment construction
-- budget is NOT reachable merely because it is within the 1024-tile survey.
remote_entities={beyond_segment_budget}
blocked("no-charted-rail-corridor-ore")
-- Native physical frontier ends at x=651, not its unbuilt x=653 candidate.
remote_entities={terminal_unreachable}
blocked("no-charted-rail-corridor-ore")
remote_entities={lateral_terminal_unreachable}
blocked("no-charted-rail-corridor-ore")
-- The physically unbuildable closer diagonal must not hide a valid patch.
remote_entities={lateral_terminal_unreachable,ore}
local still_reachable,still_reason=Rail.assess(pair)
assert(still_reason=="starved-charted-patch"
    and still_reachable and still_reachable.position.x==512,
  "unreachable lateral ore stole the counted railway mission")
remote_entities={lateral_terminal_reachable}
qty.rail=318
blocked("insufficient-physical-rails-to-reach-ore")
qty.rail=319
local diagonal_target,diagonal_why=Rail.assess(pair)
assert(diagonal_why=="starved-charted-patch"
    and diagonal_target and diagonal_target.position.x==664
    and diagonal_target.position.y==6 and qty.rail==320,
  "diagonal patch within real last-rail clearance rejected")
remote_entities={terminal_reachable}
qty.rail=319
blocked("insufficient-physical-rails-to-reach-ore")
qty.rail=320
local edge_target,edge_reason=Rail.assess(pair)
assert(edge_reason=="starved-charted-patch"
    and edge_target and edge_target.position.x==666 and qty.rail==320,
  "real 320th rail at x=651 needs exactly 320 paid rail segments")
qty.rail=700
-- A closer, charted ore deposit above the eastbound rail corridor must
-- not permanently divert 0836 into "terrain-route-planner-required".
remote_entities={off_corridor,beyond_segment_budget,ore}
local corridor_decision,corridor_reason=Rail.assess(pair)
assert(corridor_reason=="starved-charted-patch"
    and corridor_decision and corridor_decision.position.x==512
    and corridor_decision.position.y==0,
  "nearest off-corridor ore stole the only currently buildable rail mission")
remote_entities={off_corridor}
blocked("no-charted-rail-corridor-ore")
remote_entities={ore}
-- x=512 needs 243 contiguous native-centered rail entities, not just the
-- obsolete 64-rail minimum. Refuse before making or spending any request.
qty.rail=242
blocked("insufficient-physical-rails-to-reach-ore")
qty.rail=243
local minimum_target,minimum_why=Rail.assess(pair)
assert(minimum_why=="starved-charted-patch"
    and minimum_target and minimum_target.position.x==512
    and qty.rail==243 and pair.construction_request==nil,
  "counted 243-rail reach was not accepted without material mutation")
qty.rail=700
local decision,why=Rail.assess(pair)
assert(why=="starved-charted-patch" and decision and
    decision.item=="iron-ore" and decision.position.x==512
    and decision.distance==512 and decision.observed_stock==0,
  "charted distant genuine ore not detected for rail-ready starving Magos")
local created,status=Rail.observe_pair(pair)
local original=pair.remote_rail_outpost_0835
assert(created and status=="starvation-objective-created"
    and original and original.status=="starvation-confirmed"
    and original.stage=="surveyed-remote-patch"
    and original.next_step=="plan-physical-track-route"
    and original.root_station_unit==104
    and original.target.x==512 and qty.rail==700
    and qty.locomotive==2 and qty["iron-ore"]==0,
  "rail starvation observer created phantom track, stock or wrong objective")
local again,reason=Rail.observe_pair(pair)
assert(not again and reason=="interval"
    and pair.remote_rail_outpost_0835==original,
  "rail observer duplicated the live strategic objective")
game.tick=2000
again,reason=Rail.observe_pair(pair)
assert(not again and reason=="mission-already-owned"
    and pair.remote_rail_outpost_0835==original
    and original.last_observed_tick==2000,
  "rail observation reassigned or reset an active mission")
station.name="junior-cogitator-station"
local forbidden,why_not=Rail.assess(pair)
assert(not forbidden and why_not=="not-live-planetary-magos",
  "subordinate station illegally claimed planetary rail expansion authority")
print("[remote-rail-outpost-0835] PASS charted remote-starvation discovery, genuine stock gates, durable ranked mission")
-- Scenario S1 / 1063: let the ACTUAL starvation observer select a remote
-- railway mission before invoking the real track-frontier planner. The mocked
-- 0338 receipt below is SOURCE-level interaction evidence, not a Factorio
-- engine success or a simulated physical train.
station.name="planetary-magos-cogitator-station"
pair.remote_rail_outpost_0835=nil
pair.remote_rail_outpost_probe_0835=nil
pair.remote_rail_outpost_diagnosis_0835=nil
game.tick=3600
local constructed={}
local old_scan=_G.TechPriestsScanRouting0610.find_entities
_G.TechPriestsScanRouting0610.find_entities=function(s,filters,context)
  if filters.name=="straight-rail" then
    assert(s==surface and context.category=="construction"
      and filters.limit==4 and filters.radius==0.25,
      "rail frontier bypassed shared construction scan")
    local e=constructed[filters.position.x]
    return e and {e} or {}
  end
  return old_scan(s,filters,context)
end
surface.can_place_entity=function(args)
  assert(args.force==force and args.name=="straight-rail"
    and args.direction==4 and args.position.y==1,
    "rail planner requested an uncharted or invalid corridor")
  return constructed[args.position.x]==nil
end
defines.direction={east=4}
prototypes={item={rail={name="rail"}},entity={
  ["straight-rail"]={name="straight-rail"}}}
local started,selected=Rail.observe_pair(pair)
local mission=pair.remote_rail_outpost_0835
assert(started and selected=="starvation-objective-created"
  and mission and mission.root_station_unit==station.unit_number
  and mission.target.x==512 and qty.rail==700
  and qty["iron-ore"]==0 and not next(constructed),
  "S1 did not select a real starved/stocked/charted rail objective")
local requested,request_reason=Frontier.service_pair(pair)
local req=pair.construction_request
assert(requested and request_reason=="rail-segment-requested"
  and req and req.item_name=="rail" and req.rail_segment_0836==1
  and req.position.x==13 and qty.rail==700
  and not next(constructed) and mission.rail_frontier_0836.segment==0,
  "S1 planning created free track or skipped counted builder custody")
assert(select(2,Frontier.service_pair(pair))=="waiting-for-construction-proof"
  and pair.construction_request==req and qty.rail==700,
  "S1 duplicated a rail order before the native constructor finished")
local first={valid=true,name="straight-rail",unit_number=5001,
  force=force,surface=surface,position={x=13,y=1},direction=4}
constructed[13]=first
qty.rail=qty.rail-1 -- Represents the separately tested 0338 engine debit.
pair.construction_request=nil
pair.construction_last_task_0338={request_value=req,
  phase="complete",built_entity=first}
assert(select(2,Frontier.verify_pending(pair))=="physical-rail-segment-verified"
  and mission.rail_frontier_0836.segment==1 and qty.rail==699
  and mission.rail_frontier_0836.built_units[1]==5001,
  "S1 ignored exact 0338 completion or real-entity scan")
local again,next_reason=Frontier.service_pair(pair)
assert(again and next_reason=="rail-segment-requested"
  and pair.construction_request.position.x==15
  and mission.rail_frontier_0836.segment==1
  and qty.rail==699 and not constructed[15],
  "S1 did not continue one verified rail section at a time")
print("[remote-expansion-scenario-S1-1063] PASS autonomous rail-starvation selection, exact first 0338 track receipt, next counted request; full train expedition still open")
-- 1064: verify that the production broker, not a test-only direct call,
-- drives a new strategic Magos survey into the canonical 0338 request.
-- The broker must NOT report requests as built entities or spend materials.
pair.remote_rail_outpost_0835=nil
pair.remote_rail_outpost_probe_0835=nil
pair.remote_rail_outpost_diagnosis_0835=nil
pair.construction_request=nil
pair.construction_last_task_0338=nil
constructed={}
storage={tech_priests={pairs_by_station={[104]=pair}}}
game.tick=10000
local spec,registrations
registrations=0
_G.TechPriestsRuntimeTickBroker0600={
  register_service=function(config)
    assert(config.category=="construction" and config.budget<=2
      and config.interval>=100 and type(config.fn)=="function",
      "rail installed a new unbounded or noncanonical schedule")
    registrations=registrations+1
    spec=config
    return true
  end
}
assert(Rail.install()==true and spec and registrations==1,
  "rail starvation observer did not install into existing runtime broker")
local zero=spec.fn(nil,0)
assert(zero.processed==0 and not pair.remote_rail_outpost_0835
  and not pair.construction_request and qty.rail==699,
  "zero broker budget created a new rail mission")
local result=spec.fn(nil,1)
local mission2=pair.remote_rail_outpost_0835
local first_req=pair.construction_request
assert(result.processed==1 and result.acted==0 and result.failed==0
  and mission2 and mission2.target.x==512
  and first_req and first_req.item_name=="rail"
  and first_req.rail_segment_0836==1
  and first_req.position.x==13 and not constructed[13]
  and qty.rail==699 and mission2.rail_frontier_0836.segment==0,
  "broker did not autonomously discover and request first counted rail")
local retained=spec.fn(nil,1)
assert(retained.acted==0 and retained.failed==0
  and pair.construction_request==first_req
  and mission2.rail_frontier_0836.segment==0 and qty.rail==699,
  "duplicate broker pulse falsely completed a rail or issued another request")
local actual={valid=true,name="straight-rail",unit_number=5002,
  force=force,surface=surface,position={x=13,y=1},direction=4}
constructed[13]=actual
qty.rail=qty.rail-1 -- Existing separately tested 0338 physical item debit.
pair.construction_request=nil
pair.construction_last_task_0338={phase="complete",
  request_value=first_req,built_entity=actual}
local progressed=spec.fn(nil,1)
assert(progressed.processed==1 and progressed.acted==0
  and progressed.failed==0
  and mission2.rail_frontier_0836.segment==1
  and mission2.rail_frontier_0836.built_units[1]==5002
  and pair.construction_request.position.x==15
  and qty.rail==698 and constructed[15]==nil,
  "broker did not verify native 0338 receipt before next adjacent request")
-- Fail-closed railway discovery: no technology, no mission or phantom track.
pair.remote_rail_outpost_0835=nil
pair.remote_rail_outpost_probe_0835=nil
pair.construction_request=nil
pair.construction_last_task_0338=nil
force.technologies.railway.researched=false
game.tick=12000
local rejected=spec.fn(nil,1)
assert(rejected.acted==0 and rejected.failed==0
  and pair.remote_rail_outpost_0835==nil
  and pair.construction_request==nil and qty.rail==698,
  "broker bypassed real railway technology prerequisites")
print("[remote-rail-broker-1064] PASS autonomous budgeted survey, physical builder receipt, no duplicate credit, missing-technology refusal")
