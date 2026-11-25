-- Exercise the installed economy governor through the real broker. Verify
-- bounded bursts, fair progress, unchanged movement, and saved deadlines.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
storage = {tech_priests={}}
game = {tick=0}
local Broker = require("scripts.core.runtime_tick_broker")
local Economy = require("scripts.core.efficiency_economy_0598")
Economy.install()
local calls, order, per_tick = {}, {}, {}
local active_services = {
  movement="movement", repair="repair", consecration="consecration",
  combat="combat", dispatcher="dispatcher", lifecycle="lifecycle",
  order_queue_0469="scheduler",
  ["station-starvation-first-junior-0922"]="construction",
  inventory_steward_0357="inventory",
}
local function add(name, category, interval, due)
  return assert(Broker.register_service{
    name=name,category=category,interval=interval,next_due_tick=due,
    budget=1,dynamic_budget=false,
    fn=function()
      calls[name]=(calls[name] or 0)+1
      order[#order+1]=name..":"..game.tick
      per_tick[game.tick]=per_tick[game.tick] or {background=0,movement=0}
      if name=="movement" then
        per_tick[game.tick].movement=per_tick[game.tick].movement+1
      elseif not active_services[name] then
        per_tick[game.tick].background=per_tick[game.tick].background+1
      end
      return {processed=1,acted=1}
    end,
  })
end
for name, category in pairs(active_services) do add(name,category,5,0) end
for i=1,40 do add("poll-"..i,"discovery",5,1) end
for tick=5,100,5 do
  game.tick=tick; Broker.pulse{tick=tick}
  assert(per_tick[tick].background<=4,"background burst escaped admission cap")
  assert(per_tick[tick].movement==1,"movement was deferred")
end
for name in pairs(active_services) do
  assert(calls[name]==20,"active work progression lost its cadence: "..name)
end
for i=1,40 do assert(calls["poll-"..i]==2,"starved background service "..i) end
local state=storage.tech_priests.efficiency_economy_0598
assert(state.stats.broker_background_deferred>0)
assert(state.stats.broker_background_peak==4)
-- Loaded Lua modules are rebuilt; persistent governor state survives.
local due=Broker.services[1].next_due_tick
local recorded={}
for _,s in ipairs(Broker.services)do
  if s.category=="discovery" then recorded[s.name]=s.next_due_tick end
end
Broker.services={};Broker.dormant_services={}
for i=1,40 do add("poll-"..i,"discovery",5,0) end
game.tick=101
Economy.broker_plan(Broker.services,{tick=101},5)
for _,s in ipairs(Broker.services)do
  assert(s.next_due_tick==recorded[s.name],"save/load discarded polling deadline")
end
-- New, slower services acquire separate phases using the existing governor.
Broker.services={};Broker.dormant_services={}
storage.tech_priests.efficiency_economy_0598=nil
for i=1,40 do add("new-poll-"..i,"planning",120,0) end
game.tick=200
Economy.broker_plan(Broker.services,{tick=200},5)
local phases={}
for _,s in ipairs(Broker.services)do
  assert(s.next_due_tick>=200 and s.next_due_tick<320)
  phases[s.next_due_tick]=true
end
local n=0;for _ in pairs(phases)do n=n+1 end
assert(n>=10,"background start phases still collapse together")
-- Governor-off remains an explicit diagnostic fallback, not a lost service.
storage.tech_priests.efficiency_economy_0598.enabled=false
assert(Economy.broker_plan(Broker.services,{tick=200},5)==nil)
print("[broker-background-admission] PASS bounded four callbacks, 40 polls progress fairly, movement/repair/consecration/combat/dispatcher/lifecycle/queue/expansion/custody cadence intact, reload deadlines retained")
