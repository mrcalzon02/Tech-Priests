package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}};game={tick=0}
prototypes={item={furnace={place_result={name="stone-furnace"}}}}
local Q=require("scripts.core.force_planning_queue")
local Metadata=require("scripts.core.planning_metadata_1507")
local forces={}
for f=1,4 do
  forces[f]={valid=true,index=f,recipes={furnace={object_name="LuaRecipe",enabled=true,
    products={{name="stone-furnace"}}}}}
end
local completed=0
Q.register("metadata-dependent",function(job)
  if not Metadata.ready(forces[job.force_index]) then return {processed=1} end
  completed=completed+1;return {processed=1,done=true}
end)
for f=1,4 do for i=1,64 do assert(Q.submit(f,"metadata-dependent",i)) end end
assert(select(2,Q.submit(5,"metadata-dependent",1))=="queue-full")
assert(not Metadata.ready(forces[1]))
Metadata.reset() -- existing full ordinary queue must not deadlock its dependencies
assert(not Metadata.ready(forces[1]))
local maximum=Q.root().total
for t=1,1000 do
  game.tick=t*5
  local r=Q.pulse({tick=game.tick},16)
  assert(r.processed<=16,"reserved dependencies bypassed work budget")
  maximum=math.max(maximum,Q.root().total)
  if completed==256 then break end
end
assert(completed==256,"saturated dependent jobs did not resume after configuration reset")
assert(Q.root().dependencies==0,"completed dependency slots were not reclaimed")
assert(maximum<=Q.max_jobs+Q.max_dependencies,"dependency queue grew beyond fixed bound")
assert(Q.root().stats.failures==0)
print("planning_metadata_backpressure_1507 PASS: full force/global queues, configuration reset, dependency progress, bounded admission/work")
