-- Integration: unchanged duplicate submissions must preserve no-work cooldown.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}}
game={tick=100}
package.preload["scripts.core.work_reservations"]=function()
  return {
    root=function() return {enabled=true} end,
    is_claimed=function() return false end,
    claim=function() error("far order should not be selected") end,
    release_key=function() return true end,
  }
end
local Q=require("scripts.core.work_queue_authority")
local surface={valid=true,index=1}
local force={valid=true,index=1}
local target={valid=true,unit_number=500,
  position={x=1500,y=1500},surface=surface,force=force}
local pair={station={valid=true,unit_number=20,
  position={x=0,y=0},surface=surface,force=force},radius=10}
local opts={id="repair:test-500",priority=100,expires_tick=500}
local ok,why,order=Q.submit("repair",target,opts)
assert(ok and why=="submitted" and order)
local root=Q.root()
local function generation()
  return root.category_generations["1"]["1"].repair
end
local baseline=generation()
assert(baseline==1,"new work did not bump generation")
local _,status=Q.claim_nearest(pair,"repair",{search_radius=10})
assert(status=="none","far item must create no-work record")
local before_pair_cooldown=root.no_work_until["1"]["1"].repair["20"]
assert(before_pair_cooldown,"missing no-work record")
for i=1,1000 do
  assert(Q.submit("repair",target,{id=opts.id,priority=100,expires_tick=600+i}))
end
assert(generation()==baseline,"repeated duplicate damage invalidated all priest cooldowns")
assert(root.no_work_until["1"]["1"].repair["20"]==before_pair_cooldown,
  "duplicate submission wiped existing no-work record")
_,status=Q.claim_nearest(pair,"repair",{search_radius=10})
assert(status=="no-work-cooldown","unchanged duplicate woke a sleeping priest")
assert(Q.submit("repair",target,{id=opts.id,priority=200,expires_tick=1700}))
assert(generation()==baseline+1,"higher-priority work did not signal eligibility")
_,status=Q.claim_nearest(pair,"repair",{search_radius=10})
assert(status=="none","priority increase did not clear no-work cooldown")
assert((root.stats.no_work_cleared_by_generation or 0)>0)
game.tick=1701
assert(Q.submit("repair",target,{id=opts.id,priority=200,expires_tick=1800}))
assert(generation()==baseline+2,"expired order revival did not wake readers")
assert(Q.submit("repair",target,{id="repair:new",priority=100,expires_tick=1900}))
assert(generation()==baseline+3,"new distinct work did not wake readers")
assert(root.stats.duplicates_no_work_preserved_1490>=1000)
assert(root.stats.duplicates_meaningful_wake_1490>=2)
print("[work-queue-duplicate-integration-1490] PASS")
