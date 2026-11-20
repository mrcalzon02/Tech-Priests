-- Regression 1499: an off/unavailable profiler must allocate no route stats.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=10}
local B=require("scripts.core.runtime_tick_broker")
local r=B.root()
assert(r.profiler.enabled==false and next(r.profiler.routes)==nil)
for i=1,10000 do
  assert(B.record_profile("broker","idle-service","economy",nil,true)==nil)
end
assert(next(r.profiler.routes)==nil, "disabled profiler created route records")
local calls=0
local profiler=setmetatable({}, {__tostring=function()calls=calls+1;return "0.75" end})
local record=B.record_profile("broker","idle-service","economy",profiler,true)
assert(record and record.calls==1 and record.total_ms==0.75
 and record.avg_ms==0.75 and record.worst_ms==0.75 and record.errors==0,
 "valid profiler lost its timing record")
assert(calls==1)
assert(B.record_profile("broker","idle-service","economy",nil,false)==nil)
assert(record.calls==1 and record.errors==0,
 "missing profiler was recorded as a failed measured service")
local failed=B.record_profile("broker","idle-service","economy",profiler,false)
assert(failed==record and record.calls==2 and record.errors==1
 and record.total_ms==1.5 and record.avg_ms==0.75,
 "measured failure/timing accumulation changed")
assert(B.record_profile("broker","unavailable","economy",false,false)==nil)
assert(r.profiler.routes["broker:unavailable"]==nil)
assert(r.profiler.routes["broker:idle-service"]==record)
print("[broker-profiler-off-1499] PASS: 10000 off, 2 measured")
