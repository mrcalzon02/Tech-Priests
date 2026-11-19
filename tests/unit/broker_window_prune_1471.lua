-- Regression 1471: broker telemetry retains rolling windows without
-- scanning every history bucket for each service-result counter.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=0}
local Broker=require("scripts.core.runtime_tick_broker")
for _=1,500 do assert(Broker.note_metric("fixture",1)) end
local r=Broker.root()
assert(r.windows[0] and r.windows[0].fixture==500,
  "same-window service metrics were not accumulated")
assert(Broker.rolling_sum("fixture",1)==500,
  "rolling sum must include current telemetry")
game.tick=3600
Broker.note_metric("fixture",7)
assert(r.windows[1].fixture==7 and r.windows[0].fixture==500,
  "new window must preserve its predecessor")
assert(Broker.rolling_sum("fixture",2)==507,
  "two-window rolling total diverged")
for hour=2,33 do
  game.tick=hour*3600
  Broker.note_metric("fixture",hour)
end
assert(r.windows[0]==nil and r.windows[1]==nil,
  "expired windows were retained after new-hour rotation")
assert(r.windows[3] and r.windows[33],
  "valid 30-hour historical buckets were lost")
assert(Broker.rolling_sum("fixture",2)==65,
  "current + previous hour rolling total incorrect")
print("[broker-window-prune-1471] PASS")
