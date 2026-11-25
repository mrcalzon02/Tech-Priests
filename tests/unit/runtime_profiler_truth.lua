-- Missing native durations are unknown, never zero or object-address digits.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=0}
local messages={}
log=function(message) messages[#messages+1]=message end
local function timer(text)
  return setmetatable({stop=function() end},{__tostring=function()return text end})
end
local Broker=require("scripts.core.runtime_tick_broker")
local native=timer("LuaProfiler: 0x12345")
local record=Broker.record_profile("broker","native","test",native,true)
assert(record.calls==1 and record.timed_samples==0)
assert(record.total_ms==nil and record.avg_ms==nil and record.worst_ms==nil,
  "unavailable native time became numeric evidence")
assert(record.unavailable_samples==1 and record.native_log_samples==1)
assert(type(messages[1])=="table" and messages[1][#messages[1]]==native,
  "native profiler was stringified before engine log serialization")
local report=table.concat(Broker.profiler_report_lines(20),"\n")
assert(report:find("avg_ms=unavailable",1,true)
  and report:find("worst_ms=unavailable",1,true))
for _,bad in ipairs{"0.75","table: 0x0012","LuaProfiler 2.1.25","Duration: -1ms"}do
  local r=Broker.record_profile("broker",bad,"test",timer(bad),true)
  assert(r.timed_samples==0 and r.total_ms==nil,"invalid timing text accepted: "..bad)
end
local zero=Broker.record_profile("broker","zero","test",timer("Duration: 0ms"),true)
assert(zero.timed_samples==1 and zero.avg_ms==0 and zero.worst_ms==0,
  "a measured zero must remain distinguishable from missing timing")
Broker.record_profile("broker","native","test",timer("Duration: 4ms"),true)
Broker.record_profile("broker","native","test",native,false)
Broker.record_profile("broker","native","test",timer("6ms"),true)
assert(record.calls==4 and record.timed_samples==2 and record.errors==1)
assert(record.total_ms==10 and record.avg_ms==5 and record.worst_ms==6,
  "unmeasured calls diluted the timing average")
local old={section="broker",name="legacy",calls=90,errors=2,
  avg_ms=0,total_ms=0,worst_ms=0,last_ms=0}
Broker.root().profiler.routes["broker:legacy"]=old
Broker.profiler_report_lines(20)
assert(old.calls==90 and old.errors==2 and old.timed_samples==0)
assert(old.avg_ms==nil and old.total_ms==nil and old.worst_ms==nil,
  "old-save false timing survived report normalization")

local event_handlers,tick_handlers={},{}
script={on_event=function(id,handler)event_handlers[id]=handler end,
  get_event_handler=function(id)return event_handlers[id]end,
  get_event_filter=function()return nil end,set_event_filter=function()end,
  on_nth_tick=function(tick,handler)tick_handlers[tick]=handler end}
local allocated,active_timer=0,native
helpers={create_profiler=function()allocated=allocated+1;return active_timer end}
local Registry=require("scripts.core.runtime_event_registry")
Registry.on_event(701,function()return false end,nil,
  {owner="truth",route="callback",category="test"})
for i=1,50 do event_handlers[701]({name=701,tick=i})end
assert(allocated==0,"profiling-off allocated a profiler")
local r=Registry.stats["event:701:truth:callback"]
assert(r.calls==50 and r.timed_samples==0 and r.total_ms==nil)
Registry.set_profiler_enabled(true)
event_handlers[701]({name=701,tick=51})
assert(r.calls==51 and r.profiled_calls==1 and r.timed_samples==0)
assert(r.total_ms==nil and r.avg_ms==nil and r.worst_ms==nil)
assert(table.concat(Registry.profiler_report_lines(20),"\n")
  :find("avg_ms=unavailable",1,true))
active_timer=timer("Duration: 2.5ms")
event_handlers[701]({name=701,tick=52})
assert(r.calls==52 and r.profiled_calls==2 and r.timed_samples==1)
assert(r.total_ms==2.5 and r.avg_ms==2.5,
  "profiling-off calls diluted the measured registry average")

-- The existing CI aggregate route must also serialize the live profiler.
Registry.set_profiler_enabled(false)
active_timer=native
Registry.on_nth_tick(5,function()return false end,
  {owner="truth",route="nth",category="test"})
_G.TP_CI_SAVE_RELOAD_SMOKE=true
_G.TP_CI_RUNTIME_PROFILE_1064=true
game.tick=300
tick_handlers[5]({tick=300})
local last=messages[#messages]
assert(type(last)=="table" and last[#last]==native,
  "1195 aggregate sample lost native duration serialization")
local before=allocated
_G.TP_CI_RUNTIME_PROFILE_1064=false
tick_handlers[5]({tick=600})
assert(allocated==before,"disabled profiling still allocated a native object")
print("[runtime-profiler-truth] PASS unknown, timed denominator, old-save invalidation, native logs, off path")
