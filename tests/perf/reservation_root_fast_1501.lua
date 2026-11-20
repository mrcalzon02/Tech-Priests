package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local Fast=require('scripts.core.reservation_root_fast_1501')
local cats={'repair','sanctify','resource','construction','pickup','combat'}
local store={}
local function legacy()
 store.tech_priests=store.tech_priests or {}
 local r=store.tech_priests.work_reservations_0601 or {version='0.1.674-dev',enabled=true,position_scope_integrated=true,reservations={},stats={}}
 store.tech_priests.work_reservations_0601=r
 r.version='0.1.674-dev'
 if r.enabled==nil then r.enabled=true end
 r.position_scope_integrated=true
 r.reservations=r.reservations or {}
 r.stats=r.stats or {}
 for _,cat in ipairs(cats) do r.reservations[cat]=r.reservations[cat] or {} end
 return r
end
local warm=legacy(); local new=Fast.get(store,'work_reservations_0601','0.1.674-dev',cats)
assert(warm==new)
local N=100000
local function measure(fn)
 local start=os.clock()
 for i=1,N do local x=fn();assert(x==warm) end
 return (os.clock()-start)*1000
end
local before,after=measure(legacy),measure(function()return Fast.get(store,'work_reservations_0601','0.1.674-dev',cats)end)
print(string.format('[reservation-root-1501-perf] N=%d baseline_ms=%.3f fast_ms=%.3f speedup=%.2fx (synthetic Lua only)',N,before,after,before/after))
