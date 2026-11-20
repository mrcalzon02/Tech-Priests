-- Claude T1-04: routine duplicates preserve other priests' no-work windows.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local policy=require("scripts.core.work_queue_duplicate_wake_1490")
local original={priority=100,expires_tick=500,position={x=4,y=5}}
assert(policy.reason(nil,{priority=100},100)=="new-order")
assert(policy.reason(original,{priority=100,expires_tick=700},100)==nil,
  "expiry extension of still-live order should not globally wake priests")
assert(policy.reason(original,{priority=99,expires_tick=700},100)==nil,
  "lower priority duplicates should not globally wake priests")
assert(policy.reason(original,{priority=101,expires_tick=500},100)=="priority-raised",
  "higher-priority work must wake no-work readers")
assert(policy.reason(original,{priority=100,expires_tick=500},500)=="expired-revived",
  "expired order revived at its deadline must wake no-work readers")
assert(policy.reason(original,{priority=100},501)=="expired-revived")
assert(policy.reason({priority=100,expires_tick=0},{priority=100},0)=="expired-revived")
local calls=0
for i=1,10000 do
  if policy.reason(original,{priority=100,expires_tick=500+i},100) then calls=calls+1 end
end
assert(calls==0,"event storm awakened idle priests for identical work")
print("[work-queue-duplicate-wake-1490] PASS")
