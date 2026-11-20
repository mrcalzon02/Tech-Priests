-- Regression 1488 / Claude T1-06: expired scan-negative hints are pruned
-- and newly generated unique keys cannot grow a save without bounds.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
game={tick=100}
storage={tech_priests={scan_routing_0610={
  enabled=true,stats={},negative_until={
    expired_a=10,expired_b=50,old_1=120,old_2=130,
    old_3=140,old_4=150,old_5=160,old_6=170,
  }
}}}
local M=require("scripts.core.scan_routing_0610")
M.max_negative_entries=8
M.negative_trim_target=4
M.negative_sweep_interval=10
local r=M.root()
local n=0;for _ in pairs(r.negative_until)do n=n+1 end
assert(n==4 and r.negative_entry_count==4,
  "old save migration failed to remove expired/excess entries")
assert(r.negative_schema_1488==1 and r.stats.negative_expired_pruned==2,
  "migration did not record deleted expired keys")
assert(r.stats.negative_capacity_evicted==2,
  "migration did not trim oldest remaining negative hints")
local sweeps=r.stats.negative_sweeps
assert(M.root().stats.negative_sweeps==sweeps,
  "negative table rescanned unnecessarily on every root fetch")
assert(M.record_negative("repair","hot",400))
assert(M.should_skip_negative("repair","hot")==true)
for i=1,100 do
  assert(M.record_negative("repair","k"..i,200))
  assert(M.root().negative_entry_count<=8,
    "negative knowledge grew beyond configured entry cap")
end
assert(M.should_skip_negative("repair","hot")==true,
  "capacity eviction discarded the longest-lived negative hint")
assert(r.stats.negative_capacity_evicted>2,
  "sustained unique keys never exercised capacity eviction")
assert(M.clear_negative("repair","hot")==1)
assert(M.should_skip_negative("repair","hot")==false,
  "clear_negative left an active hint")
game.tick=1000
assert(M.root().negative_entry_count==0,
  "periodic root access did not prune expired negatives")
assert(next(r.negative_until)==nil,
  "expired negative hints persisted in save state")
assert(M.record_negative("acquire","just-created",5))
assert(M.should_skip_negative("acquire","just-created")==true)
game.tick=1006
assert(M.should_skip_negative("acquire","just-created")==false,
  "expired key was not removed on direct lookup")
local report=table.concat(M.report_lines(), " ")
assert(report:find("capacity_evicted=",1,true)
  and report:find("expired_pruned=",1,true),
  "status output did not expose negative-cache leak repairs")
print("[scan-negative-bounded-1488] PASS: migration, capacity, expiry, status")
