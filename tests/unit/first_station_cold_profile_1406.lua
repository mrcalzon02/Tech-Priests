-- Opt-in profiler scope and non-serializable LuaProfiler regression.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
TIER_CONFIGS={["junior-cogitator-station"]={tier="junior"}}
game={tick=600}
local allocated,logged,closed=0,{},0
helpers={create_profiler=function()
  allocated=allocated+1
  return {valid=true,stop=function()closed=closed+1 end}
end}
log=function(message)logged[#logged+1]=message end
local Profile=require("scripts.core.first_station_cold_profile_1406")
assert(Profile.install()==true and Profile.enabled()==false)
local station={valid=true,unit_number=100,name="junior-cogitator-station"}
assert(not Profile.begin_pair(station) and allocated==0,
  "cold profile allocated native timers when disabled")
assert(Profile.set_enabled(true))
local event={entity=station}
local token=Profile.start_event("build",event)
assert(token and Profile.begin_pair(station),"first original station profile not started")
Profile.checkpoint("spawn-position")
Profile.checkpoint("hidden-logistic-support")
Profile.checkpoint("first-movement-command")
assert(Profile.finish_pair("physical-pair-registered"))
assert(Profile.stop_event(token))
assert(not Profile.stop_event(token),"stop-event duplicated native profile")
assert(closed==allocated and allocated==5,
  "unclosed or duplicate native profiling objects")
local has_event,has_pair,has_cache,has_move=false,false,false,false
for _,entry in ipairs(logged)do
  local text=type(entry)=="table" and table.concat({
    tostring(entry[2]or ""),tostring(entry[4]or ""),
    tostring(entry[6]or ""),tostring(entry[8]or "")},":") or tostring(entry)
  if text:find("all-build-event-routes",1,true)then has_event=true end
  if text:find("create-pair-total",1,true)then has_pair=true end
  if text:find("hidden-logistic-support",1,true)then has_cache=true end
  if text:find("first-movement-command",1,true)then has_move=true end
end
assert(has_event and has_pair and has_cache and has_move,
  "native phase attribution omitted event/pair/support/movement")
local state=storage.tech_priests.first_station_cold_profile_1406
assert(state.enabled==true and state.last_observed_station==100)
for _,value in pairs(state)do
  assert(type(value)~="table","LuaProfiler illegally persisted to storage")
end
-- A second, already-paired station may not be reprofiled as first.
storage.tech_priests.pairs_by_station[100]={
  station=station,priest={valid=true,unit_number=101}}
assert(not Profile.begin_pair(station) and not Profile.start_event("build",event),
  "existing pair retriggered native cold-start measurement")
assert(Profile.set_enabled(false)==false)
print("[first-station-cold-profile-1406] PASS disabled fast-path, five native clocks, staged event/placement attribution and save-safe state")
