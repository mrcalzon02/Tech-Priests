-- 1075: a late raw registration may replace the canonical robot-built
-- dispatcher. Factorio calls only the last script.on_event handler; restoring
-- the owner-keyed router must preserve every original observer exactly once.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local handlers,filters,raw_calls={}, {},0
local ROBOT_BUILT=118
game={tick=1075}
script={
  on_event=function(id,handler) handlers[id]=handler end,
  get_event_handler=function(id) return handlers[id] end,
  get_event_filter=function(id) return filters[id] end,
  set_event_filter=function(id,value) filters[id]=value end,
}
defines={events={on_robot_built_entity=ROBOT_BUILT}}
local Registry=require("scripts.core.runtime_event_registry")
local calls_a,calls_b=0,0
assert(Registry.on_event(ROBOT_BUILT,function(event)
  calls_a=calls_a+1
  assert(event.entity and event.robot and event.entity.name=="senior-cogitator-station")
end,nil,{owner="construction",route="observe-real-build",priority=0}))
assert(Registry.on_event(ROBOT_BUILT,function(event)
  calls_b=calls_b+1
  assert(event.robot.unit_number==42)
end,nil,{owner="ci_ground_rank_harness",route="S2-read-only-native-robot-built-observer",priority=1100}))
local first=Registry.event_delivery_status(ROBOT_BUILT)
assert(first.installed and first.verified and first.routes==2,
  "robot-build canonical event registration not initially connected")
-- Emulate a real late raw script.on_event owner that replaces the router.
script.on_event(ROBOT_BUILT,function()raw_calls=raw_calls+1 end)
filters[ROBOT_BUILT]={{filter="name",name="iron-chest"}}
local broken=Registry.event_delivery_status(ROBOT_BUILT)
assert(not broken.verified and broken.filter_present,
  "late raw robot event overwrite was not detected")
local ok,reason=Registry.reconcile_event(ROBOT_BUILT)
assert(ok and reason=="canonical","robot event repair failed: "..tostring(reason))
local repaired=Registry.event_delivery_status(ROBOT_BUILT)
assert(repaired.verified and not repaired.filter_present and repaired.routes==2,
  "robot event repair did not preserve all routes and clear raw engine filters")
handlers[ROBOT_BUILT]({entity={name="senior-cogitator-station"},
  robot={unit_number=42}})
assert(calls_a==1 and calls_b==1 and raw_calls==0,
  "native robot event not delivered through canonical owner-keyed routes")
local ok_again=Registry.reconcile_event(ROBOT_BUILT)
assert(ok_again and Registry.event_delivery_status(ROBOT_BUILT).routes==2,
  "robot event reconciliation is not idempotent")
handlers[ROBOT_BUILT]({entity={name="senior-cogitator-station"},
  robot={unit_number=42}})
assert(calls_a==2 and calls_b==2 and raw_calls==0,
  "repeated repair duplicated or lost native construction event listeners")
-- 1076: a raw handler can also replace the dispatcher AFTER the final
-- installer. Registering a new canonical owner must repair delivery without
-- waiting for another finalizer, preserving the original listeners once.
script.on_event(ROBOT_BUILT,function() raw_calls=raw_calls+1 end)
filters[ROBOT_BUILT]={{filter="name",name="iron-chest"}}
local calls_c=0
assert(Registry.on_event(ROBOT_BUILT,function(event)
  calls_c=calls_c+1
  assert(event.entity.name=="senior-cogitator-station")
end,nil,{owner="late-robot-observer",route="read-only-build",priority=1200}),
  "late owner registration failed to restore canonical dispatcher")
local late=Registry.event_delivery_status(ROBOT_BUILT)
assert(late.verified and not late.filter_present and late.routes==3,
  "late owner registration retained a raw handler or stale engine filter")
handlers[ROBOT_BUILT]({entity={name="senior-cogitator-station"},
  robot={unit_number=42}})
assert(calls_a==3 and calls_b==3 and calls_c==1 and raw_calls==0,
  "late robot observer lost or duplicated native event delivery")
-- Replacing the same owner-keyed route must not install a fourth listener.
assert(Registry.on_event(ROBOT_BUILT,function(event)
  calls_c=calls_c+1
  assert(event.robot.unit_number==42)
end,nil,{owner="late-robot-observer",route="read-only-build",priority=1200}))
assert(Registry.event_delivery_status(ROBOT_BUILT).routes==3,
  "late route upsert duplicated an owner-keyed event listener")
handlers[ROBOT_BUILT]({entity={name="senior-cogitator-station"},
  robot={unit_number=42}})
assert(calls_a==4 and calls_b==4 and calls_c==2 and raw_calls==0,
  "late route replacement duplicated or lost a physical build event")
-- The production final installer must actually perform the tested rebind.
local f=assert(io.open("tech-priests_src/control.lua","rb"))
local control=f:read("*a");f:close()
assert(control:find("registry.reconcile_event(\n    defines.events.on_robot_built_entity",1,true),
  "final control.lua installer omitted native robot-build registry reconciliation")
print("[native-robot-event-delivery-1075] PASS late raw override restored, late owner rebind verified, three routes exact-once, engine filters cleared")
