-- The real 0338 constructor is the sole item-debit/build owner.
-- 0836 may only sequence and accept verified successful 0338 tasks.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Track=require("scripts.core.rail_track_frontier_0836")
game={tick=2400}
defines={direction={east=4},inventory={chest=1}}
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
local pending=mission.pending_rail_0836
pair.construction_last_task_0338={request_value=next_req,
  phase="aborted",result="engine-site-collision"}
pair.construction_request=next_req
local no_credit,blocked=Track.verify_pending(pair)
assert(not no_credit and blocked=="physical-rail-builder-aborted:engine-site-collision"
  and mission.status=="rail-track-blocked"
  and mission.rail_frontier_0836.segment==1
  and mission.pending_rail_0836==pending
  and item_count==699,
  "failed engine builder forged a track or lost unfinished request")
-- A new Magos or an uncharted/different target must never claim this
-- persistent mission or construct the pending physical rail on its behalf.
local other={station={valid=true,unit_number=999,
  name="planetary-magos-cogitator-station",
  surface=surface,force=force},priest={valid=true}}
other.remote_rail_outpost_0835=mission
assert(Track.service_pair(other)==false
  and mission.rail_frontier_0836.segment==1,
  "another Magos seized original track custody")
assert(scan_calls>2,"rail builder never verified real physical track")
print("[rail-track-frontier-0836] PASS real builder provenance, sequential track, save identity, failed-custody guard")
