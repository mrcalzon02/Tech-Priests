-- Diagnostic only: synthetic Lua microbenchmark of pair bucket rebuilds.
-- This does not measure Factorio TPS/UPS or native simulation time.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local queue_reads=0
package.preload["scripts.core.work_queue_authority"]=function()
  return {count=function(kind)
    assert(kind=="repair")
    queue_reads=queue_reads+1
    return 0
  end}
end
local Buckets=require("scripts.core.pair_bucket_registry")
local function run(n, forced, repetitions)
  storage={tech_priests={pairs_by_station={}}}
  game={tick=10}
  local map=storage.tech_priests.pairs_by_station
  for i=1,n do
    local pair={station={valid=true,unit_number=i},
      priest={valid=true,unit_number=i+10000}}
    map[i]=pair
    if i<=forced then assert(Buckets.force_bucket(pair,"visible",600,"perf-1474")) end
  end
  Buckets.rebuild("warmup")
  queue_reads=0
  collectgarbage("collect")
  local start=os.clock()
  for i=1,repetitions do Buckets.rebuild("microbench-1474") end
  local elapsed=os.clock()-start
  assert(Buckets.count("visible")==forced and Buckets.count("active")==forced,
    "benchmark fixture changed scheduling census")
  assert(queue_reads==repetitions,
    "shared repair-queue probe must run once per rebuild")
  print(string.format("[pair-bucket-perf-1474] priests=%d forced=%d rebuilds=%d avg_ms=%.4f queue_reads=%d", 
    n, forced, repetitions, elapsed*1000/repetitions, queue_reads))
end
run(100,60,80)
run(250,180,50)
run(500,400,25)
