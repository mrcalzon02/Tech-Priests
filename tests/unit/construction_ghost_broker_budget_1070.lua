-- No-action, invalid and failed station visits count against the offered
-- budget. A saved unsorted roster must progress without collecting/sorting it.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=10700}
storage={tech_priests={pairs_by_station={}}}
local Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
local map=storage.tech_priests.pairs_by_station
local ids={11,21,31,41,51,61}
for _,id in ipairs(ids)do
  map[id]={station={valid=true,unit_number=id},priest={valid=true,unit_number=id+1000}}
end
local visited={}
local function blocked_ghost(pair)
  local id=pair.station.unit_number;visited[#visited+1]=id
  if id==21 then error("temporary construction fixture exception")end
  return id==41,"ghost-created-or-pending"
end
Ghost.service_pair=blocked_ghost
local function eval(budget)
  local start=#visited
  local sorted=table.sort
  table.sort=function()error("roster must not sort the entire station population")end
  local acted,processed,exhausted,failed=Ghost.service_all("broker",budget)
  table.sort=sorted
  assert(processed<=math.min(budget,Ghost.max_pairs_per_pulse)
    and #visited-start<=processed and acted+failed<=processed,
    "ghost caller exceeded its offered inspection budget")
  assert(exhausted==(processed==math.min(budget,Ghost.max_pairs_per_pulse)and budget>0),
    "ghost caller reported an inaccurate budget boundary")
  return acted,processed,failed
end
local acted,processed,failed=eval(0)
assert(acted==0 and processed==0 and failed==0 and #visited==0)
local totals={0,0,0}
for _=1,3 do
  acted,processed,failed=eval(2)
  totals[1],totals[2],totals[3]=totals[1]+acted,totals[2]+processed,totals[3]+failed
end
local seen={}
for _,id in ipairs(visited)do assert(not seen[id],"no-action station starved the rest of the roster");seen[id]=true end
for _,id in ipairs(ids)do assert(seen[id],"station omitted from a complete bounded sweep")end
assert(totals[1]==1 and totals[2]==6 and totals[3]==1,"failed/no-action visits were uncharged")
local first={table.unpack(visited)}
eval(2)
package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]=nil
Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
Ghost.service_pair=blocked_ghost
eval(2);eval(2)
for i=1,6 do assert(visited[6+i]==first[i],"saved cursor lost its place across module reload")end

-- Deleted cursor keys cannot be passed back to next(); invalid stations still
-- spend inspection work, while all remaining valid stations remain reachable.
local state=storage.tech_priests.construction_bootstrap_ghost_planner_0645
local deleted=state.service_cursor_1507
map[deleted]=nil
local invalid=next(map);map[invalid].station.valid=false
local start=#visited;local work=0
for _=1,12 do local _,n=eval(1);work=work+n end
local reached={}
for i=start+1,#visited do reached[visited[i]]=true;assert(visited[i]~=invalid,"invalid station was serviced")end
for id,pair in pairs(map)do if pair.station.valid then assert(reached[id],"deleted cursor starved a surviving station")end end
assert(work==12 and #visited-start<work,"invalid roster entries were not charged")

local hook
_G.TechPriestsRuntimeTickBroker0600={register_service=function(spec)
  if spec.name=="construction_bootstrap_ghost_planner_0645"then hook=spec end
  return spec
end}
package.loaded["scripts.core.construction_site_planner"]={install=function()return true end}
assert(Ghost.install()and hook and hook.budget==6,"ghost caller was not registered with the existing broker")
start=#visited
local pulse=hook.fn({tick=game.tick},1)
assert(pulse.processed==1 and pulse.acted+pulse.failed<=1 and pulse.exhausted
  and #visited-start<=1,"broker callback ignored its actual offered budget")
assert(state.service_cursor_1507~=nil,"roster cursor was not saved")
if #visited>start then
  assert(state.last_serviced_station_1070==visited[#visited],"last actual station was not persisted")
end
print("[ghost-broker-budget-1070] PASS bounded unsorted roster, attempted/invalid/failed accounting, fairness, reload and deleted cursor")
