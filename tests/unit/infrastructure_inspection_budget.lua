-- Exercise the installed owner's real loop, including no-op work, roster
-- changes and saved cursor recovery. These are work bounds, not UPS timings.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
game={tick=100}
storage={tech_priests={pairs_by_station={}}}
local roster=storage.tech_priests.pairs_by_station
for i=1,41 do
  roster[i]={station={valid=true,unit_number=i},priest={valid=true},test_id=i}
end
local registered
_G.TechPriestsRuntimeTickBroker0600={register_service=function(spec)
  registered=spec
  return spec
end}
local M=require("scripts.core.infrastructure_first_governor_0640")
assert(M.install()==true and registered.name=="infrastructure_first_governor_0640")
local seen,calls={},0
M.service_pair=function(pair)
  calls=calls+1
  seen[pair.test_id]=(seen[pair.test_id] or 0)+1
  return false -- Most expensive failure mode: all inspections find no action.
end
for pulse=1,5 do
  local before=calls
  local result=registered.fn({tick=game.tick},10)
  assert(calls-before==10 and result.processed==10 and result.acted==0
    and result.waiting==10,"no-op scans exceeded or misreported offered budget")
  game.tick=game.tick+M.tick_interval
end
for i=1,41 do assert(seen[i],"round-robin starved station "..i) end
local saved=storage.tech_priests[M.storage_key].service_cursor
assert(type(saved)=="number","cursor must be a serializable station key")
local before=calls
local zero=registered.fn({},0)
assert(calls==before and zero.processed==0,"zero budget executed work")
local _,limited=M.service_all("test",1000)
assert(limited.processed==32,"owner ceiling ignored")

-- Remove the saved cursor as occurs during mining/death and service again.
saved=storage.tech_priests[M.storage_key].service_cursor
roster[saved]=nil
local recovered=registered.fn({},10)
assert(recovered.processed==10,"deleted cursor broke traversal")

-- Reload the module against persisted owner state; no closure/roster cache
-- may be required to preserve forward progress.
package.loaded["scripts.core.infrastructure_first_governor_0640"]=nil
local Reloaded=require("scripts.core.infrastructure_first_governor_0640")
local resumed={}
Reloaded.service_pair=function(pair) resumed[#resumed+1]=pair.test_id;return true end
local acted,after_reload=Reloaded.service_all("reload",3)
assert(acted==3 and after_reload.processed==3 and #resumed==3,
  "save-state cursor did not resume with matching action accounting")

-- A small/invalid roster must be inspected once at most, and thrown work
-- must consume its slot while subsequent pairs still receive service.
storage.tech_priests.pairs_by_station={
  [201]={station={valid=false},priest={valid=true},test_id=201},
  [202]={station={valid=true,unit_number=202},priest={valid=true},test_id=202},
  [203]={station={valid=true,unit_number=203},priest={valid=true},test_id=203},
}
Reloaded.service_pair=function(pair)
  if pair.test_id==202 then error("expected fixture failure") end
  return true
end
local n,small=Reloaded.service_all("small",10)
assert(n==1 and small.processed==3 and small.invalid==1 and small.failed==1,
  "invalid/failed slots escaped budget or small roster repeated")
storage.tech_priests.pairs_by_station={}
local _,empty=Reloaded.service_all("empty",10)
assert(empty.processed==0,"empty roster consumed work")
print("[infrastructure-inspection-budget] PASS offered=10 inspected=10 acted=0; "..
  "41 stations reached in 5 pulses; zero/max budgets, deletion, persisted cursor, failures")
