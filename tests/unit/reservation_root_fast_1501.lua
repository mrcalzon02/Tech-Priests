package.path = './tech-priests_src/?.lua;./tech-priests_src/?/init.lua;' .. package.path
local Fast = require('scripts.core.reservation_root_fast_1501')
local categories = {'repair','resource','pickup'}
local end_probes = 0
setmetatable(categories,{__index=function(_,k)
  if k==4 then end_probes=end_probes+1 end
end})
local store = {}
local r = Fast.get(store, 'work_reservations_0601', '0.1.674-dev', categories)
assert(r.enabled and r.position_scope_integrated and r.version == '0.1.674-dev')
assert(r.reservations.repair and r.reservations.resource and r.reservations.pickup)
assert(end_probes == 1, 'expected one-time normalization of categories')
r.stats.touched = 7
r.reservations.repair['unit:42']={pair_id='1',expires_tick=250}
for _=1,20000 do
  assert(Fast.get(store,'work_reservations_0601','0.1.674-dev',categories)==r)
end
assert(end_probes == 1, 'normalization repeated on every lookup')
assert(r.stats.touched==7 and r.reservations.repair['unit:42'], 'fast path lost saved state')
-- Test save replacement, not mutation of the canonical ownership contents.
local old = r
store.tech_priests.work_reservations_0601 = {
 version='old-save', enabled=false, position_scope_integrated=false,
 reservations={repair={['unit:7']={expires_tick=300}}},stats={retained=12}
}
r=Fast.get(store,'work_reservations_0601','0.1.674-dev',categories)
assert(r~=old and not r.enabled and r.position_scope_integrated and r.version=='0.1.674-dev')
assert(r.reservations.repair['unit:7'] and r.stats.retained==12)
assert(r.reservations.resource and r.reservations.pickup)
assert(end_probes == 2, 'replacement save did not normalize')
-- Existing save root whose nested tables are replaced must be normalized once.
r.reservations={}
local new=Fast.get(store,'work_reservations_0601','0.1.674-dev',categories)
assert(new==r and r.reservations.repair and r.reservations.pickup and end_probes==3)
r.stats={}
Fast.get(store,'work_reservations_0601','0.1.674-dev',categories)
assert(end_probes==4)
-- Dynamic categories are allocated by reservation.ensure_category; they are retained.
r.reservations.custom_work={['id:new']={expires_tick=999}}
assert(Fast.get(store,'work_reservations_0601','0.1.674-dev',categories).reservations.custom_work['id:new'])
assert(end_probes==4)
r.version='old-revision'
Fast.get(store,'work_reservations_0601','0.1.674-dev',categories)
assert(r.version=='0.1.674-dev' and end_probes==5, 'version/schema refresh skipped')
-- A newly initialized session must not alias an old root with the same namespace.
local next_save={}
local fresh=Fast.get(next_save,'work_reservations_0601','0.1.674-dev',categories)
assert(fresh~=r and fresh.reservations.repair and not fresh.reservations.repair['unit:7'])
assert(end_probes==6)
print('[reservation-root-fast-1501] PASS: memo, reload, normalization, persistence')
