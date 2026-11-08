-- The real 0338 constructor is the sole item-debit/build owner.
-- 0836 may only sequence and accept verified successful 0338 tasks.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
-- This is an acceptance-fixture integrity guard, NOT native ore-delivery
-- proof. The exact engine scenario must reject missing natural resources.
local f=assert(io.open("tests/scenarios/remote-rail-acquisition/fixture.lua","r"))
local source=f:read("*a")
f:close()
assert(source:find("NO_NATURALLY_GENERATED_EASTBOUND_IRON_PATCH",1,true)
  and source:find("NATURAL_ORE_SOURCE_DAMAGED_DURING_FIXTURE_ISOLATION",1,true)
  and source:find("native_ore_amount=",1,true)
  and not source:find('surface.create_entity{name="iron-ore"',1,true),
  "native railway test must not fabricate the destination resource")
local Track=require("scripts.core.rail_track_frontier_0836")
game={tick=2400}
defines={direction={east=4},inventory={chest=1},
  rail_direction={front=0,back=1},rail_connection_direction={straight=1}}
prototypes={item={rail={name="rail"}},entity={["straight-rail"]={name="straight-rail"}}}
local force={index=1}
local sites={}
local scan_calls=0
local surface={index=1,can_place_entity=function(spec)
  assert(spec.name=="straight-rail" and spec.direction==4
    and spec.force==force,"rail placement bypassed engine placement check")
  return not sites[spec.position.x]
end}
_G.TechPriestsScanRouting0610={find_entities=function(s,filters,opts)
  assert(s==surface and opts and opts.category=="construction"
    and filters.limit==4 and filters.name=="straight-rail"
    and filters.radius==0.25,"rail touched unbudgeted entity scan")
  scan_calls=scan_calls+1
  local e=sites[filters.position.x]
  return e and {e} or {}
end}
local pair={station={valid=true,unit_number=104,
  name="planetary-magos-cogitator-station",
  surface=surface,force=force,position={x=0,y=0}},
  priest={valid=true,unit_number=105,position={x=0,y=5}}}
local mission={status="starvation-confirmed",root_station_unit=104,
  target={x=512,y=0},surface_index=1,force_index=1,
  item="iron-ore",next_step="plan-physical-track-route"}
pair.remote_rail_outpost_0835=mission
local item_count=700
local original=Track.service_pair(pair)
local req=pair.construction_request
assert(original==true and req and req.item_name=="rail"
  and req.entity_name=="straight-rail" and req.position.x==12
  and req.position.y==0 and req.direction==4
  and req.rail_segment_0836==1 and item_count==700
  and mission.rail_frontier_0836.segment==0 and not sites[12],
  "planning first rail created track, consumed stock or skipped custody")
local unchanged,reason=Track.service_pair(pair)
assert(unchanged and reason=="waiting-for-construction-proof"
  and pair.construction_request==req
  and mission.pending_rail_0836.request==req,
  "second pulse duplicated an unbuilt physical track request")
-- A saved and resumed mission must preserve the original site, not replan
-- across the same pending physical construction custody.
game.tick=3600
local saved=mission
assert(Track.service_pair(pair)==true
    and mission==saved and pair.construction_request==req,
  "pending track after save/reload changed its durable objective")
-- Even a rail at the right position is NOT ours until the old builder has
-- physically debited one rail item, built and completed its OWN request.
sites[12]={valid=true,unit_number=2101,name="straight-rail",
  position={x=12,y=0},direction=4,force=force}
assert(Track.verify_pending(pair)==false
  and mission.rail_frontier_0836.segment==0,
  "unproven pre-existing rails were credited as our completed work")
-- Use the native constructor's observable terminal record to represent
-- the outcome of its separately exercised exact-item custody transition.
item_count=item_count-1
pair.construction_last_task_0338={request_value=req,phase="complete",
  built_entity=sites[12]}
pair.construction_request=nil
local progressed=Track.verify_pending(pair)
assert(progressed==true and mission.rail_frontier_0836.segment==1
  and mission.rail_frontier_0836.built_units[1]==2101
  and mission.pending_rail_0836==nil and item_count==699,
  "first real builder completion not linked to exact physical segment")
local next_ok,next_why=Track.service_pair(pair)
local next_req=pair.construction_request
assert(next_ok==true and next_why=="rail-segment-requested"
  and next_req.position.x==14 and next_req.rail_segment_0836==2
  and item_count==699 and mission.rail_frontier_0836.segment==1,
  "rail frontier failed to advance by one physically adjacent segment")
-- The engine's own straight connection, not coordinate proximity,
-- must bind two physically built and separately debited 0338 segments.
local second={valid=true,unit_number=2102,name="straight-rail",
  position={x=14,y=0},direction=4,force=force}
sites[14]=second
local connection_live=true
sites[12].get_connected_rail=function(args)
  assert(args.rail_connection_direction==defines.rail_connection_direction.straight
    and (args.rail_direction==defines.rail_direction.front
      or args.rail_direction==defines.rail_direction.back),
    "did not ask the native rail connection API")
  return connection_live and args.rail_direction==defines.rail_direction.front
    and second or nil
end
item_count=item_count-1 -- Existing 0338 debit independently tested.
pair.construction_last_task_0338={request_value=next_req,
  phase="complete",built_entity=second}
pair.construction_request=nil
assert(Track.verify_pending(pair)==true
  and mission.rail_frontier_0836.segment==2
  and mission.rail_frontier_0836.built_units[2]==2102
  and mission.pending_rail_0836==nil and item_count==698,
  "connected second 0338 rail was not verified")
-- Do not spend the next rail against a replacement in the old location.
local second_real=sites[14]
sites[14]={valid=true,unit_number=2999,name="straight-rail",
  position={x=14,y=0},direction=4,force=force}
local tampered_mission={status="building-physical-rail",
  root_station_unit=104,target={x=512,y=0},
  surface_index=1,force_index=1,
  rail_frontier_0836={segment=2,last_position={x=14,y=0},
    direction=4,built_units={2101,2102},start_position={x=12,y=0}}}
local tampered_pair={station=pair.station,priest=pair.priest,
  remote_rail_outpost_0835=tampered_mission}
local altered,altered_reason=Track.plan_next(tampered_pair)
assert(not altered and altered_reason=="previous-physical-rail-identity-changed"
  and tampered_mission.status=="rail-track-blocked"
  and tampered_mission.rail_frontier_0836.segment==2
  and tampered_pair.construction_request==nil and item_count==698,
  "replacement predecessor caused an unauthorized rail item request")
sites[14]=second_real
local third_ok,third_reason=Track.service_pair(pair)
local third_req=pair.construction_request
local pending=mission.pending_rail_0836
assert(third_ok and third_reason=="rail-segment-requested"
  and third_req.position.x==16 and third_req.rail_segment_0836==3,
  "connected frontier did not request the next counted rail")
pair.construction_last_task_0338={request_value=third_req,
  phase="aborted",result="engine-site-collision"}
pair.construction_request=third_req
local no_credit,blocked=Track.verify_pending(pair)
assert(not no_credit and blocked=="physical-rail-builder-aborted:engine-site-collision"
  and mission.status=="rail-track-blocked"
  and mission.rail_frontier_0836.segment==2
  and mission.pending_rail_0836==pending
  and item_count==698,
  "aborted physical builder forged a segment or lost its request")
-- A completed, correctly aligned second rail is still NOT proof of
-- a route when the engine says those two rail entities are disconnected.
connection_live=false
local detached_req={item_name="rail",entity_name="straight-rail",
  position={x=14,y=0},direction=4}
local detached_mission={status="building-physical-rail",
  root_station_unit=104,target={x=512,y=0},
  surface_index=1,force_index=1,
  rail_frontier_0836={segment=1,last_position={x=12,y=0},
    direction=4,built_units={2101}},
  pending_rail_0836={position={x=14,y=0},direction=4,
    segment=2,request=detached_req}}
local detached_pair={station=pair.station,priest=pair.priest,
  remote_rail_outpost_0835=detached_mission,
  construction_last_task_0338={request_value=detached_req,
    phase="complete",built_entity=second}}
-- A new physical 0338 receipt does not legitimize a replaced predecessor.
local kept_id=detached_mission.rail_frontier_0836.built_units[1]
detached_mission.rail_frontier_0836.built_units[1]=2998
local wrong_id,wrong_id_reason=Track.verify_pending(detached_pair)
assert(not wrong_id and wrong_id_reason=="previous-physical-rail-identity-changed"
  and detached_mission.rail_frontier_0836.segment==1
  and detached_mission.pending_rail_0836.request==detached_req
  and item_count==698,
  "completed rail incorrectly reconciled against another predecessor")
detached_mission.rail_frontier_0836.built_units[1]=kept_id
detached_mission.status="building-physical-rail"
local detached_ok,detached_reason=Track.verify_pending(detached_pair)
assert(not detached_ok
  and detached_reason=="physical-rail-segments-disconnected"
  and detached_mission.status=="rail-track-blocked"
  and detached_mission.rail_frontier_0836.segment==1
  and detached_mission.pending_rail_0836.request==detached_req
  and item_count==698,
  "two adjacent engine-disconnected rails were falsely counted")
-- Boundary: 320 original 0338-debited rail sections end at x=650.
-- Target x=666 is within 16 tiles of a REAL last rail; x=668 is not,
-- and a lost original final rail may not claim completion.
local terminal_rail={valid=true,unit_number=3201,name="straight-rail",
  position={x=650,y=0},direction=4,force=force}
sites[650]=terminal_rail
local function terminal_case(target_x)
  local objective={status="building-physical-rail",root_station_unit=104,
    target={x=target_x,y=0},surface_index=1,force_index=1,
    rail_frontier_0836={segment=320,last_position={x=650,y=0},
      start_position={x=12,y=0},direction=4,built_units={[320]=3201}}}
  return {station=pair.station,priest=pair.priest,
    remote_rail_outpost_0835=objective},objective
end
local terminal_pair,terminal_mission=terminal_case(666)
local terminal_ok,terminal_why=Track.plan_next(terminal_pair)
assert(not terminal_ok and terminal_why=="physical-frontier-reached"
  and terminal_mission.status=="rail-track-established"
  and terminal_mission.rail_frontier_0836.segment==320
  and terminal_pair.construction_request==nil and item_count==698,
  "physically reached x=666 frontier falsely refused as out of segments")
local over_pair,over_mission=terminal_case(668)
local over_ok,over_why=Track.plan_next(over_pair)
assert(not over_ok and over_why=="maximum-verified-rail-segments"
  and over_mission.status=="rail-track-blocked"
  and over_mission.rail_frontier_0836.segment==320
  and over_pair.construction_request==nil and item_count==698,
  "unbuilt x=652 candidate falsely completed an unreachable x=668 target")
sites[650]=nil
local missing_pair,missing_mission=terminal_case(666)
local missing_ok,missing_why=Track.plan_next(missing_pair)
assert(not missing_ok and missing_why=="previous-physical-rail-missing"
  and missing_mission.status=="rail-track-blocked"
  and missing_pair.construction_request==nil and item_count==698,
  "a vanished original final rail was accepted as track completion")
-- A new Magos or an uncharted/different target must never claim this
-- persistent mission or construct the pending physical rail on its behalf.
local other={station={valid=true,unit_number=999,
  name="planetary-magos-cogitator-station",
  surface=surface,force=force},priest={valid=true}}
other.remote_rail_outpost_0835=mission
assert(Track.service_pair(other)==false
  and mission.rail_frontier_0836.segment==2
  and mission.pending_rail_0836==pending
  and other.construction_request==nil
  and item_count==698,
  "another Magos seized original rail custody or changed counted stock")
assert(scan_calls>2,"rail builder never verified real physical track")
print("[rail-track-frontier-0836] PASS 0338 source debit, native connected track, disconnected refusal and retained custody")
-- Prove the actual 0510 dispatcher, not a separate rail tick executor,
-- owns rail constructor pulses and honors stronger physical duties.
dofile("tests/unit/rail_dispatcher_handoff_0836.lua")
