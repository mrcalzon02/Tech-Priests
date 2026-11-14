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
  and source:find("Frontier.required_segments_for_target(STATION,e.position)",1,true)
  and not source:find('surface.create_entity{name="iron-ore"',1,true),
  "native railway test must choose reachable generated ore, not fabricate it")
local Track=require("scripts.core.rail_track_frontier_0836")
game={tick=2400}
defines={direction={east=4},inventory={chest=1},
  rail_direction={front=0,back=1},rail_connection_direction={straight=1}}
prototypes={item={rail={name="rail"}},entity={["straight-rail"]={name="straight-rail"}}}
local force={index=1}
local sites={}
-- Deliberately stale indexed view: initially missing newly paid rails,
-- later still pointing to a removed original predecessor.
local indexed_rails={}
local scan_calls=0
local fresh_scan_calls=0
local indexed_scan_calls=0
local surface={valid=true,index=1,can_place_entity=function(spec)
  assert(spec.name=="straight-rail" and spec.direction==4
    and spec.force==force,"rail placement bypassed engine placement check")
  return not sites[spec.position.x]
end}
_G.TechPriestsScanRouting0610={find_entities=function(s,filters,opts)
  assert(s==surface and opts and opts.category=="construction"
    and filters.limit==4 and filters.name=="straight-rail"
    and filters.radius==0.25,"rail touched unbudgeted entity scan")
  scan_calls=scan_calls+1
  local e
  if opts.require_fresh==true then
    fresh_scan_calls=fresh_scan_calls+1
    e=sites[filters.position.x]
  else
    indexed_scan_calls=indexed_scan_calls+1
    e=indexed_rails[filters.position.x]
  end
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
-- The SAME budgeted strategic broker that plans rail also runs while the
-- Magos is executing non-rail duties. Do not seize its original assignment.
local incumbent={kind="original-magos-existing-duty"}
pair.active_task=incumbent
local deferred,deferred_reason=Track.service_pair(pair)
assert(not deferred and deferred_reason=="original-magos-incumbent-duty"
  and mission.status=="starvation-confirmed"
  and not mission.pending_rail_0836 and not mission.rail_frontier_0836
  and not pair.construction_request and item_count==700,
  "0836 issued a physical rail request over incumbent Magos work")
pair.active_task=nil
local original=Track.service_pair(pair)
local req=pair.construction_request
assert(original==true and req and req.item_name=="rail"
  and req.entity_name=="straight-rail" and req.position.x==13
  and req.position.y==1 and req.direction==4
  and req.rail_segment_0836==1 and item_count==700
  and mission.rail_frontier_0836.segment==0 and not sites[13],
  "planning first rail created track, consumed stock or skipped custody")
-- A pending, NOT YET ADMITTED rail does not outrank a newly incumbent
-- physical ore return. Preserve its original request for later service.
pair.direct_acquisition_custody_0513={item="iron-ore",count=1}
local paused,paused_reason=Track.service_pair(pair)
assert(not paused and paused_reason=="original-magos-incumbent-duty"
  and pair.construction_request==req
  and mission.pending_rail_0836.request==req and item_count==700,
  "pending rail stole active physical ore custody or lost its writ")
pair.direct_acquisition_custody_0513=nil
-- Conversely a 0338 builder ALREADY admitted for the exact rail must keep
-- its original physical construction custody/timeout and not be abandoned.
pair.active_task={kind="existing-background-order"}
pair.construction_task_0338={request_value=req,phase="move-source"}
local continued,continued_reason=Track.service_pair(pair)
assert(continued==true and continued_reason=="physical-builder-in-progress"
  and pair.construction_request==req and item_count==700,
  "original admitted 0338 rail was interrupted by background work")
pair.active_task=nil
pair.construction_task_0338=nil
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
sites[13]={valid=true,unit_number=2101,name="straight-rail",
  position={x=13,y=1},direction=4,force=force,surface=surface}
assert(Track.verify_pending(pair)==false
  and mission.rail_frontier_0836.segment==0,
  "unproven pre-existing rails were credited as our completed work")
-- Use the native constructor's observable terminal record to represent
-- the outcome of its separately exercised exact-item custody transition.
item_count=item_count-1
pair.construction_last_task_0338={request_value=req,phase="complete",
  built_entity=sites[13]}
pair.construction_request=nil
-- A saved original 0338 completion with an absent/corrupt primitive chain
-- cannot be credited by guessing a new inventory debit or rail identity.
-- This exercises the real first-segment receipt without changing stock.
local function damaged_chain_receipt(route)
  local req_copy={item_name="rail",entity_name="straight-rail",
    position={x=13,y=1},direction=4}
  local obj={status="building-physical-rail",root_station_unit=104,
    surface_index=1,force_index=1,target={x=512,y=0},
    rail_frontier_0836=route,
    pending_rail_0836={request=req_copy,segment=1,
      position={x=13,y=1},direction=4,started_tick=2400}}
  local p={station=pair.station,priest=pair.priest,
    remote_rail_outpost_0835=obj,
    construction_last_task_0338={request_value=req_copy,
      phase="complete",built_entity=sites[13]}}
  return p,obj
end
-- A completed pre-upgrade ADMIN CREATIVE 0338 rail can survive a save,
-- but its physical entity was never paid for. The current live 0338 guard
-- only sees active tasks, so 0836 must refuse this persisted terminal receipt.
local creative_pair,creative_mission=damaged_chain_receipt({
  segment=0,direction=4,start_position={x=13,y=1},built_units={}})
creative_pair.construction_last_task_0338.creative_build=true
local creative_accepted,creative_why=Track.verify_pending(creative_pair)
assert(not creative_accepted
  and creative_why=="physical-rail-creative-receipt-forbidden"
  and creative_mission.status=="rail-track-blocked"
  and creative_mission.rail_frontier_0836.segment==0
  and #creative_mission.rail_frontier_0836.built_units==0
  and creative_mission.pending_rail_0836
  and sites[13] and sites[13].unit_number==2101
  and item_count==699,
  "persisted creative-built rail was credited as a counted 0338 item debit")
local missing_ledger,missing_ledger_mission=damaged_chain_receipt({
  segment=0,direction=4,start_position={x=13,y=1}})
local missing_ok,missing_why=Track.verify_pending(missing_ledger)
assert(not missing_ok and missing_why=="rail-chain-ledger-incomplete"
  and missing_ledger_mission.pending_rail_0836
  and missing_ledger_mission.status=="rail-track-blocked"
  and item_count==699,
  "missing persisted paid-rail ledger crashed or invented rail identity")
local inconsistent_ledger,inconsistent_mission=damaged_chain_receipt({
  segment=0,built_units={9999},direction=4})
local bad_ok,bad_why=Track.verify_pending(inconsistent_ledger)
assert(not bad_ok and bad_why=="rail-chain-ledger-incomplete"
  and inconsistent_mission.pending_rail_0836 and item_count==699,
  "inconsistent persisted rail ledger was silently extended")
local corrupt_segment,corrupt_mission=damaged_chain_receipt({
  segment="corrupt",built_units={}})
local corrupt_ok,corrupt_why=Track.verify_pending(corrupt_segment)
assert(not corrupt_ok and corrupt_why=="out-of-order-physical-rail"
  and corrupt_mission.pending_rail_0836 and item_count==699,
  "invalid persisted segment index threw instead of refusing")
-- An unrelated physical duty can become incumbent after 0338 completes but
-- before the strategic broker observes that paid rail. Receipt reconciliation
-- is safe; dispatching the NEXT rail while occupied would preempt real work.
local finished_incumbent={kind="already-active-original-magos-duty"}
pair.active_task=finished_incumbent
local unrelated={item_name="rail",entity_name="straight-rail"}
local actual_receipt=pair.construction_last_task_0338
pair.construction_last_task_0338={request_value=unrelated,
  phase="complete",built_entity=sites[13]}
local foreign,foreign_reason=Track.service_pair(pair)
assert(not foreign and foreign_reason=="original-magos-incumbent-duty"
  and mission.pending_rail_0836.request==req
  and mission.rail_frontier_0836.segment==0
  and pair.construction_request==nil and item_count==699,
  "unrelated 0338 receipt stole a pending paid railway segment")
pair.construction_last_task_0338=actual_receipt
local progressed,receipt_reason=Track.service_pair(pair)
assert(progressed==true
  and receipt_reason=="physical-rail-receipt-reconciled-while-occupied"
  and mission.rail_frontier_0836.segment==1
  and mission.rail_frontier_0836.built_units[1]==2101
  and mission.pending_rail_0836==nil and item_count==699
  and pair.active_task==finished_incumbent
  and pair.construction_request==nil,
  "a physically paid original rail was not reconciled without preempting duty")
local paused_after_receipt,paused_reason=Track.service_pair(pair)
assert(not paused_after_receipt
  and paused_reason=="original-magos-incumbent-duty"
  and mission.rail_frontier_0836.segment==1
  and pair.construction_request==nil and item_count==699,
  "credited rail incorrectly dispatched another job over Magos incumbent")
pair.active_task=nil
local next_ok,next_why=Track.service_pair(pair)
local next_req=pair.construction_request
assert(next_ok==true and next_why=="rail-segment-requested"
  and next_req.position.x==15 and next_req.rail_segment_0836==2
  and item_count==699 and mission.rail_frontier_0836.segment==1,
  "rail frontier failed to advance by one physically adjacent segment")
-- The engine's own straight connection, not coordinate proximity,
-- must bind two physically built and separately debited 0338 segments.
local second={valid=true,unit_number=2102,name="straight-rail",
  position={x=15,y=1},direction=4,force=force,surface=surface}
sites[15]=second
local connection_live=true
sites[13].get_connected_rail=function(args)
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
local second_real=sites[15]
-- The index still advertises the old paid unit while the engine now
-- contains a replacement. Only the live engine read may refuse credit.
indexed_rails[14]=second_real
sites[15]={valid=true,unit_number=2999,name="straight-rail",
  position={x=15,y=1},direction=4,force=force,surface=surface}
local tampered_mission={status="building-physical-rail",
  root_station_unit=104,target={x=512,y=0},
  surface_index=1,force_index=1,
  rail_frontier_0836={segment=2,last_position={x=15,y=1},
    direction=4,built_units={2101,2102},start_position={x=13,y=1}}}
local tampered_pair={station=pair.station,priest=pair.priest,
  remote_rail_outpost_0835=tampered_mission}
local altered,altered_reason=Track.plan_next(tampered_pair)
assert(not altered and altered_reason=="previous-physical-rail-identity-changed"
  and tampered_mission.status=="rail-track-blocked"
  and tampered_mission.rail_frontier_0836.segment==2
  and tampered_pair.construction_request==nil and item_count==698,
  "replacement predecessor caused an unauthorized rail item request")
sites[15]=second_real
local third_ok,third_reason=Track.service_pair(pair)
local third_req=pair.construction_request
local pending=mission.pending_rail_0836
assert(third_ok and third_reason=="rail-segment-requested"
  and third_req.position.x==17 and third_req.rail_segment_0836==3,
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
  position={x=15,y=1},direction=4}
local detached_mission={status="building-physical-rail",
  root_station_unit=104,target={x=512,y=0},
  surface_index=1,force_index=1,
  rail_frontier_0836={segment=1,last_position={x=13,y=1},
    direction=4,built_units={2101}},
  pending_rail_0836={position={x=15,y=1},direction=4,
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
-- Boundary: 320 original 0338-debited rail sections end at native x=651.
-- Target x=666 is within 16 tiles of a REAL last rail; x=668 is not,
-- (666,-6) also lies outside 2D clearance; a missing rail never completes.
-- Populate the original 320 physical rail identities and native graph
-- edges; a terminal segment alone must never certify a broken earlier line.
local chain={}
for i=1,320 do
  local x=13+(i-1)*Track.segment_step
  chain[i]={valid=true,unit_number=4000+i,name="straight-rail",
    position={x=x,y=1},direction=4,force=force,surface=surface}
  sites[x]=chain[i]
end
for i=1,319 do
  local next_rail=chain[i+1]
  chain[i].get_connected_rail=function(args)
    assert(args.rail_connection_direction==defines.rail_connection_direction.straight,
      "terminal audit did not ask Factorio for the straight native edge")
    return args.rail_direction==defines.rail_direction.front and next_rail or nil
  end
end
local function terminal_case(target_x,target_y)
  local units={}
  for i=1,#chain do units[i]=chain[i].unit_number end
  local objective={status="building-physical-rail",root_station_unit=104,
    target={x=target_x,y=target_y or 0},
    surface_index=1,force_index=1,
    rail_frontier_0836={segment=320,last_position={x=651,y=1},
      start_position={x=13,y=1},direction=4,built_units=units}}
  return {station=pair.station,priest=pair.priest,
    remote_rail_outpost_0835=objective},objective
end
local function finish_terminal_audit(p)
  for step=1,42 do
    local progressed,why=Track.service_pair(p)
    if why~="rail-chain-audit-in-progress" then
      return progressed,why,step
    end
    assert(progressed==true and
      p.remote_rail_outpost_0835.status=="building-physical-rail",
      "pending incremental native rail audit was credited as route completion")
  end
  error("native rail integrity sweep exceeded bounded broker pulses")
end
local terminal_pair,terminal_mission=terminal_case(666)
local terminal_ok,terminal_why,audit_calls=finish_terminal_audit(terminal_pair)
assert(not terminal_ok and terminal_why=="physical-frontier-reached"
  and audit_calls>1 and audit_calls<=42
  and terminal_mission.status=="rail-track-established"
  and terminal_mission.rail_frontier_0836.chain_audit_completed_tick_0836
  and terminal_mission.rail_frontier_0836.segment==320
  and terminal_pair.construction_request==nil and item_count==698,
  "terminal frontier credited without auditing the native counted rail chain")
local diagonal_pair,diagonal_mission=terminal_case(664,6)
local diagonal_ok,diagonal_reason=finish_terminal_audit(diagonal_pair)
assert(not diagonal_ok and diagonal_reason=="physical-frontier-reached"
  and diagonal_mission.status=="rail-track-established"
  and diagonal_pair.construction_request==nil and item_count==698,
  "physically reachable lateral rail target was refused")
local lateral_over_pair,lateral_over_mission=terminal_case(666,-6)
local lateral_over_ok,lateral_over_why=Track.plan_next(lateral_over_pair)
assert(not lateral_over_ok
  and lateral_over_why=="maximum-verified-rail-segments"
  and lateral_over_mission.status=="rail-track-blocked"
  and lateral_over_pair.construction_request==nil and item_count==698,
  "east-only clearance falsely certified unreachable diagonal ore")
-- A damaged middle rail must fail closed even though the last one remains,
-- and no new item is issued or the old 0338 receipts silently discarded.
local broken=chain[160].get_connected_rail
chain[160].get_connected_rail=function()return nil end
local broken_pair,broken_mission=terminal_case(666)
local broken_ok,broken_reason=finish_terminal_audit(broken_pair)
assert(not broken_ok and broken_reason=="rail-chain-disconnected:161"
  and broken_mission.status=="rail-track-blocked"
  and broken_mission.rail_frontier_0836.segment==320
  and broken_pair.construction_request==nil and item_count==698,
  "destroyed native connection was falsely accepted as a trainable route")
chain[160].get_connected_rail=broken
local over_pair,over_mission=terminal_case(668)
local over_ok,over_why=Track.plan_next(over_pair)
assert(not over_ok and over_why=="maximum-verified-rail-segments"
  and over_mission.status=="rail-track-blocked"
  and over_mission.rail_frontier_0836.segment==320
  and over_pair.construction_request==nil and item_count==698,
  "unbuilt native x=653 candidate falsely completed an unreachable x=668 target")
local last_rail=sites[651]
sites[651]=nil
local missing_pair,missing_mission=terminal_case(666)
local missing_ok,missing_why=Track.plan_next(missing_pair)
assert(not missing_ok and missing_why=="previous-physical-rail-missing"
  and missing_mission.status=="rail-track-blocked"
  and missing_pair.construction_request==nil and item_count==698,
  "a vanished original final rail was accepted as track completion")
sites[651]=last_rail
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
-- If the existing 0338 builder never admits the first candidate, the
-- original paid-rail writ must not remain pending indefinitely. The
-- timed-out/stale writ is retained for audit, without any item debit.
local function stalled_pair(started)
  local request={item_name="rail",entity_name="straight-rail",
    position={x=13,y=1},direction=4}
  local objective={status="building-physical-rail",
    root_station_unit=104,target={x=512,y=0},
    surface_index=1,force_index=1,
    pending_rail_0836={position=request.position,direction=4,
      segment=1,request=request,started_tick=started}}
  return {station=pair.station,priest=pair.priest,
    construction_request=request,remote_rail_outpost_0835=objective},
    objective,request
end
local old_tick=game.tick
game.tick=7201
local live_pair,live_mission,live_request=stalled_pair(0)
live_pair.construction_task_0338={request_value=live_request,
  phase="moving-to-source"}
local active,active_why=Track.verify_pending(live_pair)
assert(not active and active_why=="physical-builder-in-progress"
  and live_mission.status=="building-physical-rail"
  and live_pair.construction_request==live_request,
  "active counted 0338 builder was timed out by parallel rail owner")
live_pair.construction_task_0338=nil
local late,late_why=Track.verify_pending(live_pair)
assert(not late and late_why=="pending-physical-rail-admission-timeout"
  and live_mission.status=="rail-track-blocked"
  and live_mission.pending_rail_0836.request==live_request
  and live_pair.construction_request==live_request and item_count==698,
  "unadmitted 0338 rail task waited forever or fabricated an item")
-- Independently owned 0338 construction/cargo cannot indefinitely shield
-- the original unadmitted rail writ; neither task nor item may be seized.
local foreign_req={item_name="iron-ore",owner="foreign-construction"}
local foreign_task={request_value=foreign_req,phase="move-site",
  carried=true,item_name="iron-ore"}
local foreign_pair,foreign_mission,foreign_rail=stalled_pair(0)
foreign_pair.construction_task_0338=foreign_task
local foreign_block,foreign_reason=Track.service_pair(foreign_pair)
assert(not foreign_block and foreign_reason=="pending-physical-rail-admission-timeout"
  and foreign_mission.status=="rail-track-blocked"
  and foreign_pair.construction_task_0338==foreign_task
  and foreign_pair.construction_request==foreign_rail
  and foreign_mission.pending_rail_0836.request==foreign_rail
  and item_count==698,
  "different physical builder indefinitely shielded overdue rail writ")
local current_pair,current_mission,current_req=stalled_pair(7000)
current_pair.construction_task_0338=foreign_task
local current,current_why=Track.service_pair(current_pair)
assert(not current and current_why=="original-magos-incumbent-duty"
  and current_mission.status=="building-physical-rail"
  and current_pair.construction_task_0338==foreign_task
  and current_pair.construction_request==current_req
  and item_count==698,
  "live original rail request preempted unrelated 0338 physical custody")
local foreign_custody={request_value=foreign_req,item_name="iron-ore",
  count=1,source_unit=999}
local custody_pair,custody_mission,custody_req=stalled_pair(0)
custody_pair.construction_custody_0338=foreign_custody
local custody_block,custody_reason=Track.service_pair(custody_pair)
assert(not custody_block and custody_reason=="pending-physical-rail-admission-timeout"
  and custody_mission.status=="rail-track-blocked"
  and custody_pair.construction_custody_0338==foreign_custody
  and custody_pair.construction_request==custody_req
  and item_count==698,
  "foreign real-item custody bypassed rail deadline or was displaced")
local missing_pair,missing_mission,missing_request=stalled_pair(7000)
missing_pair.construction_request=nil
local lost,lost_why=Track.verify_pending(missing_pair)
assert(not lost and lost_why=="pending-original-rail-request-lost"
  and missing_mission.status=="rail-track-blocked"
  and missing_mission.pending_rail_0836.request==missing_request
  and item_count==698,
  "lost original rail request silently kept pending custody")
local bad_tick_pair,bad_tick_mission=stalled_pair(nil)
local bad_tick,bad_tick_why=Track.verify_pending(bad_tick_pair)
assert(not bad_tick and bad_tick_why=="pending-rail-start-tick-invalid"
  and bad_tick_mission.status=="rail-track-blocked"
  and item_count==698,
  "ambiguous persisted rail admission tick acquired new item authority")
-- Independent physical custody must never hide an overdue original
-- unadmitted rail request, while a still-live writ stays deferred.
local occupied_pair,occupied_mission,occupied_req=stalled_pair(0)
local held={item="iron-ore",count=1}
occupied_pair.direct_acquisition_custody_0513=held
local refused,why=Track.service_pair(occupied_pair)
assert(not refused and why=="pending-physical-rail-admission-timeout"
  and occupied_mission.status=="rail-track-blocked"
  and occupied_pair.direct_acquisition_custody_0513==held
  and occupied_pair.construction_request==occupied_req
  and occupied_mission.pending_rail_0836.request==occupied_req
  and item_count==698,
  "expired original rail remained indefinitely pending behind real custody")
local waiting_pair,waiting_mission,waiting_req=stalled_pair(7000)
waiting_pair.direct_acquisition_custody_0513=held
local deferred,why_wait=Track.service_pair(waiting_pair)
assert(not deferred and why_wait=="original-magos-incumbent-duty"
  and waiting_mission.status=="building-physical-rail"
  and waiting_pair.construction_request==waiting_req
  and waiting_pair.direct_acquisition_custody_0513==held
  and item_count==698,
  "unexpired original rail stole incumbent ore cargo")
local lost_pair,lost_mission,lost_req=stalled_pair(7000)
lost_pair.direct_acquisition_custody_0513=held
lost_pair.construction_request=nil
local lost_while_busy,lost_busy_reason=Track.service_pair(lost_pair)
assert(not lost_while_busy and lost_busy_reason=="pending-original-rail-request-lost"
  and lost_mission.status=="rail-track-blocked"
  and lost_mission.pending_rail_0836.request==lost_req
  and lost_pair.direct_acquisition_custody_0513==held
  and item_count==698,
  "lost rail writ was hidden behind active Magos work")
game.tick=old_tick
assert(scan_calls>2 and fresh_scan_calls==scan_calls
  and indexed_scan_calls==0,
  "0836 accepted stale indexed rail geometry instead of live engine receipts")
print("[rail-track-frontier-0836] PASS fresh native 0338 rail identity, connected track, disconnected refusal and retained custody")
-- Prove the actual 0510 dispatcher, not a separate rail tick executor,
-- owns rail constructor pulses and honors stronger physical duties.
dofile("tests/unit/rail_dispatcher_handoff_0836.lua")

-- 0836 boarding must ask the existing 0528 physical owner to reconcile an
-- abandoned, *unladen* prior task, never mutate 0528 state itself. Once 0528
-- legally releases it, a unit priest is STILL not a native train passenger.
-- These source regressions are not a substitute for an engine ride.
do
  local original_priest={valid=true,unit_number=105,type="unit",
    force=force,surface=surface,position={x=0,y=5}}
  local native_train={valid=true,id=935,speed=0}
  local engine_loco={valid=true,name="locomotive",unit_number=350,
    force=force,surface=surface,position={x=3,y=1},train=native_train,
    get_driver=function()return nil end}
  local engine_wagon={valid=true,name="cargo-wagon",unit_number=351,
    force=force,surface=surface,position={x=5,y=1},train=native_train}
  -- Native live-fuel readback must use the original locomotive inventory:
  -- a historical 0528 receipt alone is never permission to board.
  defines.inventory.fuel=2
  local native_fuel={valid=true,amount=3}
  native_fuel.get_item_count=function(item)
    assert(item=="coal","0836 read foreign locomotive cargo as fuel")
    return native_fuel.amount
  end
  engine_loco.get_inventory=function(slot)
    assert(slot==defines.inventory.fuel,
      "0836 did not read the real native locomotive fuel inventory")
    return native_fuel
  end
  engine_loco.burner={valid=true,remaining_burning_fuel=0}
  local board_pair={station=pair.station,priest=original_priest}
  board_pair.remote_rail_outpost_0835={
    status="rail-track-established",root_station_unit=104,
    surface_index=1,force_index=1,target={x=512,y=0},
    rail_frontier_0836={chain_audit_completed_tick_0836=1},
    first_locomotive_0836={phase="native-paid-locomotive-verified",
      built_entity=engine_loco,built_unit=350},
    first_wagon_0836={phase="native-paid-wagon-verified",
      built_entity=engine_wagon,built_unit=351},
    first_fuel_0836={phase="native-paid-locomotive-fueled"}}
  local prior=_G.TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528
  local consultations=0
  _G.TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528={
    release_abandoned_unladen_train_preboarding_0836=function(p,e)
      assert(p==board_pair and e==engine_loco)
      consultations=consultations+1
      p.machine_logistics_0528={phase="failed"}
      return true,"original-abandoned-unladen-fuel-released"
    end}
  board_pair.machine_logistics_0528={phase="move-to-station",
    action="supply-fuel",item="coal"}
  local success,reason=Track.service_first_train_board_0836(board_pair)
  assert(not success and consultations==1
    and reason=="native-driver-requires-original-character:unit"
    and board_pair.remote_rail_outpost_0835.first_board_0836.phase==
      "native-boarding-unsupported-original-unit"
    and not board_pair.train_transport_rail_0835,
    "0836 did not release stale unladen 0528 safely or fabricated unit boarding")
  -- A real item hold must stop boarding BEFORE 0836 can ask to retire 0528.
  local physical_coal={item="coal",count=1}
  board_pair.machine_logistics_0528={phase="move-to-machine",
    action="supply-fuel",item="coal",custody=physical_coal}
  board_pair.machine_logistics_custody_0528=physical_coal
  local blocked,why=Track.service_first_train_board_0836(board_pair)
  assert(not blocked and why=="boarding-foreign-physical-custody"
    and consultations==1
    and board_pair.machine_logistics_custody_0528==physical_coal
    and physical_coal.count==1,
    "0836 preempted physical fuel custody to attempt boarding")
  board_pair.machine_logistics_custody_0528=nil
  -- A refused 0528 owner may not be overridden or treated as success.
  _G.TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528={
    release_abandoned_unladen_train_preboarding_0836=function()
      consultations=consultations+1
      return false,"live-movement-still-owned"
    end}
  local refused,why=Track.service_first_train_board_0836(board_pair)
  assert(not refused and why=="boarding-machine-logistics-still-active"
    and consultations==2
    and board_pair.machine_logistics_0528.phase=="move-to-machine"
    and not board_pair.train_transport_rail_0835,
    "0836 overrode a lawful 0528 refusal to pursue a train")
  -- Negative: 0528's earlier physical coal receipt still exists, but
  -- removing all current traction fuel must stop new boarding attempts.
  -- The original Magos/rolling stock and unrelated custody remain untouched.
  board_pair.machine_logistics_0528=nil
  native_fuel.amount=0
  engine_loco.burner.remaining_burning_fuel=0
  local empty,empty_why=Track.service_first_train_board_0836(board_pair)
  assert(not empty and empty_why=="original-train-out-of-live-fuel"
    and board_pair.remote_rail_outpost_0835.first_board_0836.phase==
      "native-boarding-fuel-blocked"
    and board_pair.priest==original_priest
    and original_priest.valid and original_priest.unit_number==105
    and engine_loco.valid and engine_wagon.valid
    and not board_pair.train_transport_rail_0835,
    "0836 treated historic fueled phase as current native traction")
  -- Positive current traction: Factorio may have already begun burning coal
  -- and therefore hold no unburned coal. Do not falsely block the live burner.
  engine_loco.burner.remaining_burning_fuel=1200
  local burning,burning_why=Track.service_first_train_board_0836(board_pair)
  assert(not burning
    and burning_why=="native-driver-requires-original-character:unit"
    and not board_pair.train_transport_rail_0835,
    "0836 failed to accept genuine burning fuel or bypassed unit refusal")
  engine_loco.burner.remaining_burning_fuel=0
  native_fuel.amount=2
  local stocked,stocked_why=Track.service_first_train_board_0836(board_pair)
  assert(not stocked
    and stocked_why=="native-driver-requires-original-character:unit"
    and not board_pair.train_transport_rail_0835,
    "0836 did not accept real stocked coal or miscredited Magos boarding")
  native_fuel.valid=false
  local unreadable,unreadable_why=Track.service_first_train_board_0836(board_pair)
  assert(not unreadable
    and unreadable_why=="original-train-live-fuel-unobservable"
    and not board_pair.train_transport_rail_0835,
    "0836 accepted unobservable locomotive fuel")
  native_fuel.valid=true
  _G.TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528=prior
end
print("[rail-board-0836] PASS 0528 custody, live coal/burner/empty/unknown fuel refusal and original unit identity")
-- The deterministic native extension scorer is a pure, separately executed
-- Lua contract. It only ranks geometry; it never creates rails or ghosts.
dofile("tests/unit/rail_route_choice_1403.lua")
