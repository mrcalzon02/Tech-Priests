-- Regression 1472: preindexed forced buckets and once-per-rebuild queue reads.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=10}
local queue_reads=0
package.preload["scripts.core.work_queue_authority"]=function()
  return {count=function(kind)
    assert(kind=="repair","unexpected queue family")
    queue_reads=queue_reads+1
    return 0
  end}
end
local M=require("scripts.core.pair_bucket_registry")
local pairs=storage.tech_priests.pairs_by_station
for i=1,250 do
  pairs[i]={station={valid=true,unit_number=i},priest={valid=true,unit_number=10000+i}}
end
for i=1,180 do assert(M.force_bucket(pairs[i],"visible",600,"test")) end
assert(M.force_bucket(pairs[181],"repair",600,"test"))
pairs[182].mode="combat"
pairs[183].mode="logistics"
local root=M.root()
root.forced_buckets["retired:visible"]={bucket="visible",until_tick=2}
root.forced_buckets["malformed-key"]={bucket="movement",until_tick=500}
local rebuilt=M.rebuild("1472-initial")
assert(rebuilt.last_total==250 and rebuilt.last_valid==250)
assert(M.count("visible")==180,"forced visible pairs lost")
assert(M.count("active")==183,"forced and natural active buckets changed")
assert(M.count("repair")==1,"forced repair pair lost")
assert(M.count("combat")==1 and M.count("logistics")==1,"natural classification changed")
assert(queue_reads==1,"shared repair queue queried more than once per rebuild")
assert(root.forced_buckets["retired:visible"]==nil
  and root.forced_buckets["malformed-key"]==nil,"expired/malformed forced records leaked")
assert(rebuilt.last_forced_active==181 and rebuilt.last_forced_pruned==2,
  "preindexed forced bookkeeping mismatch")
local each_count=0
local acted,count=M.each("visible",250,function(pair,id)
  assert(pair and id,"invalid forced pair reference")
  each_count=each_count+1
  return true
end)
assert(acted==180 and count==180 and each_count==180,
  "forced iteration changed")
game.tick=611
M.rebuild("1472-expired")
assert(M.count("visible")==0 and M.count("repair")==0,
  "expired forced bucket continued activating priest")
assert(M.count("active")==2 and M.count("combat")==1 and M.count("logistics")==1,
  "expired bucket cleanup disturbed unrelated activity")
assert(next(root.forced_buckets)==nil and root.stats.expired_forced_records==183,
  "expired forced storage did not drain")
assert(queue_reads==2,"shared repair eligibility not refreshed on rebuild")
print("[pair-bucket-forced-index-1472] PASS")
