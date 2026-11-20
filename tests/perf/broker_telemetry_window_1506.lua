-- Synthetic broker telemetry CPU comparison; not Factorio UPS.
-- Original and optimized counter functions have their exact production shape.
local function root(state)
  state.tech_priests=state.tech_priests or {}
  local r=state.tech_priests.broker or {stats={},service_stats={},windows={}}
  state.tech_priests.broker=r
  r.stats=r.stats or {};r.service_stats=r.service_stats or {};r.windows=r.windows or {}
  return r
end
local function make_old(store, clock)
  local function remember_window(metric,amount)
    local r=root(store)
    local key=math.floor((tonumber(clock.tick) or 0)/3600)
    local window=r.windows[key]
    if not window then
      window={};r.windows[key]=window
      for old in pairs(r.windows) do if tonumber(old) and tonumber(old)<key-30 then r.windows[old]=nil end end
    end
    window[metric]=(window[metric] or 0)+(tonumber(amount) or 1)
  end
  local function stat(key,amount)
    local r=root(store)
    r.stats[key]=(r.stats[key] or 0)+(tonumber(amount) or 1)
    remember_window(key,amount)
  end
  local function service_stat(name,key,amount)
    local r=root(store)
    r.service_stats[name]=r.service_stats[name] or {}
    r.service_stats[name][key]=(r.service_stats[name][key] or 0)+(tonumber(amount) or 1)
    remember_window('service:'..tostring(name)..':'..tostring(key), amount)
  end
  return stat,service_stat
end
local function make_new(store,clock)
  local function remember_window(r, metric,amount)
    local key=math.floor((tonumber(clock.tick) or 0)/3600)
    local window=r.windows[key]
    if not window then
      window={};r.windows[key]=window
      for old in pairs(r.windows) do if tonumber(old) and tonumber(old)<key-30 then r.windows[old]=nil end end
    end
    window[metric]=(window[metric] or 0)+(tonumber(amount) or 1)
  end
  local function stat(key,amount)
    local r=root(store)
    r.stats[key]=(r.stats[key] or 0)+(tonumber(amount) or 1)
    remember_window(r,key,amount)
  end
  local function service_stat(name,key,amount)
    local r=root(store)
    local stats=r.service_stats[name]
    if not stats then stats={};r.service_stats[name]=stats end
    stats[key]=(stats[key] or 0)+(tonumber(amount) or 1)
    local metric="service:"..name..":"..key
    remember_window(r,metric,amount)
  end
  return stat,service_stat
end
local function workload(make,N)
  local store, clock = {}, {tick=5}
  local stat,service_stat=make(store,clock)
  local categories={'repair','combat','logistics','construction'}
  local keys={'due','run','budget_offered','processed','acted','failed'}
  local t=os.clock()
  for i=1,N do
    clock.tick=i*5
    local name=categories[i%4+1]
    for j=1,6 do service_stat(name,keys[j],j==5 and 0 or 1) end
    stat('services_run',1)
    if i%500==0 then stat('errors',1) end
  end
  return (os.clock()-t)*1000,store.tech_priests.broker
end
local n=50000
local old_ms,old_state=workload(make_old,n)
local new_ms,new_state=workload(make_new,n)
assert(old_state.stats.services_run==new_state.stats.services_run)
assert(old_state.stats.errors==new_state.stats.errors)
for name,bucket in pairs(old_state.service_stats) do
  for k,val in pairs(bucket) do assert(new_state.service_stats[name][k]==val,name..' '..k) end
end
for key,bucket in pairs(old_state.windows) do
  for k,val in pairs(bucket) do assert(new_state.windows[key][k]==val,k) end
  for k,val in pairs(new_state.windows[key]) do assert(bucket[k]==val,k) end
end
print(string.format('original: %.2f ms; optimized: %.2f ms; ratio %.2fx (%d pulses, 7 counters/pulse)',old_ms,new_ms,old_ms/new_ms,n))

