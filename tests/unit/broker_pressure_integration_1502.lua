-- T1-09: services sharing a budget category reuse live pressure,
-- but a service that emits relevant pressure immediately updates later offers.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={}}
game={tick=5}
local B=require('scripts.core.runtime_tick_broker')
local old_roll=B.rolling_sum
local evaluations=0
B.rolling_sum=function(...)
  evaluations=evaluations+1
  return old_roll(...)
end
local offered={}
local function add(name,priority,fn)
  local service=B.register_service({name=name,category='repair',priority=priority,
    budget=4,interval=5,fn=fn})
  assert(service,'registration failed for '..name)
end
add('repair-a',10,function(_,budget)
  offered.a=budget
  if game.tick==5 then B.note_metric('event_repair_submitted',130) end
  return {processed=1,acted=0,detail='no-work'}
end)
add('repair-b',20,function(_,budget)
  offered.b=budget
  B.note_metric('non-pressure-diagnostic',17)
  return {processed=1,acted=0,detail='no-work'}
end)
add('repair-c',30,function(_,budget)
  offered.c=budget
  return {processed=1,acted=0,detail='no-work'}
end)
B.pulse({tick=5})
assert(offered.a==4 and offered.b==9 and offered.c==9,
  'mid-pulse event pressure did not immediately boost later budgets')
assert(evaluations==4,
  'repeated repair services recalculated live pressure despite no relevant changes')
assert(B.root().stats.adaptive_budget_boosts==2,
  'existing budget telemetry changed after memoization')
game.tick=10
B.pulse({tick=10})
assert(offered.a==9 and offered.b==9 and offered.c==9,
  'next pulse incorrectly discarded prior event pressure')
assert(evaluations==6,
  'new pulse failed to compute once or reused outdated prior-pulse values')
assert(B.root().stats.adaptive_budget_boosts==5)
print('[broker-pressure-integration-1502] PASS')
