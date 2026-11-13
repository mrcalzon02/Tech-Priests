-- Regression 1068: per-service profiler is CI-only, bounded, observational,
-- and never alters the canonical broker's due cadence or action reporting.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=0}
local created=0
-- Factorio 2.1.7 removed game.create_profiler; only helpers exposes
-- the native profiler. This test must fail if the broker silently retains
-- the obsolete API in its CI and per-service sampler.
helpers={create_profiler=function()
  created=created+1
  return {stop=function()return true end}
end}
local events={}
log=function(msg)
  if type(msg)~="table" then return end
  local parts={}
  for _,v in ipairs(msg) do
    if type(v)=="string" or type(v)=="number" then
      parts[#parts+1]=tostring(v)
    end
  end
  events[#events+1]=table.concat(parts)
end
local Broker=require("scripts.core.runtime_tick_broker")
local calls,budgets=0,{}
local svc=Broker.register_service{
  name="probe_1068",category="construction",priority=50,
  interval=5,budget=2,dynamic_budget=false,
  fn=function(_,offered)
    calls=calls+1
    budgets[#budgets+1]=offered
    return{processed=1,acted=0,waiting=1,detail="fixture-waiting"}
  end
}
assert(svc and Broker.service_count()==1,"fixture broker not registered")
_G.TP_CI_SAVE_RELOAD_SMOKE=true
_G.TP_CI_RUNTIME_PROFILE_1064=true
for i=1,33 do
  game.tick=i*5
  Broker.pulse({tick=game.tick})
end
assert(calls==33,"CI service sampler changed canonical dispatch cadence")
for _,budget in ipairs(budgets)do
  assert(budget==2,"CI sampling changed broker budgets")
end
local individual=0
for _,event in ipairs(events)do
  if event:find("[TP-RUNTIME-SERVICE-1068]",1,true) then
    individual=individual+1
    assert(event:find("tick=160",1,true)
      and event:find("name=probe_1068",1,true)
      and event:find("scope=service-callback",1,true),
      "CI sampled the wrong service, scope or invocation")
  end
end
assert(individual==1,"per-service timing was not bounded to every 32nd call")
local previously=created
_G.TP_CI_RUNTIME_PROFILE_1064=false
for i=34,65 do
  game.tick=i*5
  Broker.pulse({tick=game.tick})
end
assert(calls==65 and created==previously,
  "disabled profiling still allocated profilers or disrupted work")
local after=0
for _,event in ipairs(events)do
  if event:find("[TP-RUNTIME-SERVICE-1068]",1,true)then after=after+1 end
end
assert(after==1,"disabled CI profile emitted service samples")
print("[broker-service-profile-1068] PASS CI-only bounded sample, unchanged dispatch, disabled no-overhead")
