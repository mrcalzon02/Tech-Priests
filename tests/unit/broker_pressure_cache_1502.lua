package.path = './tech-priests_src/?.lua;./tech-priests_src/?/init.lua;' .. package.path
local C = require('scripts.core.broker_pressure_cache_1502')
local counts, pressure = {}, {repair=0,combat=3}
local function calculate(cat)
  counts[cat] = (counts[cat] or 0) + 1
  return pressure[cat] or 0
end
C.begin_pulse()
for i=1,10000 do assert(C.read('repair', calculate)==0) end
assert(counts.repair==1, 'identical category recalculated every service')
assert(C.read('combat', calculate)==3 and counts.combat==1)
C.note_external_metric('debug_output_ignored')
assert(C.read('repair', calculate)==0 and counts.repair==1, 'unrelated metric changed cached budget')
pressure.repair=40
C.note_external_metric('event_repair_submitted')
assert(C.read('repair', calculate)==40 and counts.repair==2, 'repair event did not invalidate pressure')
pressure.combat=99
C.note_external_metric('combat_wake_issued')
assert(C.read('combat', calculate)==99 and counts.combat==2, 'combat event did not invalidate pressure')
-- Relevant updates can occur during a broker callback and must affect the
-- next service in the same pulse, not only the next scheduled tick.
pressure.repair=45
C.note_external_metric('directed_wake_issued')
assert(C.read('repair', calculate)==45 and counts.repair==3)
C.begin_pulse()
assert(C.read(nil, calculate)==0, "nil category not handled")
assert(C.read('repair', calculate)==45 and counts.repair==4, 'new pulse reused stale category pressure')
-- Re-entrant/same-tick pulses must not retain the previous pulse's cache.
C.begin_pulse()
assert(C.read(nil, calculate)==0, "nil category not handled")
assert(C.read('repair', calculate)==45 and counts.repair==5)
print('[broker-pressure-cache-1502] PASS: pulse memo and immediate metric invalidation')
