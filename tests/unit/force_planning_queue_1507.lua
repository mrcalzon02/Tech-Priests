package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}};game={tick=0}
local Q=require("scripts.core.force_planning_queue")
local visits={}
local function worker(job,budget)
  assert(budget==1)
  visits[#visits+1]=job.force_index..":"..job.key
  job.state.count=(job.state.count or 0)+1
  if job.key=="empty"then return{processed=0,waiting=true}end
  return{processed=1,done=job.state.count==4,result=job.state.count}
end
Q.register("test",worker)
local a=assert(Q.submit(1,"test","a"));local b=assert(Q.submit(1,"test","b"))
Q.submit(2,"test","empty");Q.submit(2,"test","c")
local first=Q.pulse({tick=0},8)
assert(first.processed==8 and #visits==8)
assert(visits[1]=="1:a"and visits[2]=="2:empty"and visits[3]=="1:b"and visits[4]=="2:c","force/job fairness")
assert(Q.pulse({tick=0},99).processed==0,"same-tick duplicate advancement")
assert(Q.claim_tick("live",1)and not Q.claim_tick("live",1),"shared live cap")
local function clone(v,seen)
  if type(v)~="table"then assert(type(v)~="function"and type(v)~="thread");return v end
  seen=seen or{};if seen[v]then return seen[v]end
  local out={};seen[v]=out;for k,x in pairs(v)do out[clone(k,seen)]=clone(x,seen)end;return out
end
storage=clone(storage);package.loaded["scripts.core.force_planning_queue"]=nil
Q=require("scripts.core.force_planning_queue");Q.register("test",worker)
for t=1,4 do game.tick=t;local r=Q.pulse({tick=t},16);assert(r.processed<=16)end
local ready,status=Q.peek(1,"test","a");assert(status=="ready"and ready.result==4,"reload continuation")
assert(select(2,Q.peek(2,"test","c"))=="ready","no-action job starved peer")
assert(Q.retry(ready));assert(select(2,Q.peek(1,"test","a"))=="pending")
Q.forget(1,"test","a");assert(select(2,Q.peek(1,"test","a"))=="missing")
for i=1,64 do assert(Q.submit(3,"test",i))end
assert(select(2,Q.submit(3,"test",65))=="queue-full")
assert(Q.submit(4,"test",1),"one full force blocked another")
local calls=#visits;game.tick=100;local r=Q.pulse({tick=100},9999)
assert(r.processed<=16 and #visits-calls<=16,"global work cap")
Q.register("broken",function()error("intentional fixture fault")end)
Q.submit(5,"broken",1)
for t=101,115 do game.tick=t;Q.pulse({tick=t},16)end
local broken=Q.peek(5,"broken",1);assert(broken and broken.error and broken.status=="ready")
assert(Q.root().stats.failures>0,"handler failures hidden")
print("force_planning_queue_1507 PASS: per-force/job fairness, rejected work, full queues, reload, token caps, truthful failures")
