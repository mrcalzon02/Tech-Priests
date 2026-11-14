-- Execute the actual production fanout function, including the queue contract.
local f=assert(io.open("tech-priests_src/scripts/generated/control_legacy_part_018.lua"))
local source=f:read("*a");f:close()
local fn=assert(source:match("(function tech_priests_0284_recipe_fanout.-)\nTECH_PRIESTS_0284_PRE_ACQUIRE"))
assert(load(fn))()
tech_priests_0286_valid_pair=function()return true end
tech_priests_0284_recipe_missing_ingredients=function()return{{name="iron-plate",count=4}}end
tech_priests_0252_create_assignment=function()error("unexpected child deployment")end
tech_priests_0252_find_subordinate_pair=function()return nil end
tech_priests_0284_assignment_already_requested=function()return false end
tech_priests_0286_now=function()return 100 end
TECH_PRIESTS_0284_MAX_FANOUT_ASSIGNMENTS=3
TECH_PRIESTS_0285_TASK_PRIORITY={logistics=600}
local acquisitions=0
tech_priests_emergency_operation_acquire_item_0185=function()acquisitions=acquisitions+1 end
for _,mode in ipairs({"rejected","queued","active","legacy"})do
 local p={order_queue_0469={current={item="firearm-magazine",status="active"}}}
 if mode=="legacy"then p.order_queue_0469=nil end
 tech_priests_0285_assign_task=function(pair,task)
  if mode=="active"then pair.order_queue_0469.current={item=task.item,status="active",task=task}end
  return mode~="rejected"
 end
 acquisitions=0
 local result=tech_priests_0284_recipe_fanout(p,"firearm-magazine",{},"test")
 local started=mode=="active"or mode=="legacy"
 assert(result==started,mode)
 assert(acquisitions==(started and 1 or 0),"unowned acquisition: "..mode)
 assert((p.last_recipe_fanout_item_0284~=nil)==started,"false assignment progress")
 if not started then
  assert(p.order_queue_0469.current.item=="firearm-magazine","incumbent changed")
  assert(p.last_recipe_fanout_refusal_0284.missing=="iron-plate")
 end
end
print("PASS fanout refuses rejected/queued self-work and preserves its incumbent")
