-- Regression 1506: broker telemetry/window counters preserve behavior through
-- scheduled service pulses, failures, dynamic budgets and retention rollover.
package.path = './tech-priests_src/?.lua;./tech-priests_src/?/init.lua;' .. package.path
storage = {tech_priests = {}}
game = {tick = 0}
local failures = 0
local B = arg and arg[1] and dofile(arg[1]) or require('scripts.core.runtime_tick_broker')
local invocations = {}
local function add(name, priority, category, fn)
  local s = B.register_service({name=name,priority=priority,category=category,
    interval=5,budget=4,fn=fn})
  assert(s and s.name == name)
  return s
end
add('repair-a',1,'repair',function(_,budget)
  invocations[#invocations+1]='repair-a:'..budget
  if game.tick==10 then B.note_metric('event_repair_submitted',125) end
  if game.tick%3 == 0 then
    return {processed=3,acted=2,blocked=1,detail='repaired'}
  end
  return {processed=0,acted=0,waiting=1,detail='cooldown'}
end)
add('repair-b',2,'repair',function(_,budget)
  invocations[#invocations+1]='repair-b:'..budget
  if game.tick==20 then B.note_metric('debug_output_unused', '2') end
  if game.tick == 15 then error('intentional-test-failure') end
  return true,'acted'
end)
add('combat-c',3,'combat',function(_,budget)
  invocations[#invocations+1]='combat-c:'..budget
  return 0,'waiting on combat'
end)
local root = B.root()
assert(root.stats and root.service_stats and root.windows)
assert(root.service_stats['repair-a'].registered == 1)
assert(root.windows[0]['service:repair-a:registered'] == 1)
B.note_metric('path_requests', '3')
B.note_metric('path_requests', 0)
B.note_metric('debug_output_unused', nil)
assert(B.rolling_sum('path_requests',1) == 3)
assert(root.external_stats.path_requests == 3)
assert(root.external_stats.debug_output_unused == 1)
for t=5,80,5 do game.tick=t; B.pulse({tick=t}) end
assert(root.stats.pulses == 16)
assert(root.stats.services_run == 48)
assert(root.stats.errors == 1)
assert(root.service_stats['repair-b'].errors == 1)
assert(root.service_stats['combat-c'].waiting == 16)
assert(root.windows[0]['service:repair-a:due'] == 16)
assert(root.windows[0]['service:repair-a:processed'] >= 16)
assert(root.windows[0]['service:repair-b:errors'] == 1)
assert(root.service_stats['repair-a'].budget_offered > 16 * 4,
  'repair pressure metric failed to boost subsequent service budgets')
assert(root.windows[0].event_repair_submitted == 125)
assert(root.windows[0].path_requests == 3)
assert(root.windows[0].debug_output_unused == 3)
-- Replacing the canonical root simulates load/reinitialization. New counters
-- must not keep writing into the old save's telemetry tables.
local previous = root
storage.tech_priests[B.storage_key] = nil
local fresh = B.root()
assert(fresh~=previous)
B.note_metric('path_requests',5)
assert(fresh.external_stats.path_requests == 5)
assert(previous.external_stats.path_requests == 3)
-- Tick rollovers + 30 historical windows. A previous save may already contain
-- the legacy rolling values, which must retain exactly the same keys.
game.tick=3600*2
B.note_metric('path_requests',2)
assert(fresh.windows[2].path_requests == 2)
game.tick=3600*35
B.note_metric('path_requests',7)
assert(fresh.windows[2] == nil, 'historical window beyond 30 retained')
assert(fresh.windows[35].path_requests == 7)
assert(B.rolling_sum('path_requests',1) == 7)
assert(B.rolling_sum('path_requests',2) == 7)
-- Snapshot deterministic critical data for old/new exact-broker comparison.
local function sorted_values(t, prefix, out)
  local keys={}
  for k in pairs(t or {}) do keys[#keys+1]=k end
  table.sort(keys, function(a,b)return tostring(a)<tostring(b)end)
  for _,key in ipairs(keys) do
    local path=(prefix or '')..'/'..tostring(key)
    local v=t[key]
    if type(v)=='table' then sorted_values(v,path,out)
    elseif type(v)=='number' or type(v)=='string' or type(v)=='boolean' then
      out[#out+1]=path..'='..tostring(v)
    end
  end
end
local out={}
sorted_values(previous.stats,'old-stats',out)
sorted_values(previous.service_stats,'old-services',out)
sorted_values(previous.windows,'old-windows',out)
sorted_values(previous.external_stats,'old-external',out)
sorted_values(fresh.windows,'fresh-windows',out)
sorted_values(fresh.external_stats,'fresh-external',out)
print('[broker-telemetry-window-1506] PASS',#invocations,'service calls',#out,'counter entries')
if arg and arg[1] then for _,line in ipairs(out)do print(line) end end
