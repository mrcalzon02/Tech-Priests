-- Synthetic Lua diagnostic: same-category pressure work, not native Factorio UPS.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local C=require('scripts.core.broker_pressure_cache_1502')
local storage={tech_priests={runtime_tick_broker_0600={windows={[0]={event_repair_submitted=200,directed_wake_issued=0,event_construction_submitted=0,directed_wake_construction_issued=0,combat_targets_seen=25,combat_wake_issued=0}}}}}
local game={tick=5}
local read_count=0
local function root()
 local t=storage.tech_priests or{};storage.tech_priests=t
 local r=t.runtime_tick_broker_0600 or {windows={},stats={},service_stats={},recent={},external_stats={},profiler={enabled=false}}
 t.runtime_tick_broker_0600=r
 r.stats=r.stats or {};r.service_stats=r.service_stats or {};r.recent=r.recent or {};r.windows=r.windows or {};
 r.external_stats=r.external_stats or{};r.profiler=r.profiler or{};return r
end
local function rolling_sum(metric, windows_back)
 local r,total,current=root(),0,math.floor(game.tick/3600)
 for i=0,math.max(1,tonumber(windows_back)or 1)-1 do
  local bucket=r.windows[current-i]
  if bucket then total=total+(tonumber(bucket[metric])or 0)end
 end
 return total
end
local function compute(cat)
 read_count=read_count+1
 if cat=='repair' then
  return rolling_sum('event_repair_submitted',1)+rolling_sum('directed_wake_issued',1)
 elseif cat=='construction' then
  return rolling_sum('event_construction_submitted',1)+rolling_sum('directed_wake_construction_issued',1)
 elseif cat=='combat' then
  return rolling_sum('combat_targets_seen',1)+rolling_sum('combat_wake_issued',1)
 end
 return 0
end
local N=20000
local cats={'repair','repair','repair','repair','construction','repair','combat','repair'}
local function benchmark(cached)
  read_count=0
  local start=os.clock()
  local check=0
  for t=1,N do
    if cached then C.begin_pulse() end
    for _,cat in ipairs(cats) do
      if cached then check=check+C.read(cat,compute) else check=check+compute(cat) end
    end
  end
  return (os.clock()-start)*1000,read_count,check
end
local before,rb,result1=benchmark(false)
local after,ra,result2=benchmark(true)
assert(math.abs(result1-result2)<0.01)
assert(rb==N*#cats and ra==N*3,'category cache did not reduce computations')
print(string.format('[broker-pressure-cache-1502-perf] old_evaluations=%d new_evaluations=%d old_ms=%.3f new_ms=%.3f',rb,ra,before,after))
