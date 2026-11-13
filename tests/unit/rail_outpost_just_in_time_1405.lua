-- 1405: no speculative construction work while a single native object
-- is unbuilt. Player-built alternatives are valid only with native proof.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local JIT=require("scripts.core.rail_outpost_just_in_time_1405")
local function check(ok,why)
  assert(ok,"[rail-outpost-jit-1405] "..why)
end
local mission={root_station_unit=11,force_index=1,surface_index=2,
  target={x=300,y=200}}
local layout={read_only=true,construction_authorized=false,counts={
  loading_train_stops=1,remote_cogitator_stations=1,
  drills=2,loading_buffer_chests=4,feed_inserters=4,
  loading_inserters=4,cargo_wagons=2,home_unloading_inserters=4}}
local site={role="outpost-stop",entity_name="train-stop",
  position={x=307,y=205},native_site_verified=true,
  real_item_available=true}
local candidate,why=JIT.next(mission,layout,{
  world_revision=0,candidate=site},100)
check(candidate and why=="one-virtual-object-proposed"
  and candidate.role=="outpost-stop"
  and candidate.physical_build_authorized==false
  and candidate.construction_ghosts==0,
  "first planning call issued more than a virtual object")
local original=candidate
for t=101,190 do
  local other,reason=JIT.next(mission,layout,{
    world_revision=0,candidate={role="drills",entity_name="burner-mining-drill",
      position={x=400,y=300},native_site_verified=true,
      real_item_available=true}},t)
  check(other==nil and reason=="awaiting-one-original-object"
    and mission.outpost_jit_1405.ticket==original,
    "uncleared object triggered plan-ahead or replanning on idle tick")
end
local _,reason=JIT.next(mission,layout,{
  world_revision=1,physical_custody_active=true},191)
check(reason=="physical-item-custody-preserved"
  and mission.outpost_jit_1405.ticket==original,
  "player change discarded a live physical construction lease")
_,reason=JIT.next(mission,layout,{
  world_revision=1,physical_custody_active=false},192)
check(reason=="changed-world-invalidated-uncommitted-intent"
  and not mission.outpost_jit_1405.ticket,
  "changed construction site failed to invalidate only virtual ticket")
_,reason=JIT.next(mission,layout,{
  world_revision=1,candidate=site},193)
check(reason=="planning-interval-not-due",
  "changed world immediately triggered expensive replanning")
local new_site={role="outpost-stop",entity_name="train-stop",
  position={x=311,y=211},native_site_verified=true,
  real_item_available=true}
local fresh=JIT.next(mission,layout,{
  world_revision=1,candidate=new_site},252)
check(fresh and fresh.position.x==311 and fresh.position.y==211,
  "replanning ignored the new player-selected layout")
local foreign={valid=true,name="train-stop",unit_number=500,
  position={x=311,y=211},force={index=9},surface={index=2}}
_,reason=JIT.next(mission,layout,{world_revision=1,
  native_entity=foreign,native_role="outpost-stop",role_verified=true},253)
check(reason=="awaiting-one-original-object",
  "foreign native object was adopted")
local player_stop={valid=true,name="train-stop",unit_number=501,
  position={x=315,y=205},force={index=1},surface={index=2}}
_,reason=JIT.next(mission,layout,{world_revision=2,
  native_entity=player_stop,native_role="outpost-stop",
  role_verified=true},254)
check(reason=="native-object-accepted-rethink-after-interval"
  and mission.outpost_jit_1405.ticket==nil
  and mission.outpost_jit_1405.accepted_count==1,
  "verified alternative player stop was not adopted")
_,reason=JIT.next(mission,layout,{world_revision=2},255)
check(reason=="stage-finished-reinspect-next-interval"
  and mission.outpost_jit_1405.stage==2,
  "station plan advanced before verified construction")
_,reason=JIT.next(mission,layout,{world_revision=2,
  candidate={role="command-anchor",entity_name="senior-cogitator-station",
    position={x=302,y=206},native_site_verified=true,
    real_item_available=true}},256)
check(reason=="planning-interval-not-due",
  "next planning stage did not honor slow re-evaluation")
local command_intent=JIT.next(mission,layout,{world_revision=2,
  candidate={role="command-anchor",entity_name="senior-cogitator-station",
    position={x=302,y=206},native_site_verified=true,
    real_item_available=true}},315)
check(command_intent and command_intent.role=="command-anchor",
  "one valid current-stage object was not proposed")
local command_entity={valid=true,name="senior-cogitator-station",
  unit_number=502,position={x=302,y=206},
  force={index=1},surface={index=2}}
_,reason=JIT.next(mission,layout,{world_revision=3,
  native_role="command-anchor",native_entity=command_entity,
  role_verified=true,physical_custody_active=true},316)
check(reason=="physical-item-custody-preserved"
  and mission.outpost_jit_1405.ticket==command_intent,
  "player alternative displaced active original cargo")
_,reason=JIT.next(mission,layout,{world_revision=3,
  native_role="command-anchor",native_entity=command_entity,
  role_verified=true},317)
check(reason=="native-object-accepted-rethink-after-interval",
  "verified original command station not adopted after custody released")
_,reason=JIT.next(mission,layout,{world_revision=3},318)
check(reason=="stage-finished-reinspect-next-interval"
  and mission.outpost_jit_1405.stage==3,
  "command construction did not trigger next stage")
_,reason=JIT.next(mission,layout,{world_revision=3},319)
check(reason=="native-stage-geometry-unresolved",
  "unknown power-link length was invented before native survey")
local power_ticket,policy=JIT.next(mission,layout,{
  world_revision=3,stage_required_objects=2,
  candidate={role="power-link",entity_name="medium-electric-pole",
    position={x=310,y=200},native_site_verified=true,
    real_item_available=true}},379)
check(policy=="one-virtual-object-proposed" and power_ticket
  and JIT.current_stage(mission).key=="power-link",
  "dynamic power stage did not issue one bounded object")
_,reason=JIT.next(mission,layout,{world_revision=3},380)
check(reason=="awaiting-one-original-object",
  "cached native power goal lost during idle no-recompute ticks")
local pending=mission.outpost_jit_1405.ticket
check(JIT.native_removed(mission,501,381,true),
  "loss of previously adopted player stop not detected")
check(mission.outpost_jit_1405.stage==1
  and mission.outpost_jit_1405.ticket==pending,
  "prior-stage loss did not rewind or discarded live carried item")
_,reason=JIT.next(mission,layout,{
  world_revision=4,physical_custody_active=true},382)
check(reason=="physical-item-custody-preserved",
  "previous-stage invalidation overwrote physical custody")
_,reason=JIT.next(mission,layout,{
  world_revision=4,physical_custody_active=false},383)
check(reason=="native-loss-stage-reinspection"
  and mission.outpost_jit_1405.ticket==nil,
  "physical custody release did not enable safe reinspection")
_,reason=JIT.next(mission,layout,{world_revision=4,
  candidate=site},384)
check(reason=="planning-interval-not-due",
  "missing station immediately triggered plan spam")
check(not JIT.native_removed(mission,99999,385,false),
  "foreign or unobserved entity invalidated outpost history")
-- One physical inserter may not satisfy both the feeder and loader
-- roles simply because the planner reaches the next similarly named stage.
local m2={root_station_unit=22,force_index=1,surface_index=2,
  target={x=300,y=200},
  outpost_jit_1405={stage=8,accepted_count=0,
    accepted_units={},accepted_history={
      [7]={count=1,units={[600]=true}}},
    ticket=nil,last_world_revision=0,next_think_tick=0}}
local shared={valid=true,name="inserter",unit_number=600,
  force={index=1},surface={index=2},position={x=300,y=200}}
local denied,reason=JIT.next(m2,layout,{
  world_revision=0,native_role="load-inserters",
  native_entity=shared,role_verified=true},400)
check(denied==nil and reason=="waiting-native-next-object-preflight"
  and m2.outpost_jit_1405.accepted_count==0,
  "same physical inserter was double-counted in two loading stages")
local alternate={valid=true,name="inserter",unit_number=601,
  force={index=1},surface={index=2},position={x=301,y=201}}
local adopted,reason=JIT.next(m2,layout,{
  world_revision=1,native_role="load-inserters",
  native_entity=alternate,role_verified=true},401)
check(adopted==nil
  and reason=="native-object-accepted-rethink-after-interval"
  and m2.outpost_jit_1405.accepted_count==1,
  "distinct valid physical loading inserter could not be adopted")
print("[rail-outpost-jit-1405] PASS one object per stage, no idle planning, change revision, player adoption, physical custody, native loss rollback")
