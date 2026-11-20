-- Claude T1-12: protected manual/active work must never be slept.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local C=require("scripts.core.idle_activity_classification_1492")
for _,reason in ipairs({"manual", "force-dispatch", "recovery", "repair", "COMBAT", "debug-probe", "remote-manual-order"}) do
  assert(C.should_never_skip(reason),"protected reason was suppressed: "..reason)
  assert(C.should_never_skip(reason),"memoized protected reason changed")
end
for _,reason in ipairs({"", "broker", "scheduled", "idle-probe", "routine", "automatic"}) do
  assert(not C.should_never_skip(reason),"idle reason was marked protected: "..reason)
end
assert(not C.should_never_skip(nil) and not C.should_never_skip(nil))
local active_keys={"emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333",
  "construction_task", "combat_target", "repair_target", "consecration_target",
  "active_consecration_0515", "active_repair_0516", "combat_repair_0517",
  "logistics_fetch_task", "active_logistics_fetch", "machine_fulfillment_task"}
assert(not C.has_active_order(nil) and not C.has_active_order({mode="idle"}))
for _,key in ipairs(active_keys) do
  local p={mode="idle",[key]={valid=true}}
  assert(C.has_active_order(p),"active field missed: "..key)
  p[key]={status="active"}
  assert(C.has_active_order(p),"active task status missed: "..key)
end
for _,mode in ipairs({"combat", "repairing", "consecrating", "gathering", "crafting", "constructing", "mine", "acquiring"}) do
  assert(C.has_active_order({mode=mode}),"active mode missed: "..mode)
end
for _,mode in ipairs({"idle", "returning", "no-managed-priority-claimed"}) do
  assert(not C.has_active_order({mode=mode}),"idle mode not recognized: "..mode)
end
for _,key in ipairs({"current","active","current_order"}) do
  assert(C.has_active_order({order_queue_0469={[key]={}}}),"queued work missed: "..key)
end
assert(C.has_active_order({order_queue_0469={pending={{}}}}))
assert(C.has_active_order({order_queue_0469={queue={{}}}}))
-- Protection must survive bounded memo table recycling, no unbounded growth.
for i=1,1000 do
  assert(not C.should_never_skip("routine-"..i))
end
assert(C.should_never_skip("debug-probe"))
assert(C.has_active_order({repair_target={valid=true}}))
print("[idle-activity-classification-1492] PASS")
