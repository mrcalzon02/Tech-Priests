-- Regression 1473: filter/profiler hot path preserves owner-keyed event semantics.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
game={tick=0}
local handlers,tick_handlers={},{}
script={
  on_event=function(id,handler) handlers[id]=handler end,
  get_event_handler=function(id) return handlers[id] end,
  get_event_filter=function() return nil end,
  set_event_filter=function() end,
  on_nth_tick=function(n,handler) tick_handlers[n]=handler end,
}
local profilers,stops=0,0
helpers={create_profiler=function()
  profilers=profilers+1
  return setmetatable({stop=function() stops=stops+1 end},
    {__tostring=function() return "0.5" end})
end}
local R=require("scripts.core.runtime_event_registry")
local names,types=0,0
assert(R.on_event(101,function() names=names+1 end,
  {filter="name",name="steel-chest"},
  {owner="test-names",route="names",category="test",priority=10}))
assert(R.on_event(101,function() types=types+1 end,
  {filter="type",type="container"},
  {owner="test-types",route="types",category="test",priority=20}))
local nameRoute=R.event_routes["101"][1]
assert(nameRoute.profile_key=="event:101:test-names:names",
  "route profile-key was not precomputed")
for i=1,500 do
  game.tick=i
  handlers[101]({name=101,entity={
    name=i%2==0 and "steel-chest" or "stone-furnace",
    type=i%3==0 and "container" or "furnace", valid=true}})
end
assert(names==250 and types==166,"filter routing was changed")
assert(profilers==0,"disabled profiling allocated native objects")
local statName=R.stats["event:101:test-names:names"]
local statType=R.stats["event:101:test-types:types"]
assert(statName and statName.calls==250 and statType and statType.calls==166,
  "disabled-profiler call counts were lost")
R.set_profiler_enabled(true)
handlers[101]({name=101,entity={name="steel-chest",type="container",valid=true}})
assert(profilers==2 and stops==2,"Factorio helpers profiler not used")
assert(R.stats["event:101:test-names:names"].total_ms==0.5
  and R.stats["event:101:test-types:types"].total_ms==0.5,
  "numeric profile readings were not recorded")
local overwritten=false
script.on_event(101,function() overwritten=true end)
assert(R.reconcile_event(101)==true,"canonical dispatch was not restored")
handlers[101]({name=101,entity={name="steel-chest",type="container",valid=true}})
assert(not overwritten and names==252 and types==168,
  "canonical event rebind lost route delivery")
R.set_profiler_enabled(false)
local ticks=0
assert(R.on_nth_tick(5,function() ticks=ticks+1 end,
  {owner="test-nth",route="pulse",category="test"}))
_G.TP_CI_SAVE_RELOAD_SMOKE=true
_G.TP_CI_RUNTIME_PROFILE_1064=true
game.tick=300
tick_handlers[5]({tick=300})
assert(ticks==1 and profilers==5 and stops==5,
  "CI nth-tick profiler did not use helpers factory")
assert(R.stats["nth:5:test-nth:pulse"].calls==1,
  "nth-tick profile-key/call stats changed")
print("[event-registry-hot-path-1473] PASS")
